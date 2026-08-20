# frozen_string_literal: true
require 'open-uri'
require 'telegram/bot'
require 'uri'
require 'tmpdir'
require_relative "#{__dir__}/../lib/gallery_dl"
require_relative "#{__dir__}/../lib/reddit/video_downloader"
require_relative "#{__dir__}/../logger/logging"
require_relative "#{__dir__}/../config/reddit_config"
require_relative "#{__dir__}/../models/reddit_post"
require_relative "#{__dir__}/../models/subreddit"
require_relative "#{__dir__}/../models/banned_subreddit"
require_relative "#{__dir__}/../models/chat"
require_relative "#{__dir__}/screenshot_service"

##
# Class that holds all logic related to Reddit
# noinspection RubyArgCount
class RedditService
  include Logging

  def initialize(bilu, message)
    @reddit_session = RedditConfig.new_reddit_session
    @bilu = bilu
    @message = message
    @callback = nil
  end

  def get_media_from_subreddit_callback(chat)
    newtext = @message.data.split(' ')[1..-1].join(' ')
    # Telegram types are immutable structs, so rebuild the message with the new text
    @message = @message.message.new(text: newtext)
    get_media_from_subreddit(chat)
  end

  def is_banned?(subreddit, chat)
    !BannedSubreddit.find_by(chat_id: chat.id, subreddit_id: subreddit.id).nil?
  end

  def ban_subreddit(chat)
    text_array = @message.text.split(' ')
    if chat.telegram_type != 'private'
      chat_member = @bilu.bot.api.get_chat_member(chat_id: chat.telegram_id, user_id: @message.from.id)
      status = chat_member.status
      if (status != 'creator') && (status != 'administrator')
        @bilu.reply_with_text('You are not an Administrator', @message)
        return
      end
    end
    if text_array.size <= 1
      send_help_message
      return
    end
    subreddit_name = text_array[1]
    subreddit_db = get_subreddit_from_db(subreddit_name)
    return if subreddit_db.nil?

    logger.info("banning /r/#{subreddit_name} on chat #{chat.telegram_id}.")
    banned_subreddit = BannedSubreddit.find_or_initialize_by(chat_id: chat.id, subreddit_id: subreddit_db.id)
    if banned_subreddit.new_record?
      banned_subreddit.subreddit_id = subreddit_db.id
      banned_subreddit.save
      @bilu.reply_with_text("subreddit #{subreddit_db.name} banned", @message)
    else
      @bilu.reply_with_text("subreddit #{subreddit_db.name} was already banned on this chat.", @message)
    end
  end

  def unban_subreddit(chat)
    text_array = @message.text.split(' ')
    if chat.telegram_type != 'private'
      chat_member = @bilu.bot.api.get_chat_member(chat_id: chat.telegram_id, user_id: @message.from.id)
      status = chat_member.status
      if (status != 'creator') && (status != 'administrator')
        @bilu.reply_with_text('You are not an Administrator', @message)
        return
      end
    end
    if text_array.size <= 1
      send_help_message
      return
    end
    subreddit_name = text_array[1]
    subreddit_db = get_subreddit_from_db(subreddit_name)
    return if subreddit_db.nil?

    logger.info("banning /r/#{subreddit_name} on chat #{chat.telegram_id}.")
    banned_subreddit = BannedSubreddit.find_by(chat_id: chat.id, subreddit_id: subreddit_db.id)
    if banned_subreddit.nil?
      @bilu.reply_with_text("subreddit #{subreddit_db.name} wasn't banned on this chat.", @message)
    else
      banned_subreddit.destroy
      @bilu.reply_with_text("subreddit #{subreddit_db.name} unbanned", @message)
    end
  end

  def get_media_from_subreddit(chat)
    text_array = if @callback.nil?
                   @message.text.split(' ')
                 else
                   @message.data.split(' ')[1..-1]
                 end
    if text_array.size <= 1
      send_help_message
      return
    end
    subreddit_name = text_array[1]
    # Reddit API block
    begin
      subreddit_db = get_subreddit_from_db(subreddit_name)
      return if subreddit_db.nil?

      logger.info("searching for /r/#{subreddit_name}.")
      error_count ||= 0
      if !chat.nsfw? && subreddit_db.nsfw?
        answer = 'NSFW subreddits are banned.'
        @bilu.reply_with_text(answer, @message)
        return
      end
      if is_banned?(subreddit_db, chat)
        answer = 'This subreddit is banned'
        @bilu.reply_with_text(answer, @message)
        return
      end
      @bilu.bot.api.send_chat_action(
        chat_id: get_telegram_chat_id,
        action: 'typing'
      )
      # hot_posts = get_subreddit_hot_media_posts(subreddit_name)
      hot_posts = get_subreddit_hot_posts(subreddit_name)
    rescue Reddit::Errors::NotFound, JSON::ParserError => e
      answer = "subreddit #{subreddit_name} not found."
      logger.error(answer)
      logger.error("Exception Class: [#{e.class.name}]")
      logger.error("Exception Message: [#{e.message}']")
      @bilu.reply_with_text(answer, @message)
      return
    rescue Reddit::Errors::Unauthorized => e
      error_count += 1
      @reddit_session.refresh
      if error_count < 5
        logger.warn('Reddit session refreshed. Retrying.')
        sleep(1)
        retry
      end
      return
    rescue Reddit::Errors::Forbidden => e
      answer = "Access to this subreddit is forbidden. Reason: #{e.message}"
      @bilu.reply_with_text(answer, @message)
      return
    end
    if hot_posts.empty?
      answer = "subreddit #{subreddit_name} has no media to send."
      logger.warn(answer)
      @bilu.reply_with_text(answer, @message)
      return
    end
    post_sent = false
    hot_posts.to_a.each_with_index do |hot_post, i|
      reddit_post = RedditPost.find_or_initialize_by(reddit_id: hot_post.id)
      if reddit_post.new_record?
        reddit_post.assign_attributes(title: hot_post.title,
                                      score: hot_post.score,
                                      nsfw: hot_post.over_18?,
                                      url: hot_post.url)
        reddit_post.subreddit = subreddit_db
      elsif reddit_post.chats.include? chat
        logger.info("##{i + 1} of #{hot_posts.size} was already sent.")
        next
      end
      if !chat.nsfw? && reddit_post.nsfw?
        logger.info("##{i + 1} of #{hot_posts.size} is NSFW and it's not allowed in this chat.")
        next
      end
      reddit_post.chats << chat
      logger.info("Sending ##{i + 1} of #{hot_posts.size} posts.")
      reddit_post.save
      begin
        return if special_subreddit(hot_post)
        send_media(hot_post)
      rescue Telegram::Bot::Exceptions::Base => e
        logger.error("Error sending post, trying next post if available. Exception Message: [#{e.message}]")
        next
      end
      post_sent = true
      break
    end
    return if post_sent

    logger.warn('There are no posts left to send. Sending "no available" message.')
    answer = 'No available posts in this subreddit right now.'
    @bilu.reply_with_text(answer, @message)
  end

  def get_media_from_url(chat)
    reddit_url = extract_reddit_url(@message.text)
    return if reddit_url.nil?

    final_url = reddit_url.include?('/comments/') ? reddit_url : resolve_redirect(reddit_url)
    words = final_url.split('/')
    comments_index = words.find_index('comments')
    return if comments_index.nil? || words[comments_index + 1].nil?

    post_id = "t3_#{words[comments_index + 1]}"
    post = reddit_post_from_id(post_id)
    return if post.nil?
    if !chat.nsfw? && post.over_18?
      answer = 'NSFW posts are banned.'
      @bilu.reply_with_text(answer, @message)
      return
    end
    return if special_subreddit(post)
    send_media(post)
  rescue StandardError => e
    logger.error("Error resolving reddit link from message: [#{e.class.name}] #{e.message}")
  end

  def self.reddit_post_reply_markup(post)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [[
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: "#{post.comment_count} Comments",
          url: "https://www.reddit.com#{post.permalink}"
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: "More from r/#{post.subreddit.display_name}",
          callback_data: "callback /r #{post.subreddit.display_name}"
        )
      ]]
    )
  end

  private

  def extract_reddit_url(text)
    match = text.to_s.match(%r{(https?://)?(www\.)?reddit\.com\S*}i)
    match&.to_s
  end

  def resolve_redirect(url, limit = 10)
    return url if url.include?('/comments/')
    raise ArgumentError, 'Too many HTTP redirects' if limit == 0

    uri = URI(url)
    location = @reddit_session.resolve_share_link(uri.request_uri)
    return url if location.nil?

    resolve_redirect(URI.join(uri, location).to_s, limit - 1)
  end

  def get_subreddit_from_db(subreddit_name)
    subreddit = @reddit_session.subreddit(subreddit_name)
    subreddit_db = Subreddit.find_or_initialize_by(reddit_id: subreddit.id)
    if subreddit_db.new_record?
      subreddit_db.name = subreddit_name
      subreddit_db.nsfw = subreddit.over_18?
      subreddit_db.save
      logger.info("subreddit #{subreddit_db.name} saved to database")
    end
    subreddit_db
  rescue Reddit::Errors::NotFound, JSON::ParserError => e
    answer = "subreddit #{subreddit_name} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    @bilu.reply_with_text(answer, @message)
    nil
  end

  def reddit_post_from_id(post_id)
    @reddit_session.from_ids(post_id).first
  end

  def send_media(post)
    logger.debug("Post: score=[#{post.score}] title=[#{post.title}] url=[#{post.url}]")

    if post.self?
      send_self_post(post)
    elsif post.gallery?
      send_gallery(post)
    elsif !post.reddit_video.nil?
      send_reddit_video(post)
    elsif post.gif?
      send_gif(post)
    elsif post.reddit_hosted_media?
      send_photo(post)
    else
      begin
        GalleryDLService.new(@bilu, @message, post).send_media
      rescue Telegram::Bot::Exceptions::Base => e
        logger.error("gallery-dl failed sending #{post.url}: [#{e.class.name}] #{e.message}")
        @bilu.reply_with_text("#{post.title}\n#{post.url}", @message)
      end
    end
  end

  def send_self_post(post)
    logger.debug('START - Sending self post as text through telegram API.')
    max_len = 3500
    body = post.selftext.to_s.strip
    body = "#{body[0, max_len]}..." if body.length > max_len
    body_text = post.over_18? || post.spoiler? ? Telegram::Bot::Types::RichTextSpoiler.new(text: body) : body
    # A native collapsible "Read more" section instead of a wall of text.
    media_blocks = body.empty? ? [] : [
      Telegram::Bot::Types::InputRichBlockDetails.new(
        summary: 'Read more',
        blocks: [Telegram::Bot::Types::InputRichBlockParagraph.new(text: body_text)]
      )
    ]
    send_rich_post(post, media_blocks)
    logger.debug('END - Sending self post as text through telegram API.')
  end

  def send_reddit_video(post)
    logger.debug("START - Sending reddit-hosted video #{post.url} through telegram API.")
    Dir.mktmpdir("reddit_video_#{Thread.current.object_id}") do |dir|
      local_path = Reddit::VideoDownloader.download(post.reddit_video, dir)
      if local_path.nil?
        send_mp4(post, post.reddit_video['fallback_url'])
      else
        send_local_mp4(post, local_path)
      end
    end
    logger.debug("END - Sending reddit-hosted video #{post.url} through telegram API.")
  end

  def send_local_mp4(post, filepath)
    logger.debug("START - Sending #{filepath} as video through telegram API.")
    new_filepath = filepath
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    upload = Faraday::UploadIO.new(new_filepath, 'video/mp4')
    @bilu.bot.api.send_video(
      chat_id: get_telegram_chat_id,
      video: upload,
      caption: reddit_caption_header(post),
      parse_mode: 'HTML',
      reply_to_message_id: get_telegram_message_id,
      supports_streaming: true,
      has_spoiler: post.over_18? || post.spoiler?,
      reply_markup: RedditService.reddit_post_reply_markup(post)
    )
    upload.close
    FileUtils.rm(filepath) if File.exist?(filepath)
    FileUtils.rm("#{filepath}.json") if File.exist?("#{filepath}.json")
    FileUtils.rm(new_filepath) if File.exist?(new_filepath)
    logger.debug("END - Sending #{filepath} as video through telegram API.")
  end

  def make_telegram_html_url(url)
    url.gsub('<', '&lt;').gsub('>', '&gt;').gsub('&', '&amp;')
  end

  # HTML caption fallback for the one path that can't use rich message blocks
  # (a locally-uploaded, muxed video file), styled to match the post card.
  def reddit_caption_header(post)
    meta = "r/#{make_telegram_html_url(post.subreddit.display_name)}"
    meta += " • u/#{make_telegram_html_url(post.author)}" if post.author && post.author != '[deleted]'
    tags = []
    tags << "\u{1F51E} NSFW" if post.over_18?
    tags << "\u{26A0} SPOILER" if post.spoiler?
    lines = [meta]
    lines << tags.join(' ') unless tags.empty?
    lines << "<b>#{make_telegram_html_url(post.title)}</b>"
    "#{lines.join("\n")}\n\n\u{25B2} #{post.score}"
  end

  def reddit_selfpost_description(post)
    if post.self?
      post.selftext.empty? ? post.title : post.selftext
    else
      ''
    end
  end

  def send_photo(post, url = nil)
    url = post.url if url.nil?
    logger.debug("START - Sending #{url} as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_photo'
    )
    photo_block = Telegram::Bot::Types::InputRichBlockPhoto.new(
      photo: Telegram::Bot::Types::InputMediaPhoto.new(media: url.to_s, has_spoiler: post.over_18? || post.spoiler?)
    )
    send_rich_post(post, [photo_block])
    logger.debug("END - Sending #{url} as photo through telegram API.")
  end

  def send_mp4(post, new_url = nil)
    mp4url = new_url.nil? ? post.url.to_s : new_url
    logger.debug("START - Sending #{mp4url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    video_block = Telegram::Bot::Types::InputRichBlockVideo.new(
      video: Telegram::Bot::Types::InputMediaVideo.new(
        media: mp4url,
        supports_streaming: true,
        has_spoiler: post.over_18? || post.spoiler?
      )
    )
    send_rich_post(post, [video_block])
    logger.debug("END - Sending #{mp4url} as video through telegram API.")
  end

  def send_gallery(post)
    logger.debug('START - Sending rich message gallery through telegram API.')
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'typing'
    )
    photo_blocks = post.gallery_urls.first(50).map do |url|
      Telegram::Bot::Types::InputRichBlockPhoto.new(
        photo: Telegram::Bot::Types::InputMediaPhoto.new(media: url, has_spoiler: post.over_18? || post.spoiler?)
      )
    end
    send_rich_post(post, [Telegram::Bot::Types::InputRichBlockCollage.new(blocks: photo_blocks)])
    logger.debug('END - Sending rich message gallery through telegram API.')
  end

  # Builds and sends a single Reddit-post-card message: meta/tag/title header,
  # the type-specific media blocks, a score footer, and the existing buttons.
  # sendMediaGroup/sendPhoto/sendVideo have no reply_markup for this, but
  # sendRichMessage does - one message, no follow-up call, no chat redirection.
  def send_rich_post(post, media_blocks)
    blocks = reddit_header_blocks(post) + Array(media_blocks) + [reddit_footer_block(post)]
    @bilu.bot.api.send_rich_message(
      chat_id: get_telegram_chat_id,
      reply_parameters: Telegram::Bot::Types::ReplyParameters.new(message_id: get_telegram_message_id),
      rich_message: Telegram::Bot::Types::InputRichMessage.new(blocks: blocks),
      reply_markup: RedditService.reddit_post_reply_markup(post)
    )
  end

  # "r/subreddit • u/author" line, NSFW/SPOILER tag badges, then the title.
  def reddit_header_blocks(post)
    meta = [Telegram::Bot::Types::RichTextBold.new(text: "r/#{post.subreddit.display_name}")]
    meta << " • u/#{post.author}" if post.author && post.author != '[deleted]'
    blocks = [Telegram::Bot::Types::InputRichBlockParagraph.new(text: meta)]

    tags = []
    tags << Telegram::Bot::Types::RichTextMarked.new(text: "\u{1F51E} NSFW") if post.over_18?
    tags << Telegram::Bot::Types::RichTextMarked.new(text: "\u{26A0} SPOILER") if post.spoiler?
    blocks << Telegram::Bot::Types::InputRichBlockParagraph.new(text: tags.flat_map { |t| [t, ' '] }[0..-2]) unless tags.empty?

    blocks << Telegram::Bot::Types::InputRichBlockSectionHeading.new(text: post.title, size: 3)
    blocks
  end

  def reddit_footer_block(post)
    Telegram::Bot::Types::InputRichBlockFooter.new(text: "\u{25B2} #{post.score}")
  end


  def send_gif(post)
    animation_url = post.gif_video_url
    logger.debug("START - Sending #{animation_url} as animation through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    animation_block = Telegram::Bot::Types::InputRichBlockAnimation.new(
      animation: Telegram::Bot::Types::InputMediaAnimation.new(
        media: animation_url,
        has_spoiler: post.over_18? || post.spoiler?
      )
    )
    send_rich_post(post, [animation_block])
    logger.debug("END - Sending #{animation_url} as animation through telegram API.")
  end

  def get_telegram_chat_id
    if @callback.nil?
      @message.chat.id
    else
      @message.message.chat.id
    end
  end

  def get_telegram_message_id
    if @callback.nil?
      @message.message_id
    else
      @message.message.message_id
    end
  end

  def reddit_post_caption(post)
    caption = "#{post.over_18? ? "\u{1F51E} NSFW " : ''}#{post.spoiler? ? "\u{26A0} SPOILER" : ''}\n#{post.title}"
    unless @callback.nil?
      caption += "\n\n[post request by #{@callback.from.username.nil? ? @callback.from.first_name : "@#{@callback.from.username}"}]"
    end
    caption
  end

  def prepare_gifv_url(url)
    url_array = url.split('.')
    url_array.pop
    url_array.push 'mp4'
    url_array.join '.'
  end

  def send_screenshot(post)
    style = post.spoiler? ? 'i' : 'www'
    permalink = "https://#{style}.reddit.com#{post.permalink}"
    logger.debug("START - Sending #{permalink} screenshot as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_photo'
    )
    
    options = {
      response_type: 'json',
      format: 'jpeg',
      cookies: "over18=1",
      wait_until: 'dom_loaded',
    }
    case style
    when 'www'
      options.merge!({
        element: "##{post.name}"
      })
    when 'i','old'
      options.merge!({
        element: '#siteTable',
        width: 700
      })
    end
    send_photo(post, ScreenshotService.screenshot_url(permalink, options))
    logger.debug("END - Sending #{permalink} screenshot as photo through telegram API.")
  end

  def send_gifv(post)
    new_url = prepare_gifv_url(post.url)
    logger.debug("START - Sending #{new_url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: get_telegram_chat_id,
      video: new_url,
      caption: reddit_post_caption(post),
      supports_streaming: true,
      reply_to_message_id: get_telegram_message_id,
      reply_markup: RedditService.reddit_post_reply_markup(post)
    )
    logger.debug("END - Sending #{new_url} as video through telegram API.")
  end

  def get_subreddit_hot_media_posts(subreddit)
    logger.debug('START - Fetching and filtering posts.')
    selection = get_subreddit_hot_posts(subreddit).find_all do |p|
      (!p.url.nil? &&
        ((p.url.end_with? '.jpg') ||
          (p.url.end_with? '.png') ||
          (p.url.end_with? '.gif') ||
          (p.url.end_with? '.gifv') ||
          (p.url.end_with? '.mp4') ||
          (p.url.include? 'gfycat.com') ||
          (p.is_reddit_media_domain && p.is_video))) ||
        (p.instance_variable_get :@attributes)[:is_gallery]
    end
    logger.debug('END - Fetching and filtering posts.')
    selection
  end

  def get_subreddit_hot_posts(subreddit)
    @reddit_session.subreddit(subreddit).hot.to_a.select{|h| !h.stickied? }
  end

  def send_help_message
    help =
      "`/reddit subreddit`\n\u{2022} Get a random media post from subreddit."
    @bilu.reply_with_markdown_text(help, @message)
  end

  def send_poll(post)
    @bilu.bot.api.send_poll({
      chat_id: get_telegram_chat_id,
      question: post.title,
      options: post.poll_data[:options].map{|option| option[:text]},
      open_period: 300,
      is_anonymous: false,
      reply_markup: RedditService.reddit_post_reply_markup(post)
    })
  end

  def special_subreddit(post)
    case post.subreddit.display_name.downcase
    when 'wouldyourather','polls'
      return false if post.to_h[:poll_data].nil?

      send_poll(post)
    else
      return false
    end

    return true
  end
end
