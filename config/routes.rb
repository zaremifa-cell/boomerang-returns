Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "orders/lookup", to: "customer#lookup"
    post "returns", to: "customer#create"
    get "returns/:id", to: "customer#show"

    scope "retailer", controller: :retailer do
      get "returns", action: :index
      get "stats", action: :stats
      post "returns/:id/refund", action: :refund
      post "returns/:id/retry_label", action: :retry_label
    end

    post "demo/orders", to: "demo#order"
    post "demo/returns/:id/scan", to: "demo#scan"
  end

  post "webhooks/carrier", to: "webhooks/carrier#create"

  get "*path", to: "spa#index", constraints: ->(req) { !req.path.start_with?("/api", "/webhooks") }
  root "spa#index"
end
