module Api
  # Lets the demo UI play the carrier: sends a signed webhook through the real endpoint logic.
  class DemoController < ApplicationController
    NEXT_EVENT = { "label_created" => "picked_up", "in_transit" => "delivered" }.freeze

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
