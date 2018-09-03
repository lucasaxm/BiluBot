##
# Class created to represent bot API related configuration
module BotConfig
  attr_reader :telegram_token,
              :forecastio_token,
              :reddit_config

  Dotenv.load('tokens.env')

  def gather_tokens
    @telegram_token = ENV['BILU_TELEGRAM_TOKEN']

    @forecastio_token = ENV['BILU_FORECAST_IO_TOKEN']

    @reddit_config = {
      client_id: ENV['BILU_REDDIT_CLIENT_ID'],
      secret: ENV['BILU_REDDIT_SECRET'],
      username: ENV['BILU_REDDIT_USERNAME'],
      password: ENV['BILU_REDDIT_PASSWORD']
    }
  end

  gather_tokens
end
