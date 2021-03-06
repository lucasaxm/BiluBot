require_relative 'logger/logging'
require_relative 'routes'
require_relative 'models/chat'
Dir['controllers/*.rb'].each { |file| require_relative file }

module Router
  include Logging

  @botname = ENV['BILU_BOTNAME']

  def self.route_message(bot, message)
    routes = Routes.message_map.select { |a| a.call message }
    return nil if routes.nil?

    chat = save_chat(message)

    routes.each do |map|
      route = map.last
      logger.info("Message '#{message.to_s}' routed to #{route[:controller]}##{route[:action]}") unless message.nil?
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
