# -*- coding: utf-8 -*-
require 'oauth'
require 'rubytter'
require 'json'
require 'time'
require 'pp'

require 'rakuseikabot/auth'
require 'rakuseikabot/tokens'

module RakuseikaBot
  class Main
    TWEET_SOURCE   = 'data/source.txt'
    SETTING_FILE   = 'data/setting.json'
    REPLY_STATUSES = 'data/replies.json'
    REPLY_AT_ONCE  = 10         # 一度に処理するリプライ数

    # コンストラクタ
    def initialize
      $KCODE = 'utf8'

      # rubytterの準備
      @rubytter= RakuseikaBot::Auth.get_oauth_rubytter

      # APIの利用残を取得
#       rate_limit_status = @rubytter.limit_status
#       puts rate_limit_status
#       exit

      # 金言の読み込み
      eval(File.open(TWEET_SOURCE).read)

      # セッティングの読み込み
      if File.exists? SETTING_FILE
        @settings = JSON::parse(File.open(SETTING_FILE).read)
      else
        @settings = {}
      end

      # メイン処理
      main

      # 設定を保存して終了
      save_settings
    end

    # メイン - 状況判断して各メソッドを呼び出し
    def main
      # 未リプライのmentionsを取得
      last_mentions = get_last_mentions
      if last_mentions.length > 0
        # 存在するなら書き出し
        save_replies get_last_mentions
      end

      # リプライしてない書き込みがあれば処理
      if replies_left = load_replies and replies_left.length > 0
        # 配列に変換
        replies = replies_left.to_a

        # いくつかずつ処理
        REPLY_AT_ONCE.times do |t|

          # 末尾から切り出して返事をする
          reply = replies.pop
          next unless reply
          reply_wise_saying reply
          @settings['last_replied_id'] = reply.id
        end

        # 処理しなかったリプライを書き戻す
        save_replies Rubytter::json_to_struct(replies)
      end

      # 何もすることがなければ金言をつぶやく
      tweet_wise_saying

    end

    # 設定を保存
    def save_settings
      File.open(SETTING_FILE, 'w') { |w|
        w.puts @settings.to_json
      }
    end

    # mentionをローカルに保存
    def save_replies timeline
      File.open(REPLY_STATUSES, 'w') { |w|
        w.write timeline.to_json
      }
    end

    # mentionをローカルから読み込み
    def load_replies
      return nil unless File.exists? REPLY_STATUSES
      Rubytter::json_to_struct(JSON::parse(File.open(REPLY_STATUSES).read))
    end

    # 金言をつぶやく
    def tweet_wise_saying
      # 次につぶやく時間を越えてなければ終了
      if @settings['wise_next_time'] and Time.parse(@settings['wise_next_time']) > Time.now
        return
      end

      gaps = [11, 23, 37, 61, 89]
      index = @settings['wise_index'] ||= 0
      gap   = @settings['wise_gap']   ||= gaps[rand(gaps.length)]

      # つぶやく
      update sprintf('[%3d] %s', index + 1, @tweet_source[index][0])

      # 一周したらgapをクリア
      index = (index + gap) % 100
      @settings['wise_gap']   = nil   if index == 0
      @settings['wise_index'] = index

      # 次のつぶやき時間を決める (120分 +- 15分)
      @settings['wise_next_time'] = Time.now + (rand(30) + 105) * 60
    end

    # 金言をつぶやき返す
    def reply_wise_saying status
      if /([0-9]{1,3})/ =~ status.text
        index = $1.to_i
        if index < 1 || index > @tweet_source.length
          index = nil
        end
      end

      if index
        reply sprintf('[Point! %3d] %s', index, @tweet_source[index - 1][1]), status.user.screen_name, status.id
      else
        index = rand(@tweet_source.length) + 1
        reply sprintf('[%3d] %s', index, @tweet_source[index - 1][0]), status.user.screen_name, status.id
      end
    end

    # 未リプライのmentionsを取得
    def get_last_mentions
      if @settings['last_replied_id']
        @rubytter.mentions :count => 200, :since_id => @settings['last_replied_id']
      else
        @rubytter.mentions :count => 200
      end
    end

    # フッタをつけてupdate
    def update text
      @rubytter.update text + ' [http://bit.ly/rakuseika]'
    end

    # フッタをつけてリプライ
    def reply text, user_name, status_id
      @rubytter.update "@#{user_name} #{text} [http://bit.ly/rakuseika]", :in_reply_to_status_id => status_id
    end
  end

  # エントリポイント
  bot = Main.new
end
