require "rails_helper"

RSpec.describe "Carrier webhooks" do
  let(:order) { build_order }
  let!(:request_record) do
    r = CreateReturn.call(order: order, lines: [line(order.order_items.first)], carrier: "dhl", idempotency_key: "k").return_request
    r.update!(status: "label_created", tracking_number: "TRK1")
    r
  end

  def deliver(event_id:, status:, signature: nil)
    body = { event_id: event_id, tracking_number: "TRK1", status: status, occurred_at: Time.current.iso8601 }.to_json
    post "/webhooks/carrier", params: body,
                              headers: { "CONTENT_TYPE" => "application/json",
                                         "X-Carrier-Signature" => signature || CarrierWebhook.sign(body) }
    response.parsed_body["outcome"]
  end

  it "moves the return forward" do
    expect(deliver(event_id: "e1", status: "picked_up")).to eq("applied")
    expect(request_record.reload.status).to eq("in_transit")
  end

  it "acknowledges a repeated event without applying it twice" do
    deliver(event_id: "e1", status: "picked_up")
    expect(deliver(event_id: "e1", status: "picked_up")).to eq("duplicate")
    expect(request_record.tracking_events.count).to eq(1)
  end

  it "records a late event but never moves the return backwards" do
    deliver(event_id: "e2", status: "delivered")
    expect(deliver(event_id: "e1", status: "in_transit")).to eq("stale")
    expect(request_record.reload.status).to eq("delivered_to_warehouse")
    expect(request_record.tracking_events.count).to eq(2)
  end

  it "rejects unsigned requests" do
    deliver(event_id: "e1", status: "picked_up", signature: "forged")
    expect(response).to have_http_status(:unauthorized)
    expect(request_record.reload.status).to eq("label_created")
  end
end
