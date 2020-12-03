require_relative '../logger/logging'
require_relative '../services/image_service'

class ImageController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @service = ImageService.new(bilu)
  end

  def distort_reply(message, chat)
    @service.distort_reply(message)
  end

  def deepfry_reply(message, chat)
    @service.deepfry_reply(message)
  end

  def deepfry(message, chat)
    @service.deepfry(message)
  end

  def send_photo_from_instagram(message, chat)
    @service.send_photo_from_instagram(message)
  end
end