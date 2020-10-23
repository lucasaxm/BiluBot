Dir['controllers/*.rb'].each {|file| require_relative file}

module Routes
  class << self
    attr_reader :message_map
  end

  @message_map = {
    %r{^/((r)|(reddit)) \w+$}i => {
      controller: RedditController,
      action: :get_media_from_subreddit
    },
    %r{^callback /((r)|(reddit)) \w+$}i => {
      controller: RedditController,
      action: :get_media_from_subreddit_callback
    },
    %r{^\/weather [[:alpha:]]+( [[:alpha:]]+)*$}i => {
      controller: ForecastController,
      action: :get_current_weather
    },
    %r{^/markov(@mkv_bot)?$}i => {
      controller: MiscController,
      action: :delete_message
    },
    %r{inline_query} => {
      controller: RedditController,
      action: :handle_inline_query
    },
    %r{chosen_inline_result} => {
      controller: RedditController,
      action: :handle_chosen_inline_result
    },
    %r{^(https?:\/\/(www\.)?)?reddit\.com\S*\/comments\/\w+\S*$} => {
      controller: RedditController,
      action: :get_media_from_url
    },
    %r{^\/s\/.*\/.*$}i => {
      controller: MiscController,
      action: :delete_message
    },
    %r{^\/spam$}i => {
        controller: MiscController,
        action: :spam
    },
    %r{^\/spam .*$}i => {
        controller: MiscController,
        action: :spam
    },
    %r{^\/bilov.*$}i => {
        controller: MiscController,
        action: :delete_message
    },
    %r{^\/distort$}i => {
        controller: ImageController,
        action: :distort_reply
    },
    %r{^\/distort@[^@]*$}i => {
        controller: ImageController,
        action: :distort_reply
    },
    %r{^\/d$}i => {
        controller: ImageController,
        action: :distort_reply
    },
    %r{^scale$}i => {
        controller: ImageController,
        action: :distort_reply
    },
    %r{^fry}i => {
      controller: ImageController,
      action: :deepfry_reply
    },
    %r{^$}i => {
        controller: ImageController,
        action: :random_deepfry
    }

  }.freeze
end
