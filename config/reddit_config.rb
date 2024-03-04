##
# Configuration for the RedditController
#
module RedditConfig
  include Logging
  class << self
    attr_reader :reddit_config
  end

  # Create a new reddit session using Redd class
  def self.new_reddit_session
    retries_redd ||= 0
    begin
      return Redd.it(@reddit_config)
    rescue StandardError => e
      logger.error("Exception Class: [#{e.class.name}]")
      logger.error("Exception Message: [#{e.message}']")
      retry if (retries_redd += 1) < 3
    end
  end

  # Hash with needed information to create a session using Redd.it
  @reddit_config = {
    client_id: ENV['BILU_REDDIT_CLIENT_ID_DL'],
    secret: ENV['BILU_REDDIT_CLIENT_SECRET_DL']
  }
end
