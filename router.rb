require_relative 'logger/logging'
require_relative 'routes'
Dir['controllers/*.rb'].each {|file| require_relative file}

module Router
  include Logging

  @botname = ENV['BILU_BOTNAME']

  def self.route_message(bot, message)
    entities = message.entities
    return nil if entities.nil? || entities.empty? || entities.first.type != 'bot_command'
    command = message.text.split(' ').first[1..-1].downcase
    command = command.include?('@') && command.split('@').last.casecmp(@botname).zero? ? command.split('@')[0..-2].join('@').to_sym : command.to_sym
    map = Routes.message_map.find {|a| a.first.include? command}
    return nil if map.nil?
    route = map.last
    logger.info("Command '#{command}' received. Routed to #{route[:controller]}##{route[:action]}")
    controller = route[:controller].new bot
    controller.send route[:action], message
  end
end
