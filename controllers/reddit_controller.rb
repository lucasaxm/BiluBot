require_relative "#{__dir__}/../logger/logging"
require_relative "#{__dir__}/../config/reddit_config"
require_relative "#{__dir__}/../services/reddit_service"

##
# Controller for RedditService
class RedditController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu, message)
    @service = RedditService.new(bilu, message)
  end

  def get_media_from_subreddit(chat)
    @service.get_media_from_subreddit(chat)
  end

  def get_media_from_subreddit_callback(chat)
    @service.get_media_from_subreddit_callback(chat)
  end

  def get_media_from_url(chat)
    @service.get_media_from_url(chat)
  end

  def ban_subreddit(chat)
    @service.ban_subreddit(chat)
  end

  def unban_subreddit(chat)
    @service.unban_subreddit(chat)
  end

  def handle_inline_query(inline_query)
    @service.handle_inline_query(inline_query)
  end

  def handle_chosen_inline_result(chosen_inline_result)
    @service.handle_chosen_inline_result(chosen_inline_result)
  end

end
