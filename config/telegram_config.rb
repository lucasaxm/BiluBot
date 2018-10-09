##
# Configuration for the Telegram API connection
#
module TelegramConfig
  class << self
    attr_reader :telegram_token
  end

  # token used to connect to Telegram API
  @telegram_token = ENV['BILU_TELEGRAM_TOKEN']
end
