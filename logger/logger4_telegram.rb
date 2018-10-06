require 'logger'

##
# Class that holds log related config
class Logger4Telegram < Logger
  attr_accessor :from, :chat_type

  def set_up
    @log_file_name = 'log.txt'
    @basis = 'daily'
    @date_format = '%Y-%m-%d %H:%M:%S'
    @from = @chat_type = ''
  end

  def initialize(level)
    set_up
    super(@log_file_name, @basis)
    self.level = level
    self.datetime_format = @date_format
    self.formatter = proc { |severity, datetime, progname, msg|
      "#{severity}\t| #{datetime} | #{@from}\t| #{@chat_type}\t| #{msg}\n"
    }
  end

  def message=(message)
    @from = message.from.username.nil? ? message.from.id : message.from.username
    @chat_type = message.chat.type == 'private' ? 'private' : message.chat.title
    @chat_type << " (#{message.chat.id})"
  end

end