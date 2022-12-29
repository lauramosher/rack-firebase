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
  end
end