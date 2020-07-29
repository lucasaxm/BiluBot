require 'logger'

##
# Class that holds log related config
class Logger4Telegram < Logger
  attr_accessor :from, :chat_type

  def set_up
    # Dir.mkdir('logs') unless File.exist?('logs')
    # @log_file_name = 'logs/log.txt'
    # @basis = 'daily'
    @date_format = '%Y-%m-%d %H:%M:%S'
    @from = @chat_type = ''
  end

  def initialize(level)
    set_up
    STDOUT.sync = true
    super(STDOUT)
    self.level = level
    self.datetime_format = @date_format
    self.formatter = proc {|severity, datetime, progname, msg|
      "#{severity}\t| #{datetime} | #{@from}\t| #{@chat_type}\t| #{msg}\n"
    }
  end

  def message=(message)
    if message.from.nil?
      @from = ''
    else
      @from = message.from.username.nil? ? message.from.id : message.from.username
    end
    case message
    when Telegram::Bot::Types::InlineQuery
      @chat_type = "Inline Query (#{message.from.id})"

    when Telegram::Bot::Types::Message
      @chat_type = message.chat.type == 'private' ? 'private' : message.chat.title
      @chat_type << " (#{message.chat.id})"

    else
      puts 'unknown message type'

#   when Telegram::Bot::Types::CallbackQuery
#     # callback query not needed
#
#   when Telegram::Bot::Types::ChosenInlineResult
#     # no inline query
    end
  end
end
