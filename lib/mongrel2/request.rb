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
        body, _ = parse_netstring(rest)
        headers = MultiJson.decode(headers)
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
      @data = headers['METHOD'] == 'JSON' ? MultiJson.decode(body) : {}
      @connection = connection
    end

    def disconnect?
      headers['METHOD'] == 'JSON' && @data['type'] == 'disconnect'
    end

    def close?
      headers['connection'] == 'close' || headers['VERSION'] == 'HTTP/1.0'
    end

    def env
      script_name = ENV['RACK_RELATIVE_URL_ROOT'] || headers['PATTERN'].split('(', 2).first.gsub(/\/$/, '')
      env = {
        'rack.version' => Rack::VERSION,
        'rack.url_scheme' => 'http', # Only HTTP for now
        'rack.input' => StringIO.new(body),
        'rack.errors' => $stderr,
        'rack.multithread' => true,
        'rack.multiprocess' => true,
        'rack.run_once' => false,
        'mongrel2.pattern' => headers['PATTERN'],
        'REQUEST_METHOD' => headers['METHOD'],
        'CONTENT_TYPE' => headers['content-type'],
        'SCRIPT_NAME' => script_name,
        'PATH_INFO' => headers['PATH'].gsub(script_name, ''),
        'QUERY_STRING' => headers['QUERY'] || '',
        'async.callback' => Proc.new { |resp|
          connection.method(:post_process).call(resp, self)
        },
        'async.close' => EM::DefaultDeferrable.new
      }
      
      env['SERVER_NAME'], env['SERVER_PORT'] = headers['host'].split(':', 2)
      headers.each do |key, val|
        unless key =~ /content_(type|length)/i
          key = "HTTP_#{key.upcase.gsub('-', '_')}"
        end
        env[key] = val
      end

      env
    end
  end
end
