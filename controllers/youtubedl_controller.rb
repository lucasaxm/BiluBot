require 'youtube-dl'
require_relative '../logger/logging'
require_relative '../services/youtubedl_service'

class YoutubedlController
  include Logging

  def initialize(bilu)
    @service = YoutubedlService.new(bilu)
  end

  def send_video(message, chat)
    @service.send_video(message)
  end

end