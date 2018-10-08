require_relative 'domain/request_weather'
require_relative 'config/telegram_config.rb'
require_relative 'logger/logging'
require_relative 'router'
require 'telegram/bot'
require 'redd'
require 'forecast_io'
require 'geocoder'

module Bilu
  include Logging

  @name = 'bilubot'

  class Bot
    include Logging
    attr_reader :bot

    def initialize
      @pidfile = "#{__FILE__}.pid"
      save_pid
      @bot = Telegram::Bot::Client.new(TelegramConfig.telegram_token)
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
      logger.info("Sending message '#{text}' to #{message.chat.id}.")
      @bot.api.send_message(
        chat_id: message.chat.id,
        text: text,
        reply_to_message_id: message.message_id
      )
    end

    def process_update(message)
      logger.message = message
      case message
        # when Telegram::Bot::Types::InlineQuery
        #   # no inline query implementation yet
        #
        # when Telegram::Bot::Types::CallbackQuery
        #   # callback query not needed
        #
        # when Telegram::Bot::Types::ChosenInlineResult
        #   # no inline query

      when Telegram::Bot::Types::Message
        Router.route_message(self, message)

        # elsif message.text == "/start"
        # @bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}!\nThis bot should be used inline.\nType @hideItBot to start")
        # @bot.api.send_message(chat_id: message.chat.id, text: "You can use it to send a spoiler in a group conversation.\nOr to send a message that won't be readable in notifications!\nYou can hide only *parts of the message* enclosing them in asterisks.\nExample:\n")
        # @bot.api.send_message(
        #   chat_id: message.chat.id,
        #   text: message_to_blocks(Welcome_message),
        #   reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
        #     inline_keyboard: [
        #       Telegram::Bot::Types::InlineKeyboardButton.new(
        #         text: 'Read',
        #         callback_data: @rootMessageId
        #       )
        #     ]
        #   )
        # )
        # if BotConfig.has_botan_token
        #   @bot.track('message', message.from.id, message_type: 'hello')
        # end
      end
    end
  end
end