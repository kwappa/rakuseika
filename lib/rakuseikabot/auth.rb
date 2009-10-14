# -*- coding: utf-8 -*-
module RakuseikaBot
  class Auth
    # アクセストークンを取得
    def self.get_acceess_token
      consumer = OAuth::Consumer.new(
                                     RakuseikaBot::Tokens::CONSUMER_KEY,
                                     RakuseikaBot::Tokens::CONSUMER_SECRET,
                                     :site => 'http://twitter.com'
                                     )

      OAuth::AccessToken.new(
                             consumer,
                             RakuseikaBot::Tokens::ACCESS_TOKEN,
                             RakuseikaBot::Tokens::ACCESS_TOKEN_SECRET
                             )
    end

    # Rubytterインスタンスを取得
    def self.get_oauth_rubytter
      OAuthRubytter.new(get_acceess_token)
    end

  end
end
