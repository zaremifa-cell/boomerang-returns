class CreateLabelJob < ApplicationJob
  queue_as :carriers

  MAX_ATTEMPTS = 5

  retry_on Carrier::Timeout, attempts: MAX_ATTEMPTS, wait: ->(executions) { executions * 2 } do |job, error|
    ReturnRequest.find(job.arguments.first).update!(status: "label_failed", last_error: error.message)
  end

  discard_on Carrier::Rejected do |job, error|
    ReturnRequest.find(job.arguments.first).update!(status: "label_failed", last_error: error.message)
  end

  def perform(return_request_id)
    request = ReturnRequest.find(return_request_id)
    return unless request.status == "label_pending"

    request.increment!(:label_attempts)
    begin
      label = Carrier.client.create_label(reference: request.public_id, carrier: request.carrier)
    rescue Carrier::Timeout => e
      request.update_column(:last_error, e.message)
      raise
    end

    request.with_lock do
      next unless request.status == "label_pending"

      request.update!(status: "label_created", tracking_number: label.tracking_number,
                      label_url: label.label_url, last_error: nil)
    end
  end
end
