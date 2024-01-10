require_relative "#{__dir__}/../logger/logging"
require 'rmagick'
require 'fastimage'
require 'securerandom'

class ImageService
  include Logging, Magick

  # @param [Bilu::Bot] bilu
  def initialize(bilu, message)
    @bilu = bilu
    @message = message
    @dir = "#{__dir__}/#{Thread.current.object_id}"
  end

  def is_image? m
    !m.photo.empty? || !m.sticker.nil? || (!m.document.nil? && m.document.mime_type.start_with?('image/'))
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

  def distort_reply
    return unless @message.reply_to_message
    distort @message.reply_to_message
  end

  def deepfry_reply
    return unless @message.reply_to_message
    deepfry @message.reply_to_message
  end

  def deepfry(m=@message)
    file_path = download_image m

    @bilu.bot.api.send_chat_action(
        chat_id: m.chat.id,
        action: 'upload_photo'
    )

    deep_fry_image(file_path)

    logger.info "sending deep fried photo"
    send_local_image(file_path, m)
    logger.info('deep fried photo sent.')


    FileUtils.rm(file_path) if File.exists? file_path
    logger.info "file #{file_path} deleted"
  end

  def split_image_and_save(image_url, chunk_height)
    Dir.mkdir(@dir) unless Dir.exist?(@dir)
    # Download the image to a local temporary file
    image_path = download_image_from_url(image_url)

    # Now read the image from the local file
    img = Magick::Image.read(image_path).first
    File.delete(image_path) # Clean up the temporary file after reading
    image_chunks = []

    0.step(img.rows, chunk_height) do |y|
      height = [chunk_height, img.rows - y].min
      chunk = img.crop(0, y, img.columns, height)
      file_path = "#{@dir}/image_chunk_#{SecureRandom.uuid}.jpg"
      chunk.write(file_path)
      image_chunks << file_path
    end

    image_chunks
  end

  private

  def distort(m)
    filepath = download_image m

    @bilu.bot.api.send_chat_action(
        chat_id: m.chat.id,
        action: 'upload_photo'
    )

    distort_image(filepath)

    logger.info "sending scaled photo"
    send_local_image(filepath, m)
    logger.info('scaled photo sent.')

    FileUtils.rm(filepath) if File.exists? filepath
    logger.info "file #{filepath} deleted"
  end

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

  def send_photo(message, url, caption = nil)
    logger.debug("START - Sending #{url} as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
        chat_id: message.chat.id,
        action: 'upload_photo'
    )
    if caption.nil?
      options = {chat_id: message.chat.id,
                 photo: url.to_s,
                 reply_to_message_id: message.message_id, }
    else
      options = {chat_id: message.chat.id,
                 photo: url.to_s,
                 caption: caption,
                 reply_to_message_id: message.message_id, }
    end
    @bilu.bot.api.send_photo(options)
    logger.debug("END - Sending #{url} as photo through telegram API.")
  end


  def download_image_from_url(url)
    # Create a temporary file
    file_path = "temp_image_#{Time.now.to_i}.jpg"
    URI.open(url) do |image|
      File.open(file_path, 'wb') do |file|
        file.write(image.read)
      end
    end
    file_path
  end

  def split_image(img, chunk_height)
    image_chunks = []
    0.step(img.rows, chunk_height) do |y|
      height = [chunk_height, img.rows - y].min
      chunk = img.crop(0, y, img.columns, height)
      image_chunks << chunk
    end
    image_chunks
  end

end
