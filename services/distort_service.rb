require_relative '../logger/logging'
require 'rmagick'
require 'fastimage'

class DistortService
  include Logging, Magick

  # @param [Bilu::Bot] bilu
  def initialize(bilu)
    @bilu = bilu
  end

  def distort(message)
    return unless message.reply_to_message
    m = message.reply_to_message
    if !m.photo.empty?
      logger.info('photo found.')
      file_id = m.photo[-1].file_id
      file_name = "#{file_id}.jpg"
    elsif !m.sticker.nil?
      logger.info('sticker found.')
      file_id = m.sticker.file_id
      file_name = "#{file_id}.webp"
    elsif !m.document.nil?
      return unless m.document.mime_type.start_with? 'image/'
      logger.info('image as document found.')
      file_id = m.document.file_id
      file_name = "#{file_id}.#{m.document.mime_type.split('/')[1]}"
    else
      return
    end


    file_path = @bilu.get_file(file_id)
    logger.info("telegram file path = '#{file_path}'.")

    if File.extname(file_path) == '.tgs'
      logger.warn 'animated sticker found, aborting distortion.'
      return
    end

    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_photo'
    )
    temp_file = @bilu.download_file(file_path, file_name)

    width, height = FastImage.size(temp_file.path)
    logger.info "image resolution #{width}x#{height}"

    img = ImageList.new(temp_file.path)

    temp_file.close

    logger.info 'applying liquid rescale'
    img = img.liquid_rescale(width*0.35, height*0.35, 3, 5)
    img.resize!(width, height)

    logger.info "saving scaled photo to #{file_name}"
    img.write(file_name)
    img.destroy!

    logger.info "sending scaled photo"
    upload = Faraday::UploadIO.new(file_name, 'image/jpeg')
    @bilu.bot.api.send_photo(
        chat_id: message.chat.id,
        photo: upload,
        reply_to_message_id: m.message_id
    )
    upload.close
    logger.info('scaled photo sent.')


    FileUtils.rm(file_name)
    logger.info "file #{file_name} deleted"

  end

end