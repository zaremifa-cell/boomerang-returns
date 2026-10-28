# Applies a tracking update pushed by a carrier.
#
# Carriers deliver webhooks at least once and not always in order, so:
# - the same event_id is stored once and acknowledged again without side effects;
# - a late "in_transit" after "delivered" is recorded but never moves the return backwards.
class CarrierWebhook
  STATUS_MAP = {
    "picked_up" => "in_transit",
    "in_transit" => "in_transit",
    "delivered" => "delivered_to_warehouse"
  }.freeze

  Result = Data.define(:outcome, :return_request)

  def self.secret = ENV.fetch("CARRIER_WEBHOOK_SECRET", "dev-webhook-secret")

  def self.sign(body) = OpenSSL::HMAC.hexdigest("SHA256", secret, body)

  def self.valid_signature?(body, signature)
    signature.present? && ActiveSupport::SecurityUtils.secure_compare(sign(body), signature)
  end

  def self.process(payload)
    payload = payload.to_h.stringify_keys
    status = STATUS_MAP[payload["status"]]
    return Result.new(:unknown_status, nil) unless status

    request = ReturnRequest.find_by(tracking_number: payload["tracking_number"])
    return Result.new(:unknown_shipment, nil) unless request

    request.with_lock do
      request.tracking_events.create!(
        external_id: payload["event_id"], status: payload["status"],
        occurred_at: Time.zone.parse(payload["occurred_at"].to_s) || Time.current, payload: payload
      )
      outcome = request.advance_to!(status) ? :applied : :stale
      Result.new(outcome, request)
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(:duplicate, request)
  end
end
