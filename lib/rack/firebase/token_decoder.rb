require "jwt"
require "net/http"
require "rack/firebase"

module Rack
  module Firebase
    class TokenDecoder
      attr_accessor :config, :jwt_loader

      def initialize
        @jwt_loader = FIREBASE_KEY_LOADER
        @config = Rack::Firebase.configuration
      end

      def call(token)
        JWT.decode(
          token, nil, true,
          {
            jwks: jwt_loader,
            algorithm: ALG,
            verify_iat: true,
            verify_aud: true, aud: config.project_ids,
            verify_iss: true, iss: firebase_issuers
          }
        )[0]
      end

      def firebase_issuers
        config.project_ids.map { |project_id|
          "https://securetoken.google.com/#{project_id}"
        }
      end
    end
  end
end
