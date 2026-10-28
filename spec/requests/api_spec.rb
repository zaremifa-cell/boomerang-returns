require "rails_helper"

RSpec.describe "Returns API" do
  let(:retailer) { build_retailer(api_token: "secret-token") }
  let(:order) { build_order(retailer: retailer) }
  let(:item) { order.order_items.first }
  let(:auth) { { "Authorization" => "Bearer secret-token" } }

  def create_return(key: "k1", quantity: 1)
    post "/api/returns",
         params: { order_number: order.number, email: order.email, carrier: "dhl",
                   items: [{ order_item_id: item.id, quantity: quantity, reason: "too_small" }] },
         headers: { "Idempotency-Key" => key }, as: :json
  end

  it "looks up an order by number and email" do
    post "/api/orders/lookup", params: { order_number: order.number, email: "A@example.com " }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["items"].first["returnable_quantity"]).to eq(2)
  end

  it "does not reveal orders for the wrong email" do
    post "/api/orders/lookup", params: { order_number: order.number, email: "x@example.com" }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "creates a return once and replays it for the same key" do
    create_return
    expect(response).to have_http_status(:created)
    id = response.parsed_body["id"]

    create_return
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["id"]).to eq(id)
  end

  it "explains why a return is not allowed" do
    create_return(quantity: 5)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to match(/up to 2/)
  end

  it "lists returns for the retailer only with a valid token" do
    create_return
    get "/api/retailer/returns"
    expect(response).to have_http_status(:unauthorized)

    get "/api/retailer/returns", headers: auth
    expect(response.parsed_body.size).to eq(1)
  end

  it "refunds only returns that reached the warehouse" do
    create_return
    id = response.parsed_body["id"]

    post "/api/retailer/returns/#{id}/refund", headers: auth
    expect(response).to have_http_status(:conflict)

    ReturnRequest.find_by(public_id: id).update!(status: "delivered_to_warehouse")
    post "/api/retailer/returns/#{id}/refund", headers: auth
    expect(response.parsed_body["status"]).to eq("refunded")
  end
end
