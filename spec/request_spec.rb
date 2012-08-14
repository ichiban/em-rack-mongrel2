require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongrel2::Request do
  it "should parse a Mongrel2 message" do
    message = "UUID CON PATH 253:{\"PATH\":\"/\",\"user-agent\":\"curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3\",\"host\":\"localhost:6767\",\"accept\":\"*/*\",\"connection\":\"close\",\"x-forwarded-for\":\"::1\",\"METHOD\":\"GET\",\"VERSION\":\"HTTP/1.1\",\"URI\":\"/\",\"PATTERN\":\"/\"},0:,"
    connection = double('connection')
    uuid = 'UUID'
    conn_id = 'CON'
    path = 'PATH'
    headers = {
      'PATH' => '/',
      'user-agent' => 'curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3',
      'host' => 'localhost:6767',
      'accept' => '*/*',
      'connection' => 'close',
      'x-forwarded-for' => '::1',
      'METHOD' => 'GET',
      'VERSION' => 'HTTP/1.1',
      'URI' => '/',
      'PATTERN' => '/'
    }
    body = ''
    request = double('request')
    Mongrel2::Request.should_receive(:new).with(uuid, conn_id, path, headers, body, connection).and_return(request)
    r = Mongrel2::Request.parse(message, connection)
    r.should eql(request)
  end

  it "should have all parts populated" do
    headers = {
      "PATH" => "/",
      "user-agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
      "host" => "localhost:6767",
      "accept" => "*/*",
      "connection" => "close",
      "x-forwarded-for" => "::1",
      "METHOD" => "GET",
      "VERSION" => "HTTP/1.1",
      "URI" => "/",
      "PATTERN" => "/"
    }
    r = Mongrel2::Request.new('UUID', 'CON', 'PATH', headers, '', double())
    r.should_not be_nil
    r.uuid.should eql('UUID')
    r.conn_id.should eql('CON')
    r.path.should eql('PATH')
    r.body.length.should == 0
    r.headers.length.should == 10
    r.headers['PATH'].should eql('/')
    r.headers['user-agent'].should eql('curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3')
    r.headers['host'].should eql('localhost:6767')
    r.headers['accept'].should eql('*/*')
    r.headers['x-forwarded-for'].should eql('::1')
    r.headers['METHOD'].should eql('GET')
    r.headers['VERSION'].should eql('HTTP/1.1')
    r.headers['URI'].should eql('/')
    r.headers['PATTERN'].should eql('/')
    r.close?.should be_true
  end

  it "should return rack env with async callbacks" do
    response = double("response")
    uuid = double('uuid')
    conn_id = double('conn_id')
    path = double('path')
    headers = {
      "PATH" => "/",
      "user-agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
      "host" => "localhost:6767",
      "accept" => "*/*",
      "connection" => "close",
      "x-forwarded-for" => "::1",
      "METHOD" => "GET",
      "VERSION" => "HTTP/1.1",
      "URI" => "/",
      "PATTERN" => "/"
    }
    body = double('body')
    connection = double("connection")
    r = Mongrel2::Request.new(uuid, conn_id, path, headers, body, connection)
    connection.should_receive(:post_process).with(response, r)
    env = r.env
    env['async.callback'].call(response)
    env['async.close'].should_not be_nil
  end

  it "should open an async uploaded file for body" do
    response = double("response")
    uuid = double('uuid')
    conn_id = double('conn_id')
    path = double('path')
    headers = {
      "PATH" => "/",
      "user-agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
      "host" => "localhost:6767",
      "accept" => "*/*",
      "connection" => "close",
      "x-forwarded-for" => "::1",
      "METHOD" => "GET",
      "VERSION" => "HTTP/1.1",
      "URI" => "/",
      "PATTERN" => "/",
      'x-mongrel2-upload-done' => 'tmp/upload.file'
    }
    body = double('body')
    connection = double("connection")
    connection.stub(:chroot).and_return('.')
    io = double('io')
    File.should_receive(:open).with('./tmp/upload.file').and_return(io)
    r = Mongrel2::Request.new(uuid, conn_id, path, headers, body, connection)
    r.body.should eql(io)
  end

  it "should split host header into SERVER_NAME:SERVER_PORT" do
    response = double("response")
    uuid = double('uuid')
    conn_id = double('conn_id')
    path = double('path')
    headers = {
      "PATH" => "/",
      "user-agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
      "host" => "localhost:6767",
      "accept" => "*/*",
      "connection" => "close",
      "x-forwarded-for" => "::1",
      "METHOD" => "GET",
      "VERSION" => "HTTP/1.1",
      "URI" => "/",
      "PATTERN" => "/"
    }
    body = double('body')
    connection = double("connection")
    r = Mongrel2::Request.new(uuid, conn_id, path, headers, body, connection)
    env = r.env
    env['SERVER_NAME'].should eql('localhost')
    env['SERVER_PORT'].should eql('6767')
  end

  it "should assume SERVER_PORT = 80 if not given" do
    response = double("response")
    uuid = double('uuid')
    conn_id = double('conn_id')
    path = double('path')
    headers = {
      "PATH" => "/",
      "user-agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
      "host" => "example.com", # mongrel2 is running on port 80
      "accept" => "*/*",
      "connection" => "close",
      "x-forwarded-for" => "::1",
      "METHOD" => "GET",
      "VERSION" => "HTTP/1.1",
      "URI" => "/",
      "PATTERN" => "/"
    }
    body = double('body')
    connection = double("connection")
    r = Mongrel2::Request.new(uuid, conn_id, path, headers, body, connection)
    env = r.env
    env['SERVER_PORT'].should eql('80')
  end
end
