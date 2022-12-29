module Rack
  module Firebase
    class AuthorizationHeader
      METHOD = "Bearer"
      AUTH_HEADER_ENV = "HTTP_AUTHORIZATION"

      def self.read_token(env)
        return unless (auth = env[AUTH_HEADER_ENV])

        method, token = auth.split
        return token if method == METHOD
      end
    end
  end
end
