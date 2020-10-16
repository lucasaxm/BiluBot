require_relative '../logger/logging'

class DistortService
  include Logging

  # @param [Bilu::Bot] bilu
  def initialize(bilu)
    @bilu = bilu
  end

  def distort(message)
    # todo
  end

end