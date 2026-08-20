module Reddit
  module Errors
    # Base class for all errors raised by the Reddit client.
    class Error < StandardError; end
    class NotFound < Error; end
    class Forbidden < Error; end
    class Unauthorized < Error; end
    class RateLimited < Error; end
  end
end
