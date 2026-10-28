class Order < ApplicationRecord
  belongs_to :retailer
  # Returns go first: their items point at order items, which refuse to go while referenced.
  has_many :return_requests, dependent: :destroy
  has_many :order_items, dependent: :destroy

  validates :number, :email, :country, presence: true

  def self.find_for_customer(number:, email:)
    find_by(number: number.to_s.strip, email: email.to_s.strip.downcase)
  end

  # Quantity per order item already claimed by returns that are still alive.
  def returned_quantities
    ReturnItem.joins(:return_request)
              .where(return_requests: { order_id: id })
              .where.not(return_requests: { status: ReturnRequest::DEAD_STATUSES })
              .group(:order_item_id)
              .sum(:quantity)
  end
end
