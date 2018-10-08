module TelegramConfig
  class << self
    attr_reader :telegram_token
  end
  @telegram_token = ENV['BILU_TELEGRAM_TOKEN']
end