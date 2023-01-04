require "spec_helper"
require "rack/firebase/test_helpers"

RSpec.describe Rack::Firebase::TestHelpers do
  let(:headers) { {"foo" => "bar"} }
  let(:uid) { "12345" }

  def payload_from_headers(headers)
    _method, token = headers["Authorization"].split
    Rack::Firebase::TokenDecoder.new.call(token)
  end

  describe "::auth_headers(headers, uid, aud = nil, options = {})" do
    around(:example) do |example|
      Rack::Firebase::TestHelpers.mock_signature_verification do
        example.run
      end
    end

    before do
      Rack::Firebase.configure do |config|
        config.project_ids = ["test-helper-project", "second-project-id"]
      end
    end

    it "adds a valid token to the headers" do
      auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid)
      payload = payload_from_headers(auth_headers)

      expect(payload["sub"]).to eq(uid.to_s)
    end

    it "preserves current headers" do
      auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid)

      expect(auth_headers["foo"]).to eq("bar")
    end

    it "uses first project_id from config for aud claim" do
      auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid)
      payload = payload_from_headers(auth_headers)

      expect(payload["aud"]).to eq("test-helper-project")
    end

    it "can manually specify aud claim" do
      auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, aud: "second-project-id")
      payload = payload_from_headers(auth_headers)

      expect(payload["aud"]).to eq("second-project-id")
    end

    describe "options param" do
      let(:auth_time) { Time.now.to_i - 10 }
      let(:iat_time) { Time.now.to_i - 5 }
      let(:exp_time) { Time.now.to_i + 10 }

      it "can manually specify auth_time" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {auth_time: auth_time})
        payload = payload_from_headers(auth_headers)

        expect(payload["auth_time"]).to eq(auth_time)
      end

      it "can manually specify iat (issued_at)" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {iat: iat_time})
        payload = payload_from_headers(auth_headers)

        expect(payload["auth_time"]).to eq(iat_time)
        expect(payload["iat"]).to eq(iat_time)
      end

      it "can manually specify different iat and auth times" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {iat: iat_time, auth_time: auth_time})
        payload = payload_from_headers(auth_headers)

        expect(payload["iat"]).to eq(iat_time)
        expect(payload["auth_time"]).to eq(auth_time)
      end

      it "can manually specify token expiry time" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {exp: exp_time})
        payload = payload_from_headers(auth_headers)

        expect(payload["exp"]).to eq(exp_time)
      end

      it "can manually specify payload email" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {email: "options@test.com"})
        payload = payload_from_headers(auth_headers)

        expect(payload["email"]).to eq("options@test.com")
        expect(payload.dig("firebase", "identities", "email")).to include("options@test.com")
      end

      it "can manually specify payload emai_verified" do
        auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, uid, options: {verified: true})
        payload = payload_from_headers(auth_headers)

        expect(payload["email_verified"]).to be true
      end
    end
  end

  describe "::mock_start" do
    after { Rack::Firebase::TestHelpers.mock_end }

    it "sets @cached_keys" do
      allow(JWT::JWK::RSA).to receive(:new).and_return("cached-key")

      expect {
        Rack::Firebase::TestHelpers.mock_start
      }.to change {
        Rack::Firebase.instance_variable_get(:@cached_keys)
      }.from(nil).to(["cached-key"])
    end

    it "sets @refresh_cache_by" do
      allow(Time).to receive(:now)

      expect {
        Rack::Firebase::TestHelpers.mock_start
      }.to change {
        Rack::Firebase.instance_variable_get(:@refresh_cache_by)
      }.from(nil).to(5000)
    end

    it "allows manually setting of expiration time" do
      allow(Time).to receive(:now)

      expect {
        Rack::Firebase::TestHelpers.mock_start(1000)
      }.to change {
        Rack::Firebase.instance_variable_get(:@refresh_cache_by)
      }.from(nil).to(1000)
    end
  end

  describe "::mock_end" do
    before do
      allow(JWT::JWK::RSA).to receive(:new).and_return("cached-key")
      allow(Time).to receive(:now)

      Rack::Firebase::TestHelpers.mock_start
    end

    it "unsets @cached_keys" do
      expect {
        Rack::Firebase::TestHelpers.mock_end
      }.to change {
        Rack::Firebase.instance_variable_get(:@cached_keys)
      }.from(["cached-key"]).to(nil)
    end

    it "unsets @refresh_cache_by" do
      expect {
        Rack::Firebase::TestHelpers.mock_end
      }.to change {
        Rack::Firebase.instance_variable_get(:@refresh_cache_by)
      }.from(5000).to(nil)
    end
  end

  describe "::mock_signature_verification" do
    it "should yield to example" do
      expect { |example| Rack::Firebase::TestHelpers.mock_signature_verification(&example) }.to yield_with_no_args
    end
  end
end
