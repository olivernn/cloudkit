module CloudKit
  class Request < Rack::Request
    include CloudKit::Util
    alias_method :cloudkit_params, :params

    def initialize(env)
      super(env)
    end

    def params
      @cloudkit_params ||= cloudkit_params.merge(oauth_header_params)
    end

    def doc_id
      result = path_element(2)
      return nil if result == 'meta'
      result
    end

    def match?(method, path, required_params=[])
      (request_method == method) &&
        path_info.match(path.gsub(':id', '*')) && # just enough to work for now
        param_match?(required_params)
    end

    def param_match?(required_params)
      required_params.all? do |required_param|
        case required_param
        when Hash
          key = required_param.keys.first
          return false unless params.has_key? key
          return false unless params[key] == required_param[key]
        when String
          return false unless params.has_key? required_param
        else
          false
        end
        true
      end
    end

    def oauth_header_params
      %w( X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION ).each do |header|
        next unless @env.include?(header)
        header = @env[header]
        next unless header[0,6] == 'OAuth '
        oauth_param_string = header[6,header.length].split(/[,=]/)
        oauth_param_string.map!{|v| unescape(v.strip)}
        oauth_param_string.map!{|v| v =~ /^\".*\"$/ ? v[1..-2] : v}
        oauth_params = Hash[*oauth_param_string.flatten]
        oauth_params.reject!{|k,v| k !~ /^oauth_/}
        return oauth_params
      end
      return {}
    end

    def unescape(value)
      URI.unescape(value.gsub('+', '%2B'))
    end

    def last_path_element
      path_element(-1)
    end

    def path_element(index)
      path_info.split('/')[index] rescue nil
    end

    def via
      @env[via_key].split(', ') rescue []
    end

    def if_match
      parse_header('HTTP_IF_MATCH')
    end

    def if_none_match
      parse_header('HTTP_IF_NONE_MATCH')
    end

    def parse_header(name)
      return nil unless @env[name]
      list = @env[name].split(',')
      list.map!{|i| i.strip}
      list.map!{|i| i =~ /^\".*\"$/ ? i[1..-2] : i}
    end

    def inject_via(key)
      items = via << key
      @env[via_key] = items.join(', ')
    end

    def current_user
      return nil unless @env[auth_key] && @env[auth_key] != ''
      @env[auth_key]
    end

    def current_user=(user)
      @env[auth_key] = user
    end

    def using_auth?
      @env[auth_presence_key] != nil
    end

    def history_path?
      last_path_element == 'history'
    end

    def etags_path?
      last_path_element == 'etags'
    end

    def meta_path?
      last_path_element == 'meta'
    end

    def announce_auth(via)
      inject_via(via)
      @env[auth_presence_key] = 1
    end

    def session
      @env['rack.session']
    end

    def login_url
      @env[login_url_key] || '/login'
    end

    def login_url=(url)
      @env[login_url_key] = url
    end

    def logout_url
      @env[logout_url_key] || '/logout'
    end

    def logout_url=(url)
      @env[logout_url_key] = url
    end

    def flash
      session[flash_key] ||= CloudKit::FlashSession.new
    end
  end
end