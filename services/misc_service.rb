require_relative '../logger/logging'

class MiscService
  include Logging

  def initialize(bilu)
    @bilu = bilu
  end

  def delete_message(message)
    @bilu.delete_message(message)
    logger.info('message deleted')
  rescue Telegram::Bot::Exceptions::ResponseError => e
    if e.message.include? 'message can\'t be deleted'
      logger.error('message can\'t be deleted')
    elsif e.message.include? 'error_code: "400"'
      logger.error('message no longer exists')
    else
      throw e
    end
  end
end
