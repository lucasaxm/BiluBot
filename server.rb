require 'dotenv'
Dotenv.load('tokens.env')
require_relative 'bot'

module Server
  include Logging

  MAX_ATTEMPTS = 2
  error_count = 0

  bot ||= Bilu::Bot.new

  bot.listen do |message|
    begin
      if !message.nil? && (message.class == Telegram::Bot::Types::CallbackQuery || message.chat.type != 'channel')
        bot.process_update message
        error_count = 0
      end
    rescue StandardError => e
      error_count += 1
      logger.error("Exception Class: [#{e.class.name}]")
      logger.error("Exception Message: [#{e.message}']")
      if message.class == Telegram::Bot::Types::Message
        if error_count < MAX_ATTEMPTS
          sleep(1)
          logger.info("Retrying (Attempt #{error_count + 1}/#{MAX_ATTEMPTS})")
          retry
        elsif !bot.nil?
          answer = "Exception Class: [#{e.class.name}]\nException Message: [#{e.message}']."
          logger.error("Message=[#{answer}]")
          bot.log_to_channel(answer, message)
        end
      end
    end
  end
end
