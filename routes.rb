Dir['controllers/*.rb'].each { |file| require_relative file }

module Routes
  class << self
    attr_reader :message_map

    def regex_match(message, regex)
      return false if message.text.nil?
      regex.match? message.text.to_s
    end

    def is_image? m
      !m.photo.empty? || !m.sticker.nil? || (!m.document.nil? && m.document.mime_type.start_with?('image/'))
    end

    def is_link?(message)
      !message.entities.nil? && !message.entities.empty? && message.entities.any? { |entity| entity.type == 'url' }
    end

    def is_reddit_link?(message)
      regex_match(message, %r{^(https?:\/\/(www\.)?)?reddit\.com\S*\/comments\/\w+\S*$})
    end
  end


  @message_map = {
      Proc.new do |message|
        regex_match message, %r{^/((r)|(reddit)) \w+$}i
      end => {
          controller: RedditController,
          action: :get_media_from_subreddit
      },
      Proc.new do |message|
        regex_match message, %r{^callback /((r)|(reddit)) \w+$}i
      end => {
          controller: RedditController,
          action: :get_media_from_subreddit_callback
      },
      Proc.new do |message|
        regex_match message, %r{^\/weather [[:alpha:]]+( [[:alpha:]]+)*$}i
      end => {
          controller: ForecastController,
          action: :get_current_weather
      },
      Proc.new do |message|
        regex_match message, %r{^/markov(@mkv_bot)?$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      Proc.new do |message|
        regex_match message, %r{inline_query}
      end => {
          controller: RedditController,
          action: :handle_inline_query
      },
      Proc.new do |message|
        regex_match message, %r{chosen_inline_result}
      end => {
          controller: RedditController,
          action: :handle_chosen_inline_result
      },
      Proc.new do |message|
        is_reddit_link?(message)
      end => {
          controller: RedditController,
          action: :get_media_from_url
      },
      Proc.new do |message|
        regex_match message, %r{^\/s\/.*\/.*$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      Proc.new do |message|
        regex_match message, %r{^\/spam$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      Proc.new do |message|
        regex_match message, %r{^\/spam .*$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      Proc.new do |message|
        regex_match message, %r{^\/bilov.*$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      Proc.new do |message|
        regex_match message, %r{^\/distort$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      Proc.new do |message|
        regex_match message, %r{^\/distort@[^@]*$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      Proc.new do |message|
        regex_match message, %r{^\/d$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      Proc.new do |message|
        regex_match message, %r{^scale$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      Proc.new do |message|
        regex_match message, %r{^fry}i
      end => {
          controller: ImageController,
          action: :deepfry_reply
      },
      Proc.new do |message|
        # percentage integer
        probability = 2
        false unless is_image? message
        rand(100) < probability
      end => {
          controller: ImageController,
          action: :deepfry
      },
      Proc.new do |message|
        is_link?(message) && !is_reddit_link?(message)
      end => {
          controller: YoutubedlController,
          action: :send_video
      }

  }.freeze
end
