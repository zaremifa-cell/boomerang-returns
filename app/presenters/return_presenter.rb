module ReturnPresenter
  module_function

  def summary(request)
    {
      id: request.public_id,
      order_number: request.order.number,
      email: request.order.email,
      status: request.status,
      carrier: request.carrier,
      tracking_number: request.tracking_number,
      label_url: request.label_url,
      label_attempts: request.label_attempts,
      last_error: request.last_error,
      refund_cents: request.refund_cents,
      created_at: request.created_at
    }
  end

  def detail(request)
    summary(request).merge(
      items: request.return_items.includes(:order_item).map do |ri|
        { name: ri.order_item.name, sku: ri.order_item.sku, quantity: ri.quantity, reason: ri.reason }
      end,
      events: request.tracking_events.map do |e|
        { id: e.external_id, status: e.status, occurred_at: e.occurred_at }
      end
    )
  end

  def order(order, policy)
    {
      number: order.number,
      retailer: order.retailer.name,
      delivered_at: order.delivered_at,
      return_window_days: order.retailer.return_window_days,
      order_errors: policy.order_errors,
      carriers: ReturnRequest::CARRIERS,
      reasons: ReturnItem::REASONS,
      items: policy.item_states.map do |s|
        item = s[:item]
        { id: item.id, sku: item.sku, name: item.name, price_cents: item.price_cents, quantity: item.quantity,
          returnable_quantity: s[:returnable_quantity], blocked_reason: s[:blocked_reason] }
      end,
      returns: order.return_requests.order(created_at: :desc).map { |r| summary(r) }
    }
  end
end
