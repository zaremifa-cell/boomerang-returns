# Serves the built React app for any non-API path, so /retailer survives a page reload.
class SpaController < ApplicationController
  def index
    index = Rails.public_path.join("index.html")
    if index.exist?
      # API controllers have no view layer, so the file is sent as-is.
      send_file index, type: "text/html", disposition: "inline"
    else
      render plain: "Frontend not built. Run: cd frontend && npm install && npm run build", status: :not_found
    end
  end
end
