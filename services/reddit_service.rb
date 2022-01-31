require 'open-uri'
require 'telegram/bot'
require 'nokogiri'
require_relative '../lib/gallery_dl'
require_relative '../logger/logging'
require_relative '../config/reddit_config'
require_relative '../models/reddit_post'
require_relative '../models/subreddit'
require_relative '../models/banned_subreddit'
require_relative '../models/chat'

##
# Class that holds all logic related to Reddit
# noinspection RubyArgCount
class RedditService
  include Logging

  def initialize(bilu, message)
    @reddit_session = RedditConfig.new_reddit_session
    @bilu = bilu
    @message = message
    @available_posts = 0
    @callback = nil
  end

  def get_media_from_subreddit_callback(chat)
    @callback = @message
    get_media_from_subreddit(chat)
  end

  def is_banned?(subreddit, chat)
    !(BannedSubreddit.find_by(chat_id: chat.id, subreddit_id: subreddit.id).nil?)
  end

  def ban_subreddit(chat)
    text_array = @message.text.split(' ')
    if chat.telegram_type != 'private'
      chat_member = @bilu.bot.api.get_chat_member(chat_id: chat.telegram_id, user_id: @message.from.id)
      status = chat_member['result']['status']
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
      status = chat_member['result']['status']
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
    hot_posts = get_subreddit_hot_media_posts(subreddit_name)
    if hot_posts.empty?
      answer = "subreddit #{subreddit_name} has no media to send."
      logger.warn(answer)
      @bilu.reply_with_text(answer, @message)
      return
    end
    post_to_send = nil
    hot_posts.each_with_index do |hot_post, i|
      reddit_post = RedditPost.find_or_initialize_by(reddit_id: hot_post.id)
      if reddit_post.new_record?
        reddit_post.assign_attributes(title: hot_post.title,
                                      score: hot_post.score,
                                      nsfw: hot_post.over_18,
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
      reddit_post.save
      logger.info("Sending ##{i + 1} of #{hot_posts.size} posts.")
      @available_posts = hot_posts.size - (i + 1)
      post_to_send = hot_post
      break
    end
    if post_to_send.nil?
      logger.warn('There are no posts left to send. Sending "no available" message.')
      answer = 'No available posts in this subreddit right now.'
      @bilu.reply_with_text(answer, @message)
    else
      send_media(post_to_send)
    end
  rescue Redd::NotFound, JSON::ParserError => e
    answer = "subreddit #{subreddit_name} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    @bilu.reply_with_text(answer, @message)
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
    @bilu.reply_with_text(answer, @message)
  end

  def get_media_from_url(chat)
    words = @message.text.split('/')
    comments_index = words.find_index('comments')
    return if comments_index.nil? || words[comments_index + 1].nil?

    post_id = "t3_#{words[comments_index + 1]}"
    post = reddit_post_from_id(post_id)
    if !chat.nsfw? && post.over_18
      answer = 'NSFW posts are banned.'
      @bilu.reply_with_text(answer, @message)
      return
    end
    send_media(post)
  end

  private

  def get_subreddit_from_db(subreddit_name)
    subreddit = @reddit_session.subreddit(subreddit_name)
    subreddit_db = Subreddit.find_or_initialize_by(reddit_id: subreddit.id)
    if subreddit_db.new_record?
      subreddit_db.name = subreddit_name
      subreddit_db.nsfw = subreddit.over18
      subreddit_db.save
      logger.info("subreddit #{subreddit_db.name} saved to database")
    end
    subreddit_db
  rescue Redd::NotFound, JSON::ParserError => e
    answer = "subreddit #{subreddit_name} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{e.class.name}]")
    logger.error("Exception Message: [#{e.message}']")
    @bilu.reply_with_text(answer, @message)
    return nil
  end

  def reddit_post_from_id(post_id)
    @reddit_session.from_ids(post_id).first
  end

  def send_media(post)
    logger.debug("Post: score=[#{post.score}] title=[#{post.title}] url=[#{post.url}]")
    return if post.is_self
    url_extension = post.url.split('.').last
    if ['gif', 'gifv'].include?(url_extension)
      send_gifv(post)
    elsif url_extension == 'mp4'
      send_mp4(post)
    elsif post.url.include? 'gfycat.com'
      gif_name = post.url.split('/').last.split('-').first
      new_url = JSON.parse(open("https://api.gfycat.com/v1/gfycats/#{gif_name}").string)['gfyItem']['mp4Url']
      send_mp4(post, new_url)
    elsif post.is_reddit_media_domain && post.is_video
      result = GalleryDL.download "reddit.com#{post.permalink}"
      filepath = result.information.first[:local_path]
      send_local_mp4(post, filepath)
    elsif (post.instance_variable_get :@attributes)[:is_gallery]
      send_gallery(post)
    else
      send_photo(post)
    end
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
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    upload.close
    FileUtils.rm(filepath) if File.exist?(filepath)
    FileUtils.rm("#{filepath}.json") if File.exist?("#{filepath}.json")
    FileUtils.rm(new_filepath) if File.exist?(new_filepath)
    logger.debug("END - Sending #{filepath} as video through telegram API.")
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

  def send_photo(post)
    logger.debug("START - Sending #{post.url} as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_photo'
    )
    @bilu.bot.api.send_photo(
      chat_id: get_telegram_chat_id,
      photo: post.url.to_s,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id,
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
        text: "Next post from r/#{post.subreddit.display_name}",
        callback_data: "callback /r #{post.subreddit.display_name}"
      )
    end
    button_array
  end

  def send_mp4(post, new_url = nil)
    mp4url = new_url.nil? ? post.url.to_s : new_url
    logger.debug("START - Sending #{mp4url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: get_telegram_chat_id,
      video: mp4url,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{mp4url} as video through telegram API.")
  end

  def send_gallery(post)
    logger.debug('START - Sending media group through telegram API.')
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'typing'
    )
    post.media_metadata.each_slice(10) do |medias|
      @bilu.bot.api.send_media_group(
        chat_id: get_telegram_chat_id,
        reply_to_message_id: get_telegram_message_id,
        media: medias.map do |_id, metadata|
          logger.debug("Adding #{metadata[:p].last[:u]} to media group.")
          {
            type: 'photo',
            media: metadata[:p].last[:u]
          }
        end
      )
    end
    @bilu.bot.api.send_message(
      chat_id: get_telegram_chat_id,
      text: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug('END - Sending media group through telegram API.')
  end

  def send_gif(post)
    logger.debug("START - Sending #{post.url} as document through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: get_telegram_chat_id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_document(
      chat_id: get_telegram_chat_id,
      document: post.url,
      caption: reddit_post_caption(post),
      reply_to_message_id: get_telegram_message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
    )
    logger.debug("END - Sending #{post.url} as document through telegram API.")
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
    caption = "#{post.over_18 ? "\u{1F51E} NSFW " : ''}#{post.spoiler ? "\u{26A0} SPOILER" : ''}\n#{post.title}"
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
      reply_to_message_id: get_telegram_message_id,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: reddit_post_buttons(post)
      )
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
    @reddit_session.subreddit(subreddit).hot
  end

  def send_help_message
    help =
      "`/reddit subreddit`\n\u{2022} Get a random media post from subreddit."
    @bilu.reply_with_markdown_text(help, @message)
  end
end
