require 'telegram/bot'
require 'streamio-ffmpeg'
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
        format: 'bestvideo[height<=720][filesize<?20M]+bestaudio/best',
        'merge-output-format': 'mp4',
        output: filepath
    }
    result = YoutubeDL.download message.text, options
    if result.nil?
      logger.error 'Failed to download video using youtube-dl'
      return
    end
    result.information[:category] = result.information[:extractor]

    movie = FFMPEG::Movie.new(filepath)
    new_file_path = "#{message.message_id}.mp4"
    logger.info("Transcoding video to #{new_file_path}")
    movie.transcode(new_file_path, %w(-c:v libx264 -crf 26 -vf scale=640:-1))
    send_local_video(new_file_path, build_caption(result.information), message)
    FileUtils.rm([filepath, new_file_path])
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
    else
      information[:category]
    end
  end

  def send_gallerydl_media(message, result)
    logger.info "#{result.information.size} medias found from #{message.text}"
    result.information.each do |information|
      path = information[:local_path]
      movie = FFMPEG::Movie.new(path)
      if movie.frame_rate.nil?
        send_local_photo(path, build_caption(information), message)
      else
        file_path = "#{message.message_id}.mp4"
        logger.info("Transcoding video to #{file_path}")
        movie.transcode(file_path, %w(-c:v libx264 -crf 26 -vf scale=640:-1))
        send_local_video(file_path, build_caption(information), message)
        FileUtils.rm(file_path)
      end
      FileUtils.rm(%W[#{path} #{path}.json])
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