# Decides what a customer may return from an order, and why not when they can't.
# Every "no" carries a reason the customer portal can show as-is.
class ReturnPolicy
  def initialize(order, now: Time.current)
    @order = order
    @retailer = order.retailer
    @now = now
  end

  # Problems that block the whole order.
  def order_errors
    errors = []
    errors << "This order has not been delivered yet." if @order.delivered_at.nil?
    errors << "The #{@retailer.return_window_days}-day return window has closed." if window_closed?
    errors << "Returns are not available from #{@order.country}." unless @retailer.ships_to?(@order.country)
    errors
  end

  # Per item: how many units can still be returned, or why none can.
  def item_states
    returned = @order.returned_quantities
    @order.order_items.order(:id).map do |item|
      remaining = item.quantity - returned.fetch(item.id, 0)
      blocked = if item.final_sale then "Final sale items can't be returned."
                elsif remaining <= 0 then "Already returned."
                end
      { item: item, returnable_quantity: blocked ? 0 : remaining, blocked_reason: blocked }
    end
  end

  # lines: [{ order_item_id:, quantity:, reason: }]
  def validate(lines)
    errors = order_errors.dup
    errors << "Choose at least one item to return." if lines.blank?
    states = item_states.index_by { |s| s[:item].id }

    Array(lines).each do |line|
      state = states[line[:order_item_id].to_i]
      quantity = line[:quantity].to_i
      if state.nil?
        errors << "Item #{line[:order_item_id]} is not part of this order."
      elsif state[:blocked_reason]
        errors << "#{state[:item].name}: #{state[:blocked_reason]}"
      elsif quantity < 1 || quantity > state[:returnable_quantity]
        errors << "#{state[:item].name}: you can return up to #{state[:returnable_quantity]}."
      elsif !ReturnItem::REASONS.include?(line[:reason])
        errors << "#{state[:item].name}: choose a return reason."
      end
    end
    errors
  end

  private

  def window_closed?
    @order.delivered_at.present? && @order.delivered_at < @retailer.return_window_days.days.ago(@now)
  end
end
