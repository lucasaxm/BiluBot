require 'json'
module GalleryDLConfig
  class << self
    def save_config
      # Windows
      File.write(File.join(Dir.home, 'gallery-dl.conf'), @default.to_json)
      # Linux
      File.write(File.join(Dir.home, '.gallery-dl.conf'), @default.to_json)
      File.write(File.join("#{__dir__}", 'youtubedl.conf'), @youtubedl.to_json)
    end
  end

  @default = {
    "cookies-from-browser": "chrome:#{File.join(__dir__, '..', 'puppeteer', 'user_data', 'Default')}",
    extractor: {
      filename: '{filename|id}.{extension|ext}',
      reddit: {
        "client-id": ENV['BILU_REDDIT_CLIENT_ID_DL'],
        "user-agent": "Python:#{ENV['BILU_REDDIT_APP_NAME_DL']}:v1.0 (by /u/#{ENV['BILU_REDDIT_USERNAME']})"
      },
      twitter: {
        cards: 'ytdl'
      },
      ytdl: {
        enabled: true,
        format: 'bestvideo[filesize<35M][ext=mp4]+bestaudio[filesize<15M][ext=m4a]/bestvideo[filesize_approx<35M][ext=mp4]+bestaudio[filesize_approx<15M][ext=m4a]/bestvideo[filesize<40M][ext=mp4]+bestaudio[filesize<10M][ext=m4a]/bestvideo[filesize_approx<40M][ext=mp4]+bestaudio[filesize_approx<10M][ext=m4a]/bestvideo[filesize<15M][ext=mp4]+bestaudio[filesize<35M][ext=m4a]/bestvideo[filesize_approx<15M][ext=mp4]+bestaudio[filesize_approx<35M][ext=m4a]/bestvideo[filesize<10M][ext=mp4]+bestaudio[filesize<40M][ext=m4a]/bestvideo[filesize_approx<10M][ext=mp4]+bestaudio[filesize_approx<40M][ext=m4a]/best[filesize<50M][ext=mp4]/best[filesize_approx<50M][ext=mp4]/bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/bestvideo[filesize<35M]+bestaudio[filesize<15M][ext=m4a]/bestvideo[filesize_approx<35M]+bestaudio[filesize_approx<15M][ext=m4a]/bestvideo[filesize<40M]+bestaudio[filesize<10M][ext=m4a]/bestvideo[filesize_approx<40M]+bestaudio[filesize_approx<10M][ext=m4a]/bestvideo[filesize<15M]+bestaudio[filesize<35M][ext=m4a]/bestvideo[filesize_approx<15M]+bestaudio[filesize_approx<35M][ext=m4a]/bestvideo[filesize<10M]+bestaudio[filesize<40M][ext=m4a]/bestvideo[filesize_approx<10M]+bestaudio[filesize_approx<40M][ext=m4a]/best[filesize<50M]/best[filesize_approx<50M]/bestvideo[height<=360]+bestaudio[ext=m4a]/best',
        logging: true,
        "cmdline-args": "--write-thumbnail --convert-thumbnails jpg --http-chunk-size 8M --max-filesize 52428800 --merge-output-format mp4",
        module: 'yt_dlp',
        Facebook: {
          filename: '{id}.{extension}'
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

  @youtubedl = {
    extractor: {
      ytdl: {
        "cmdline-args": "--write-thumbnail --http-chunk-size 8M --max-filesize 52428800 --merge-output-format mp4",
        module: 'youtube_dl'
      }
    }
  }
end
