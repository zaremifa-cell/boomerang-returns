class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: ["Not found."] }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { errors: [e.message] }, status: :bad_request
  end
end
