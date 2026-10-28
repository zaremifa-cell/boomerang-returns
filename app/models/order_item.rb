class OrderItem < ApplicationRecord
  belongs_to :order
  has_many :return_items, dependent: :restrict_with_error

  validates :sku, :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end
