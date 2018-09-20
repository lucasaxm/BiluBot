module ForecastConfig
  attr_reader :forecastio_token
  attr_accessor :request_weather_list

  @request_weather_list = []

  @forecastio_token = ENV['BILU_FORECAST_IO_TOKEN']

  def self.set_up_forecastio_api
    ForecastIO.configure do |configuration|
      configuration.api_key = @forecastio_token
      configuration.default_params = { units: 'si' }
    end
  end
end
