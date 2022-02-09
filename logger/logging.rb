require_relative 'logger4_telegram'

module Logging
  class << self
    def logger
      @logger ||= {}
      @logger[Thread.current.object_id] ||= Logger4Telegram.new(Logger4Telegram::DEBUG)
      @logger[Thread.current.object_id]
    end
  end

  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end