class ReturnRequest < ApplicationRecord
  CARRIERS = %w[dhl royal_mail evri].freeze

  # Forward-only lifecycle. Carrier events may arrive late or out of order,
  # so a transition is only applied when it moves the return further along.
  FLOW = %w[label_pending label_created in_transit delivered_to_warehouse refunded].freeze
  DEAD_STATUSES = %w[label_failed cancelled].freeze

  belongs_to :order
  has_many :return_items, dependent: :destroy
  has_many :tracking_events, -> { order(:occurred_at) }, dependent: :destroy

  validates :carrier, inclusion: { in: CARRIERS }
  validates :status, inclusion: { in: FLOW + DEAD_STATUSES }
  validates :idempotency_key, presence: true

  before_validation { self.public_id ||= "RET-#{SecureRandom.alphanumeric(8).upcase}" }

  def advance_to!(new_status)
    return false unless forward?(new_status)

    update!(status: new_status)
  end

  def forward?(new_status)
    current = FLOW.index(status)
    target = FLOW.index(new_status)
    current && target && target > current
  end

  def refund_cents
    return_items.includes(:order_item).sum { |ri| ri.order_item.price_cents * ri.quantity }
  end
end
