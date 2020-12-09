require 'youtube-dl'
require_relative '../logger/logging'
require_relative '../services/gallery_dl_service'

class GalleryDLController
  include Logging

  def initialize(bilu)
    @service = GalleryDLService.new(bilu)
  end

  def send_media(message, chat)
    @service.send_media(message)
  end

end