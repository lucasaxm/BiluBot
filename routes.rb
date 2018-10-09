Dir['controllers/*.rb'].each {|file| require_relative file}

module Routes
  class << self
    attr_reader :message_map
  end

  @message_map = {
    r: {
      controller: RedditController,
      action: :get_media_from_subreddit
    },
    reddit: {
      controller: RedditController,
      action: :get_media_from_subreddit
    },
    ow: {
      controller: OverwatchController,
      action: :sub_router
    },
    weather: {
      controller: ForecastController,
      action: :get_current_weather
    }
  }.freeze
end
