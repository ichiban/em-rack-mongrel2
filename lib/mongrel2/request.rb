module Mongrel2
  class Request
    attr_reader :headers, :body, :uuid, :conn_id, :path, :connection

    class << self
      def parse(msg, connection)
        # UUID CONN_ID PATH SIZE:HEADERS,SIZE:BODY,
        uuid, conn_id, path, rest = msg.split(' ', 4)
        headers, rest = TNetstring.parse(rest)
        headers = MultiJson.decode(headers)
        body, _ = TNetstring.parse(rest)
        new(uuid, conn_id, path, headers, body, connection)
      end
    end

    def initialize(uuid, conn_id, path, headers, body, connection)
      @uuid, @conn_id, @path, @headers = uuid, conn_id, path, headers
      if (body_path = headers['x-mongrel2-upload-done'])
        @body = File.open(File.join(connection.chroot, body_path))
      else
        @body = StringIO.new(body)
      end
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
      @env['SERVER_PORT'] ||= '80'
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
