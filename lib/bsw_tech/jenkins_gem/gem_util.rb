module BswTech
  module JenkinsGem
    module GemUtil
      def with_quiet_gem
        current_ui = Gem::DefaultUserInteraction.ui
        Gem::DefaultUserInteraction.ui = Gem::SilentUI.new
        yield
      ensure
        Gem::DefaultUserInteraction.ui = current_ui
      end

      def fetch(uri_str, limit = 10)
        # You should choose a better exception.
        raise ArgumentError, 'too many HTTP redirects' if limit == 0

        response = Net::HTTP.get_response(URI(uri_str))
        case response
        when Net::HTTPSuccess then
          response
        when Net::HTTPRedirection then
          location = response['location']
          fetch(location, limit - 1)
        else
          response.value
        end
      end
    end
  end
end
