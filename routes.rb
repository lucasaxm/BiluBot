require_relative 'controllers/reddit_controller'
require_relative 'controllers/overwatch_controller'
require_relative 'controllers/forecast_controller'

module Routes

  message_map = {
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
