require 'telegram/bot'
require 'youtube-dl'
require 'timeout'
require_relative '../config/gallery_dl_config'
require_relative '../lib/gallery_dl'
require_relative '../logger/logging'

class GalleryDLService
  include Logging

  def initialize(bilu, message)
    GalleryDLConfig.save_config
    @bilu = bilu
    @message = message
    @dir = './gallerydl'
    @uploads_chat_id = ENV['BILU_UPLOADS_TELEGRAM_ID']
  end

  def clean_dir
    FileUtils.rm(dir) if File.exist?(dir)
  end

  def fallback_youtubedl
    logger.info 'Retrying with YoutubeDL'
    filepath = "#{@dir}/#{@message.message_id}"
    options = {
      format: 'best[filesize<?20M]/best',
      output: filepath
    }
    result = Timeout::timeout(300, nil, "YoutubeDL.download timeout. url=[#{@message.text}] options=[#{options}]") do
      YoutubeDL.download @message.text, options
    end
    if result.nil?
      logger.error 'Failed to download video using youtube-dl'
      return
    end
    result.information[:category] = result.information[:extractor]
    new_filepath = "#{filepath}.#{result.information[:ext]}"
    FileUtils.mv(filepath, new_filepath)
    result.information[:local_path] = new_filepath
    send_gallerydl_media(GalleryDL::Media.new(@message.text, {}, [result.information]))
  ensure
    logger.warn `pkill -e youtube-dl`
    logger.warn `rm -fv #{filepath}`
    logger.warn `rm -rfv #{filepath}`
  end

  def send_media
    logger.info "Trying to send #{@message.text} as media"
    options = {}
    result = Timeout::timeout(300, nil, "GalleryDL.download timeout. url=[#{@message.text}] options=[#{options}]") do
      GalleryDL.download @message.text, options
    end
    if result.nil? || result.information.nil? || result.information.any? { |r| r[:local_path].nil? }
      logger.error 'Failed to download media using gallery-dl'
      return
    end
    send_gallerydl_media(result)
  rescue => e
    gallery_dl_errors = e.message.each_line.grep /\[error\]/
    if gallery_dl_errors.empty?
      logger.warn "Failed to send media. message: #{e.message}"
    else
      logger.warn "Failed to send media. message: #{gallery_dl_errors}"
      fallback_youtubedl
    end
  ensure
    logger.warn `pkill -e gallery-dl`
    logger.warn `rm -rf gallery-dl`
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
    else
      information[:category]
    end[0..1023]
  end

  def send_gallerydl_media(result)
    logger.info "#{result.information.size} medias found from #{@message.text}"
    group_caption = build_caption(result.information.first) if result.information.length > 1
    result.information.each_slice(10) do |information_group|
      media = information_group.map do |information|
        filepath = information[:local_path]
        begin
          logger.info("adding #{filepath} to media group")
          if @bilu.is_local_image?(filepath)
            caption = build_caption(information)
            group_caption = nil unless group_caption == caption
            local_photo_media(filepath, caption)
          else
            file_size_mb = @bilu.file_size_mb(filepath)
            if (File.extname(filepath) == '.mp4') && (file_size_mb < 20)
              caption = build_caption(information)
              group_caption = nil unless group_caption == caption
              local_video_media(filepath, caption)
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
      @bilu.bot.api.send_media_group(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        media: media
      )
    end
    return if group_caption.nil?

    @bilu.bot.api.send_message(
      chat_id: @message.chat.id,
      reply_to_message_id: @message.message_id,
      text: group_caption
    )
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

  def local_photo_media(filepath, caption)
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
    {
      type: 'photo',
      media: upload_to_telegram('photo', upload),
      caption: caption
    }
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

  def local_video_media(filepath, caption)
    upload = Faraday::UploadIO.new(filepath, 'video/mp4')
    {
      type: 'video',
      media: upload_to_telegram('video', upload),
      caption: caption
    }
  end

end