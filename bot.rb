require_relative 'domain/request_weather'
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
require 'optparse'

module Bilu
  include Logging

  class Bot
    include Logging
    attr_reader :bot

    def initialize
      BiluSchema.create_db
      @token = ENV['BILU_TELEGRAM_TOKEN']
      @log_id = ENV['BILU_TELEGRAM_LOG_ID']
      OptionParser.new do |opts|
        opts.on('-d', '--dev', 'dev mode') do
          @token = ENV['BILU_DEV_TELEGRAM_TOKEN']
          @log_id = ENV['BILU_DEV_TELEGRAM_LOG_ID']
        end
      end.parse!
      @bot = Telegram::Bot::Client.new(@token)
      ActiveRecord::Base.establish_connection ENV['DATABASE_URL']
      logger.info("server started as #{@bot.api.get_me['result']['username']}")
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
        logger.info("Logging '#{text}'.")
        error_msg = @bot.api.send_message(
            chat_id: @log_id,
            text: text
        )
        if !message.nil?
          formatted_message = <<~MESSAGE
            ```json
            #{JSON.pretty_generate(message)}
            ```
          MESSAGE
          @bot.api.send_message(
              chat_id: @log_id,
              text: formatted_message,
              parse_mode: 'MarkdownV2',
              reply_to_message_id: error_msg['result']['message_id']
          )
        end
      rescue StandardError => e
        answer = "Error logging #{e.class.name}: #{e.message}."
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
      url = "https://api.telegram.org/file/bot#{@token}/#{telegram_file_path}"
      temp_file = Down.download(url)
      path = temp_file.path
      logger.info("file downloaded '#{path}'.")
      temp_file.close

      return path if save_path.nil?
      FileUtils.mv(path, save_path)
      logger.info("file moved to '#{save_path}'.")
      save_path
    end

  end
end