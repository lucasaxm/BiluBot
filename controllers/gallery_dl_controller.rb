require_relative "#{__dir__}/../logger/logging"
require_relative "#{__dir__}/../services/gallery_dl_service"

class GalleryDLController
  include Logging

  def initialize(bilu, message)
    @service = GalleryDLService.new(bilu, message)
  end

  def send_media(chat)
    @service.send_media
  end

  def fetch_metadata(chat)
    @service.fetch_metadata
  end

  def fetch_metadata_callback(chat)
    @service.fetch_metadata_callback
  end

  def search_and_send_as_audio(chat)
    @service.search_and_send 'audio'
  end

  def search_and_send_as_video(chat)
    @service.search_and_send 'video'
  end
end