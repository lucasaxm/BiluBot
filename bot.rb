require 'telegram/bot'
require 'dotenv'
require "redd"
require 'forecast_io'
require "geocoder"

Dotenv.load('tokens.env')

from=""
chat_type=""
pidfile = "bot.rb.pid"
owfilesuffix = "owplayers.txt"

logger = Logger.new('log.txt', 'daily')
# e.g. "2004-01-03 00:54:26"
logger.datetime_format = '%Y-%m-%d %H:%M:%S'

logger.level = Logger::DEBUG

logger.formatter = proc { |severity, datetime, progname, msg|
    "#{severity}\t| #{datetime} | #{from}\t| #{chat_type}\t| #{msg}\n"
}

begin
    retries_redd ||= 0
    reddit_session = Redd.it(
        client_id:  ENV['REDDIT_CLIENT_ID'],
        secret:     ENV['REDDIT_SECRET'],
        username:   ENV['REDDIT_USERNAME'],
        password:   ENV['REDDIT_PASSWORD'],
        )
rescue => e
    logger.error("Exception Class: [#{ e.class.name }]")
    logger.error("Exception Message: [#{ e.message }']")
    retry if (retries_redd += 1) < 3
ensure
    retries_redd=0
end

token = ENV['BILUTOKEN']

ForecastIO.configure do |configuration|
    configuration.api_key = ENV['FORECAST_IO_TOKEN']
    configuration.default_params = {units: 'si'}
end

class RequestWeather
    attr_reader :user_id, :group_id, :message_id

    def initialize(user_id, group_id, message_id)
        @user_id = user_id
        @group_id = group_id
        @message_id = message_id
    end

    def ==(another_request)
        (self.user_id == another_request.user_id) && (self.group_id == another_request.group_id)
    end
end


request_weather_list = []

forbidden_subs_file="forbidden_list.txt"
forbidden_subs=[]
begin
    File.open(forbidden_subs_file, "r"){ |f|
        forbidden_subs = f.read.split("\n")
    }
rescue Errno::ENOENT
    logger.warn("forbidden_list.txt doesn't exist")
end


File.open(pidfile, "a+") { |file|
    begin
        oldpid = file.read.chomp
        if !oldpid.empty?
            logger.debug("killing (#{oldpid}).")
            Process.kill("KILL", oldpid.to_i)
        end
    rescue Errno::ESRCH
        logger.warn("old process (#{oldpid}) already killed")
    rescue Errno::EPERM
        logger.error("You don't have permissions to kill the process #{oldpid}")
    ensure
        logger.debug("saving PID (#{Process.pid}) into file #{pidfile}")
        file.truncate(0)
        file.write(Process.pid)
        logger.info("PID (#{Process.pid}) saved in file #{pidfile}")
    end
}
loop {
    begin
        retries_tel ||= 0
        Telegram::Bot::Client.run(token) do |bot|
            bot.listen do |message|
                from = message.to_h[:from][:username].nil? ? message.to_h[:from][:id] : message.to_h[:from][:username]
                chat_type = message.to_h[:chat][:type] == 'private' ? 'private' : message.to_h[:chat][:title]
                chat_type << " (#{message.chat.id})"
                if !message.text.nil?
                    if (message.text.start_with? "/reddit")
                        message_array = message.text.split(" ")
                        if message_array.first != "/reddit"
                            next
                        end
                        if message_array.size > 1
                            subreddit=message_array[1]
                            logger.info("searching for /r/#{subreddit}.")
                            begin
                                retries ||= 0
                                if forbidden_subs.include? subreddit
                                    logger.info("subreddit is forbidden.")
                                    bot.api.send_message(
                                        chat_id: message.chat.id,
                                        text: "pls stop",
                                        reply_to_message_id: message.to_h[:message_id]
                                    )
                                    next
                                end
                                logger.debug("START - Fetching and filtering posts.")
                                bot.api.send_chat_action(
                                    chat_id: message.chat.id,
                                    action: "typing"
                                )
                                #selection = reddit_session.subreddit(subreddit).top(limit: 10, time: :day).entries.select{ |p|
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
                                if (e.instance_of? Redd::NotFound) || (e.instance_of? JSON::ParserError)
                                    bot.api.send_message(
                                        chat_id: message.chat.id,
                                        text: "subreddit #{subreddit} not found.",
                                        reply_to_message_id: message.to_h[:message_id]
                                    )
                                elsif e.instance_of? Redd::InvalidAccess
                                    reddit_session.client.refresh
                                    logger.info("Reddit session refreshed. Retrying.")
                                    retry if (retries += 1) < 3
                                else
                                    bot.api.send_message(
                                        chat_id: message.chat.id,
                                        text: "Error=[#{ e.message }].",
                                        reply_to_message_id: message.to_h[:message_id]
                                    )
                                end
                            ensure
                                retries=0
                            end
                        end
                    end # reddit
                    if (message.text.start_with? "/ow")
                        message_array = message.text.split(" ")
                        if message_array.first != "/ow"
                            next
                        end
                        if message_array.size > 1
                            user_id = message.to_h[:from][:id].to_s
                            user_first_name = message.to_h[:from][:first_name]
                            user_first_name ||= user_id

                            case message_array[1]
                            when "subscribe", "s"
                                logger.info("/ow subscribe received")
                                File.open(message.chat.id.to_s+"_"+owfilesuffix,"a+") { |f|
                                    subscribers = f.read.chomp.split("\n")
                                    logger.debug("START subscribers=[#{subscribers}]")
                                    logger.debug("looking for #{user_id}")
                                    if (subscribers.any? { |s|
                                        s.split(";").first == user_id
                                    })
                                        logger.info("#{user_id} already subscribed.")
                                        bot.api.send_message(
                                            chat_id: message.chat.id,
                                            text: "You are already subscribed.",
                                            reply_to_message_id: message.to_h[:message_id]
                                        )
                                    else
                                        subscribers << "#{user_id};#{user_first_name}"
                                        f.truncate(0)
                                        f.write(subscribers.join("\n"))
                                        logger.info("#{user_id};#{user_first_name} subscribed.")
                                        bot.api.send_message(
                                            chat_id: message.chat.id,
                                            text: "#{user_first_name} subscribed.",
                                            reply_to_message_id: message.to_h[:message_id]
                                        )
                                    end
                                    f.close
                                    logger.debug("END subscribers=#{subscribers}")
                                }
                            when "unsubscribe", "u"
                                logger.info("/ow unsubscribe received")
                                File.open(message.chat.id.to_s+"_"+owfilesuffix,"a+") { |f|
                                    subscribers = f.read.chomp.split("\n")
                                    logger.debug("START subscribers=[#{subscribers}]")
                                    logger.debug("looking for #{user_id}")
                                    oldsize = subscribers.size
                                    subscribers.delete_if { |s|
                                        s.split(";").first == user_id
                                    }
                                    newsize = subscribers.size
                                    if (newsize != oldsize-1)
                                        logger.info("#{user_id} not subscribed.")
                                        bot.api.send_message(
                                            chat_id: message.chat.id,
                                            text: "You aren't subscribed.",
                                            reply_to_message_id: message.to_h[:message_id]
                                        )
                                    else
                                        f.truncate(0)
                                        f.write(subscribers.join("\n"))
                                        logger.info("#{user_id};#{user_first_name} deleted.")
                                        bot.api.send_message(
                                            chat_id: message.chat.id,
                                            text: "#{user_first_name} unsubscribed.",
                                            reply_to_message_id: message.to_h[:message_id]
                                        )
                                    end
                                    f.close
                                    logger.debug("END subscribers=#{subscribers}")
                                }
                            when "play", "p"
                                logger.info("/ow play received")
                                begin
                                    File.open(message.chat.id.to_s+"_"+owfilesuffix,"r") { |f|
                                        subscribers = f.read.chomp.split("\n")
                                        logger.debug("START subscribers=[#{subscribers}]")
                                        if subscribers.empty?
                                            logger.info("No users subscribed.")
                                            bot.api.send_message(
                                                chat_id: message.chat.id,
                                                text: "There are no users subscribed.",
                                                reply_to_message_id: message.to_h[:message_id]
                                            )
                                        else
                                            text_play = "overwatch?"
                                            subscribers.each{ |user|
                                                usersplit = user.split(";")
                                                text_play+="\n[#{usersplit[1]}](tg://user?id=#{usersplit.first})"
                                            }
                                            bot.api.send_message(
                                                chat_id: message.chat.id,
                                                text: text_play,
                                                parse_mode: "markdown",
                                                reply_to_message_id: message.to_h[:message_id]
                                            )
                                            logger.debug("sent message=[#{text_play}]")
                                        end
                                        logger.debug("END subscribers=#{subscribers}")
                                    }
                                rescue Errno::ENOENT
                                    logger.warn("#{message.chat.id.to_s+"_"+owfilesuffix} file doesn't exists.")
                                    bot.api.send_message(
                                        chat_id: message.chat.id,
                                        text: "No users subscribed.",
                                        reply_to_message_id: message.to_h[:message_id]
                                    )
                                end
                            when "list", "l"
                                logger.info("/ow list received")
                                begin
                                    File.open(message.chat.id.to_s+"_"+owfilesuffix,"r") { |f|
                                        subscribers = f.read.chomp.split("\n")
                                        logger.debug("START subscribers=[#{subscribers}]")
                                        if subscribers.empty?
                                            logger.info("No users subscribed.")
                                            bot.api.send_message(
                                                chat_id: message.chat.id,
                                                text: "There are no users subscribed.",
                                                reply_to_message_id: message.to_h[:message_id]
                                            )
                                        else
                                            text_list = "*Players subscribed*:"
                                            subscribers.each{ |user|
                                                usersplit = user.split(";")
                                                text_list+="\n• #{usersplit[1]}"
                                            }
                                            bot.api.send_message(
                                                chat_id: message.chat.id,
                                                text: text_list,
                                                parse_mode: "markdown",
                                                reply_to_message_id: message.to_h[:message_id]
                                            )
                                            logger.debug("sent message=[#{text_list}]")
                                        end
                                        logger.debug("END subscribers=#{subscribers}")
                                    }
                                rescue Errno::ENOENT
                                    logger.warn("#{message.chat.id.to_s+"_"+owfilesuffix} file doesn't exists.")
                                    bot.api.send_message(
                                        chat_id: message.chat.id,
                                        text: "No users subscribed.",
                                        reply_to_message_id: message.to_h[:message_id]
                                    )
                                end
                            end
                        else
                            help =
                                "`/ow option`\n"+
                                    "*Options*:\n"+
                                    "• *subscribe*: put you in the players list.\n"+
                                    "• *unsubscribe*: get out of players list.\n"+
                                    "• *list*: receive players list.\n"+
                                    "• *play*: send a message mentioning all players."
                            bot.api.send_message(
                                chat_id: message.chat.id,
                                text: help,
                                parse_mode: "markdown",
                                reply_to_message_id: message.to_h[:message_id]
                            )
                            logger.info("/ow help messaged sent")
                        end
                    end # ow
                    if (message.text.start_with? "/weather")
                        message_array = message.text.split(" ")
                        if message_array.first != "/weather"
                            next
                        end
                        logger.info("#{message.text} command received")
                        if message_array.size == 1
                            req = RequestWeather.new(message.from.id, message.chat.id, message.message_id)
                            begin
                                bot.api.send_message(
                                    chat_id: message.from.id,
                                    text: "Please send me your location",
                                    reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                                        keyboard: [[
                                                       Telegram::Bot::Types::KeyboardButton.new(
                                                           text: 'Send location',
                                                           request_location: true,
                                                           remove_keyboard: true
                                                       )
                                                   ]]
                                    )
                                )
                                request_weather_list << req unless request_weather_list.include? req
                                logger.info("request saved and location request sent.")
                            rescue Telegram::Bot::Exceptions::ResponseError
                                logger.error("User didn't start the bot")
                                bot.api.send_message(
                                    chat_id: message.chat.id,
                                    parse_mode: "markdown",
                                    text: "You need to start me first. Please do it clicking here: @bilubot.",
                                    reply_to_message_id: message.message_id
                                )
                            end
                        else
                            cityname = message_array[1..-1].join " "
                            logger.info("cityname=[#{cityname}]")
                            search_results = Geocoder.search(cityname).select{ |c|
                                ((c.data["address"]["city"].instance_of? String) &&
                                    (c.data["address"]["city"].downcase == cityname.downcase)) ||
                                    ((c.data["address"]["town"].instance_of? String) &&
                                        (c.data["address"]["town"].downcase == cityname.downcase))
                            }
                            if search_results.nil? || search_results.empty?
                                logger.error("no results for [#{cityname}]")
                                bot.api.send_message(
                                    chat_id: message.chat.id,
                                    text: "#{cityname} not found.",
                                    reply_to_message_id: message.message_id
                                )
                            else
                                logger.info("#{search_results.size} results found for [#{cityname}]")
                                citygeo = search_results.first
                                forecast = ForecastIO.forecast(citygeo.latitude,citygeo.longitude)
                                city = citygeo.data["address"]["city"].nil? ? citygeo.data["address"]["town"] : citygeo.data["address"]["city"]
                                address = "#{city}, #{citygeo.data["address"]["state"]}, #{citygeo.data["address"]["country"]}"
                                bot.api.send_message(
                                    chat_id: message.chat.id,
                                    text: "#{address}\n#{forecast.currently.temperature} °C",
                                    reply_to_message_id: message.message_id,
                                    )
                            end
                        end
                    end
                elsif (!message.location.nil?) && (message.chat.type == "private")
                    user_requests = request_weather_list.select{ |req| req.user_id == message.from.id }
                    if !user_requests.nil? && !user_requests.empty?
                        logger.info("sending forecast for [#{message.location.latitude}, #{message.location.longitude}].")
                        forecast = ForecastIO.forecast(message.location.latitude,message.location.longitude)
                        user_requests.each do |req|
                            bot.api.send_message(
                                chat_id: req.group_id,
                                text: "#{forecast.currently.temperature}",
                                reply_to_message_id: req.message_id,
                                )
                            request_weather_list.delete req
                        end
                    end
                end
            end
        end
    rescue => e
        logger.error("Exception Class: [#{ e.class.name }]")
        logger.error("Exception Message: [#{ e.message }']")
        sleep 1
        retry if (retries_tel += 1) < 3
    ensure
        retries_tel=0
    end
}
