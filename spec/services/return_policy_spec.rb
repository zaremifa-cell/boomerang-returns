require "rails_helper"

RSpec.describe ReturnPolicy do
  it "accepts a delivered order inside the window" do
    order = build_order
    expect(described_class.new(order).validate([line(order.order_items.first)])).to be_empty
  end

  it "rejects an order outside the return window" do
    order = build_order(delivered_at: 31.days.ago)
    expect(described_class.new(order).order_errors).to include("The 30-day return window has closed.")
  end

  it "rejects an order that has not been delivered" do
    expect(described_class.new(build_order(delivered_at: nil)).order_errors)
      .to include("This order has not been delivered yet.")
  end

  it "rejects countries the retailer does not accept returns from" do
    expect(described_class.new(build_order(country: "US")).order_errors).to include(/not available from US/)
  end

  it "blocks final sale items" do
    order = build_order(items: [{ final_sale: true }])
    expect(described_class.new(order).validate([line(order.order_items.first)])).to include(/Final sale/)
  end

  it "counts units already claimed by earlier returns" do
    order = build_order(items: [{ quantity: 2 }])
    item = order.order_items.first
    CreateReturn.call(order: order, lines: [line(item)], carrier: "dhl", idempotency_key: "a")

    policy = described_class.new(order.reload)
    expect(policy.item_states.first[:returnable_quantity]).to eq(1)
    expect(policy.validate([line(item, quantity: 2)])).to include(/up to 1/)
  end

  it "frees units again when a return's label failed for good" do
    order = build_order(items: [{ quantity: 1 }])
    result = CreateReturn.call(order: order, lines: [line(order.order_items.first)], carrier: "dhl", idempotency_key: "a")
    result.return_request.update!(status: "label_failed")

    expect(described_class.new(order.reload).item_states.first[:returnable_quantity]).to eq(1)
  end

  it "requires a known reason" do
    order = build_order
    expect(described_class.new(order).validate([line(order.order_items.first, reason: "meh")])).to include(/reason/)
  end
end
