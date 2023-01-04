module Rack
  module Firebase
    class Configuration
      attr_accessor :project_ids, :public_routes

      def initialize
        reset!
      end

      def reset!
        @project_ids = []
        @public_routes = []
      end
    end
  end
end
