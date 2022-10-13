require 'terrapin'
require 'json'
require 'ostruct'
require 'timeout'

require_relative "#{__dir__}/gallery-dl/version"
require_relative "#{__dir__}/gallery-dl/support"
require_relative "#{__dir__}/gallery-dl/options"
require_relative "#{__dir__}/gallery-dl/runner"
require_relative "#{__dir__}/gallery-dl/media"
require_relative "#{__dir__}/../logger/logging"

module GalleryDL
  extend self
  extend Support
  include Logging

  # Downloads given array of URLs with any options passed
  #
  # @param urls [String, Array] URLs to download
  # @param options [Hash] Downloader options
  # @return [GalleryDL::Media, Array] Video model or array of Video models
  def download(urls, timeout = 30, options = {})
    if urls.is_a? Array
      urls.map { |url| GalleryDL::Media.get(url, timeout, options) }
    else
      GalleryDL::Media.get(urls, timeout, options) # Urls should be singular but oh well. url = urls. There. Go cry in a corner.
    end
  end

  # Downloads given array of URLs with any options passed
  #
  # @param urls [String, Array] URLs to download
  # @param options [Hash] Downloader options
  # @return [GalleryDL::Media, Array] Video model or array of Video models
  def fetch_metadata(urls, timeout = 30, options = {})
    if urls.is_a? Array
      urls.map { |url| GalleryDL::Media.fetch_metadata(url, timeout, options) }.sum
    else
      GalleryDL::Media.fetch_metadata(urls, timeout, options) # Urls should be singular but oh well. url = urls. There. Go cry in a corner.
    end
  end

end