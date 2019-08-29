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
    throw e unless e.message.include? 'message can\'t be deleted'
    logger.error('message can\'t be deleted')
  end
end