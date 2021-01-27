require_relative '../logger/logging'
require_relative '../services/misc_service'

class MiscController
  include Logging

  def initialize(bilu)
    @service = MiscService.new(bilu)
  end

  def delete_message(message, chat)
    @service.delete_message(message)
  end

  def spam(message, chat)
    @service.spam(message)
  end

  def keyboard(message, chat)
    @service.keyboard(message)
  end

  def close_keyboard(message, chat)
    @service.close_keyboard(message)
  end
end