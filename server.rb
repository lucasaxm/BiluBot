require 'dotenv'
require 'byebug'
require 'awesome_print'
Dotenv.load("#{__dir__}/tokens.env")
require_relative 'bot'

module Server
  include Logging

  bot ||= Bilu::Bot.new
  Thread.abort_on_exception = true

  pool = Concurrent::FixedThreadPool.new(5) # 5 threads

  supported_messages = [
    Telegram::Bot::Types::Message,
    Telegram::Bot::Types::CallbackQuery
  ]

  bot.listen do |message|
    if (message.nil?) || (!supported_messages.include? message.class) || (!message.to_h['edit_date'].nil?)
      next
    end

    pool.post do
      begin
        Timeout.timeout(300, nil, 'Timeout processing message.') do
          bot.process_update message
        end
      rescue => e
        logger.error("Exception Class: [#{e.class.name}]")
        logger.error("Exception Message: [#{e.message}']")
        logger.error e.backtrace.join "\n"
        unless bot.nil?
          answer = "Exception Class: [#{e.class.name}]\nException Message: [#{e.message}']\nBacktrace first row: [#{e.backtrace.first}]"
          logger.error("Message=[#{answer}]")
          bot.log_to_channel(answer, message)
        end
        # end
      end
    end
  end
end
