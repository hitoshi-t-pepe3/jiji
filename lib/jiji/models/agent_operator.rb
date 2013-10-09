module JIJI
  module Models
	  #===オペレータ
	  #取引を行うためのクラスです。
	  #エージェントのプロパティとして設定されるので、エージェント内では以下のコードで取引を実行できます。
	  #
	  # sell_position = operator.sell(1, :EURJPY) # 売り
	  # buy_position  = operator.buy(1, :EURJPY) # 買い
	  # operator.commit( sell_position ) # 決済
	  #
	  class AgentOperator
		def initialize( operator, agent_name ) #:nodoc:
		  @operator = operator
		  @agent_name = agent_name
		  @positions = {}.taint
		end

		#====購入します。
		#count:: 購入する数量
		#pair:: 通貨ペアコード 例) :EURJPY
		#return:: ポジション(JIJI::Position)
		def buy(count, pair=:EURJPY)
		  p = @operator.buy( count, pair, @agent_name )
		  @positions[p.position_id] = p
		  return p
		end

		#====売却します。
		#count:: 売却する数量
		#pair:: 通貨ペアコード 例) :EURJPY
		#return:: ポジション(JIJI::Position)
		def sell(count, pair=:EURJPY)
		  p = @operator.sell( count, pair, @agent_name )
		  @positions[p.position_id] = p
		  return p
		end

		#===取引を確定します。
		#position:: ホジション(JIJI::Position)
		def commit(position)
		  @operator.commit(position)
		  @positions.delete position.position_id
		end

		#建て玉
		attr_reader :positions
		attr :agent_name, true
	  end
  end
end