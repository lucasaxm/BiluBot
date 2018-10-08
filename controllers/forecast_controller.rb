require_relative '../logger/logging'
require_relative '../config/forecast_config'

class ForecastController
  include Logging

  def initialize
    ForecastConfig.set_up_forecastio_api
  end

  def get_current_weather(bilu, message)
    bilu.reply_with_text("received #{message.text}", message)
  end

end