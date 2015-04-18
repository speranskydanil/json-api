require 'net/http'
require 'json'
require 'pp'

class JsonApi
  def initialize(base_path = nil, log = false)
    @base_path = base_path
    @log = log
  end

  def method_missing(name, *args)
    if [:get, :post, :delete, :put].include? name
      request(name, *args)
    else
      super
    end
  end

  def request(method, path, params = {})
    path = "#{@base_path}/#{path}" unless path.include? '//'

    query_params, form_params = (method == :get ? [params, {}] : [{}, params])

    uri = uri(path, query_params)

    req = req(method, uri, form_params)
    configure_request(req)

    res = http(uri).request(req)
    configure_response(res)

    log(method, path, params, res) if @log

    res
  end

  def uri(path, params)
    uri = URI.parse(path)
    uri.query = URI.encode_www_form(params)
    uri
  end

  def req(method, uri, params)
    req = Net::HTTP.const_get(method.capitalize).new(uri.to_s)
    req.form_data = params
    req
  end

  def http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http
  end

  def configure_response(res)
    res.body = JSON.parse(res.body) rescue {}

    res.instance_variable_set(:@json_api, self)

    def res.ok?
      code == '200'
    end

    def res.error
      @json_api.error(self)
    end
  end

  def log(method, path, params, res)
    puts <<-heredoc
[JsonApi#request begin]
# Request
Method - #{method}
Path   - #{path}
Params -
#{params.pretty_inspect.strip}
# Response
Code - #{res.code}
Body -
#{res.body.pretty_inspect.strip}
[JsonApi#request end]
    heredoc
  end

  def configure_request(req)
  end

  def error(res)
    res.message
  end

  def self.routes(routes)
    routes.each do |name, path|
      define_method("#{name}_path") do |*args|
        case path
        when String
          path
        when Symbol
          send("#{path}_path", *args)
        when Proc
          path.call(*args)
        end
      end
    end
  end
end

