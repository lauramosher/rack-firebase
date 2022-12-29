require "spec_helper"

RSpec.describe Rack::Firebase do
  it "has a version" do
    expect(Rack::Firebase::VERSION).not_to be nil
  end

  describe "#reset!" do
    before do
      Rack::Firebase.configure do |config|
        config.project_ids = 1
      end
    end

    it "resets the configuration" do
      expect(Rack::Firebase.configuration.project_ids).to eq(1)
      Rack::Firebase.configuration.reset!
      expect(Rack::Firebase.configuration.project_ids).to eq([])
    end
  end
end
