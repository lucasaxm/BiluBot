require_relative '../logger/logging'

class RedditController
  include Logging

  def initialize
    @reddit_session = RedditConfig.new_reddit_session
  end

  def get_media_from_subreddit(bot, message)
    text_array = message.text.split(' ')
    send_help_message(bot, message) if text_array.size <= 1
    subreddit = text_array[1]
    logger.info("searching for /r/#{subreddit}.")
    retries ||= 0
    unless RedditConfig.valid_subreddit? subreddit
      answer = 'This subreddit is banned'
      bot.send_text_message(answer, message)
      return
    end
    bot.api.send_chat_action(
      chat_id: message.chat.id,
      action: 'typing'
    )
    hot_posts = get_subreddit_hot_posts(subreddit)
    if hot_posts.empty?
      answer = "subreddit #{subreddit} has no sendable media."
      logger.warn(answer)
      bot.send_text_message(answer, message)
      return
    end
    sample = hot_posts.sample.to_h
    logger.debug("Sample: score=[#{sample[:score]}] title=[#{sample[:title]}] url=[#{sample[:url]}]")
    send_media(bot, message, sample)
  rescue Redd::NotFound, JSON::ParserError => e
    answer = "subreddit #{subreddit} not found."
    logger.error(answer)
    logger.error("Exception Class: [#{ e.class.name }]")
    logger.error("Exception Message: [#{ e.message }']")
    bot.send_text_message(answer, message)
  rescue Redd::InvalidAccess => e
    error_count += 1
    @reddit_session.client.refresh
    if error_count < 5
      logger.warn('Reddit session refreshed. Retrying.')
      sleep(1)
      retry
    end
  else
    answer = "Error=[#{ e.message }]."
    bot.send_text_message(answer, message)
  end
end

private

def send_media(bot, message, post)
  url_extension = post[:url].split('.').last
  if url_extension == 'gif'
    send_gif(bot, message, post)
  elsif url_extension == 'gifv'
    send_gifv(bot, message, post)
  elsif url_extension == 'mp4'
    send_mp4(bot, message, post)
  elsif post[:url].include? 'gfycat.com'
    send_gfycat(bot, message, post)
  else
    send_photo(bot, message, post)
  end
end

def send_photo(bot, message, post)
  logger.debug("START - Sending #{post[:url]} as photo through telegram API.")
  bot.api.send_chat_action(
    chat_id: message.chat.id,
    action: 'upload_photo'
  )
  bot.api.send_photo(
    chat_id: message.chat.id,
    photo: "#{post[:url]}",
    caption: "(#{post[:score]}) - #{post[:title]}",
    reply_to_message_id: message.to_h[:message_id]
  )
  logger.debug("END - Sending #{post[:url]} as photo through telegram API.")
end

def send_gfycat(bot, message, post)
  new_url = (post[:url].sub 'gfycat.com', 'thumbs.gfycat.com') + '-max-14mb.gif'
  logger.debug("START - Sending #{new_url} as document through telegram API.")
  bot.api.send_chat_action(
    chat_id: message.chat.id,
    action: 'upload_video'
  )
  bot.api.send_document(
    chat_id: message.chat.id,
    document: "#{new_url}",
    caption: "(#{post[:score]}) - #{post[:title]}",
    reply_to_message_id: message.to_h[:message_id]
  )
  logger.debug("END - Sending #{new_url} as document through telegram API.")
end

def send_mp4(bot, message, post)
  logger.debug("START - Sending #{post[:url]} as video through telegram API.")
  bot.api.send_chat_action(
    chat_id: message.chat.id,
    action: 'upload_video'
  )
  bot.api.send_video(
    chat_id: message.chat.id,
    video: "#{post[:url]}",
    caption: "(#{post[:score]}) - #{post[:title]}",
    reply_to_message_id: message.to_h[:message_id]
  )
  logger.debug("END - Sending #{post[:url]} as video through telegram API.")
end

def send_gif(bot, message, post)
  logger.debug("START - Sending #{post[:url]} as document through telegram API.")
  bot.api.send_chat_action(
    chat_id: message.chat.id,
    action: 'upload_video'
  )
  bot.api.send_document(
    chat_id: message.chat.id,
    document: "#{post[:url]}",
    caption: "(#{post[:score]}) - #{post[:title]}",
    reply_to_message_id: message.to_h[:message_id]
  )
  logger.debug("END - Sending #{post[:url]} as document through telegram API.")
end

def send_gifv(bot, message, post)
  url_array = post[:url].split('.')
  url_array.pop
  url_array.push 'mp4'
  new_url = url_array.join '.'
  logger.debug("START - Sending #{new_url} as video through telegram API.")
  bot.api.send_chat_action(
    chat_id: message.chat.id,
    action: 'upload_video'
  )
  bot.api.send_video(
    chat_id: message.chat.id,
    video: "#{new_url}",
    caption: "(#{post[:score]}) - #{post[:title]}",
    reply_to_message_id: message.to_h[:message_id]
  )
  logger.debug("END - Sending #{new_url} as video through telegram API.")
end

def get_subreddit_hot_posts(subreddit)
  logger.debug('START - Fetching and filtering posts.')
  selection = reddit_session.subreddit(subreddit).hot.entries.select do |p|
    (p.to_h[:post_hint] == 'image') ||
      (!p.to_h[:url].nil? && (
      (p.to_h[:url].split('.').last == 'gif') ||
        (p.to_h[:url].split('.').last == 'gifv') ||
        (p.to_h[:url].split('.').last == 'mp4') ||
        (p.to_h[:url].include? 'gfycat.com')
      ))
  end
  logger.debug('END - Fetching and filtering posts.')
  selection
end

def send_help_message(bot, message)
  help =
    "`/reddit subreddit`\n" \
    '• Post here a random media post from subreddit.'
  bot.api.send_message(
    chat_id: message.chat.id,
    text: help,
    parse_mode: 'markdown',
    reply_to_message_id: message.to_h[:message_id]
  )
end