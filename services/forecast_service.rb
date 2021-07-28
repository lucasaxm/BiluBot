require_relative '../logger/logging'
require_relative '../config/forecast_config'
require 'forecast_io'

class ForecastService
  include Logging

  # @param [Bilu::Bot] bilu
  def initialize(bilu, message)
    ForecastConfig.set_up_forecastio_api
    @bilu = bilu
    @message = message
  end

  # @param [Telegram::Bot::Types::Message] @message
  def get_current_weather
    text_array = @message.text.split(' ')
    if text_array.size <= 1
      send_help_message
      return
    end
    cityname = text_array[1..-1].join ' '
    logger.info("cityname=[#{cityname}]")
    search_results = search_for_city(cityname)
    if !search_results['status'].nil?
      answer = search_results['status']['message']
      logger.error(answer)
    else
      if search_results['totalResultsCount'].zero?
        answer = "no results for [#{cityname}]"
        logger.error(answer)
      else
        citygeo = search_results['geonames'].first
        lat = citygeo['lat']
        lng = citygeo['lng']
        forecast = ForecastIO.forecast(lat, lng).currently
        city = "#{citygeo['name']}, #{citygeo['countryName']}"
        time = begin
          timezone_string = ForecastConfig::TIMEZONE_FINDER.lookup(lat, lng)
          timezone = Timezone.fetch(timezone_string)
          if timezone.valid?
            "\u{1F552} `#{timezone.time(Time.now).strftime('%H:%M:%S')} (#{timezone_string})`"
          else
            ''
          end
        rescue ::Timezone::Error::Lookup
          ''
        end
        icon = get_weather_icon(forecast.icon)
        answer = "#{city}\n#{time}\n#{icon} `#{forecast.temperature}°C (#{forecast.apparentTemperature}°C), #{forecast.summary}`"
        logger.info(answer.to_json)
      end
      @bilu.reply_with_markdown_text(answer, @message)
    end
  end

  private

  def search_for_city(cityname)
    ForecastConfig.city_search_api.get('searchJSON', q: cityname).body
  end

  def send_help_message
    help =
      "`/weather city`\n\u{2022} Get current weather conditions for the city."
    @bilu.reply_with_markdown_text(help, @message)
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
    when 'cloudy', 'partly-cloudy-night'
      "\u{2601}"
    when 'partly-cloudy-day'
      "\u{26c5}"
    end
  end
end
