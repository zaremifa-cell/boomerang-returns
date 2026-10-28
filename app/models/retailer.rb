class Retailer < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :return_requests, through: :orders

  validates :name, :slug, :api_token, presence: true
  validates :return_window_days, numericality: { greater_than: 0 }

  def ships_to?(country)
    allowed_countries.include?(country)
  end
end
