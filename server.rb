error_count = 0

logger = Logger4Telegram.new(Logger4Telegram::DEBUG)

Bilu::Bot.start

begin
  bot = Bilu::Bot.new(logger)

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
  end
end
