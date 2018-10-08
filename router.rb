require_relative 'routes'
Dir['controllers/*.rb'].each {|file| require_relative file}

module Router

  def self.route_message(bot, message)
    entities = message.entities
    return nil if entities.nil? || entities.first.type != 'bot_command'
    command = message.text.split(' ').first[1..-1].to_sym
    route = Routes.message_map[command]
    return nil if route.nil?
    controller = route[:controller].new
    controller.send route[:action], bot, message
  end

end