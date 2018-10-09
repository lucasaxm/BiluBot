require_relative 'logger/logging'
require_relative 'routes'
Dir['controllers/*.rb'].each {|file| require_relative file}

module Router
  include Logging
  def self.route_message(bot, message)
    entities = message.entities
    return nil if entities.nil? || entities.first.type != 'bot_command'
    command = message.text.split(' ').first[1..-1].to_sym
    route = Routes.message_map[command]
    return nil if route.nil?
    logger.info("Command '#{command}' received. Routed to #{route[:controller]}##{route[:action]}")
    controller = route[:controller].new bot
    controller.send route[:action], message
  end
end
