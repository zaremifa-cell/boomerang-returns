module Api
  # Retailer dashboard endpoints, authenticated with the retailer's API token.
  class RetailerController < ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate!

    def index
      scope = @retailer.return_requests.includes(:order, return_items: :order_item).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      render json: scope.limit(200).map { |r| ReturnPresenter.summary(r) }
    end

    def stats
      requests = @retailer.return_requests
      render json: {
        by_status: requests.group(:status).count,
        by_reason: ReturnItem.joins(return_request: :order).where(orders: { retailer_id: @retailer.id })
                             .group(:reason).sum(:quantity),
        total: requests.count
      }
    end

    def refund
      request = @retailer.return_requests.find_by!(public_id: params[:id])
      if request.status == "delivered_to_warehouse" && request.advance_to!("refunded")
        render json: ReturnPresenter.summary(request)
      else
        render json: { errors: ["Only returns received at the warehouse can be refunded."] }, status: :conflict
      end
    end

    # Re-queues a return whose label creation gave up after all retries.
    def retry_label
      request = @retailer.return_requests.find_by!(public_id: params[:id])
      return render(json: { errors: ["Only failed labels can be retried."] }, status: :conflict) unless request.status == "label_failed"

      request.update!(status: "label_pending", last_error: nil)
      CreateLabelJob.perform_later(request.id)
      render json: ReturnPresenter.summary(request)
    end

    private

    def authenticate!
      authenticate_with_http_token { |token, _| @retailer = Retailer.find_by(api_token: token) }
      render(json: { errors: ["Invalid API token."] }, status: :unauthorized) unless @retailer
    end
  end
end
