require_relative '../logger/logging'
require_relative '../services/distort_service'

class DistortController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @service = DistortService.new(bilu)
  end

  def distort(message, chat)
    @service.distort(message)
  end
end