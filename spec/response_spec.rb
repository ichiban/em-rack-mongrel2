# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongrel2::Response do
  before(:each) do
    @req = double()
    @resp = double()
    @response = Mongrel2::Response.new(@resp)
  end

  it 'should build the HTTP request format' do
    @req.should_receive(:uuid) { 'UUID' }
    @req.should_receive(:conn_id) { 'CONN_ID' }

    httpreq = "UUID 7:CONN_ID, HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nBoo!"
    @resp.should_receive(:send_msg).with(httpreq)

    @response.send_http(@req, 'Boo!', 200, {})
  end

  it 'should send a blank response to close the response' do
    @req.should_receive(:uuid) { 'UUID' }
    @req.should_receive(:conn_id) { 'CONN_ID' }

    httpreq = 'UUID 7:CONN_ID, '
    @resp.should_receive(:send_msg).with(httpreq)

    @response.close(@req)
  end

  it 'should count bytesize of body as Content-Length' do
    def @response.send_resp(uuid, conn_id, data)
      # do nothing
    end
    @req.stub(:uuid).and_return(nil)
    @req.stub(:conn_id).and_return(nil)
    headers = {}
    @response.send_http @req, 'abc', 200, headers
    headers['Content-Length'].should eql('abc'.bytesize.to_s)
    @response.send_http @req, 'あいう', 200, headers
    headers['Content-Length'].should eql('あいう'.bytesize.to_s)
  end
end
