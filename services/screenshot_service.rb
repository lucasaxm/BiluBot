require_relative '../logger/logging'
require 'faraday'
require 'faraday_middleware'

class ScreenshotService
  include Logging

  def self.get_connection(token=nil)
    api_url = 'https://api.apiflash.com/v1'
    token = get_available_token if (token.nil?)
    Faraday.new(url: api_url, params: { access_key: token }) do |f|
      f.response :json
      f.request :json
      f.response :logger
      f.adapter Faraday.default_adapter
    end
  end

  def self.get_available_token
    tokens = ENV['BILU_APIFLASH_ACCESS_KEY'].split(',')
    tokens.detect do |t|
      next if t.nil?
      conn = get_connection t
      response = conn.get('urltoimage/quota')
      raise StandardError, "code: #{response.status}" if response.status != 200
      response.body['remaining'] > 0
    end
  end

  # @param [Telegram::Bot::Types::Message] @message
  def self.screenshot_url(target_url, options = {})

    conn = get_connection

    response = conn.get('urltoimage') do |req|
      req.params['url'] = target_url
      req.params.merge!(options)
    end

    raise StandardError, "code: #{response.status}" if response.status != 200

    response.body['url']
  end
end
