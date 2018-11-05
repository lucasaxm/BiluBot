require_relative 'logger/logging'
require_relative 'routes'
Dir['controllers/*.rb'].each {|file| require_relative file}

module Router
  include Logging

  @botname = ENV['BILU_BOTNAME']

  def self.route_message(bot, message)
    case message
    when Telegram::Bot::Types::InlineQuery
      action = :inline_query
      #
      # when Telegram::Bot::Types::CallbackQuery
      #   # callback query not needed
      #
    when Telegram::Bot::Types::ChosenInlineResult
      action = :chosen_inline_result

    when Telegram::Bot::Types::Message
      entities = message.entities
      return nil if entities.nil? || entities.empty? || entities.first.type != 'bot_command'
      action = message.text.split(' ').first[1..-1].downcase
      action = action.include?('@') && action.split('@').last.casecmp(@botname).zero? ? action.split('@')[0..-2].join('@').to_sym : action.to_sym
      return nil if action == %i[inline_query chosen_inline_result]
    else
      action = nil

    end
    map = Routes.message_map.find {|a| a.first.include? action}
    return nil if map.nil?
    route = map.last
    logger.info("Action '#{action}' routed to #{route[:controller]}##{route[:action]}")
    controller = route[:controller].new bot
    controller.send route[:action], message
  end
end
