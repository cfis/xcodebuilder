module XcodeBuilder
  module DeploymentStrategies
    def self.valid_strategy?(strategy_name)
      strategies.keys.include?(strategy_name.to_sym)
    end

    def self.build(strategy_name, configuration)
      strategies[strategy_name.to_sym].new(configuration)
    end

    class Strategy
      def initialize(configuration)
        @configuration = configuration

        if respond_to?(:extended_configuration_for_strategy)
          @configuration.instance_eval(&extended_configuration_for_strategy)
        end
      end

      def configure(&block)
        yield @configuration
      end

      def prepare
        puts "Nothing to prepare!" if @configuration.verbose
      end
    end

    private

    def self.strategies
      {:testflight => TestFlight}
    end
  end
end

require File.dirname(__FILE__) + '/deployment_strategies/testflight'
