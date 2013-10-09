# -*- encoding:utf-8 -*-
module JIJI
  module Models
      #==ポジション
      class Position

        #売り/買い区分:売り
        SELL = 0
        #売り/買い区分:買い
        BUY  = 1

        #状態:注文中
        STATE_WAITING = 0
        #状態:新規
        STATE_START = 1
        #状態:決済注文中
        STATE_FIX_WAITING = 2
        #状態:決済済み
        STATE_FIXED = 3
        #状態:約定前にシステムが再起動された
        STATE_LOST = 4

        #===コンストラクタ
        #
        #sell_or_buy:: 売りor買い
        #count:: 数量
        #unit:: 取引単位
        #date:: 取引日時
        #rate:: レート
        #pair:: 通貨ペア
        #trader:: 取引実行者
        #operator:: operator
        #open_interest_no:: 建玉番号
        #order_no:: 注文番号
        def initialize( position_id, sell_or_buy, count, unit, date, rate, pair,
          trader, operator, open_interest_no="", order_no="" ) #:nodoc:
          @position_id = position_id
          @sell_or_buy = sell_or_buy
          @count = count
          @unit = unit
          @price = (count*unit*rate).to_i
          @date = date
          @profit_or_loss = 0
          @state =STATE_START
          @rate = rate
          @pair = pair
          @trader = trader

          @open_interest_no = open_interest_no
          @order_no = order_no

          @operator = operator
          @info = {}
          @swap = 0
          
          #@swap_time = Time.local( date.year, \
          #  date.month, date.day, operator.conf.get([:swap_time], 5 ))
          @swap_time = Time.local( date.year, date.month, date.day, 5)
          @swap_time += 60*60*24 if date > @swap_time
        end

        def _commit #:nodoc:
          raise "illegal state" if @state != STATE_START
          @state = STATE_FIXED
          @fix_date = @current_date
          @fix_rate = @current_rate
        end

        def lost #:nodoc:
          @state = STATE_LOST
        end

        #===現在価格を更新
        def next(rates) #:nodoc:
          return if @state == STATE_FIXED
          rate = rates[@pair]
          @current_rate = @sell_or_buy == BUY ? rate.bid : rate.ask
          @current_price = (@count * @unit * @current_rate).to_i

          # swap
          if @swap_time <= rates.time
            @swap += @sell_or_buy == BUY ? rate.buy_swap : rate.sell_swap
            @swap_time += 60*60*24
          end

          @profit_or_loss = @sell_or_buy == BUY \
              ? @current_price - @price + @swap\
              : @price - @current_price + @swap

          @current_date = rates.time
        end
        
        def [](key) #:nodoc:
          @info[key]
        end
        def []=(key, value) #:nodoc:
          @info[key] = value
        end

        def values #:nodoc:
          {
            :position_id => position_id,
            :raw_position_id => raw_position_id,
            :sell_or_buy =>  sell_or_buy == JIJI::Position::SELL ? :sell : :buy,
            :state => state,
            :date => date.to_i,
            :fix_date => fix_date.to_i,
            :count => count ,
            :price => price,
            :profit_or_loss => profit_or_loss.to_i,
            :rate => rate,
            :fix_rate => fix_rate,
            :swap=> swap,
            :pair => pair,
            :trader => trader
          }
        end

        # クライアント 
        attr :operator #:nodoc:

        # 一意な識別子
        attr_reader :position_id
        # プラグインが返す識別子
        attr :raw_position_id, true

        # 売りか買いか?
        attr_reader :sell_or_buy
        # 状態
        attr_reader :state

        # 購入日時
        attr_reader :date
        # 決済日時
        attr_reader :fix_date
        # 取引数量
        attr_reader :count
        # 取得金額
        attr_reader :price
        # 現在価値
        attr_reader :current_price
        # 現在の損益
        attr_reader :profit_or_loss
        # 購入時のレート
        attr_reader :rate
        # 決済時のレート
        attr_reader :fix_rate
        # 決済時のレート
        attr_reader :swap
        # 通貨ペア
        attr_reader :pair
        # 取引を行ったエージェント名
        attr_reader :trader
        # 注文番号
        attr_reader :order_no
      end
  end
end