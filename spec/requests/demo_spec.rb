require "rails_helper"

RSpec.describe "Demo helpers" do
  before { load Rails.root.join("db/seeds.rb") }

  it "gives every visitor a fresh, returnable order of their own" do
    post "/api/demo/orders"
    expect(response).to have_http_status(:created)
    first = response.parsed_body

    post "/api/demo/orders"
    second = response.parsed_body
    expect(second["order_number"]).not_to eq(first["order_number"])

    post "/api/orders/lookup", params: first, as: :json
    expect(response.parsed_body["order_errors"]).to be_empty
    expect(response.parsed_body["items"].map { |i| i["returnable_quantity"] }).to eq([1, 3, 0])
  end

  it "removes generated orders older than a day" do
    post "/api/demo/orders"
    old = Order.find_by(number: response.parsed_body["order_number"])
    old.update!(created_at: 2.days.ago)

    post "/api/demo/orders"
    expect(Order.exists?(old.id)).to be(false)
  end
end
