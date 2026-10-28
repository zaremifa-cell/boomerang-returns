module Webhooks
  class CarrierController < ApplicationController
    def create
      body = request.raw_post
      unless CarrierWebhook.valid_signature?(body, request.headers["X-Carrier-Signature"])
        return render json: { error: "invalid signature" }, status: :unauthorized
      end

      result = CarrierWebhook.process(JSON.parse(body))
      # Unknown shipments are acknowledged too: a 4xx would make the carrier retry forever.
      render json: { outcome: result.outcome }, status: :ok
    rescue JSON::ParserError
      render json: { error: "invalid JSON" }, status: :bad_request
    end
  end
end
