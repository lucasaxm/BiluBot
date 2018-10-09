##
# Module that holds all configuration related to ForecastController
module ForecastConfig
  class << self
    attr_reader :forecastio_token
    attr_accessor :request_weather_list

    # set up ForecastIO configuration
    def set_up_forecastio_api
      ForecastIO.configure do |configuration|
        configuration.api_key = @forecastio_token
        configuration.default_params = {units: 'si'}
      end
    end
  end

  # holds the api key used in ForecastIO configuration
  @forecastio_token = ENV['BILU_FORECAST_IO_TOKEN']
end
