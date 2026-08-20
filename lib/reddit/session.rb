require_relative 'client'
require_relative 'subreddit'
require_relative 'submission'

module Reddit
  ##
  # Entry point mimicking the small subset of the old `redd` gem's session
  # object that this bot relies on.
  class Session
    def initialize(client_id:, secret:, user_agent:)
      @client = Client.new(client_id: client_id, secret: secret, user_agent: user_agent)
    end

    def subreddit(name)
      Subreddit.new(@client, name)
    end

    def from_ids(ids)
      names = Array(ids).join(',')
      response = @client.get('/api/info', id: names, raw_json: 1)
      children = response.dig('data', 'children') || []
      children.map { |child| Submission.new(child['data']) }
    end

    def resolve_share_link(path)
      @client.resolve_share_link(path)
    end

    def refresh
      @client.refresh
    end
  end
end
