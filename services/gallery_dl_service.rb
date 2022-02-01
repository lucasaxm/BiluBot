require 'telegram/bot'
require 'youtube-dl'
require 'timeout'
require_relative '../config/gallery_dl_config'
require_relative '../lib/gallery_dl'
require_relative '../logger/logging'

class GalleryDLService
  include Logging

  def initialize(bilu, message, reddit_post = nil)
    GalleryDLConfig.save_config
    @bilu = bilu
    @message = message
    @dir = './gallerydl'
    @uploads_chat_id = ENV['BILU_UPLOADS_TELEGRAM_ID']
    @reddit_post = reddit_post
  end

  def clean_dir
    FileUtils.rm(dir) if File.exist?(dir)
  end

  def fallback_youtubedl
    logger.info 'Retrying with YoutubeDL'
    filepath = "#{@dir}/#{@message.message_id}"
    options = {
      format: 'bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]',
      output: filepath
    }
    result = Timeout.timeout(300, nil, "YoutubeDL.download timeout. url=[#{@message.text}] options=[#{options}]") do
      if !@reddit_post.nil? && !@reddit_post.url.nil?
        YoutubeDL.download @reddit_post.url, options
      else
        YoutubeDL.download @message.text, options
      end
    end
    if result.nil?
      logger.error 'Failed to download video using youtube-dl'
      raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error' unless @reddit_post.nil?

      return
    end
    result.information[:category] = result.information[:extractor]
    new_filepath = "#{filepath}.#{result.information[:ext]}"
    FileUtils.mv(filepath, new_filepath)
    result.information[:local_path] = new_filepath
    send_gallerydl_media(GalleryDL::Media.new(@message.text, {}, [result.information]))
  rescue => e
    raise e if @reddit_post.nil?

    logger.error e.message
    raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error'
  ensure
    logger.warn "killing youtube-dl #{`pkill -e youtube-dl`}"
    logger.warn "cleaning files #{filepath} #{`rm -fv #{filepath}`}"
    logger.warn "cleaning directories #{filepath} #{`rm -rfv #{filepath}`}"
  end

  def send_media
    logger.info "Trying to send #{@message.text} as media"
    options = {}
    result = Timeout.timeout(300, nil, "GalleryDL.download timeout. url=[#{@message.text}] options=[#{options}]") do
      if @reddit_post.nil?
        GalleryDL.download @message.text, options
      else
        permalink_result = GalleryDL.download "reddit.com#{@reddit_post.permalink}", options
        if permalink_result.information.empty? && !@reddit_post.url.nil?
          GalleryDL.download @reddit_post.url, options
        else
          permalink_result
        end
      end
    end
    if result.nil? || result.information.nil? || result.information.any? { |r| r[:local_path].nil? }
      logger.error 'Failed to download media using gallery-dl'
      raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error' unless @reddit_post.nil?

      return
    end
    send_gallerydl_media(result)
  rescue => e
    gallery_dl_errors = e.message.each_line.grep /\[error\]/
    if gallery_dl_errors.empty?
      logger.warn "Failed to send media. message: #{e.message}"
      raise Telegram::Bot::Exceptions::Base, 'GalleryDL Service error' unless @reddit_post.nil?
    else
      logger.warn "Failed to send media. message: #{gallery_dl_errors}"
      fallback_youtubedl
    end
  ensure
    logger.warn "killing gallery-dl #{`pkill -e gallery-dl`}"
    logger.warn "cleaning gallery-dl local dir #{`rm -rf gallery-dl`}"
  end

  def build_caption(information)
    case information[:category].downcase
    when 'twitter'
      "#{information[:author][:nick]}(@#{information[:author][:name]}):\n#{information[:content]}"
    when 'instagram'
      "#{information[:fullname]}(@#{information[:username]}):\n#{information[:description]}"
    when 'tiktok'
      "#{information[:title]}:\n#{information[:description]}"
    when 'youtube'
      "#{information[:title]}:\n#{information[:description]}"
    when 'mangadex'
      "#{information[:manga]}\nChapter #{information[:chapter]}"
    when 'reddit'
      "#{information[:over_18] ? "\u{1F51E} NSFW " : ''}#{information[:spoiler] ? "\u{26A0} SPOILER" : ''}\n#{information[:title]}"
    else
      if @reddit_post.nil?
        information[:category]
      else
        "#{@reddit_post.over_18 ? "\u{1F51E} NSFW " : ''}#{@reddit_post.spoiler ? "\u{26A0} SPOILER" : ''}\n#{@reddit_post.title}"
      end
    end[0..1023]
  end

  def send_gallerydl_media(result)
    logger.info "#{result.information.size} medias found from #{@message.text}"
    first_caption = nil
    messages_sent = []
    result.information.each_slice(10) do |information_group|
      media = information_group.map do |information|
        filepath = information[:local_path]
        begin
          logger.info("adding #{filepath} to media group")
          if @bilu.is_local_image?(filepath)
            caption = build_caption(information)
            if first_caption.nil?
              first_caption = caption
              local_photo_media(filepath, first_caption)
            elsif first_caption == caption
              local_photo_media(filepath)
            else
              local_photo_media(filepath, caption)
            end
          else
            file_size_mb = @bilu.file_size_mb(filepath)
            if (File.extname(filepath) == '.mp4') && (file_size_mb < 20)
              caption = build_caption(information)
              if first_caption.nil?
                first_caption = caption
                local_video_media(filepath, first_caption)
              elsif first_caption == caption
                local_video_media(filepath)
              else
                local_video_media(filepath, caption)
              end
            else
              error_msg = "Error sending file #{filepath}:#{file_size_mb}MB"
              logger.warn(error_msg)
              @bilu.log_to_channel(error_msg, @message)
            end
          end
        ensure
          FileUtils.rm(filepath) if File.exist?(filepath)
          FileUtils.rm("#{filepath}.json") if File.exist?("#{filepath}.json")
        end
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

  def upload_to_telegram(type, data)
    response = @bilu.bot.api.send "send_#{type}", {
      'chat_id' => @uploads_chat_id,
      type => data
    }
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
    end
  end

  def local_photo_media(filepath, caption = nil)
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

  def send_local_video(file_path, caption)
    logger.debug("START - Sending #{file_path} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: @message.chat.id,
      action: 'upload_video'
    )
    upload = Faraday::UploadIO.new(file_path, 'video/mp4')
    @bilu.bot.api.send_video(
      chat_id: @message.chat.id,
      video: upload,
      caption: caption,
      reply_to_message_id: @message.message_id
    )
    upload.close unless upload.nil?
    logger.debug("END - Sending #{file_path} as video through telegram API.")

  end

  private

  def local_video_media(filepath, caption = nil)
    upload = Faraday::UploadIO.new(filepath, 'video/mp4')
    media = {
      type: 'video',
      media: upload_to_telegram('video', upload)
    }
    media[:caption] = caption unless caption.nil?
    media
  end

end