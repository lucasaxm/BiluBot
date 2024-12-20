require_relative "#{__dir__}/../logger/logging"
require 'telegram/bot'

class MiscService
  include Logging

  def initialize(bilu, message)
    @bilu = bilu
    @message = message
  end

  def kill_process
    text = @message.text
    msg_words = text.split ' '
    return unless msg_words.size == 2

    bot_name = msg_words[1].downcase
    command = nil
    case bot_name
    when 'bilov'
      command = 'markov-telegram-bot-0.2.3.jar'
    when 'djbilu'
      command = 'evobot/index.js'
    when 'shellbot'
      command = 'shell-bot/server.js'
    else
      @bilu.bot.api.send_message(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        parse_mode: 'MarkdownV2',
        text: "`/acorda bilov` ou `/acorda djbilu`",
        allow_sending_without_reply: true
      )
    end

    return if command.nil?


    logger.info "restarting #{bot_name}"
    old_pid = `pgrep -fa '#{command}' | grep -v 'grep' | cut -d " " -f1`.to_i
    `pkill -f '#{command}'`
    sleep 2
    new_pid = `pgrep -fa '#{command}' | grep -v 'grep' | cut -d " " -f1`.to_i
    logger.info "old_pid=[#{old_pid}] new_pid=[#{new_pid}]"
    if new_pid == 0 || (old_pid == new_pid)
      @bilu.bot.api.send_message(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        text: "failed to start bot",
        allow_sending_without_reply: true
      )
    else old_pid == new_pid
      @bilu.bot.api.send_message(
        chat_id: @message.chat.id,
        reply_to_message_id: @message.message_id,
        text: "bot started",
        allow_sending_without_reply: true
      )
    end
  end

  def delete_reply
    @bilu.delete_message(@message.reply_to_message)
    logger.info('message deleted')
  rescue Telegram::Bot::Exceptions::ResponseError => e
    if e.message.include? 'message can\'t be deleted'
      logger.error('message can\'t be deleted')
    elsif e.message.include? 'error_code: "400"'
      logger.error('message no longer exists')
    else
      throw e
    end
  end

  def sudo_delete_reply
    if @message.from.id == 470438197
      @bilu.delete_message(@message.reply_to_message)
      logger.info('message deleted')
    end
    @bilu.delete_message(@message)
  rescue Telegram::Bot::Exceptions::ResponseError => e
    if e.message.include? 'message can\'t be deleted'
      logger.error('message can\'t be deleted')
    elsif e.message.include? 'error_code: "400"'
      logger.error('message no longer exists')
    else
      throw e
    end
  end

  def delete_message
    @bilu.delete_message(@message)
    logger.info('message deleted')
  rescue Telegram::Bot::Exceptions::ResponseError => e
    if e.message.include? 'message can\'t be deleted'
      logger.error('message can\'t be deleted')
    elsif e.message.include? 'error_code: "400"'
      logger.error('message no longer exists')
    else
      throw e
    end
  end

  def spam
    logger.info('spam command found')
    repetitions = 5 # default value
    text_array = @message.text.split(' ')

    if text_array.size == 1 && !@message.reply_to_message.nil?
      # /spam (reply)
      spam_forward(@message.reply_to_message, repetitions)
    elsif text_array.size > 1
      if text_array[1] =~ /\A[0-9]+\Z/
        if text_array.size == 2
          if !@message.reply_to_message.nil?
            # /spam 5 (reply)
            repetitions = text_array[1].to_i
            spam_forward(@message.reply_to_message, repetitions)
          else
            # /spam 5
            text = text_array[1]
            spam_message(repetitions, text)
          end
        else
          # /spam 5 text to spam
          repetitions = text_array[1].to_i
          text = text_array[2..-1].join(' ')
          spam_message(repetitions, text)
        end
      else
        # /spam text to spam
        text = text_array[1..-1].join(' ')
        spam_message(repetitions, text)
      end
    end
  end

  def keyboard
    text = @message.text.split(' ')[1..-1].join(' ').strip

    if (text[0] == '(') && (text[-1] == ')')
      keys = text[1..-2].split(')(').map(&:strip).map { |r| r.split(',').map(&:strip) }
    else
      keys = [[text]]
    end

    text_markdown = "Keyboard created\n```\n#{keys.map do |k|
      "#{k.map{ |kk| "[#{kk}]"}.join}"
    end.join("\n")}\n```"

    logger.info "showing keyboard #{keys.to_s}."
    @bilu.bot.api.send_message(
      chat_id: @message.chat.id,
      reply_to_message_id: @message.message_id,
      parse_mode: 'MarkdownV2',
      text: text_markdown,
      reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
        keyboard: keys,
        resize_keyboard: true,
        selective: true
      ))
  end

  def close_keyboard
    logger.info "Closing keyboard"
    @bilu.bot.api.send_message(
      chat_id: @message.chat.id,
      reply_to_message_id: @message.message_id,
      text: 'Keyboard closed',
      reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(
        remove_keyboard: true,
        selective: true
    ))

  end

  private

  def spam_message(repetitions, text)
    repetitions = 10 if repetitions > 10
    repetitions.times do
      @bilu.send_message(text, @message)
    end
  end

  def spam_forward(message, repetitions)
    repetitions = 10 if repetitions > 10
    repetitions.times do
      @bilu.forward_message_same_chat(message)
    end
  end
end
