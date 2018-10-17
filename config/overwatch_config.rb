##
# Configuration for the OverwatchController
#
module OverwatchConfig
  class << self
    attr_reader :owfilesuffix
  end

  # defines the suffix in the file that stores players names
  @owfilesuffix = 'owplayers.txt'
end