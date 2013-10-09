# -*- encoding:utf-8 -*-
module JIJI
  module Modles
    #===注文
	class Order
		attr :order_no
		attr :trade_type
		attr :order_type
		attr :execution_expression
		attr :sell_or_buy
		attr :pair
		attr :count
		attr :rate
		attr :trail_range
		attr :order_state
	end
   end
 end