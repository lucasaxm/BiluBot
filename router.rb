require_relative 'logger/logging'
require_relative 'routes'
require_relative 'models/chat'
Dir['controllers/*.rb'].each {|file| require_relative file}

module Router
  include Logging

  @botname = ENV['BILU_BOTNAME']

  def self.route_message(bot, message)
    case message
    when Telegram::Bot::Types::InlineQuery
      sleep(1)
      response = bot.bot.api.getUpdates
      if response['ok'] &&
        !response['result'].nil? &&
        !response['result'].empty? &&
        !response['result'].first['inline_query'].nil? &&
        response['result'].first['inline_query']['from']['id'] == message.from.id &&
        response['result'].first['inline_query']['query'] != message.query
        logger.debug("Query '#{message.query}' being typed (found '#{response['result'].first['inline_query']['query']}')")
        return nil
      end
      text = :inline_query

    when Telegram::Bot::Types::CallbackQuery
      text = message.data

    when Telegram::Bot::Types::ChosenInlineResult
      text = :chosen_inline_result

    when Telegram::Bot::Types::Message
      text = message.text
      return nil if text == %i[inline_query chosen_inline_result]
    else
      text = nil

    end
    routes = Routes.message_map.select {|a| a.match? text.to_s}
    return nil if routes.nil?

    chat = save_chat(message)

    routes.each do |map|
      route = map.last
      logger.info("Action '#{text}' routed to #{route[:controller]}##{route[:action]}") unless text.nil?
      controller = route[:controller].new bot
      controller.send route[:action], message, chat
    end
  end

  def self.save_chat(message)
    if message.class == Telegram::Bot::Types::CallbackQuery
      chat = Chat.find_or_create_by(telegram_id: message.message.chat.id)
      chat.telegram_type = message.message.chat.type
      if chat.telegram_type == 'private'
        chat.username = message.from.username
      elsif chat.telegram_type.include? 'group'
        chat.grouptitle = message.message.chat.title
      end
    else
      chat = Chat.find_or_create_by(telegram_id: message.chat.id)
      chat.telegram_type = message.chat.type
      if chat.telegram_type == 'private'
        chat.username = message.chat.username
      elsif chat.telegram_type.include? 'group'
        chat.grouptitle = message.chat.title
      end
    end
    chat.save
    chat
  end
end
