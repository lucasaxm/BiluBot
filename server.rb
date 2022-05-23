require 'dotenv'
Dotenv.load('tokens.env')
require_relative 'bot'

module Server
  include Logging

  # MAX_ATTEMPTS = 2
  # error_count = 0

  bot ||= Bilu::Bot.new
  Thread.abort_on_exception = true

  pool = Concurrent::FixedThreadPool.new(5) # 5 threads

  supported_messages = [
    Telegram::Bot::Types::Message,
    Telegram::Bot::Types::CallbackQuery
  ]

  bot.listen do |message|
    if (message.nil?) || (!supported_messages.include? message.class)
      next
    end

    pool.post do
      Timeout.timeout(300, nil, 'Timeout processing message.') {
        begin
          bot.process_update message
        rescue StandardError => e
          logger.error("Exception Class: [#{e.class.name}]")
          logger.error("Exception Message: [#{e.message}']")
          unless bot.nil?
            answer = "Exception Class: [#{e.class.name}]\nException Message: [#{e.message}']."
            logger.error("Message=[#{answer}]")
            bot.log_to_channel(answer, message)
          end
          # end
        end
      }
    end
  end
end
