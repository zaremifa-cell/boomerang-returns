class TrackingEvent < ApplicationRecord
  belongs_to :return_request

  validates :external_id, :status, :occurred_at, presence: true
end
