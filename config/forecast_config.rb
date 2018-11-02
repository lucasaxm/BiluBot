require 'faraday'
require 'faraday_middleware'
require 'timezone'

##
# Module that holds all configuration related to ForecastController
module ForecastConfig
  class << self
    attr_reader :forecastio_token,
                :geonames_username
    attr_accessor :request_weather_list

    # set up ForecastIO configuration
    def set_up_forecastio_api
      ForecastIO.configure do |configuration|
        configuration.api_key = @forecastio_token
        configuration.default_params = {units: 'si'}
      end
    end

    def city_search_api

      url = 'http://api.geonames.org'

      Faraday.new(url: url, params: {username: @geonames_username, maxRows: '1', featureClass: 'P'}) do |faraday|
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end

  # holds the api key used in ForecastIO configuration
  @forecastio_token = ENV['BILU_FORECAST_IO_TOKEN']
  @geonames_username = ENV['BILU_GEONAMES_USERNAME']
  TIMEZONE_FINDER = Timezone::Lookup.config(:geonames) {|c| c.username = @geonames_username}
end
