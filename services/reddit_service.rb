require 'open-uri'
require 'telegram/bot'
require 'nokogiri'
require 'youtube-dl'
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
    @available_posts = 0
    @callback = nil
  end

  def get_media_from_subreddit_callback(message, chat)
    @callback = message
    get_media_from_subreddit(message, chat)
  end

  def get_media_from_subreddit(message, chat)
    text_array = if @callback.nil?
                   message.text.split(' ')
                 else
                   message.data.split(' ')[1..-1]
                 end
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
      chat_id: get_telegram_chat_id(message),
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
      @available_posts = hot_posts.size - (i + 1)
      sample = hot_post
      break
    end
    if sample.nil?
      logger.warn('There are no posts left to send. Sending "try again later" message.')
      answer = 'You have seen all hot posts in this subreddit. Try again later.'
      @bilu.reply_with_text(answer, message)
    else
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

  def get_media_from_url(message, _chat)
    words = message.text.split('/')
    comments_index = words.find_index('comments')
    return if comments_index.nil? || words[comments_index + 1].nil?
    post_id = 't3_' + words[comments_index + 1]
    post = reddit_post_from_id(post_id)
    send_media(message, post)
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

  def reddit_post_from_id(post_id)
    @reddit_session.from_ids(post_id).first
  end

  def send_media(message, post)
    logger.debug("Post: score=[#{post.score}] title=[#{post.title}] url=[#{post.url}]")
    return if post.is_self
    url_extension = post.url.split('.').last
    if url_extension == 'gif' || url_extension == 'gifv'
      send_gifv(message, post)
    elsif url_extension == 'mp4'
      send_mp4(message, post)
    elsif post.url.include? 'gfycat.com'
      gif_name = post.url.split('/').last.split('-').first
      new_url = JSON.parse(open("https://api.gfycat.com/v1/gfycats/#{gif_name}").string)['gfyItem']['mp4Url']
      send_mp4(message, post, new_url)
    elsif post.is_reddit_media_domain && post.is_video

      options = {
        'write-annotations': true,
        'add-metadata': true,
        'write-thumbnail': true,
        'merge-output-format': 'mp4',
        'all-subs': true,
        'embed-subs': true,
        'ignore-errors': true,
        'embed-thumbnail': true,
        'restrict-filenames': true,
        'geo-bypass': true,
        continue: true,
        'external-downloader': 'aria2c',
        'external-downloader-args': '-c -j 3 -x 3 -s 3 -k 1M',
        output: "#{post.id}.mp4"
      }

      YoutubeDL.download post.url, options
      send_local_mp4(message, post, mp4_url)
      FileUtils.rm("#{post.id}.mp4")
    else
      send_photo(message, post)
    end
  end

  def send_local_mp4(message, post, file_path)
    logger.debug("START - Sending #{file_path} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
        chat_id: get_telegram_chat_id(message),
        action: 'upload_video'
    )
    file_ext = File.extname(file_path)
    if file_ext == '.mp4'
      upload = Faraday::UploadIO.new(file_path, 'video/mp4')
      @bilu.bot.api.send_video(
          chat_id: get_telegram_chat_id(message),
          video: upload,
          caption: reddit_post_caption(post),
          reply_to_message_id: get_telegram_message_id(message),
          reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
              inline_keyboard: reddit_post_buttons(post)
          )
      )
    else
      log.error "file extension #{file_ext} is not valid"
      return
    end
    upload.close
    logger.debug("END - Sending #{file_path} as video through telegram API.")
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
    "https://www.reddit.com#{post.permalink}"
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
      chat_id: get_telegram_chat_id(message),
      action: 'upload_photo'
    )
    @bilu.bot.api.send_photo(
      chat_id: get_telegram_chat_id(message),
      photo: post.url.to_s,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id(message),
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as photo through telegram API.")
  end

  def reddit_post_buttons(post)
    button_array = [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "#{post.num_comments} Comments",
        url: reddit_post_full_permalink(post)
      )
    ]
    if @available_posts.positive?
      button_array << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "Next post? (#{@available_posts} post#{'s' if @available_posts > 1} left)",
        callback_data: "callback /r #{post.subreddit.display_name}"
      )
    end
    button_array
  end

  def send_mp4(message, post, new_url = nil)
    mp4url = new_url.nil? ? post.url.to_s : new_url
    logger.debug("START - Sending #{mp4url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id(message),
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: get_telegram_chat_id(message),
      video: mp4url,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id(message),
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{mp4url} as video through telegram API.")
  end

  def send_gif(message, post)
    logger.debug("START - Sending #{post.url} as document through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id(message),
      action: 'upload_video'
    )
    @bilu.bot.api.send_document(
      chat_id: get_telegram_chat_id(message),
      document: post.url,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id(message),
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as document through telegram API.")
  end


  def get_telegram_chat_id(message)
    if @callback.nil?
      message.chat.id
    else
      message.message.chat.id
    end
  end

  def get_telegram_message_id(message)
    if @callback.nil?
      message.message_id
    else
      message.message.message_id
    end
  end

  def reddit_post_caption(post)
    caption = "#{post.over_18 ? "\u{1F51E} NSFW " : ''}#{post.spoiler ? "\u{26A0} SPOILER" : ''}\n#{post.title}"
    unless @callback.nil?
      caption += "\n\n[post request by #{@callback.from.username.nil? ? @callback.from.first_name : '@' + @callback.from.username}]"
    end
    caption
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
      chat_id: get_telegram_chat_id(message),
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: get_telegram_chat_id(message),
      video: new_url,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id(message),
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{new_url} as video through telegram API.")
  end

  def get_subreddit_hot_media_posts(subreddit)
    logger.debug('START - Fetching and filtering posts.')
    selection = get_subreddit_hot_posts(subreddit).find_all do |p|
      !p.url.nil? &&
        ((p.url.end_with? '.jpg') ||
          (p.url.end_with? '.png') ||
          (p.url.end_with? '.gif') ||
          (p.url.end_with? '.gifv') ||
          (p.url.end_with? '.mp4') ||
          (p.url.include? 'gfycat.com') ||
          (p.is_reddit_media_domain && p.is_video)
        )
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
