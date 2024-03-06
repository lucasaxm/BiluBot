Dir["#{__dir__}/controllers/*.rb"].each { |file| require_relative file }
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

    def has_link?(message)
      !is_callback_query?(message) && !message.entities.nil? && !message.entities.empty? && message.entities.any? { |entity| ['url','text_link'].include? entity.type }
    end

    def is_via_bilutempobot?(message)
      !message.via_bot.nil? && message.via_bot.username == 'bilutempobot'
    end

    def is_reddit_link?(message)
      existing_pattern = %r{^(https?:\/\/(www\.)?)?reddit\.com\S*\/comments\/\w+\S*$}
      new_pattern = %r{^(https?:\/\/(www\.)?)?reddit\.com\/r\/([^/?#]+)\/s\/([a-zA-Z0-9]{10})}

      combined_pattern = Regexp.union(existing_pattern, new_pattern)

      regex_match(message, combined_pattern)
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
        regex_match message, %r{^callback /((r)|(reddit))(?:@((?!^$)([^\s]))*)? \w+$}i
      end => {
          controller: RedditController,
          action: :get_media_from_subreddit_callback
      },
      lambda do |message|
        regex_match message, %r{^/((usr)|(unbansubreddit))(?:@((?!^$)([^\s]))*)? \w+$}i
      end => {
        controller: RedditController,
        action: :unban_subreddit
      },
      lambda do |message|
        regex_match message, %r{^/((bsr)|(bansubreddit))(?:@((?!^$)([^\s]))*)? \w+$}i
      end => {
        controller: RedditController,
        action: :ban_subreddit
      },
      # lambda do |message|
      #   is_reddit_link?(message)
      # end => {
      #     controller: RedditController,
      #     action: :get_media_from_url
      # },
      lambda do |message|
        regex_match message, %r{^\/spam(?:@((?!^$)([^\s]))*)?$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      lambda do |message|
        regex_match message, %r{^\/spam(?:@((?!^$)([^\s]))*)? .*$}i
      end => {
          controller: MiscController,
          action: :spam
      },
      lambda do |message|
        regex_match message, %r{^\/print(?:@((?!^$)([^\s]))*)?$}i
      end => {
          controller: ScreenshotService,
          action: :take_screenshot
      },
      lambda do |message|
        regex_match message, %r{^\/print(?:@((?!^$)([^\s]))*)? .*$}i
      end => {
          controller: ScreenshotService,
          action: :take_screenshot
      },
      lambda do |message|
        regex_match message, %r{^\/leiaisso(?:@((?!^$)([^\s]))*)?$}i
      end => {
          controller: ScreenshotService,
          action: :leia_isso
      },
      lambda do |message|
        regex_match message, %r{^\/leiaisso(?:@((?!^$)([^\s]))*)? .*$}i
      end => {
          controller: ScreenshotService,
          action: :leia_isso
      },
      lambda do |message|
        regex_match message, %r{^\/bilov(?:@((?!^$)([^\s]))*)?$}i
      end => {
          controller: MiscController,
          action: :delete_message
      },
      lambda do |message|
        regex_match message, %r{^fry$}i
      end => {
          controller: ImageController,
          action: :deepfry_reply
      },
      lambda do |message|
        # has_link?(message) && !is_reddit_link?(message) && !is_via_bilutempobot?(message)
        has_link?(message) && !is_via_bilutempobot?(message)
      end => {
          controller: GalleryDLController,
          action: :fetch_metadata
      },
      lambda do |message|
        regex_match message, %r{^callback download .*}i
      end => {
          controller: GalleryDLController,
          action: :fetch_metadata_callback
      },
      lambda do |message|
        regex_match message, %r{^-p [[:alpha:]]+( [[:alpha:]]+)*$}i
      end => {
          controller: GalleryDLController,
          action: :search_and_send_as_audio
      },
      lambda do |message|
        regex_match message, %r{^-v [[:alpha:]]+( [[:alpha:]]+)*$}i
      end => {
          controller: GalleryDLController,
          action: :search_and_send_as_video
      },
      lambda do |message|
        regex_match message, %r{^\/keyboard(?:@((?!^$)([^\s]))*)? .*$}i
      end => {
        controller: MiscController,
        action: :keyboard
      },
      lambda do |message|
        regex_match message, %r{^\/close(?:@((?!^$)([^\s]))*)?$}i
      end => {
        controller: MiscController,
        action: :close_keyboard
      }
  }.freeze
end
