require_relative 'domain/request_weather'
require_relative 'config/telegram_config.rb'
require_relative 'logger/logging'
require_relative 'router'
require_relative 'db/bilu_schema'
require 'telegram/bot'
require 'redd'
require 'forecast_io'
require 'active_record'
require 'pg'
require "down"
require "fileutils"
require 'streamio-ffmpeg'

module Bilu
  include Logging

  class Bot
    include Logging
    attr_reader :bot

    def initialize
      @pidfile = "#{__FILE__}.pid"
      save_pid
      BiluSchema.create_db
      @bot = Telegram::Bot::Client.new(TelegramConfig.telegram_token)
      ActiveRecord::Base.establish_connection ENV['DATABASE_URL']
      logger.info('server started')
    end

    def save_pid
      File.open(@pidfile, 'a+') do |file|
        begin
          oldpid = file.read.chomp
          unless oldpid.empty?
            logger.debug("killing (#{oldpid}).")
            Process.kill('KILL', oldpid.to_i)
          end
        rescue Errno::ESRCH
          logger.warn("old process (#{oldpid}) already killed")
        rescue Errno::EPERM
          logger.error("You don't have permissions to kill the process #{oldpid}")
        ensure
          logger.debug("saving PID (#{Process.pid}) into file #{@pidfile}")
          file.truncate(0)
          file.write(Process.pid)
          logger.info("PID (#{Process.pid}) saved in file #{@pidfile}")
        end
      end
    end

    def listen(&block)
      @bot.listen(&block)
    end

    def reply_with_text(text, message)
      msg = if message.class == Telegram::Bot::Types::CallbackQuery
              message.message
            else
              message
            end
      logger.info("Sending message '#{text.to_json}' to #{msg.chat.id}.")
      @bot.api.send_message(
          chat_id: msg.chat.id,
          text: text,
          reply_to_message_id: msg.message_id
      )
    end

    def send_message(text, msg, reply = false)
      logger.info("Sending message '#{text}' to #{msg.chat.id}.")
      if reply
        @bot.api.send_message(
            chat_id: msg.chat.id,
            text: text,
            reply_to_message_id: msg.message_id
        )
      else
        @bot.api.send_message(
            chat_id: msg.chat.id,
            text: text
        )
      end
    end

    def forward_message_same_chat(message)
      logger.info("Forwarding message id '#{message.message_id}' to #{message.chat.id}.")
      @bot.api.forward_message(
          chat_id: message.chat.id,
          from_chat_id: message.chat.id,
          message_id: message.message_id
      )
    end

    def log_to_channel(text, message)
      begin
        logger.info("Sending message '#{text.to_json}' to #{message.chat.id}.")
        channel_id = ENV['TELEGRAM_LOG_CHANNEL_ID']
        @bot.api.send_message(
            chat_id: channel_id,
            text: text
        )
        if !message.nil? && !message.chat.id.nil?
          @bot.api.send_message(
              chat_id: channel_id,
              text: 'message:'
          )
          @bot.api.forward_message(
              chat_id: channel_id,
              from_chat_id: message.chat.id,
              message_id: message.message_id
          )
          unless message.reply_to_message.nil?
            @bot.api.send_message(
                chat_id: channel_id,
                text: 'that was a reply to:'
            )
            @bot.api.forward_message(
                chat_id: channel_id,
                from_chat_id: message.chat.id,
                message_id: message.reply_to_message.message_id
            )
          end
        end
      rescue StandardError => e
        answer = "Error #{e.class.name}: #{e.message}."
        logger.error("Message=[#{answer}]")
      end
    end

    def delete_message(message)
      logger.info("Deleting message #{message.text.nil? ? message.message_id : '\'' + message.text + '\''} from #{message.chat.id}.")
      @bot.api.delete_message(
          chat_id: message.chat.id,
          message_id: message.message_id,
      )
    end

    def reply_with_markdown_text(text, message)
      logger.info("Sending message '#{text.to_json}' to #{message.chat.id}.")
      @bot.api.send_message(
          chat_id: message.chat.id,
          text: text,
          parse_mode: 'markdown',
          reply_to_message_id: message.message_id
      )
    end

    def process_update(message)
      logger.message = message
      Router.route_message(self, message)
    end

    # returns file path
    def get_file(file_id)
      file_hash = @bot.api.get_file(file_id: file_id)
      if file_hash.nil? || !file_hash['ok']
        log.error('Error getting file from telegram')
        return
      end
      file_hash['result']['file_path']
    end

    def download_file(telegram_file_path, save_path=nil)
      token = TelegramConfig.telegram_token
      url = "https://api.telegram.org/file/bot#{token}/#{telegram_file_path}"
      temp_file = Down.download(url)
      path = temp_file.path
      logger.info("file downloaded '#{path}'.")
      temp_file.close

      return path if save_path.nil?
      FileUtils.mv(path, save_path)
      logger.info("file moved to '#{save_path}'.")
      save_path
    end

    def transcode_video_to_mp4(orig, dest)
      movie = FFMPEG::Movie.new(orig)
      logger.info("Transcoding video to #{dest}")
      movie.transcode(dest, %w(-c:v libx264 -crf 26 -vf scale=640:-1)){ |progress| progressing = (progress * 100).round(2); puts "#{progressing}%"; }
    end

    def is_local_image?(path)
      FFMPEG::Movie.new(path).frame_rate.nil?
    end

  end
end