require 'faraday'
require 'json'
require 'base64'
require_relative 'errors'

module Reddit
  ##
  # Minimal OAuth2 (app-only / client_credentials) client for Reddit's read-only API.
  # Replaces the abandoned `redd` gem with just the surface this bot needs.
  class Client
    TOKEN_URL = 'https://www.reddit.com/api/v1/access_token'.freeze
    API_URL = 'https://oauth.reddit.com'.freeze

    def initialize(client_id:, secret:, user_agent:)
      @client_id = client_id
      @secret = secret
      @user_agent = user_agent
      @access_token = nil
      @expires_at = Time.at(0)
    end

    def get(path, params = {})
      ensure_token
      response = connection.get(path, params) do |req|
        req.headers['Authorization'] = "Bearer #{@access_token}"
      end
      handle_response(response)
    end

    # Resolves a share link path (e.g. "/r/sub/s/CODE") to its redirect target
    # via the authenticated API host, returning nil if there's no redirect.
    # Some hosting providers' IPs get WAF-blocked outright on www.reddit.com's
    # plain web pages regardless of headers, but oauth.reddit.com only cares
    # about a valid token + User-Agent, so share-link resolution goes through
    # here instead of an anonymous request to the web domain.
    def resolve_share_link(path)
      ensure_token
      response = connection.head(path) do |req|
        req.headers['Authorization'] = "Bearer #{@access_token}"
      end
      response.headers['location']
    end

    def refresh
      fetch_token
    end

    private

    def ensure_token
      fetch_token if @access_token.nil? || Time.now >= @expires_at
    end

    def fetch_token
      response = auth_connection.post(TOKEN_URL) do |req|
        req.headers['Authorization'] = "Basic #{Base64.strict_encode64("#{@client_id}:#{@secret}")}"
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = 'grant_type=client_credentials'
      end
      raise Errors::Unauthorized, "Failed to authenticate with Reddit (#{response.status}): #{response.body}" unless response.success?

      body = JSON.parse(response.body)
      @access_token = body['access_token']
      @expires_at = Time.now + body['expires_in'].to_i - 30
    end

    def handle_response(response)
      case response.status
      when 200..299
        JSON.parse(response.body)
      when 401
        raise Errors::Unauthorized, "Unauthorized (401): #{response.body}"
      when 403
        raise Errors::Forbidden, "Forbidden (403): #{response.body}"
      when 404
        raise Errors::NotFound, "Not Found (404): #{response.body}"
      when 429
        raise Errors::RateLimited, "Rate limited (429): #{response.body}"
      else
        raise Errors::Error, "Reddit API error #{response.status}: #{response.body}"
      end
    end

    def connection
      @connection ||= Faraday.new(url: API_URL) do |f|
        f.headers['User-Agent'] = @user_agent
        f.adapter Faraday.default_adapter
      end
    end

    def auth_connection
      @auth_connection ||= Faraday.new do |f|
        f.headers['User-Agent'] = @user_agent
        f.adapter Faraday.default_adapter
      end
    end
  end
end
