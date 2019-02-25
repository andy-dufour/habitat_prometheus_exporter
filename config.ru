require 'rack'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

require_relative 'hab_prometheus_exporter'

use Rack::Deflater
use Prometheus::Middleware::Exporter
use Habitat::Exporter::Collector

run ->(_) { [200, {'Content-Type' => 'text/html'}, ['OK']] }
