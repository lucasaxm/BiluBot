require 'open-uri'
require 'telegram/bot'
require_relative '../logger/logging'
require_relative '../config/reddit_config'
require_relative '../models/reddit_post'
require_relative '../models/subreddit'
require_relative '../models/chat'

##
# Class that holds all logic related to Reddit
# noinspection RubyArgCount
class RedditService
  include Logging

  def initialize(bilu)
    @reddit_session = RedditConfig.new_reddit_session
    @bilu = bilu
  end

  def get_media_from_subreddit(message, chat)
    text_array = message.text.split(' ')
    if text_array.size <= 1
      send_help_message(message)
      return
    end
    subreddit = text_array[1]
    logger.info("searching for /r/#{subreddit}.")
    error_count ||= 0
    unless RedditConfig.valid_subreddit? subreddit
      answer = 'This subreddit is banned'
      @bilu.reply_with_text(answer, message)
      return
    end
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'typing'
    )
    hot_posts = get_subreddit_hot_media_posts(subreddit)
    if hot_posts.empty?
      answer = "subreddit #{subreddit} has no media to send."
      logger.warn(answer)
      @bilu.reply_with_text(answer, message)
      return
    end
    sample = nil
    hot_posts.each_with_index do |hot_post, i|
      reddit_post = RedditPost.find_or_initialize_by(reddit_id: hot_post.id)
      if reddit_post.new_record?
        reddit_post.assign_attributes(title: hot_post.title,
                                      score: hot_post.score,
                                      nsfw: hot_post.over_18,
                                      url: hot_post.url)
        subreddit_db = Subreddit.find_or_initialize_by(reddit_id: hot_post.subreddit_id)
        if subreddit_db.new_record?
          subreddit_db.name = hot_post.subreddit_name_prefixed
          subreddit_db.save
          logger.info("subreddit #{subreddit_db.name} saved to database")
        end
        reddit_post.subreddit = subreddit_db
      elsif reddit_post.chats.include? chat
        logger.info("##{i + 1} of #{hot_posts.size} was already sent.")
        next
      end
      reddit_post.chats << chat
      reddit_post.save
      logger.info("Sending ##{i + 1} of #{hot_posts.size} posts.")
      sample = hot_post
      break
    end
    if sample.nil?
      logger.warn('There are no posts left to send. Sending "try again later" message.')
      answer = 'You have seen all hot posts in this subreddit. Try again later.'
      @bilu.reply_with_text(answer, message)
    else
      logger.debug("Sample: score=[#{sample.score}] title=[#{sample.title}] url=[#{sample.url}]")
      send_media(message, sample)
    end
  rescue Redd::NotFound, JSON::ParserError => e
    answer = "subreddit #{subreddit} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    @bilu.reply_with_text(answer, message)
  rescue Redd::InvalidAccess => e
    error_count += 1
    @reddit_session.client.refresh
    if error_count < 5
      logger.warn('Reddit session refreshed. Retrying.')
      sleep(1)
      retry
    end
  rescue Redd::Forbidden => e
    answer = "Access to this subreddit is forbidden. Reason: #{e.message.split[1]}"
    @bilu.reply_with_text(answer, message)
  end

  def handle_inline_query(inline_query)
    return if inline_query.query.empty?
    logger.debug("Query: #{inline_query.query}")
    results = get_subreddit_hot_posts(inline_query.query).map do |post|
      create_inline_query_result_media post
    end
    @bilu.bot.api.answer_inline_query(inline_query_id: inline_query.id, results: results)
  rescue Redd::NotFound, JSON::ParserError => e
    answer = "subreddit #{inline_query.query} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    @bilu.bot.api.answer_inline_query(inline_query_id: inline_query.id,
                                      cache_time: 1,
                                      results: [],
                                      switch_pm_text: answer,
                                      switch_pm_parameter: 'e')
  rescue Redd::Forbidden => e
    answer = "Access to this subreddit is forbidden. Reason: #{e.message.split[1]}"
    @bilu.bot.api.answer_inline_query(inline_query_id: inline_query.id,
                                      cache_time: 1,
                                      results: [],
                                      switch_pm_text: answer,
                                      switch_pm_parameter: 'e')
  end

  def handle_chosen_inline_result(chosen_inline_result)
    ;
  end

  private

  def send_media(message, post)
    url_extension = post.url.split('.').last
    if url_extension == 'gif'
      send_gif(message, post)
    elsif url_extension == 'gifv'
      send_gifv(message, post)
    elsif url_extension == 'mp4'
      send_mp4(message, post)
    elsif post.url.include? 'gfycat.com'
      gif_name = post.url.split('/').last
      new_url = JSON.parse(open("https://api.gfycat.com/v1/gfycats/#{gif_name}").string)['gfyItem']['mp4Url']
      send_mp4(message, post, new_url)
    else
      send_photo(message, post)
    end
  end

  def create_inline_query_result_media(post)
    default_info = {
      id: post.id,
      title: reddit_post_caption(post),
      thumb_url: (post.thumbnail unless post.is_self),
      thumb_width: (post.thumbnail_width unless post.is_self),
      thumb_height: (post.thumbnail_height unless post.is_self)
    }
    # url_extension = post.url.split('.').last
    # if url_extension == 'gif'
    #   Telegram::Bot::Types::InlineQueryResultGif.new({
    #                                                    gif_url: post.url,
    #                                                    caption: "[#{default_info[:title]}](https://reddit.com#{post.permalink})",
    #                                                    parse_mode: 'markdown'
    #                                                  }.merge(default_info))
    # elsif url_extension == 'gifv'
    #   new_url = prepare_gifv_url(post.url)
    #   Telegram::Bot::Types::InlineQueryResultVideo.new({
    #                                                      video_url: new_url,
    #                                                      mime_type: 'video/mp4'
    #                                                    }.merge(default_info))
    # elsif url_extension == 'mp4'
    #   Telegram::Bot::Types::InlineQueryResultVideo.new({
    #                                                      video_url: post.url,
    #                                                      mime_type: 'video/mp4'
    #                                                    }.merge(default_info))
    # elsif post.url.include? 'gfycat.com'
    #   gif_name = post.url.split('/').last
    #   new_url = JSON.parse(open("https://api.gfycat.com/v1/gfycats/#{gif_name}").string)["gfyItem"]["mp4Url"]
    #   Telegram::Bot::Types::InlineQueryResultVideo.new({
    #                                                      video_url: new_url,
    #                                                      mime_type: 'video/mp4'
    #                                                    }.merge(default_info))
    # else
    #   Telegram::Bot::Types::InlineQueryResultArticle.new({
    #                                                        description: (post.selftext if post.is_self),
    #                                                        input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(
    #                                                          message_text: post.url
    #                                                        )}.merge(default_info))
    # end
    Telegram::Bot::Types::InlineQueryResultArticle.new({
                                                         description: reddit_selfpost_description(post),
                                                         input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(
                                                           message_text: input_text_message_content(post),
                                                           parse_mode: 'html'
                                                         ),
                                                         reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
                                                           inline_keyboard: reddit_post_buttons(post)
                                                         )
                                                       }.merge(default_info))
  end

  def input_text_message_content(post)
    "<a href=\"#{make_telegram_html_url(post.is_self ? reddit_post_full_permalink(post) : post.url)}\">#{reddit_post_caption(post)}</a>"
  end

  def reddit_post_full_permalink(post)
    "https://reddit.com#{post.permalink}"
  end

  def make_telegram_html_url(url)
    url.gsub('<', '&lt;').gsub('>', '&gt;').gsub('&', '&amp;')
  end

  def reddit_selfpost_description(post)
    if post.is_self
      post.selftext.empty? ? post.title : post.selftext
    else
      ''
    end
  end

  def send_photo(message, post)
    logger.debug("START - Sending #{post.url} as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_photo'
    )
    @bilu.bot.api.send_photo(
      chat_id: message.chat.id,
      photo: post.url.to_s,
      caption: reddit_post_caption(post),
      reply_to_message_id: message.message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as photo through telegram API.")
  end

  def reddit_post_buttons(post)
    [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "#{post.num_comments} Comments",
        url: reddit_post_full_permalink(post)
      )
    ]
  end

  def send_mp4(message, post, new_url = nil)
    logger.debug("START - Sending #{post.url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: message.chat.id,
      video: new_url.nil? ? post.url.to_s : new_url,
      caption: reddit_post_caption(post),
      reply_to_message_id: message.message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as video through telegram API.")
  end

  def send_gif(message, post)
    logger.debug("START - Sending #{post.url} as document through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_document(
      chat_id: message.chat.id,
      document: post.url,
      caption: reddit_post_caption(post),
      reply_to_message_id: message.message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as document through telegram API.")
  end

  def reddit_post_caption(post)
    "(#{post.score}) - #{post.title}"
  end

  def prepare_gifv_url(url)
    url_array = url.split('.')
    url_array.pop
    url_array.push 'mp4'
    url_array.join '.'
  end

  def send_gifv(message, post)
    new_url = prepare_gifv_url(post.url)
    logger.debug("START - Sending #{new_url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: message.chat.id,
      video: new_url,
      caption: reddit_post_caption(post),
      reply_to_message_id: message.message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{new_url} as video through telegram API.")
  end

  def get_subreddit_hot_media_posts(subreddit)
    logger.debug('START - Fetching and filtering posts.')
    selection = get_subreddit_hot_posts(subreddit).find_all do |p|
      !p.url.nil? && ((p.url.end_with? '.jpg') || (p.url.end_with? '.png') || (p.url.end_with? '.gif') ||
        (p.url.end_with? '.gifv') || (p.url.end_with? '.mp4') || (p.url.include? 'gfycat.com'))
    end
    logger.debug('END - Fetching and filtering posts.')
    selection
  end

  def get_subreddit_hot_posts(subreddit)
    @reddit_session.subreddit(subreddit).hot
  end

  def send_help_message(message)
    help =
      "`/reddit subreddit`\n\u{2022} Get a random media post from subreddit."
    @bilu.reply_with_markdown_text(help, message)
  end
end