module Rack
  module Firebase
    class Configuration
      attr_accessor :project_ids

      def initialize
        reset!
      end

      def reset!
        @project_ids = []
      end
    end
  end
end
