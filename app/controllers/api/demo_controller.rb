module Api
  # Lets the demo UI play the carrier: sends a signed webhook through the real endpoint logic.
  class DemoController < ApplicationController
    NEXT_EVENT = { "label_created" => "picked_up", "in_transit" => "delivered" }.freeze
    DEMO_PREFIX = "NW-D"
    DEMO_ITEMS = [
      ["JKT-RAIN-M", "Rain jacket, M", 8900, 1, false],
      ["TEE-WHT-L", "Organic tee, white, L", 2500, 3, false],
      ["SCK-WOOL", "Wool socks (sale)", 900, 2, true]
    ].freeze

    # Every visitor gets their own fresh order, so one person's returns never use up the demo
    # for the next. Generated orders older than a day are removed on the way.
    def order
      retailer = Retailer.find_by!(slug: "northwind")
      retailer.orders.where("number LIKE ?", "#{DEMO_PREFIX}%").where(created_at: ...1.day.ago).destroy_all

      order = retailer.orders.create!(
        number: "#{DEMO_PREFIX}#{SecureRandom.alphanumeric(5).upcase}",
        email: "you+#{SecureRandom.hex(3)}@example.com",
        country: "BG",
        delivered_at: 4.days.ago
      )
      DEMO_ITEMS.each do |sku, name, price, quantity, final_sale|
        order.order_items.create!(sku: sku, name: name, price_cents: price, quantity: quantity, final_sale: final_sale)
      end
      render json: { order_number: order.number, email: order.email }, status: :created
    end

    def scan
      request = ReturnRequest.find_by!(public_id: params[:id])
      event = NEXT_EVENT[request.status]
      return render(json: { errors: ["Nothing to scan in status #{request.status}."] }, status: :conflict) unless event

      result = CarrierWebhook.process(
        event_id: "evt_#{SecureRandom.hex(6)}", tracking_number: request.tracking_number,
        status: event, occurred_at: Time.current.iso8601
      )
      render json: { outcome: result.outcome, return: ReturnPresenter.detail(request.reload) }
    end
  end
end
