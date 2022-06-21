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
        format: 'bestvideo[filesize<35M]+bestaudio[filesize<15M]/bestvideo[filesize_approx<35M]+bestaudio[filesize_approx<15M]/bestvideo[filesize<40M]+bestaudio[filesize<10M]/bestvideo[filesize_approx<40M]+bestaudio[filesize_approx<10M]/bestvideo[filesize<15M]+bestaudio[filesize<35M]/bestvideo[filesize_approx<15M]+bestaudio[filesize_approx<35M]/bestvideo[filesize<10M]+bestaudio[filesize<40M]/bestvideo[filesize_approx<10M]+bestaudio[filesize_approx<40M]/best[filesize<50M]/best[filesize_approx<50M]/bestvideo[height<=360]+bestaudio[ext=m4a]/best',
        logging: true,
        "cmdline-args": "--write-thumbnail --convert-thumbnails jpg --http-chunk-size 8M --max-filesize 52428800 --merge-output-format mp4",
        module: 'yt_dlp',
        Facebook: {
          'cmdline-args': "--add-header 'cookie: #{ENV['BILU_FACEBOOK_COOKIES']}'"
        },
        Steam: {
          filename: '{id}.{extension}'
        }
      }
    },
    downloader: {
      'filesize-max': '50M'
    }
  }
end
