require_relative '../logger/logging'
require 'faraday'
require 'faraday_middleware'

class ScreenshotService
  include Logging

  # @param [Telegram::Bot::Types::Message] @message
  def self.screenshot_url(target_url, options = {})
    api_url = 'https://api.apiflash.com/v1'

    conn = Faraday.new(url: api_url,
                       params: { access_key: ENV['BILU_APIFLASH_ACCESS_KEY'], response_type: 'json' }) do |f|
      f.response :json
      f.request :json
      f.response :logger
    end

    response = conn.get('urltoimage') do |req|
      req.params['url'] = target_url
      req.params.merge!(options)
    end

    raise StandardError, "code: #{response.status}" if response.status != 200

    response.body['url']
  end
end
