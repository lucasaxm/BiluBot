require_relative '../logger/logging'
require_relative '../services/forecast_service'

##
# Controller for ForecastService
class ForecastController
  include Logging

  def initialize(bilu, message)
    @service = ForecastService.new(bilu, message)
  end

  # Returns current weather for city in message text
  #
  # @param [Telegram::Bot::Types::Message] message Message received from Telegram
  def get_current_weather(chat)
    @service.get_current_weather
  end
end
