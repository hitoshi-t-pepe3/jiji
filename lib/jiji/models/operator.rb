module JIJI

  #==オペレーター
  class Operator #:nodoc:

	#===コンストラクタ
	#*money*:: 保証金
	def initialize( trade_result_dao=nil, money=nil )
	  @rate = nil
	  @money = money
	  @profit_or_loss = 0
	  @fixed_profit_or_loss = 0
	  @positions = {}
	  @draw = 0
	  @lose = 0
	  @win = 0.0
	  @trade_result_dao = trade_result_dao
	end

	#===レートを更新する。
	def next_rates( rate )
	  @rate = rate
	  result = @positions.inject({:total=>0.0,:profit=>0}) {|r,e|
		p = e[1]
		p.next(rate)
		r[:total] += p.price if p.state == Position::STATE_START
		r[:profit] += p.profit_or_loss
		r
	  }
	  @profit_or_loss = result[:profit] + @fixed_profit_or_loss
	  if @money && (( @money + result[:profit] ) / result[:total]) <= 0.007
		raise "loss cut"
	  end
	  @trade_result_dao.next( self, rate.time ) if @trade_result_dao
	end

	#===購入する
	#count:: 購入する数量
	#pair:: 通貨ペア(:EURJPYなど)
	#trader:: 取引実行者識別用の名前
	#return:: Position
	def buy(count, pair=:EURJPY, trader="")
	  rate = @rate[pair]
	  unit = @rate.pair_infos[pair].trade_unit
	  p = Position.new( UUIDTools::UUID.random_create().to_s, Position::BUY, count,
		unit, @rate.time, rate.ask, pair, trader, self )
	  p.next( @rate )
	  @profit_or_loss += p.profit_or_loss
	  @positions[p.position_id] = p
	  @trade_result_dao.save( p ) if @trade_result_dao
	  return p
	end

	#===売却する
	#count:: 売却する数量
	#pair:: 通貨ペア(:EURJPYなど)
	#trader:: 取引実行者識別用の名前
	#return:: Position
	def sell(count, pair=:EURJPY, trader="")
	  rate = @rate[pair]
	  unit = @rate.pair_infos[pair].trade_unit
	  p = Position.new( UUIDTools::UUID.random_create().to_s, Position::SELL, count,
		unit, @rate.time, rate.bid, pair, trader, self )
	  p.next( @rate )
	  @profit_or_loss += p.profit_or_loss
	  @positions[p.position_id] = p
	  @trade_result_dao.save( p ) if @trade_result_dao
	  return p
	end

	# 取引を確定する
	def commit(position)
	  position._commit
	  @trade_result_dao.save( position ) if @trade_result_dao
	  @positions.delete position.position_id

	  @fixed_profit_or_loss += position.profit_or_loss
	  if position.profit_or_loss == 0
		@draw+=1
	  elsif position.profit_or_loss < 0
		@lose+=1
	  else
		@win+=1
	  end
	end

	# 勝率
	def win_rate
	  win > 0 ? win / (win+lose+draw) : 0.0
	end

	# 未約定のポジションデータを"ロスト"としてマークする。
	def stop
	  @positions.each_pair {|k, v|
		v.lost
		@trade_result_dao.save( v ) if @trade_result_dao
	  }
	end

	# すべてのポジションデータを保存する。
	def flush
	  @positions.each_pair {|k, v|
		@trade_result_dao.save( v ) if @trade_result_dao
	  }
	end

	#現在の損益
	attr_reader :profit_or_loss
	#現在の確定済み損益
	attr_reader :fixed_profit_or_loss
	#建て玉
	attr :positions

	# 勝ち数
	attr_reader :win
	# 負け数
	attr_reader :lose
	# 引き分け
	attr_reader :draw

	attr :conf, true
  end
end