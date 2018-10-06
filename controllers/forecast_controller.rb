module ForecastController

  def initialize
    ForecastConfig.set_up_forecastio_api
  end

  def parse_command(message)
    puts message
  end

end