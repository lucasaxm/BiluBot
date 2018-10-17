##
# Configuration for the RedditController
#
module RedditConfig
  include Logging
  class << self
    attr_reader :reddit_config,
                :forbidden_subs_file
  end

  # get list of forbidden subreddits from +forbidden_subs_file+
  # if +forbidden_subs_file+ doesn't exist it will be created
  def self.read_forbidden_subs_from_file
    File.open(@forbidden_subs_file, 'a+', &:readlines).map(&:chomp)
  rescue Errno::ENOENT
    logger.warn("forbidden_list.txt doesn't exist")
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

  # This method checks if a subreddit is in the forbidden subreddit list
  # @param [String] subreddit
  # @return [Boolean]
  def self.valid_subreddit?(subreddit)
    forbidden_subs = read_forbidden_subs_from_file
    !forbidden_subs.include? subreddit
  end

  # Hash with needed information to create a session using Redd.it
  @reddit_config = {
    client_id: ENV['BILU_REDDIT_CLIENT_ID'],
    secret: ENV['BILU_REDDIT_SECRET'],
    username: ENV['BILU_REDDIT_USERNAME'],
    password: ENV['BILU_REDDIT_PASSWORD']
  }

  # Name of the file that contains the forbidden subreddits list
  @forbidden_subs_file = 'forbidden_list.txt'
end
