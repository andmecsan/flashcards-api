class AuthController < ApplicationController
  skip_before_action :authenticate_request!

  def google_callback
    user = User.from_omniauth(request.env["omniauth.auth"])
    token = JwtService.encode({ user_id: user.id })
    redirect_to "http://localhost:5173/auth/callback?token=#{token}", allow_other_host: true
  end

  def failure
    render json: { error: "Autenticación fallida" }, status: :unauthorized
  end
end
