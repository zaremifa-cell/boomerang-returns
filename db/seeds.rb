# Demo data: one retailer with a handful of orders covering the interesting cases.
retailer = Retailer.find_or_create_by!(slug: "northwind") do |r|
  r.name = "Northwind Apparel"
  r.api_token = ENV.fetch("DEMO_RETAILER_TOKEN", "demo-retailer-token")
  r.return_window_days = 30
  r.allowed_countries = %w[GB BG DE FR]
end

def seed_order(retailer, number:, email:, country:, delivered_days_ago:, items:)
  order = retailer.orders.find_or_initialize_by(number: number)
  # Dates are refreshed on every seed so the live demo's return windows never drift.
  order.update!(email: email, country: country, delivered_at: delivered_days_ago&.days&.ago)
  items.each do |sku, name, price, qty, final_sale|
    order.order_items.find_or_create_by!(sku: sku) do |i|
      i.name = name
      i.price_cents = price
      i.quantity = qty
      i.final_sale = final_sale
    end
  end
end

seed_order(retailer, number: "NW-1001", email: "maria@example.com", country: "BG", delivered_days_ago: 5, items: [
  ["JKT-RAIN-M", "Rain jacket, M", 8900, 1, false],
  ["TEE-WHT-L", "Organic tee, white, L", 2500, 3, false],
  ["SCK-WOOL", "Wool socks (sale)", 900, 2, true]
])
seed_order(retailer, number: "NW-1002", email: "tom@example.com", country: "GB", delivered_days_ago: 45, items: [
  ["BTS-LTH-42", "Leather boots, 42", 15900, 1, false]
])
seed_order(retailer, number: "NW-1003", email: "lena@example.com", country: "US", delivered_days_ago: 3, items: [
  ["CAP-BLK", "Wool cap, black", 3200, 1, false]
])
seed_order(retailer, number: "NW-1004", email: "ivan@example.com", country: "DE", delivered_days_ago: nil, items: [
  ["BAG-CNV", "Canvas tote", 4500, 1, false]
])

puts "Seeded #{retailer.name}. Try order NW-1001 / maria@example.com. Retailer token: #{retailer.api_token}"
