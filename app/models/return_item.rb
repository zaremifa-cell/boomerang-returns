class ReturnItem < ApplicationRecord
  REASONS = %w[too_small too_large not_as_described damaged changed_mind].freeze

  belongs_to :return_request
  belongs_to :order_item

  validates :reason, inclusion: { in: REASONS }
  validates :quantity, numericality: { greater_than: 0 }
end
