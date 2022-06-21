require 'telegram/bot'
require 'timeout'
require_relative "#{__dir__}/../config/gallery_dl_config"
require_relative "#{__dir__}/../lib/gallery_dl"
require_relative "#{__dir__}/../logger/logging"
require 'mime/types'
class GalleryDLService
  include Logging

  def initialize(bilu, message, reddit_post = nil)
    GalleryDLConfig.save_config
    @bilu = bilu
    @message = message
    @dir = "#{__dir__}/#{Thread.current.object_id}"
    @timeout = 300
    @uploads_chat_id = ENV['BILU_UPLOADS_TELEGRAM_ID']
    @reddit_post = reddit_post
  end

  # formats: audio or video
  def search_and_send format
    search_query = "ytsearch:#{@message.text.split(' ')[1..-1].join(' ')}"
    logger.info "Searching for '#{search_query}' and sending as #{format}"
    options = {
      destination: @dir
    }
    if format == 'audio'
      options[:o] = 'extractor.ytdl.YoutubeSearch.format=bestaudio[ext=m4a][filesize<50M]/bestaudio[ext=m4a][filesize_approx<50M]'
    end
    result = GalleryDL.download search_query, @timeout, options
    if ((result.nil?) || (result.information.nil?) || (result.information.any? { |r| r.nil? || r[:local_path].nil? }))
      logger.error 'Failed to download media using gallery-dl'
      @bilu.bot.api.send_message(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        text: 'Failed to download media'
      )
      raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error'

      return
    end
    logger.info "#{result.information.size} medias found from #{search_query}"
    send_gallerydl_media(result)
  rescue GalleryDL::GalleryDlError, GalleryDL::GalleryDlTimeout => e
    @bilu.log_to_channel(e.message, @message)
    raise Telegram::Bot::Exceptions::Base, "GalleryDL Service error #{e.class}" unless @reddit_post.nil?
  ensure
    logger.warn "cleaning thread local dir #{`rm -rf #{@dir}`.inspect}"
  end

  def send_media
    unless @reddit_post.nil?
      send_media_from_url @reddit_post.url
      return
    end
    urls = extract_urls @message
    errors = []
    urls.each do |url|
      begin
        send_media_from_url url
      rescue Telegram::Bot::Exceptions::Base => e
        errors << {
          url: url,
          exception: e
        }
        next
      end
    end
#    if ((!errors.empty?) && (@reddit_post.nil?))
    if !errors.empty?
      raise Telegram::Bot::Exceptions::Base, "GalleryDL Service error #{errors}" 
    end
  end

  def send_media_from_url url
    options = {
      destination: @dir
    }
    result = if @reddit_post.nil?
      logger.info "Trying to send #{url} as media"
      GalleryDL.download url, @timeout, options
    else
      permalink = "reddit.com#{@reddit_post.permalink}"
      logger.info "Trying to send #{permalink} as media"
      permalink_result = GalleryDL.download permalink, @timeout, options
      if permalink_result.information.empty? && !@reddit_post.url.nil?
        logger.info "Trying to send #{@reddit_post.url} as media"
        GalleryDL.download @reddit_post.url, @timeout, options
      else
        permalink_result
      end
    end
    if ((result.nil?) || (result.information.nil?) || (result.information.any? { |r| r.nil? || r[:local_path].nil? }))
      logger.error 'Failed to download media using gallery-dl'
      raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error' unless @reddit_post.nil?

      return
    end
    logger.info "#{result.information.size} medias found from #{url}"
    send_gallerydl_media(result)
  rescue GalleryDL::GalleryDlError, GalleryDL::GalleryDlTimeout => e
    @bilu.log_to_channel(e.message, @message)
    raise Telegram::Bot::Exceptions::Base, "GalleryDL Service error #{e.class}" unless @reddit_post.nil?
  ensure
    logger.warn "cleaning thread local dir #{`rm -rf #{@dir}`.inspect}"
  end

  def build_caption(information)
    full_caption = case information[:category].downcase
    when 'twitter'
      "#{information[:author][:nick]}(@#{information[:author][:name]}):\n#{information[:content]}"
    when 'instagram'
      "#{information[:fullname]}(@#{information[:username]}):\n#{information[:description]}"
    when 'tiktok'
      "#{information[:title]}:\n#{information[:description]}"
    when 'mangadex'
      "#{information[:manga]}\nChapter #{information[:chapter]}"
    when 'reddit'
      "#{information[:over_18] ? "\u{1F51E} NSFW " : ''}#{information[:spoiler] ? "\u{26A0} SPOILER" : ''}\n#{information[:title]}"
    when 'ytdl'
      case information[:subcategory].downcase
      when 'youtube', 'youtubesearch'
        "#{information[:title]}:\n#{information[:description]}" unless information[:extension] == 'm4a'
      when 'facebook'
        if information[:fulltitle].downcase == 'watch'
          "#{information[:uploader]}:\n#{information[:description]}"
        else
          information[:fulltitle]
        end
      when 'twitchvod'
        "#{information[:uploader]}:\n#{information[:fulltitle]}"
      when 'steam'
        "#{information[:webpage_url_basename]}"
      when 'generic'
        information[:fulltitle]
      else
        information[:subcategory]
      end
    else
      if @reddit_post.nil?
        information[:category]
      else
        "#{@reddit_post.over_18? ? "\u{1F51E} NSFW " : ''}#{@reddit_post.spoiler? ? "\u{26A0} SPOILER" : ''}\n#{@reddit_post.title}"
      end
    end
    if (!full_caption.nil?) && (full_caption.length > 150)
      return full_caption[0..296]+'...'
    end

    full_caption
  end

  def send_gallerydl_media(result)
    first_caption = nil
    messages_sent = []
    result.information.each_slice(10) do |information_group|
      media = information_group.map do |information|
        uploaded_media = local_media information
        logger.info("adding #{uploaded_media[:media]} to media group")
        if first_caption.nil?
          first_caption = uploaded_media[:caption]
        elsif !uploaded_media[:caption].nil? && first_caption == uploaded_media[:caption]
          uploaded_media.delete(:caption)
        end
        uploaded_media
      end
      response = @bilu.bot.api.send_media_group(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        media: media
      )
      messages_sent.push(*response['result'])
    end
    return if @reddit_post.nil?

    @bilu.bot.api.send_message({
                                 chat_id: @message.chat.id,
                                 reply_to_message_id: messages_sent.first['message_id'],
                                 text: "#{messages_sent.size} media#{'s' if messages_sent.size > 1} found",
                                 reply_markup: RedditService.reddit_post_reply_markup(@reddit_post)
                               })
  end

  def upload_to_telegram(type, upload, options={})
    payload = {
      'chat_id' => @uploads_chat_id,
      'supports_streaming' => true,
      type => upload
    }
    payload.merge! options
    logger.debug "uploading media to telegram. payload:#{payload.to_json}"
    response = @bilu.bot.api.send "send_#{type}", payload
    response_type = (['audio','document','photo','sticker','video','video_note','voice'] & response['result'].keys)
    type = response_type.first unless response_type.empty?
    if response['result'][type].is_a? Array
      response['result'][type].last['file_id']
    else
      response['result'][type]['file_id']
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
    if e.error_code == 429
      sleep_time = JSON.parse(e.response.body)['parameters']['retry_after']
      logger.debug "retrying after #{sleep_time}"
      sleep(sleep_time)
      retry
    else
      raise e
    end
  end

  private

  def local_media(information)
    case get_file_type information[:local_path]
    when 'image'
      local_photo_media(information)
    when 'video'
      local_video_media(information)
    when 'audio'
      local_audio_media(information)
    end
  end

  def local_photo_media(information)
    filepath = information[:local_path]
    caption = build_caption(information)
    file_ext = File.extname(filepath)
    case file_ext
    when '.jpeg', '.jpg'
      upload = Faraday::UploadIO.new(filepath, 'image/jpeg')
    when '.png'
      upload = Faraday::UploadIO.new(filepath, 'image/png')
    when '.webp'
      upload = Faraday::UploadIO.new(filepath, 'image/webp')
    else
      logger.error "file extension #{file_ext} is not valid"
      return
    end
    media = {
      type: 'photo',
      media: upload_to_telegram('photo', upload)
    }
    media[:caption] = caption unless caption.nil?
    media
  end

  def local_video_media(information)
    filepath = information[:local_path]
    caption = build_caption(information)
    upload = Faraday::UploadIO.new(filepath, 'video/mp4')
    options = {}
    thumb = filepath.split('.')[0..-2].join('.')+'.jpg'
    if File.exists? thumb
      options['thumb'] = Faraday::UploadIO.new(thumb, 'image/jpeg')
    end
    options['duration'] = information[:duration].to_i unless information[:duration].nil?
    media = {
      type: 'video',
      media: upload_to_telegram('video', upload, options),
      supports_streaming: true
    }
    media[:caption] = caption unless caption.nil?
    media
  end

  def local_audio_media(information)
    filepath = information[:local_path]
    caption = build_caption(information)

    upload = Faraday::UploadIO.new(filepath, 'audio/m4a')
    options = {}
    thumb = filepath.split('.')[0..-2].join('.')+'.jpg'
    if File.exists? thumb
      options['thumb'] = Faraday::UploadIO.new(thumb, 'image/jpeg')
    end
    if (information[:category].downcase == 'ytdl') && (['youtube','youtubesearch'].include? information[:subcategory].downcase)
      options['performer'] = information[:channel]
      options['title'] = information[:title]
      options['duration'] = information[:duration]
    end
    media = {
      type: 'audio',
      media: upload_to_telegram('audio', upload, options),
      supports_streaming: true
    }
    media[:caption] = caption unless caption.nil?

    media
  end

  # returns audio, video or image
  def get_file_type(path)
    #puts "mime type: #{MIME::Types.type_for(path)}"
    #puts "mime type filtered: #{MIME::Types.type_for(path).group_by{|x| x.try(:media_type)}.max_by{|x| x.last.length}.first}"
    MIME::Types.type_for(path).group_by{|x| x.try(:media_type)}.max_by{|x| x.last.length}.first
    #ffmpeg_movie = FFMPEG::Movie.new(path)
    #return 'video' unless ffmpeg_movie.frame_rate.nil?

    #return 'audio' unless ffmpeg_movie.audio_codec.nil?

    #return 'image'
  end

  def extract_urls(msg)
    msg['entities'].select do |entity|
      entity['type'] == 'url' || entity['type'] == 'text_link'
    end.map do |url_entity|
      if url_entity['type'] == 'url'
        msg['text'].chars.map do |x|
          x.bytes.each_slice(2).to_a
        end.flatten(1)[url_entity['offset'], url_entity['offset'] + url_entity['length']].flatten.pack('C*')
      else # text_link
        url_entity['url']
      end
    end
  end

end
