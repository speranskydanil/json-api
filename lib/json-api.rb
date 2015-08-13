require 'net/http'
require 'json'
require 'pp'

module JsonApi
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def method_missing(name, *args)
      if [:get, :post, :delete, :put].include? name
        request(name, *args)
      else
        super
      end
    end

    def request(method, path, params = {})
      path = full_path(path)

      params = merged_params(params)

      query_params, form_params = (method == :get ? [params, {}] : [{}, params])

      uri = uri(path, query_params)

      req = req(method, uri, form_params)
      configure_request(req)

      res = http(uri).request(req)
      req.content_type = 'application/x-www-form-urlencoded; charset=UTF-8'
      configure_response(res)

      log(method, path, params, res)

      res
    end

    def full_path(path)
      (path.include?('//') or @base_path.nil?) ? path : "#{@base_path}/#{path}"
    end

    def merged_params(params)
      @default_params.nil? ? params : @default_params.merge(params)
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
      res.instance_variable_set(:@json_api, self)

      def res.ok?
        code == '200'
      end

      def res.hash
        @hash ||= JSON.parse(body) rescue {}
      end

      def res.json
        @json ||= JSON.pretty_generate(hash)
      end

      def res.error
        @json_api.error(self)
      end
    end

    def configure_request(req)
    end

    def log(method, path, params, res)
      return unless @logger

      @logger.call <<-heredoc
[JsonApi#request begin]
# Request
Method - #{method}
Path   - #{path}
Params -
#{params.pretty_inspect.strip}
# Response
Code - #{res.code}
Body -
#{res.json}
[JsonApi#request end]
      heredoc
    end

    def error(res)
      res.message
    end
  end

  module ClassMethods
    def routes(routes)
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

    def method_missing(name, *args)
      if instance_methods.include? name
        new.send(name, *args)
      else
        super
      end
    end
  end

  def self.method_missing(name, *args)
    if [:get, :post, :delete, :put].include? name
      api = Class.new.send(:include, self)
      api.new.send(name, *args)
    else
      super
    end
  end
end

