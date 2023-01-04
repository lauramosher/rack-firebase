module Rack
  module Firebase
    module TestHelpers
      def self.auth_headers(headers, uid, aud: nil, options: {})
        cached_current_time = Time.now.to_i
        aud ||= Rack::Firebase.configuration.project_ids.first

        payload = {
          iss: "https://securetoken.google.com/#{aud}",
          aud: aud,
          auth_time: options[:auth_time] || options[:iat] || cached_current_time,
          user_id: uid,
          sub: uid,
          iat: options[:iat] || cached_current_time,
          exp: options[:exp] || cached_current_time + 5000,
          email: options[:email] || "test@test.com",
          email_verified: !!options[:verified],
          firebase: {
            identities: {
              email: [
                options[:email],
                "test@test.com"
              ]
            },
            sign_in_provider: "password"
          }
        }
        token = JWT.encode(payload, secret_key, Rack::Firebase::ALG, kid: "1234567890")
        headers = headers.dup
        headers["Authorization"] = "Bearer #{token}"
        headers
      end

      def self.mock_start(expires_in = 5000)
        Rack::Firebase.instance_variable_set(:@cached_keys, [JWT::JWK::RSA.new(secret_key.public_key, kid: "1234567890")])
        Rack::Firebase.instance_variable_set(:@refresh_cache_by, Time.now.to_i + expires_in)
      end

      def self.mock_signature_verification
        mock_start
        yield
        mock_end
      end

      def self.mock_end
        Rack::Firebase.instance_variable_set(:@cached_keys, nil)
        Rack::Firebase.instance_variable_set(:@refresh_cache_by, nil)
      end

      private_class_method

      def self.secret_key
        @secret_key ||= OpenSSL::PKey::RSA.generate(2048)
      end
    end
  end
end
