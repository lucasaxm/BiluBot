require_relative '../logger/logging'
require_relative '../services/misc_service'

class MiscController
  include Logging

  def initialize(bilu)
    @service = MiscService.new(bilu)
  end

  def delete_message(message)
    @service.delete_message(message)
  end

end