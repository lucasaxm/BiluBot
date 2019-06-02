require_relative '../logger/logging'
require_relative '../config/reddit_config'
require_relative '../services/reddit_service'

##
# Controller for RedditService
class RedditController
  include Logging

  # @param [Bilu::Bot] bilu Telegram bot instance
  def initialize(bilu)
    @service = RedditService.new(bilu)
  end

  def get_media_from_subreddit(message)
    @service.get_media_from_subreddit(message)
  end

  def handle_inline_query(inline_query)
    @service.handle_inline_query(inline_query)
  end

  def handle_chosen_inline_result(chosen_inline_result)
    @service.handle_chosen_inline_result(chosen_inline_result)
  end

end
