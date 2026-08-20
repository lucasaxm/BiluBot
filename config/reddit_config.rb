require_relative "#{__dir__}/../lib/reddit/session"
require_relative "#{__dir__}/../lib/reddit/errors"

##
# Configuration for the RedditController
#
module RedditConfig
  include Logging

  # Create a new reddit session using our own Reddit::Session class
  def self.new_reddit_session
    retries_redd ||= 0
    begin
      return Reddit::Session.new(
        client_id: ENV['BILU_REDDIT_CLIENT_ID_DL'],
        secret: ENV['BILU_REDDIT_CLIENT_SECRET_DL'],
        user_agent: user_agent
      )
    rescue StandardError => e
      logger.error("Exception Class: [#{e.class.name}]")
      logger.error("Exception Message: [#{e.message}']")
      retry if (retries_redd += 1) < 3
    end
  end

  # Reddit requires a unique, descriptive User-Agent for API access
  def self.user_agent
    app_name = ENV['BILU_REDDIT_APP_NAME_DL'] || 'bilubot'
    username = ENV['BILU_REDDIT_USERNAME'] || 'unknown'
    "ruby:#{app_name}:v1.0 (by /u/#{username})"
  end
end
