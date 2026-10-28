module Api
  # Customer-facing endpoints. A customer proves who they are with order number + email,
  # the same way most returns portals work.
  class CustomerController < ApplicationController
    def lookup
      order = find_order
      return render_not_found unless order

      render json: ReturnPresenter.order(order, ReturnPolicy.new(order))
    end

    def create
      order = find_order
      return render_not_found unless order

      result = CreateReturn.call(
        order: order,
        lines: params.require(:items).map { |i| i.permit(:order_item_id, :quantity, :reason).to_h },
        carrier: params[:carrier],
        idempotency_key: request.headers["Idempotency-Key"]
      )
      render json: ReturnPresenter.detail(result.return_request), status: result.replayed ? :ok : :created
    rescue CreateReturn::Invalid => e
      render json: { errors: e.errors }, status: :unprocessable_content
    end

    def show
      request = ReturnRequest.find_by!(public_id: params[:id])
      ReturnRequest.recover_stale_labels!(ReturnRequest.where(id: request.id))
      render json: ReturnPresenter.detail(request.reload)
    end

    private

    def find_order
      Order.includes(:retailer).find_for_customer(number: params[:order_number], email: params[:email])
    end

    def render_not_found
      render json: { errors: ["We couldn't find an order with that number and email."] }, status: :not_found
    end
  end
end
