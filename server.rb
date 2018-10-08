require 'dotenv'
Dotenv.load('devtokens.env')
require_relative 'bot'

module Server
  include Logging

  error_count = 0

  begin
    bot ||= Bilu::Bot.new

    bot.listen do |message|
      bot.process_update message
      error_count = 0
    end
  rescue => e
    error_count += 1
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    if error_count < 5
      sleep(1)
      retry
    elsif !bot.nil?
      logger.error('Sending error message and continuing.')
      bot.reply_with_text("Error=[#{e.message}].", message)
    end
  end
end