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

Telegram::Bot::Client.run(token) do |bot|
    bot.listen do |message|
        if !message.text.nil? && (message.text.start_with? "/reddit")
            message_array = message.text.split(" ")
            if message_array.size > 1
                puts "subreddit: #{message_array[1]}"
                if reddit_session.from_url("reddit.com/r/#{message_array[1]}").nil?
                    bot.api.send_message(
                        chat_id: message.chat.id,
                        text: "subreddit #{message_array[1]} doesn't exists."
                    )
                else
                    selection = reddit_session.subreddit(message_array[1]).hot.entries.select{ |p|
                        p.to_h[:post_hint] == "image"
                    }
                    if selection.empty?
                        bot.api.send_message(
                            chat_id: message.chat.id,
                            text: "subreddit #{message_array[1]} has no pictures."
                        )
                    else
                        postobj = selection.sample.to_h
                        bot.api.send_photo(
                            chat_id: message.chat.id,
                            photo: "#{postobj[:url]}",
                            caption: "(#{postobj[:score]}) - #{postobj[:title]}"
                        )
                    end
                end
            end
        end
    end
end
