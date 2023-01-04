require "rack/firebase/configuration"
require "rack/firebase/version"

module Rack
  module Firebase
    class << self
      attr_writer :configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield configuration
    end

    ALG = "RS256".freeze
    CERTIFICATE_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com".freeze
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
  end
end
require "rack/firebase/error"
require "rack/firebase/authorization_header"
require "rack/firebase/token_decoder"
require "rack/firebase/middleware"
