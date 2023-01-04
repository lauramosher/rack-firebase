require "spec_helper"

RSpec.describe Rack::Firebase::TokenDecoder do
  describe "#call" do
    let(:secret) { OpenSSL::PKey::RSA.generate(2048) }
    let(:token) { JWT.encode(payload, secret, "RS256", {kid: "1234567890"}) }
    let(:payload) { {"foo" => "bar", "aud" => "token-test", "iss" => "https://securetoken.google.com/token-test"} }

    before do
      Rack::Firebase.instance_variable_set(:@cached_keys, [JWT::JWK::RSA.new(secret.public_key, kid: "1234567890")])
      Rack::Firebase.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 6000)

      Rack::Firebase.configure do |config|
        config.project_ids = ["token-test"]
      end
    end

    after do
      Rack::Firebase.instance_variable_set(:@cached_keys, nil)
      Rack::Firebase.instance_variable_set(:@refresh_cache_by, nil)
    end

    it "returns decoded token payload" do
      expect(described_class.new.call(token)).to eq(payload)
    end
  end
end
