require "spec_helper"

RSpec.describe Rack::Firebase do
  it "has a version" do
    expect(Rack::Firebase::VERSION).not_to be nil
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

  describe "#reset!" do
    before do
      Rack::Firebase.configure do |config|
        config.project_ids = 1
        config.public_routes = ["/healthcheck"]
      end
    end

    it "resets the configuration" do
      expect(Rack::Firebase.configuration.project_ids).to eq(1)
      expect(Rack::Firebase.configuration.public_routes).to eq(["/healthcheck"])
      Rack::Firebase.configuration.reset!
      expect(Rack::Firebase.configuration.project_ids).to eq([])
      expect(Rack::Firebase.configuration.public_routes).to eq([])
    end
  end
end
