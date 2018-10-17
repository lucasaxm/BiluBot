Dir['controllers/*.rb'].each {|file| require_relative file}

module Routes
  class << self
    attr_reader :message_map
  end

  @message_map = {
    %i[r reddit] => {
      controller: RedditController,
      action: :get_media_from_subreddit
    },
    %i[ow] => {
      controller: OverwatchController,
      action: :sub_router
    },
    %i[weather] => {
      controller: ForecastController,
      action: :get_current_weather
    },
    %i[markov markov@mkv_bot] => {
      controller: MiscController,
      action: :delete_message
    }
  }.freeze
end
