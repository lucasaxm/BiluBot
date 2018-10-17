require 'open-uri'
require_relative '../logger/logging'
require_relative '../config/reddit_config'

##
# Class that holds all logic related to Reddit
class RedditService
  include Logging

  def initialize(bilu)
    @reddit_session = RedditConfig.new_reddit_session
    @bilu = bilu
  end

  def get_media_from_subreddit(message)
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
    hot_posts = get_subreddit_hot_posts(subreddit)
    if hot_posts.empty?
      answer = "subreddit #{subreddit} has no media to send."
      logger.warn(answer)
      @bilu.reply_with_text(answer, message)
      return
    end
    sample = hot_posts.sample.to_h
    logger.debug("Sample: score=[#{sample[:score]}] title=[#{sample[:title]}] url=[#{sample[:url]}]")
    send_media(message, sample)
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

  private

  def send_media(message, post)
    url_extension = post[:url].split('.').last
    if url_extension == 'gif'
      send_gif(message, post)
    elsif url_extension == 'gifv'
      send_gifv(message, post)
    elsif url_extension == 'mp4'
      send_mp4(message, post)
    elsif post[:url].include? 'gfycat.com'
      gif_name = post[:url].split('/').last
      post[:url] = JSON.parse(open("https://api.gfycat.com/v1/gfycats/#{gif_name}").string)["gfyItem"]["mp4Url"]
      send_mp4(message, post)
    else
      send_photo(message, post)
    end
  end

  def send_photo(message, post)
    logger.debug("START - Sending #{post[:url]} as photo through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_photo'
    )
    @bilu.bot.api.send_photo(
      chat_id: message.chat.id,
      photo: "#{post[:url]}",
      caption: "(#{post[:score]}) - #{post[:title]}",
      reply_to_message_id: message.to_h[:message_id]
    )
    logger.debug("END - Sending #{post[:url]} as photo through telegram API.")
  end

  def send_mp4(message, post)
    logger.debug("START - Sending #{post[:url]} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: message.chat.id,
      video: "#{post[:url]}",
      caption: "(#{post[:score]}) - #{post[:title]}",
      reply_to_message_id: message.to_h[:message_id]
    )
    logger.debug("END - Sending #{post[:url]} as video through telegram API.")
  end

  def send_gif(message, post)
    logger.debug("START - Sending #{post[:url]} as document through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_document(
      chat_id: message.chat.id,
      document: post[:url],
      caption: "(#{post[:score]}) - #{post[:title]}",
      reply_to_message_id: message.to_h[:message_id]
    )
    logger.debug("END - Sending #{post[:url]} as document through telegram API.")
  end

  def prepare_gifv_url(url)
    url_array = url.split('.')
    url_array.pop
    url_array.push 'mp4'
    new_url = url_array.join '.'
  end

  def send_gifv(message, post)
    new_url = prepare_gifv_url(post[:url])
    logger.debug("START - Sending #{new_url} as video through telegram API.")
    @bilu.bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'upload_video'
    )
    @bilu.bot.api.send_video(
      chat_id: message.chat.id,
      video: new_url,
      caption: "(#{post[:score]}) - #{post[:title]}",
      reply_to_message_id: message.to_h[:message_id]
    )
    logger.debug("END - Sending #{new_url} as video through telegram API.")
  end

  def get_subreddit_hot_posts(subreddit)
    logger.debug('START - Fetching and filtering posts.')
    selection = @reddit_session.subreddit(subreddit).hot.find_all do |p|
      !p.url.nil? && ((p.url.end_with? '.jpg') || (p.url.end_with? '.png') || (p.url.end_with? '.gif') ||
        (p.url.end_with? '.gifv') || (p.url.end_with? '.mp4') || (p.url.include? 'gfycat.com'))
    end
    logger.debug('END - Fetching and filtering posts.')
    selection
  end

  def send_help_message(message)
    help =
      "`/reddit subreddit`\n• Get a random media post from subreddit."
    @bilu.reply_with_markdown_text(help, message)
  end
end