require "rails_helper"

RSpec.describe ReturnRequest do
  let(:order) { build_order(items: [{ quantity: 5 }]) }

  def pending_return(age)
    request = CreateReturn.call(order: order, lines: [line(order.order_items.first)], carrier: "dhl", idempotency_key: SecureRandom.hex(4)).return_request
    request.update_columns(updated_at: age.ago)
    request
  end

  it "queues a label job again for a return stuck in label_pending" do
    stale = pending_return(5.minutes)
    clear_enqueued_jobs
    expect { described_class.recover_stale_labels! }.to have_enqueued_job(CreateLabelJob).with(stale.id)
  end

  it "leaves a return alone while its first attempt may still be running" do
    pending_return(5.seconds)
    clear_enqueued_jobs
    expect { described_class.recover_stale_labels! }.not_to have_enqueued_job(CreateLabelJob)
  end

  it "recovers a stuck return when the customer looks at it", type: :request do
    stale = pending_return(5.minutes)
    clear_enqueued_jobs
    get "/api/returns/#{stale.public_id}"
    expect(CreateLabelJob).to have_been_enqueued.with(stale.id)
  end
end
