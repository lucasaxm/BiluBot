require_relative '../logger/logging'
require_relative '../services/image_service'

class ImageController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @service = ImageService.new(bilu)
  end

  def distort(message, chat)
    @service.distort(message)
  end

  def deepfry(message, chat)
    @service.deepfry(message)
  end
end