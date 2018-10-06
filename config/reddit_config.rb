module RedditConfig
  Include Logging
  attr_reader :reddit_config,
              :forbidden_subs_file

  @reddit_config = {
    client_id: ENV['BILU_REDDIT_CLIENT_ID'],
    secret: ENV['BILU_REDDIT_SECRET'],
    username: ENV['BILU_REDDIT_USERNAME'],
    password: ENV['BILU_REDDIT_PASSWORD']
  }

  @forbidden_subs_file = 'forbidden_list.txt'

  def get_forbidden_subs()
    File.readlines(@forbidden_subs_file).map(&:chomp)
  rescue Errno::ENOENT
    logger.warn("forbidden_list.txt doesn't exist")
  end

  def self.new_reddit_session()
    retries_redd ||= 0
    begin
      return Redd.it(@reddit_config)
    rescue => e
      logger.error("Exception Class: [#{e.class.name}]")
      logger.error("Exception Message: [#{e.message}']")
      retry if (retries_redd += 1) < 3
    end
  end

  def self.valid_subreddit?(subreddit)
    forbidden_subs = get_forbidden_subs(logger)
    forbidden_subs.include? subreddit
  end

end
