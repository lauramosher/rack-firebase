require "spec_helper"
require "rack/test"

RSpec.describe Rack::Firebase::Middleware do
  include Rack::Test::Methods

  let(:simulated_app) { ->(_env) { [200, {}, []] } }
  let(:app) { described_class.new(simulated_app) }

  let(:firebase_project) { "rack-firebase-auth" }

  before do
    Rack::Firebase.configure do |config|
      config.project_ids = [firebase_project]
    end
  end

  after do
    described_class.instance_variable_set(:@cached_keys, nil)
    described_class.instance_variable_set(:@refresh_cache_by, nil)
  end

  describe "::ALG" do
    it "returns Firebase's algorithm" do
      expect(described_class::ALG).to eq("RS256")
    end
  end

  describe "::CERTIFICATE_URL" do
    it "returns Firebase's Certification Endpoint" do
      expect(described_class::CERTIFICATE_URL).to eq("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
    end
  end

  describe "::USER_UID" do
    it "returns request env helper key" do
      expect(described_class::USER_UID).to eq("firebase.user.uid")
    end
  end

  describe "#call(env)" do
    let(:auth_time) { Time.now.to_i }
    let(:iat) { auth_time }
    let(:exp) { iat + 18000 } # 5 HOURS AFTER ISSUED AT
    let(:aud) { firebase_project }
    let(:uid) { "123" }

    let(:payload) {
      {
        iss: "https://securetoken.google.com/#{firebase_project}",
        aud: aud,
        auth_time: auth_time,
        user_id: "123",
        sub: uid,
        iat: iat,
        exp: exp,
        email: "test@test.com",
        email_verified: false,
        firebase: {
          identities: {
            email: [
              "test@test.com"
            ]
          },
          sign_in_provider: "password"
        }
      }
    }

    let(:alg) { "RS256" }
    let(:jwt_custom_headers) { {kid: "1234567890"} }
    let(:secret) { OpenSSL::PKey::RSA.generate(2048) }

    let(:token) { JWT.encode(payload, secret, alg, jwt_custom_headers) }
    let(:cached_jwks) { [JWT::JWK::RSA.new(secret.public_key, kid: "1234567890")] }

    let(:net_response) { Net::HTTPResponse.new(1.0, "200", "OK") }

    let(:json_response) { JSON.parse(last_response.body) }

    it "returns a 401 unauthorized when no HTTP_AUTHORIZATION request header" do
      get "/"

      expect(json_response["error"]).to eq("Nil JSON web token")
      expect(last_response).to be_unauthorized
    end

    it "returns a 401 unauthorized when authorization is not a Bearer token" do
      header "AUTHORIZATION", "Basic just-a-token"
      get "/"

      expect(json_response["error"]).to eq("Nil JSON web token")
      expect(last_response).to be_unauthorized
    end

    context "when provided token is encoded using a different algorithm" do
      let(:secret) { nil }
      let(:alg) { "HS256" }

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Expected a different algorithm")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token header does not include a key id" do
      let(:jwt_custom_headers) { {} }

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("No key id (kid) found from token headers")
        expect(last_response).to be_unauthorized
      end
    end

    context "when no public key was found for the provided key id" do
      let(:net_response) { Net::HTTPResponse.new(1.0, "200", "OK") }
      let(:certs) { File.read("#{CERT_PATH}/certificates_with_different_kid.json") }

      before do
        allow(net_response).to receive(:[]).with("Cache-Control").and_return("public, max-age=19302, must-revalidate, no-transform")
        allow(net_response).to receive(:body).and_return(certs)
      end

      it "returns a 401 unauthorized" do
        expect(Net::HTTP).to receive(:get_response).twice { net_response }

        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to include("Could not find public key for kid")
        expect(last_response).to be_unauthorized
      end

      context "with cached kids" do
        let(:cached_jwks) {
          [
            JWT::JWK::RSA.new(secret.public_key, kid: "some-old-key"),
            JWT::JWK::RSA.new(secret.public_key, kid: "another-old-key")
          ]
        }

        before do
          described_class.instance_variable_set(:@cached_keys, cached_jwks)
          described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
        end

        it "returns a 401 unauthorized" do
          expect(Net::HTTP).to receive(:get_response).once { net_response }

          header "AUTHORIZATION", "Bearer #{token}"
          get "/"

          expect(json_response["error"]).to include("Could not find public key for kid")
          expect(last_response).to be_unauthorized
        end
      end
    end

    context "when token has expired" do
      let(:exp) { Time.now.to_i - 1000 }

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Signature has expired")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has invalid issuer" do
      before do
        Rack::Firebase.configure do |config|
          config.project_ids = ["different-project-name"]
        end
      end

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to include("Invalid issuer")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has invalid audience" do
      let(:aud) { "different-audience" }

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to include("Invalid audience")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has invalid issued at time" do
      let(:iat) { Time.now.to_i + 100 } # in the future

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Invalid iat")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has an empty sub claim" do
      let(:uid) { nil }

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Invalid subject")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has an empty sub claim" do
      let(:uid) { "" }

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Invalid subject")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token has an invalid auth time" do
      let(:auth_time) { Time.now.to_i + 60 } # 1 minute in the future
      let(:iat) { Time.now.to_i - 60 } # 1 minute in the past

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 401 unauthorized" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(json_response["error"]).to eq("Invalid auth time")
        expect(last_response).to be_unauthorized
      end
    end

    context "when token is valid" do
      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, Time.now.to_i + 5000)
      end

      it "returns a 200 success" do
        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        expect(last_response).to be_ok
        expect(last_request.env[described_class::USER_UID]).to eq("123")
      end
    end
  end

  describe "Firebase Public Key Cache" do
    let(:secret) { OpenSSL::PKey::RSA.generate(2048) }
    let(:token) { JWT.encode({}, secret, "RS256", kid: "1234567890") }

    let(:net_response) { Net::HTTPResponse.new(1.0, "200", "OK") }

    context "when there are no cached public keys" do
      let(:certs) { File.read("#{CERT_PATH}/certificates.json") }
      let(:cache_control) { "public, max-age=19302, must-revalidate, no-transform" }

      before do
        allow(net_response).to receive(:[]).with("Cache-Control").and_return(cache_control)
        allow(net_response).to receive(:body).and_return(certs)
      end

      it "caches the keys on the first request so it doesn't make additional requests" do
        expect(JWT).to receive(:decode).exactly(3).times.and_call_original
        expect(Net::HTTP).to receive(:get_response).with(URI(described_class::CERTIFICATE_URL)).once { net_response }

        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        header "AUTHORIZATION", "Bearer #{token}"
        get "/"

        header "AUTHORIZATION", "Bearer #{token}"
        get "/"
      end
    end

    context "when there are cached public keys" do
      let!(:current_time) { Time.now.to_i }
      let(:cached_jwks) {
        [
          JWT::JWK::RSA.new(secret.public_key, kid: "1234567890"),
          JWT::JWK::RSA.new(secret.public_key, kid: "this-key-should-be-busted")
        ]
      }

      before do
        described_class.instance_variable_set(:@cached_keys, cached_jwks)
        described_class.instance_variable_set(:@refresh_cache_by, current_time + 5000)
      end

      it "does not request public keys on request" do
        expect(Net::HTTP).not_to receive(:get_response)

        header "AUTHORIZATION", "Bearer #{token}"
        get "/"
      end

      context "and the cache is about to expire" do
        let(:certs) { File.read("#{CERT_PATH}/certificates.json") }
        let(:cache_control) { "public, max-age=19302, must-revalidate, no-transform" }

        before do
          described_class.instance_variable_set(:@refresh_cache_by, current_time + 1200)

          allow(net_response).to receive(:[]).with("Cache-Control").and_return(cache_control)
          allow(net_response).to receive(:body).and_return(certs)
        end

        it "resets cache and re-requests public keys" do
          expect(JWT).to receive(:decode).once.and_call_original
          expect(Net::HTTP).to receive(:get_response).with(URI(described_class::CERTIFICATE_URL)).once { net_response }

          header "AUTHORIZATION", "Bearer #{token}"
          get "/"

          expect(described_class.instance_variable_get(:@refresh_cache_by)).to be_within(1).of(current_time + 19302)
          expect(described_class.instance_variable_get(:@cached_keys).map(&:kid)).not_to include("this-key-should-be-busted")
        end
      end
    end
  end
end
