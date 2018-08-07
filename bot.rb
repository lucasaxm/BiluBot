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
                logger.info("Subreddit set is #{subreddit}.")
                begin
                    logger.debug("START - Fetching and filtering posts.")
                    selection = reddit_session.subreddit(subreddit).hot.entries.select{ |p|
                        p.to_h[:post_hint] == "image"
                    }
                    logger.debug("END - Fetching and filtering posts.")
                    if selection.empty?
                        logger.warn("subreddit #{subreddit} has no pictures.")
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "subreddit #{subreddit} has no pictures."
                        )
                    else
                        postobj = selection.sample.to_h
                        logger.debug("START - Sending #{postobj[:url]} through telegram API.")
                        bot.api.send_photo(
                            chat_id: message.chat.id,
                            photo: "#{postobj[:url]}",
                            caption: "(#{postobj[:score]}) - #{postobj[:title]}"
                        )
                        logger.debug("END - Sending #{postobj[:url]} through telegram API.")
                    end
                rescue => e
                    logger.error("Exception Class: [#{ e.class.name }]")
                    logger.error("Exception Message: [#{ e.message }']")
                    if e.instance_of? Redd::NotFound
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "subreddit #{subreddit} not found."
                        )
                    else
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "Error=[#{ e.message }]."
                        )
                    end
                end
            end
        end
    end
end
