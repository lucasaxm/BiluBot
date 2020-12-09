require 'telegram/bot'
require 'youtube-dl'
require_relative '../lib/gallery_dl'
require_relative '../logger/logging'

class GalleryDLService
  include Logging

  def initialize(bilu)
    @bilu = bilu
  end

  def fallback_youtubedl(message)
    logger.info 'Retrying with YoutubeDL'
    filepath = "#{message.message_id}"
    options = {
        format: 'best[filesize<?20M]/best',
        output: filepath
    }
    result = YoutubeDL.download message.text, options
    if result.nil?
      logger.error 'Failed to download video using youtube-dl'
      return
    end
    result.information[:category] = result.information[:extractor]
    new_filepath = "#{message.message_id}.mp4"
    @bilu.transcode_video_to_mp4(filepath, new_filepath)
    send_local_video(new_filepath, build_caption(result.information), message)
    FileUtils.rm([filepath, new_filepath])
  rescue Terrapin::ExitStatusError => e
    logger.warn "Failed to send video. message: #{e.message.each_line.grep /^ERROR/}"
  end

  def send_media(message)
    logger.info "Trying to send #{message.text} as media"
    options = {}
    result = GalleryDL.download message.text, options
    if result.nil? || result.information.nil? || result.information.any? { |r| r[:local_path].nil? }
      logger.error 'Failed to download media using gallery-dl'
      return
    end
    send_gallerydl_media(message, result)
  rescue Terrapin::ExitStatusError => e
    logger.warn "Failed to send video. message: #{e.message.each_line.grep /\[error\]/}"
    fallback_youtubedl(message)
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
    end
  end

  def send_gallerydl_media(message, result)
    logger.info "#{result.information.size} medias found from #{message.text}"
    result.information.each do |information|
      filepath = information[:local_path]
      if @bilu.is_local_image?(filepath)
        send_local_photo(filepath, build_caption(information), message)
      else
        new_filepath = "#{message.message_id}.mp4"
        @bilu.transcode_video_to_mp4(filepath, new_filepath)
        send_local_video(new_filepath, build_caption(information), message)
        FileUtils.rm(new_filepath)
      end
      FileUtils.rm(%W[#{filepath} #{filepath}.json])
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