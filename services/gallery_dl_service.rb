require 'telegram/bot'
require 'youtube-dl'
require 'timeout'
require_relative '../config/gallery_dl_config'
require_relative '../lib/gallery_dl'
require_relative '../logger/logging'

class GalleryDLService
  include Logging

  def initialize(bilu)
    GalleryDLConfig.save_config
    @bilu = bilu
  end

  def fallback_youtubedl(message)
    logger.info 'Retrying with YoutubeDL'
    filepath = "#{message.message_id}"
    options = {
        format: 'best[filesize<?20M]/best',
        output: filepath
    }
    result = Timeout::timeout(20, nil, "YoutubeDL.download timeout. url=[#{message.text}] options=[#{options}]") do
      YoutubeDL.download message.text, options
    end
    if result.nil?
      logger.error 'Failed to download video using youtube-dl'
      return
    end
    result.information[:category] = result.information[:extractor]
    new_filepath = "#{filepath}.#{result.information[:ext]}"
    FileUtils.mv(filepath, new_filepath)
    result.information[:local_path] = new_filepath
    send_gallerydl_media(message, GalleryDL::Media.new(message.text, {}, [result.information]))
  rescue Terrapin::ExitStatusError => e
    logger.warn "Failed to send video. message: #{e.message.each_line.grep /^ERROR/}"
  rescue Timeout::Error => e
    @bilu.log_to_channel("Exception Class: [#{e.class.name}]\nException Message: [#{e.message}'].", message)
  end

  def send_media(message)
    logger.info "Trying to send #{message.text} as media"
    options = {}
    result = Timeout::timeout(20, nil, "GalleryDL.download timeout. url=[#{message.text}] options=[#{options}]") do
      GalleryDL.download message.text, options
    end
    if result.nil? || result.information.nil? || result.information.any? { |r| r[:local_path].nil? }
      logger.error 'Failed to download media using gallery-dl'
      return
    end
    send_gallerydl_media(message, result)
  rescue Terrapin::ExitStatusError => e
    logger.warn "Failed to send media. message: #{e.message.each_line.grep /\[error\]/}"
    fallback_youtubedl(message)
  rescue Timeout::Error => e
    @bot.log_to_channel("Exception Class: [#{e.class.name}]\nException Message: [#{e.message}'].", message)
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
    else
      information[:category]
    end[0..1023]
  end

  def send_gallerydl_media(message, result)
    logger.info "#{result.information.size} medias found from #{message.text}"
    result.information.each do |information|
      filepath = information[:local_path]
      if @bilu.is_local_image?(filepath)
        send_local_photo(filepath, build_caption(information), message)
      else
        file_size_mb = @bilu.file_size_mb(filepath)
        if (File.extname(filepath) == '.mp4') && (file_size_mb < 20)
          send_local_video(filepath, build_caption(information), message)
        else
          error_msg = "Error sending file #{filepath}:#{file_size_mb}MB"
          logger.warn(error_msg)
          @bilu.log_to_channel(error_msg, message)
        end
      end
      FileUtils.rm(filepath) if File.exists?(filepath)
      FileUtils.rm("#{filepath}.json") if File.exists?("#{filepath}.json")
    end
  end

  def send_local_photo(file_path, caption, message)
    logger.debug("START - Sending #{file_path} as photo through telegram API.")
    file_ext = File.extname(file_path)
    if file_ext == '.jpeg' || file_ext == '.jpg'
      upload = Faraday::UploadIO.new(file_path, 'image/jpeg')
    elsif file_ext == '.png'
      upload = Faraday::UploadIO.new(file_path, 'image/png')
    elsif file_ext == '.webp'
      upload = Faraday::UploadIO.new(file_path, 'image/webp')
    else
      logger.error "file extension #{file_ext} is not valid"
      return
    end

    @bilu.bot.api.send_photo(
        chat_id: message.chat.id,
        photo: upload,
        caption: caption,
        reply_to_message_id: message.message_id
    )
    upload.close unless upload.nil?
    logger.debug("END - Sending #{file_path} as photo through telegram API.")

  end

  def send_local_video(file_path, caption, message)
    logger.debug("START - Sending #{file_path} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_video'
    )
    upload = Faraday::UploadIO.new(file_path, "video/mp4")
    @bilu.bot.api.send_video(
        chat_id: message.chat.id,
        video: upload,
        caption: caption,
        reply_to_message_id: message.message_id
    )
    upload.close unless upload.nil?
    logger.debug("END - Sending #{file_path} as video through telegram API.")

  end


end