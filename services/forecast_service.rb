require_relative '../logger/logging'
require_relative '../config/forecast_config'
require 'forecast_io'
require 'geocoder'

class ForecastService
  include Logging

  # @param [Bilu::Bot] bilu
  def initialize(bilu)
    ForecastConfig.set_up_forecastio_api
    @bilu = bilu
  end

  # @param [Telegram::Bot::Types::Message] message
  def get_current_weather(message)
    text_array = message.text.split(' ')
    if text_array.size <= 1
      send_help_message(message)
      return
    end
    cityname = text_array[1..-1].join ' '
    logger.info("cityname=[#{cityname}]")
    search_results = search_for_city(cityname)
    if search_results.nil? || search_results.empty?
      answer = "no results for [#{cityname}]"
      logger.error(answer)
    else
      citygeo = search_results.first
      forecast = ForecastIO.forecast(citygeo.latitude, citygeo.longitude).currently
      city = citygeo.data['address']['city'].nil? ? citygeo.data['address']['town'] : citygeo.data['address']['city']
      address = "#{city}, #{citygeo.data['address']['state']}, #{citygeo.data['address']['country']}"

      weather_icon = get_weather_icon(forecast.icon)
      answer = "`#{address}\n"\
        "#{weather_icon} #{forecast.temperature}°C (#{forecast.apparentTemperature}ºC), #{forecast.summary}`"
      logger.info(answer)
    end
    @bilu.reply_with_markdown_text(answer, message)
  end

  private

  def search_for_city(cityname)
    Geocoder.search(cityname).select do |c|
      ((c.data['address']['city'].instance_of? String) &&
        c.data['address']['city'].casecmp(cityname).zero?) ||
        ((c.data['address']['town'].instance_of? String) &&
          c.data['address']['town'].casecmp(cityname).zero?)
    end
  end

  def send_help_message(message)
    help =
      "`/weather city`\n• Get current weather conditions for the city."
    @bilu.reply_with_markdown_text(help, message)
  end

  def get_weather_icon(icon)
    case icon
    when 'clear-day'
      "\u{2600}"
    when 'clear-night'
      "\u{1f319}"
    when 'rain'
      "\u{2614}"
    when 'snow'
      "\u{26c4}"
    when 'sleet'
      "\u{2744}"
    when 'wind'
      "\u{1f32c}"
    when 'fog'
      "\u{1f32b}"
    when 'cloudy'
      "\u{2601}"
    when 'partly-cloudy-day'
      "\u{26c5}"
    when 'partly-cloudy-night'
      "\u{1f319}\u{2601}"
    end
  end
end
