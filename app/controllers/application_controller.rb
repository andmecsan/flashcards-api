class ApplicationController < ActionController::API
  before_action :authenticate_request!

  private

  def authenticate_request!
    token = request.headers["Authorization"]&.split(" ")&.last
    decoded = JwtService.decode(token)
    @current_user = User.find(decoded["user_id"]) if decoded
    render json: { error: "No autorizado" }, status: :unauthorized unless @current_user
  end
end