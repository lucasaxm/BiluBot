require 'json'
module GalleryDLConfig
  class << self
    def save_config
      # Windows
      File.write(File.join(Dir.home, 'gallery-dl.conf'), @config.to_json)
      # Linux
      File.write(File.join(Dir.home, '.gallery-dl.conf'), @config.to_json)
    end
  end

  # holds the api key used in ForecastIO configuration
  @config = {
    extractor: {
      filename: '{filename|id}.{extension}',
      twitter: {
        username: ENV['BILU_TWITTER_USERNAME'],
        password: ENV['BILU_TWITTER_PASSWORD'],
        cookies: {
          'auth_token': ENV['BILU_TWITTER_AUTH_TOKEN']
        }
      },
      instagram: {
        username: ENV['BILU_INSTAGRAM_USERNAME'],
        password: ENV['BILU_INSTAGRAM_PASSWORD'],
        cookies: {
          session_id: ENV['BILU_INSTAGRAM_SESSION_ID']
        }
      },
      ytdl: {
        enabled: true,
        format: 'bestvideo[filesize<40M][ext=mp4]+bestaudio[filesize<10M][ext=m4a]/bestvideo[filesize_approx<40M][ext=mp4]+bestaudio[filesize_approx<10M][ext=m4a]/bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best',
        logging: true,
        module: 'yt_dlp',
        Facebook: {
          'cmdline-args': "--add-header 'cookie: #{ENV['BILU_FACEBOOK_COOKIES']}'"
        }
      }
    },
    downloader: {
      'filesize-max': '50M'
    }
  }
end
