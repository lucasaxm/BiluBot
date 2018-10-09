require_relative '../logger/logging'
require_relative '../config/forecast_config'

##
# Controller for ForecastService
class ForecastController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @bilu = bilu
    ForecastConfig.set_up_forecastio_api
  end

  # Returns current weather for city in message text
  #
  # @param [Telegram::Bot::Types::Message] message Message received from Telegram
  def get_current_weather(message)
    @bilu.reply_with_text("received #{message.text}", message)
  end
end