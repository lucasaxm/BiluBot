require 'terrapin'
require 'json'
require 'ostruct'

require_relative 'gallery-dl/version'
require_relative 'gallery-dl/support'
require_relative 'gallery-dl/options'
require_relative 'gallery-dl/runner'
require_relative 'gallery-dl/media'
require_relative '../logger/logging'

module GalleryDL
  extend self
  extend Support
  include Logging

  # Downloads given array of URLs with any options passed
  #
  # @param urls [String, Array] URLs to download
  # @param options [Hash] Downloader options
  # @return [GalleryDL::Media, Array] Video model or array of Video models
  def download(urls, options = {})
    if urls.is_a? Array
      urls.map { |url| GalleryDL::Media.get(url, options) }
    else
      GalleryDL::Media.get(urls, options) # Urls should be singular but oh well. url = urls. There. Go cry in a corner.
    end
  end

end