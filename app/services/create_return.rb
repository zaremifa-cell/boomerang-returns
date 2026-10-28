# Creates a return request exactly once per idempotency key.
#
# A customer double-clicking "Confirm", or a mobile client retrying after a
# dropped connection, sends the same key again and gets the original return back
# instead of a second shipping label.
class CreateReturn
  class Invalid < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.join(" "))
    end
  end

  Result = Data.define(:return_request, :replayed)

  def self.call(...) = new(...).call

  def initialize(order:, lines:, carrier:, idempotency_key:)
    @order = order
    @lines = Array(lines).map { |l| l.to_h.symbolize_keys }
    @carrier = carrier
    @idempotency_key = idempotency_key.to_s
  end

  def call
    raise Invalid, ["Missing Idempotency-Key header."] if @idempotency_key.blank?

    existing = @order.return_requests.find_by(idempotency_key: @idempotency_key)
    return Result.new(existing, true) if existing

    request = create!
    CreateLabelJob.perform_later(request.id)
    Result.new(request, false)
  rescue ActiveRecord::RecordNotUnique
    # Two identical requests raced past the lookup above; the loser returns the winner's row.
    Result.new(@order.return_requests.find_by!(idempotency_key: @idempotency_key), true)
  end

  private

  def create!
    ReturnRequest.transaction do
      # Serialise returns per order so two different requests can't both claim the last unit.
      @order.lock!

      raise Invalid, ["Choose a carrier."] unless ReturnRequest::CARRIERS.include?(@carrier)

      errors = ReturnPolicy.new(@order).validate(@lines)
      raise Invalid, errors if errors.any?

      request = @order.return_requests.create!(carrier: @carrier, idempotency_key: @idempotency_key)
      @lines.each do |line|
        request.return_items.create!(order_item_id: line[:order_item_id], quantity: line[:quantity], reason: line[:reason])
      end
      request
    end
  end
end
