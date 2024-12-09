require_relative "#{__dir__}/../logger/logging"
require_relative "#{__dir__}/../services/misc_service"

class MiscController
  include Logging

  def initialize(bilu, message)
    @service = MiscService.new(bilu, message)
  end

  def delete_reply(chat)
    @service.delete_reply
  end

  def sudo_delete_reply(chat)
    @service.sudo_delete_reply
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

  def kill_process(chat)
    @service.kill_process
  end
  
end
