module TelegramConfig
  attr_reader :telegram_token
  @telegram_token = ENV['BILU_TELEGRAM_TOKEN']
end