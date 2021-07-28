require_relative '../logger/logging'
require_relative '../services/misc_service'

class MiscController
  include Logging

  def initialize(bilu, message)
    @service = MiscService.new(bilu, message)
  end

  def delete_message(chat)
    @service.delete_message
  end

  def spam(chat)
    @service.spam
  end

  def keyboard(chat)
    @service.keyboard
  end

  def close_keyboard(chat)
    @service.close_keyboard
  end
end