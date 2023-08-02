require "oauth"
require "json"
require "net/http"

module X
  # Main client that handles HTTP authentication and requests
  class Client
    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze

    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
                   base_url: DEFAULT_BASE_URL)
      @base_url = base_url
      @use_bearer_token = !bearer_token.nil?

      if @use_bearer_token
        initialize_bearer_token(bearer_token)
      else
        initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      end
    end

    def get(endpoint)
      response = send_request(:get, endpoint)
      handle_response(response)
    end

    def post(endpoint, body = nil)
      response = send_request(:post, endpoint, body)
      handle_response(response)
    end

    def put(endpoint, body = nil)
      response = send_request(:put, endpoint, body)
      handle_response(response)
    end

    def delete(endpoint)
      response = send_request(:delete, endpoint)
      handle_response(response)
    end

    private

    def initialize_bearer_token(bearer_token)
      @bearer_token = bearer_token
    end

    def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      unless api_key && api_key_secret && access_token && access_token_secret
        raise ArgumentError, "Missing OAuth credentials."
      end

      @consumer = OAuth::Consumer.new(api_key, api_key_secret, site: @base_url)
      @access_token = OAuth::Token.new(access_token, access_token_secret)
    end

    def send_request(http_method, endpoint, body = nil)
      url = URI.parse(@base_url + endpoint)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = create_request(http_method, url, body)
      add_authorization(request)

      http.request(request)
    end

    def create_request(http_method, url, body)
      http_method_class = HTTP_METHODS[http_method]

      raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

      request = http_method_class.new(url)
      request.body = body if body && http_method != :get
      request
    end

    def add_authorization(request)
      if @use_bearer_token
        request["Authorization"] = "Bearer #{@bearer_token}"
      else
        @consumer.sign!(request, @access_token)
      end
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPUnauthorized
        raise X::AuthenticationError, "Authentication failed. Please check your credentials."
      when Net::HTTPServerError
        raise X::ServerError, "An internal server error occurred."
      else
        raise X::Error, "Unexpected response: #{response.code} #{response.message}"
      end
    end
  end
end
