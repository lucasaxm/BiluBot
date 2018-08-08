require 'telegram/bot'
require 'dotenv'
require 'timeout'
require "redd"
require "awesome_print"

Dotenv.load('vars.env')

reddit_session = Redd.it(
  client_id:  ENV['REDDIT_CLIENT_ID'],
  secret:     ENV['REDDIT_SECRET'],
  username:   ENV['REDDIT_USERNAME'],
  password:   ENV['REDDIT_PASSWORD'],
)

token = ENV['BILUTOKEN']

from=""
chat_type=""

logger = Logger.new(STDOUT)
# e.g. "2004-01-03 00:54:26"
logger.datetime_format = '%Y-%m-%d %H:%M:%S'

logger.level = Logger::DEBUG

logger.formatter = proc { |severity, datetime, progname, msg|
  "#{severity}\t| #{datetime} | #{from}\t| #{chat_type}\t| #{msg}\n"
}

Telegram::Bot::Client.run(token) do |bot|
    bot.listen do |message|
        from = message.to_h[:from][:username].nil? ? message.to_h[:from][:id] : message.to_h[:from][:username]
        chat_type = message.to_h[:chat][:type] == 'private' ? 'private' : message.to_h[:chat][:title]
        if !message.text.nil? && (message.text.start_with? "/reddit")
            message_array = message.text.split(" ")
            if message_array.size > 1
                subreddit=message_array[1]
                logger.info("searching for /r/#{subreddit}.")
                begin
                    logger.debug("START - Fetching and filtering posts.")
                    bot.api.send_chat_action(
                        chat_id: message.chat.id,
                        action: "typing"
                    )
                    selection = reddit_session.subreddit(subreddit).hot.entries.select{ |p|
                        (p.to_h[:post_hint] == "image") ||
                        (!p.to_h[:url].nil? && (
                            (p.to_h[:url].split(".").last == "gif") ||
                            (p.to_h[:url].split(".").last == "gifv") ||
                            (p.to_h[:url].split(".").last == "mp4") ||
                            (p.to_h[:url].include? "gfycat.com")
                        ))
                    }
                    logger.debug("END - Fetching and filtering posts.")
                    if selection.empty?
                        logger.warn("subreddit #{subreddit} has no sendable media.")
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "subreddit #{subreddit} has no sendable media.",
                            reply_to_message_id: message.to_h[:message_id]
                        )
                    else
                        sample = selection.sample.to_h
                        logger.debug("Sample: score=[#{sample[:score]}] title=[#{sample[:title]}] url=[#{sample[:url]}]")
                        if (sample[:url].split(".").last == "gif")
                            logger.debug("START - Sending #{sample[:url]} as document through telegram API.")
                            bot.api.send_chat_action(
                                chat_id: message.chat.id,
                                action: "upload_video"
                            )
                            bot.api.send_document(
                                chat_id: message.chat.id,
                                document: "#{sample[:url]}",
                                caption: "(#{sample[:score]}) - #{sample[:title]}",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.debug("END - Sending #{sample[:url]} as document through telegram API.")
                        elsif (sample[:url].split(".").last == "gifv")
                            url_array = sample[:url].split(".")
                            url_array.pop
                            url_array.push "mp4"
                            new_url = url_array.join "."
                            logger.debug("START - Sending #{new_url} as video through telegram API.")
                            bot.api.send_chat_action(
                                chat_id: message.chat.id,
                                action: "upload_video"
                            )
                            bot.api.send_video(
                                chat_id: message.chat.id,
                                video: "#{new_url}",
                                caption: "(#{sample[:score]}) - #{sample[:title]}",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.debug("END - Sending #{new_url} as video through telegram API.")
                        elsif (sample[:url].split(".").last == "mp4")
                            logger.debug("START - Sending #{sample[:url]} as video through telegram API.")
                            bot.api.send_chat_action(
                                chat_id: message.chat.id,
                                action: "upload_video"
                            )
                            bot.api.send_video(
                                chat_id: message.chat.id,
                                video: "#{sample[:url]}",
                                caption: "(#{sample[:score]}) - #{sample[:title]}",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.debug("END - Sending #{sample[:url]} as video through telegram API.")
                        elsif (sample[:url].include? "gfycat.com")
                            # new_url = sample[:preview][:images].first[:variants][:gif][:source][:url]
                            # new_url = (sample[:url].sub "gfycat.com", "giant.gfycat.com")+".mp4"
                            new_url = (sample[:url].sub "gfycat.com", "thumbs.gfycat.com")+"-max-14mb.gif"
                            logger.debug("START - Sending #{new_url} as document through telegram API.")
                            bot.api.send_chat_action(
                                chat_id: message.chat.id,
                                action: "upload_video"
                            )
                            bot.api.send_document(
                                chat_id: message.chat.id,
                                document: "#{new_url}",
                                caption: "(#{sample[:score]}) - #{sample[:title]}",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.debug("END - Sending #{new_url} as document through telegram API.")
                        else
                            logger.debug("START - Sending #{sample[:url]} as photo through telegram API.")
                            bot.api.send_chat_action(
                                chat_id: message.chat.id,
                                action: "upload_photo"
                            )
                            bot.api.send_photo(
                                chat_id: message.chat.id,
                                photo: "#{sample[:url]}",
                                caption: "(#{sample[:score]}) - #{sample[:title]}",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.debug("END - Sending #{sample[:url]} as photo through telegram API.")
                        end
                    end
                rescue => e
                    logger.error("Exception Class: [#{ e.class.name }]")
                    logger.error("Exception Message: [#{ e.message }']")
                    if e.instance_of? Redd::NotFound
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "subreddit #{subreddit} not found.",
                            reply_to_message_id: message.to_h[:message_id]
                        )
                    elsif e.instance_of? Redd::InvalidAccess
                        reddit_session.client.refresh
                        logger.info("Reddit session refreshed.")
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "Reddit session refreshed. Please try again.",
                            reply_to_message_id: message.to_h[:message_id]
                        )
                    else
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "Error=[#{ e.message }].",
                            reply_to_message_id: message.to_h[:message_id]
                        )
                    end
                end
            end
        end
    end
end
