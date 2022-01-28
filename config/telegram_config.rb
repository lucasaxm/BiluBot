##
# Configuration for the Telegram API connection
#
module TelegramConfig
  class << self
    attr_reader :telegram_token, :telegram_dev_token
  end

  # token used to connect to Telegram API
  @telegram_token = ENV['BILU_TELEGRAM_TOKEN']
  @telegram_dev_token = ENV['BILU_DEV_TELEGRAM_TOKEN']
end
