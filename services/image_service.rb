require_relative '../logger/logging'
require 'rmagick'
require 'fastimage'

class ImageService
  include Logging, Magick

  # @param [Bilu::Bot] bilu
  def initialize(bilu)
    @bilu = bilu
  end

  def get_image_file_info(m)
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
    [file_id, file_name]
  end

  def download_image(m)
    file_id, file_name = get_image_file_info m
    return if file_id.nil? || file_name.nil?

    telegram_file_path = @bilu.get_file(file_id)
    logger.info("telegram file path = '#{telegram_file_path}'.")

    if File.extname(telegram_file_path) == '.tgs'
      logger.warn 'animated sticker found, aborting download.'
      return
    end

    @bilu.download_file(telegram_file_path, file_name)
  end

  def distort(message)
    return unless message.reply_to_message
    m = message.reply_to_message

    file_path = download_image m

    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_photo'
    )

    distort_image(file_path)

    logger.info "sending scaled photo"
    send_local_image(file_path, m)
    logger.info('scaled photo sent.')

    FileUtils.rm(file_path)
    logger.info "file #{file_path} deleted"
  end

  def deepfry(message)
    return unless message.reply_to_message
    m = message.reply_to_message

    file_path = download_image m

    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_photo'
    )

    deep_fry_image(file_path)

    logger.info "sending deep fried photo"
    send_local_image(file_path, m)
    logger.info('deep fried photo sent.')


    FileUtils.rm(file_path)
    logger.info "file #{file_path} deleted"
  end

  private

  def distort_image(file_path)
    img = ImageList.new(file_path)
    height, width = get_image_resolution(file_path)
    logger.info "applying liquid rescale and saving to #{file_path}"
    img.liquid_rescale(width * 0.35, height * 0.35, 3, 5).resize(width, height).write(file_path)
        .destroy!
  end

  def send_local_image(file_path, m)
    file_ext = File.extname(file_path)
    if file_ext == '.jpeg' || file_ext == '.jpg'
      upload = Faraday::UploadIO.new(file_path, 'image/jpeg')
      @bilu.bot.api.send_photo(
          chat_id: m.chat.id,
          photo: upload,
          reply_to_message_id: m.message_id
      )
    elsif file_ext == '.webp'
      upload = Faraday::UploadIO.new(file_path, 'image/webp')
      @bilu.bot.api.send_sticker(
          chat_id: m.chat.id,
          sticker: upload,
          reply_to_message_id: m.message_id
      )
    else
      log.error "file extension #{file_ext} is not valid"
      return
    end
    upload.close
  end

  def deep_fry_image(file_path)
    img = ImageList.new(file_path)
    height, width = get_image_resolution(file_path)
    logger.info "applying deep fry and saving to #{file_path}"
    img.liquid_rescale(width * 0.5, height * 0.5, 3, 5)
    .resize(width, height)
    .modulate(0.5, 2, 2)
    .emboss(0.5)
    .implode(-0.4)
    .add_noise(Magick::GaussianNoise)
    .write(file_path)
    .destroy!
  end

  def get_image_resolution(file_path)
    width, height = FastImage.size(file_path)
    logger.info "image resolution #{width}x#{height}"
    [height, width]
  end

end