##
# This class stores all needed information to answer an user weather request
class RequestWeather
  attr_reader :chat_id, :message_id, :user_id

  ##
  # Creates a new request for weather
  # @param [String] user_id The Telegram id of the user who requested the
  #                         weather information.
  # @param [String] chat_id The Telegram id of the chat where the request was
  #                         typed.
  # @param [String] message_id The Telegram id of the message where the weather
  #                            was requested. Can be used to be replied to.
  def initialize(user_id, chat_id, message_id)
    @user_id = user_id
    @chat_id = chat_id
    @message_id = message_id
  end

  def ==(other)
    (user_id == other.user_id) && (chat_id == other.chat_id)
  end
end
