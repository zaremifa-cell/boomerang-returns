require "rails_helper"

RSpec.describe CreateLabelJob do
  let(:order) { build_order }
  let(:request) do
    CreateReturn.call(order: order, lines: [line(order.order_items.first)], carrier: "dhl", idempotency_key: "k").return_request
  end

  around do |example|
    original = Carrier.client
    example.run
  ensure
    Carrier.client = original
  end

  def run_with(carrier)
    Carrier.client = carrier
    request
    clear_enqueued_jobs
    perform_enqueued_jobs { described_class.perform_later(request.id) }
    request.reload
  end

  it "stores the label when the carrier answers" do
    expect(run_with(Builders::ScriptedCarrier.new(:ok))).to have_attributes(status: "label_created", tracking_number: "TRK1")
  end

  it "retries after a timeout and succeeds" do
    carrier = Builders::ScriptedCarrier.new(:timeout_before, :ok)
    expect(run_with(carrier).status).to eq("label_created")
    expect(carrier.calls).to eq(2)
  end

  it "does not create a second label when the first response was lost" do
    carrier = Builders::ScriptedCarrier.new(:timeout_after, :ok)
    result = run_with(carrier)

    expect(carrier.labels.size).to eq(1)
    expect(result.tracking_number).to eq("TRK1")
  end

  it "gives up after the last attempt and records why" do
    carrier = Builders::ScriptedCarrier.new(*Array.new(CreateLabelJob::MAX_ATTEMPTS, :timeout_before))
    result = run_with(carrier)

    expect(result).to have_attributes(status: "label_failed", last_error: "timeout")
    expect(carrier.calls).to eq(CreateLabelJob::MAX_ATTEMPTS)
  end

  it "does nothing for a return that already has a label" do
    carrier = Builders::ScriptedCarrier.new(:ok)
    run_with(carrier)
    perform_enqueued_jobs { described_class.perform_later(request.id) }

    expect(carrier.calls).to eq(1)
  end
end
