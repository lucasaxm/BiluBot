require 'dotenv'
Dotenv.load('tokens.env')
require_relative 'bot'

module Server
  include Logging

  MAX_ATTEMPTS = 5
  error_count = 0

  bot ||= Bilu::Bot.new

  bot.listen do |message|
    begin
      bot.process_update message
      error_count = 0
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
          logger.error('Sending error message and continuing.')
          answer = "Error #{e.class.name}: #{e.message}."
          logger.error("Message=[#{answer}]")
          bot.reply_with_text(answer, message)
        end
      end
    end
  end
end
