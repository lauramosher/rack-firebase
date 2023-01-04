require "jwt"
require "net/http"

module Rack
  module Firebase
    class Middleware
      USER_UID = "firebase.user.uid"

      def initialize(app)
        @app = app

        @config = ::Rack::Firebase.configuration

        @jwt_loader = FIREBASE_KEY_LOADER
        @error_responder = DEFAULT_ERROR_RESPONDER
      end

      def call(env)
        token = AuthorizationHeader.read_token(env)
        decoded_token = TokenDecoder.new.call(token)

        raise Rack::Firebase::InvalidSubError.new("Invalid subject") if decoded_token["sub"].nil? || decoded_token["sub"] == ""
        raise Rack::Firebase::InvalidAuthTimeError.new("Invalid auth time") unless decoded_token["auth_time"] <= Time.now.to_i

        env[USER_UID] = decoded_token["sub"]
        @app.call(env)
      rescue JWT::JWKError => error # Issues with fetched JWKs
        error_responder.call(error, "unauthorized")
      rescue JWT::ExpiredSignature => error # Token has expired
        error_responder.call(error, "expired")
      rescue JWT::InvalidIatError => error # invalid issued at claim (iat)
        error_responder.call(error, "unauthorized")
      rescue JWT::InvalidIssuerError => error # invalid issuer
        error_responder.call(error, "unauthorized")
      rescue JWT::InvalidAudError => error # invalid audience
        error_responder.call(error, "unauthorized")
      rescue JWT::DecodeError => error # General JWT error
        error_responder.call(error, "unauthorized")
      rescue Rack::Firebase::InvalidSubError => error # subject is empty or missing
        error_responder.call(error, "unauthorized")
      rescue Rack::Firebase::InvalidAuthTimeError => error # auth time is in the future
        error_responder.call(error, "unauthorized")
      end

      private

      attr_reader :config, :error_responder, :jwt_loader

      DEFAULT_ERROR_RESPONDER = lambda do |error, reason|
        error_detail = {
          error: error.message,
          message: reason
        }.to_json
        [401, {"content-type" => "application/json"}, [error_detail]]
      end

      FIREBASE_KEY_LOADER = lambda do |options|
        if options[:kid_not_found] || (@refresh_cache_by.to_i < Time.now.to_i + 3600)
          @cached_keys = nil
        end

        @cached_keys ||= begin
          response = ::Net::HTTP.get_response(URI(CERTIFICATE_URL))
          cache_control = response["Cache-Control"]

          expires_in = cache_control.match(/max-age=([0-9]+)/).captures.first.to_i
          @refresh_cache_by = Time.now.to_i + expires_in

          json = JSON.parse(response.body)
          json.map do |kid, cert_string|
            key = OpenSSL::X509::Certificate.new(cert_string).public_key
            JWT::JWK::RSA.new(key, kid: kid)
          end
        end
      end

      def firebase_issuers
        config.project_ids.map { |project_id|
          "https://securetoken.google.com/#{project_id}"
        }
      end
    end
  end
end
