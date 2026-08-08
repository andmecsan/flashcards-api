class AuthController < ApplicationController
  skip_before_action :authenticate_request!

  def google_callback
    user = User.from_omniauth(request.env["omniauth.auth"])
    token = JwtService.encode({ user_id: user.id })
    render json: { token: token, user: { id: user.id, name: user.name, email: user.email } }
  end

  def failure
    render json: { error: "Autenticación fallida" }, status: :unauthorized
  end
end