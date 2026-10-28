module Builders
  def build_retailer(**attrs)
    Retailer.create!({ name: "Shop", slug: "shop-#{SecureRandom.hex(3)}", api_token: SecureRandom.hex(8),
                       return_window_days: 30, allowed_countries: %w[GB BG] }.merge(attrs))
  end

  def build_order(retailer: build_retailer, delivered_at: 3.days.ago, country: "BG", items: [{ quantity: 2 }])
    order = retailer.orders.create!(number: "NW-#{SecureRandom.hex(3)}", email: "a@example.com",
                                    country: country, delivered_at: delivered_at)
    items.each_with_index do |attrs, i|
      order.order_items.create!({ sku: "SKU-#{i}", name: "Item #{i}", price_cents: 1000, quantity: 1 }.merge(attrs))
    end
    order
  end

  def line(item, quantity: 1, reason: "too_small")
    { order_item_id: item.id, quantity: quantity, reason: reason }
  end

  # A carrier whose answers are scripted: :ok, :timeout_before or :timeout_after (label made, response lost).
  class ScriptedCarrier
    attr_reader :calls, :labels

    def initialize(*script)
      @script = script
      @calls = 0
      @labels = {}
    end

    def create_label(reference:, carrier:)
      step = @script[@calls] || :ok
      @calls += 1
      raise Carrier::Timeout, "timeout" if step == :timeout_before

      label = @labels[reference] ||= Carrier::Label.new(tracking_number: "TRK#{@labels.size + 1}", label_url: "u")
      raise Carrier::Timeout, "lost response" if step == :timeout_after

      label
    end
  end
end
