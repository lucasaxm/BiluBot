require_relative 'submission'

module Reddit
  ##
  # Wraps a Reddit subreddit and the small set of listing endpoints the bot needs.
  class Subreddit
    attr_reader :display_name

    def initialize(client, display_name)
      @client = client
      @display_name = display_name
      @about = nil
    end

    def id
      about['name']
    end

    def over_18?
      !!about['over18']
    end

    def hot(limit: 100)
      response = @client.get("/r/#{display_name}/hot", limit: limit, raw_json: 1)
      children = response.dig('data', 'children') || []
      children.map { |child| Submission.new(child['data']) }
    end

    private

    def about
      @about ||= @client.get("/r/#{display_name}/about", raw_json: 1)['data']
    end
  end
end
