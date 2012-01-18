require 'mongrel2'
require 'rack'
require 'eventmachine'

module Mongrel2
  class Request
    attr_reader :headers, :body, :uuid, :conn_id, :path, :connection

    class << self
      def parse(msg, connection)
        # UUID CONN_ID PATH SIZE:HEADERS,SIZE:BODY,
        uuid, conn_id, path, rest = msg.split(' ', 4)
        headers, rest = parse_netstring(rest)
        headers = Mongrel2::JSON.parse(headers)
        if (body_path = headers['x-mongrel2-upload-done'])
          body = File.open(body_path)
        else
          body, _ = parse_netstring(rest)
          body = StringIO.new(body)
        end
        new(uuid, conn_id, path, headers, body, connection)
      end

      def parse_netstring(ns)
        # SIZE:HEADERS,

        len, rest = ns.split(':', 2)
        len = len.to_i
        raise "Netstring did not end in ','" unless rest[len].chr == ','
        [rest[0, len], rest[(len + 1)..-1]]
      end
    end

    def initialize(uuid, conn_id, path, headers, body, connection)
      @uuid, @conn_id, @path, @headers, @body = uuid, conn_id, path, headers, body
      @data = headers['METHOD'] == 'JSON' ? Mongrel2::JSON.parse(body.read) : {}
      @connection = connection
    end

    def disconnect?
      headers['METHOD'] == 'JSON' && @data['type'] == 'disconnect'
    end

    def close?
      headers['connection'] == 'close' || headers['VERSION'] == 'HTTP/1.0'
    end

    def env
      return @env if @env
      script_name = ENV['RACK_RELATIVE_URL_ROOT'] || headers['PATTERN'].split('(', 2).first.gsub(/\/$/, '')
      @env = {
        'rack.version' => Rack::VERSION,
        'rack.url_scheme' => 'http', # Only HTTP for now
        'rack.input' => body,
        'rack.errors' => $stderr,
        'rack.multithread' => true,
        'rack.multiprocess' => true,
        'rack.run_once' => false,
        'mongrel2.pattern' => headers['PATTERN'],
        'REQUEST_METHOD' => headers['METHOD'],
        'SCRIPT_NAME' => script_name,
        'PATH_INFO' => headers['PATH'].gsub(script_name, ''),
        'QUERY_STRING' => headers['QUERY'] || '',
        'async.callback' => Proc.new { |resp|
          connection.method(:post_process).call(resp, self)
        },
        'async.close' => EM::DefaultDeferrable.new
      }
      
      @env['SERVER_NAME'], @env['SERVER_PORT'] = headers['host'].split(':', 2)
      headers.each do |key, val|
        key = key.upcase.gsub('-', '_')
        unless %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
          key = "HTTP_#{key}"
        end
        @env[key] = val
      end

      @env
    end
  end
end
