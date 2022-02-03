require_relative '../logger/logging'
require_relative '../services/gallery_dl_service'

class GalleryDLController
  include Logging

  def initialize(bilu, message)
    @service = GalleryDLService.new(bilu, message)
  end

  def send_media(chat)
    @service.send_media
  end

end