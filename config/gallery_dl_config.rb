require 'json'
module GalleryDLConfig
  class << self
    def save_config
      # Windows
      File.write(File.join(Dir.home,'gallery-dl.conf'), @config.to_json)
      # Linux
      File.write(File.join(Dir.home,'.gallery-dl.conf'), @config.to_json)

    end
  end

  # holds the api key used in ForecastIO configuration
  @config = {
      extractor: {
          twitter: {
              username: ENV['BILU_TWITTER_USERNAME'],
              password: ENV['BILU_TWITTER_PASSWORD']
          },
          instagram: {
              username: ENV['BILU_INSTAGRAM_USERNAME'],
              password: ENV['BILU_INSTAGRAM_PASSWORD']
          }
      },
      downloader: {
          'filesize-max': '20M'
      }
  }
end