require_relative '../logger/logging'
require_relative '../config/overwatch_config'

##
# Controller for OverwatchService
class OverwatchController

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @bilu = bilu
  end

  # Delegates the received message to the right method based in the parameter received
  #
  # @param [Telegram::Bot::Types::Message] message Message received from Telegram
  def sub_router(message)
    @bilu.reply_with_text("received #{message.text}", message)
  end
end
