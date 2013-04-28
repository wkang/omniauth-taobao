# lots of stuff taken from https://github.com/intridea/omniauth/blob/0-3-stable/oa-oauth/lib/omniauth/strategies/oauth2/taobao.rb
require 'omniauth-oauth2'
module OmniAuth
  module Strategies
    class Taobao < OmniAuth::Strategies::OAuth2

      class TaobaoAuthorizationError < StandardError; end

      option :client_options, {
        :site => "https://oauth.taobao.com",
        :authorize_url => '/authorize',
        :token_url => '/token',
        :top_url =>"http://gw.api.taobao.com/router/rest"
      }
      
      option :fields, 'user_id,uid,nick,sex,buyer_credit,seller_credit,location,created,last_visit,birthday,type,status,alipay_bind,avatar,email,consumer_protection'

      def request_phase
        options[:state] ||= '1'
        super
      end

      uid { raw_info['uid'] }

      info do
        {
          'uid' => raw_info['uid'],
          'nickname' => raw_info['nick'],
          'email' => raw_info['email'],
          'user_info' => raw_info,
          'extra' => {
            'user_hash' => raw_info,
          },
        }
      end

      def raw_info
        query_param = {
          :app_key => options.client_id,

          # TODO to be moved in options
          # TODO add more default fields (http://my.open.taobao.com/apidoc/index.htm#categoryId:1-dataStructId:3)
          :fields => options.fields,
          :format => 'json',
          :method => 'taobao.user.get',
          :session => @access_token.token,
          :sign_method => 'md5',
          :timestamp   => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          :v => '2.0'
        }

        query_param = generate_sign(query_param)
        res = Net::HTTP.post_form(URI.parse(options.client_options.top_url), query_param)
        body = MultiJson.decode(res.body)
        raise TaobaoAuthorizationError, body["error_response"] if body["error_response"]
        @raw_info ||= body['user_get_response']['user']
      rescue ::Errno::ETIMEDOUT
        raise ::Timeout::Error
      end
      
      def generate_sign(params)
        # params.sort.collect { |k, v| "#{k}#{v}" }
        str = options.client_secret + params.sort {|a,b| "#{a[0]}"<=>"#{b[0]}"}.flatten.join + options.client_secret
        params['sign'] = Digest::MD5.hexdigest(str).upcase!
        params
      end
    end
  end
end
