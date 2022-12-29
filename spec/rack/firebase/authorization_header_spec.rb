require "spec_helper"

RSpec.describe Rack::Firebase::AuthorizationHeader do
  describe "#read_token(env)" do
    context "when authorization is Bearer" do
      it "returns token" do
        env = {"HTTP_AUTHORIZATION" => "Bearer ey123.token"}

        expect(described_class.read_token(env)).to eq("ey123.token")
      end
    end

    context "when authorization is missing a method" do
      it "returns nil" do
        env = {"HTTP_AUTHORIZATION" => "ey123.token"}

        expect(described_class.read_token(env)).to be_nil
      end
    end

    context "when Authorization is a different method" do
      it "returns nil" do
        env = {"HTTP_AUTHORIZATION" => "Basic password"}

        expect(described_class.read_token(env)).to be_nil
      end
    end

    context "when there is no authorization header" do
      it "returns nil" do
        expect(described_class.read_token({})).to be_nil
      end
    end
  end
end
