require 'telegram/bot'
require 'youtube-dl'
require_relative '../logger/logging'

class YoutubedlService
  include Logging

  def initialize(bilu)
    @bilu = bilu
  end

  def send_video(message)
    logger.info "Trying to send #{message.text} as a video"
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
    FileUtils.mv(filepath,"#{filepath}.#{result.ext}") if File.exists? filepath
    filepath << ".#{result.ext}"
    send_youtubedl_video(message, filepath, result)
    FileUtils.rm(filepath)
  rescue Terrapin::ExitStatusError => e
    logger.warn "Failed to send video. message: #{e.message.each_line.grep /^ERROR/}"
  end

  def send_youtubedl_video(message, file_path, result)
    logger.debug("START - Sending #{file_path} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_video'
    )
    upload = Faraday::UploadIO.new(file_path, "video/#{result.ext}")
    @bilu.bot.api.send_video(
        chat_id: message.chat.id,
        video: upload,
        caption: result.title,
        reply_to_message_id: message.message_id
    )
    upload.close unless upload.nil?
    logger.debug("END - Sending #{file_path} as video through telegram API.")
  end


end