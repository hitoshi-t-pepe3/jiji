module JIJI
#==リアル取引用オペレーター
  class RmtOperator < Operator #:nodoc:

	#===コンストラクタ
	#client:: クライアント
	#logger:: ロガー
	#money:: 保証金
	def initialize( client, logger, trade_result_dao, trade_enable=true, money=nil )
	  super(trade_result_dao,money)
	  @client = client
	  @logger = logger
	  @trade_enable = trade_enable
	end

	#===購入する
	#count:: 購入する数量
	#return:: Position
	def buy(count, pair=:EURJPY, trader="", options = {})
	  id = nil
	  if @trade_enable
		JIJI::Util.log_if_error_and_throw( @logger ) {
		  rate = @rate[pair]
		  # 成り行きで買い
		  id = @client.order( pair, :buy, count, options).position_id
		}
	  end
	  p = super(count, pair, trader)
	  p.raw_position_id = id if id
	  p
	end

	#===売却する
	#count:: 売却する数量
	#return:: Position
	def sell(count, pair=:EURJPY, trader="", options = {})
	  id = nil
	  if @trade_enable
		JIJI::Util.log_if_error_and_throw( @logger ) {
		  rate = @rate[pair]
		  # 成り行きで売り
		  id = @client.order( pair, :sell, count, options).position_id
		}
	  end
	  p = super(count, pair, trader)
	  p.raw_position_id = id if id
	  p
	end

	# 取引を確定する
	def commit(position)
	  if @trade_enable && position.raw_position_id
		JIJI::Util.log_if_error_and_throw( @logger ) {
		  @client.commit( position.raw_position_id, position.count )
		}
	  end
	  super(position)
	end
	
	def trade_enable=(value)
	  @trade_enable = value && conf.get([:system,:trade_enable], true)
	end
	def trade_enable
	  return @trade_enable
	end
  end
end