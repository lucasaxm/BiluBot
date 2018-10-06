module TelegramConfig
  class << self
    attr_accessor :telegram_token
  end
  self.telegram_token = ENV['BILU_TELEGRAM_TOKEN']
end