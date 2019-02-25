require 'prometheus/client'
require 'net/http'
require 'json'

# returns a default registry
module Habitat
  module Exporter
    class Collector
      attr_reader :app, :registry

      def initialize(app, options = {})
        @app = app
        @registry = options[:registry] || Prometheus::Client.registry
        @metrics_prefix = options[:metrics_prefix] || 'habitat'

        init_habitat_metrics

        @package_status = service_health_check

      end

      def call(env) # :nodoc:
        service_health_check
        get_package_versions
      end

      def init_habitat_metrics
        @package_status = @registry.gauge(
          :"#{@metrics_prefix}_package_health_status",
          'Current status of packages health check.',
        )
        @package_version = @registry.gauge(
          :"#{@metrics_prefix}_package_version",
          'Current version of Habitat package installed',
        )
        @package_release = @registry.gauge(
          :"#{@metrics_prefix}_package_release",
          'Current release number of Habitat package installed',
        )
      end

      def get_package_versions
        url = "http://localhost:9631/butterfly"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        packages = JSON.parse(response)['service']['list']
        packages.each do | name, data |
          package = name.split('.')[0]
          svc_group = name.split('.')[1]
          get_package_version(package, svc_group)
        end
      end

      def get_package_version(package, group)
        url = "http://localhost:9631/services/#{package}/#{group}"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        pkg_info = JSON.parse(response)['pkg']
        @package_version.set({ package: "#{package}_#{pkg_info['version']}"}, 1)
        @package_release.set({ package: "#{package}_#{pkg_info['release']}"}, 1)

      end

      def service_health_check
        url = "http://localhost:9631/butterfly"
        begin
          uri = URI(url)
          response = Net::HTTP.get(uri)
          packages = JSON.parse(response)['service']['list']
          packages.each do | name, data |
            package = name.split('.')[0]
            svc_group = name.split('.')[1]
            get_package_status(package, svc_group)
          end
        rescue

        end
      end

      def get_package_status(package, group)
        url = "http://localhost:9631/services/#{package}/#{group}/health"
        begin
          uri = URI(url)
          response = Net::HTTP.get(uri)
          status = JSON.parse(response)['status']
          if status == 'OK'
            @package_status.set({ package: package}, 1)
          else
            @package_status.set({ package: package}, 0)
          end
        rescue
          @package_status.set({ package: package}, 0)
        end
      end
    end
  end
end
