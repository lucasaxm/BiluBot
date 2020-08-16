require_relative '../logger/logging'

class MiscService
  include Logging

  def initialize(bilu)
    @bilu = bilu
  end

  def delete_message(message)
    @bilu.delete_message(message)
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

  def spam(message)
    logger.info('spam command found')
    repetitions = 5 # default value
    text_array = message.text.split(' ')

    if text_array.size == 1 && !message.reply_to_message.nil?
      # /spam (reply)
      spam_forward(message.reply_to_message, repetitions)
    elsif text_array.size > 1
      if text_array[1] =~ /\A[0-9]+\Z/
        if text_array.size == 2
          if !message.reply_to_message.nil?
            # /spam 5 (reply)
            repetitions = text_array[1].to_i
            spam_forward(message.reply_to_message, repetitions)
          else
            # /spam 5
            text = text_array[1]
            spam_message(message, repetitions, text)
          end
        else
          # /spam 5 text to spam
          repetitions = text_array[1].to_i
          text = text_array[2..-1].join(' ')
          spam_message(message, repetitions, text)
        end
      else
        # /spam text to spam
        text = text_array[1..-1].join(' ')
        spam_message(message, repetitions, text)
      end
    end
  end

  private

  def spam_message(message, repetitions, text)
    repetitions = 10 if repetitions > 10
    repetitions.times do
      @bilu.send_message(text, message)
    end
  end

  def spam_forward(message, repetitions)
    repetitions = 10 if repetitions > 10
    repetitions.times do
      @bilu.forward_message_same_chat(message)
    end
  end
end
