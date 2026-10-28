require "rails_helper"

RSpec.describe CreateReturn do
  let(:order) { build_order(items: [{ quantity: 1 }]) }
  let(:item) { order.order_items.first }

  def call(key, lines: [line(item)])
    described_class.call(order: order, lines: lines, carrier: "dhl", idempotency_key: key)
  end

  it "creates a return and queues label creation" do
    expect { call("k1") }.to have_enqueued_job(CreateLabelJob)
    expect(order.return_requests.count).to eq(1)
  end

  it "returns the original return when the same key is sent again" do
    first = call("k1")
    second = call("k1")

    expect(second.replayed).to be(true)
    expect(second.return_request).to eq(first.return_request)
    expect(order.return_requests.count).to eq(1)
  end

  it "does not let a second key claim a unit that is already being returned" do
    call("k1")
    expect { call("k2") }.to raise_error(CreateReturn::Invalid, /Already returned/)
  end

  it "requires an idempotency key" do
    expect { call("") }.to raise_error(CreateReturn::Invalid, /Idempotency-Key/)
  end

  it "rejects unknown carriers" do
    expect {
      described_class.call(order: order, lines: [line(item)], carrier: "pigeon", idempotency_key: "k")
    }.to raise_error(CreateReturn::Invalid, /carrier/)
  end
end
