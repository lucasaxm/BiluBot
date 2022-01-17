Dir['controllers/*.rb'].each { |file| require_relative file }

module Routes
  class << self
    attr_reader :message_map

    def regex_match(message, regex)
      text = if is_callback_query? message
               message.data
             else
               message.text
             end
      return false if text.nil?
      regex.match? text.to_s
    end

    def is_image? message
      !is_callback_query?(message) && (!message.photo.empty? || !message.sticker.nil? || (!message.document.nil? && message.document.mime_type.start_with?('image/')))
    end

    def is_link?(message)
      !is_callback_query?(message) && !message.entities.nil? && !message.entities.empty? && message.entities.any? { |entity| entity.type == 'url' }
    end

    def is_reddit_link?(message)
      regex_match(message, %r{^(https?:\/\/(www\.)?)?reddit\.com\S*\/comments\/\w+\S*$})
    end

    private

    def is_callback_query?(message)
      message.class == Telegram::Bot::Types::CallbackQuery
    end
  end


  @message_map = {
      lambda do |message|
        regex_match message, %r{^/((r)|(reddit)) \w+$}i
      end => {
          controller: RedditController,
          action: :get_media_from_subreddit
      },
      #lambda do |message|
      #  regex_match message, %r{^\/delete$}i
      #end => {
      #    controller: MiscController,
      #    action: :delete_reply
      #},
      lambda do |message|
        regex_match message, %r{^callback /((r)|(reddit)) \w+$}i
      end => {
          controller: RedditController,
          action: :get_media_from_subreddit_callback
      },
      lambda do |message|
        regex_match message, %r{^/((usr)|(unbansubreddit)) \w+$}i
      end => {
        controller: RedditController,
        action: :unban_subreddit
      },
      lambda do |message|
        regex_match message, %r{^/((bsr)|(bansubreddit)) \w+$}i
      end => {
        controller: RedditController,
        action: :ban_subreddit
      },
      lambda do |message|
        regex_match message, %r{^\/weather [[:alpha:]]+( [[:alpha:]]+)*$}i
      end => {
          controller: ForecastController,
          action: :get_current_weather
      },
      lambda do |message|
        regex_match message, %r{^/markov(@mkv_bot)?$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      lambda do |message|
        is_reddit_link?(message)
      end => {
          controller: RedditController,
          action: :get_media_from_url
      },
      lambda do |message|
        regex_match message, %r{^\/s\/.*\/.*$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      lambda do |message|
        regex_match message, %r{^\/spam$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      lambda do |message|
        regex_match message, %r{^\/spam .*$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      lambda do |message|
        regex_match message, %r{^\/bilov.*$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      lambda do |message|
        regex_match message, %r{^\/distort$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      lambda do |message|
        regex_match message, %r{^\/distort@[^@]*$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      lambda do |message|
        regex_match message, %r{^\/d$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      lambda do |message|
        regex_match message, %r{^scale$}i
      end => {
          controller: ImageController,
          action: :distort_reply
      },
      lambda do |message|
        regex_match message, %r{^fry$}i
      end => {
          controller: ImageController,
          action: :deepfry_reply
      },
      lambda do |message|
        regex_match message, %r{^\/fry$}i
      end => {
        controller: ImageController,
        action: :deepfry_reply
      },
      lambda do |message|
        # percentage integer
        probability = 1
        return false unless is_image? message
        rand(100) < probability
      end => {
          controller: ImageController,
          action: :deepfry
      },
      lambda do |message|
        is_link?(message) && !is_reddit_link?(message)
      end => {
          controller: GalleryDLController,
          action: :send_media
      },
      lambda do |message|
        regex_match message, %r{^\/keyboard .*$}i
      end => {
        controller: MiscController,
        action: :keyboard
      },
      lambda do |message|
        regex_match message, %r{^\/close$}i
      end => {
        controller: MiscController,
        action: :close_keyboard
      }

  }.freeze
end
