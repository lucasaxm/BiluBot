require_relative 'logger4_telegram'

module Logging
  class << self
    def logger
      @logger ||= Logger4Telegram.new(Logger4Telegram::DEBUG)
    end

    def logger=(logger)
      @logger = logger
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