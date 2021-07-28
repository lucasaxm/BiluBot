require_relative '../logger/logging'
require_relative '../services/image_service'

class ImageController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu, message)
    @service = ImageService.new(bilu, message)
  end

  def distort_reply(chat)
    @service.distort_reply
  end

  def deepfry_reply(chat)
    @service.deepfry_reply
  end

  def deepfry(chat)
    @service.deepfry
  end
end