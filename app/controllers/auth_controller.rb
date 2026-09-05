class AuthController < ApplicationController
  skip_before_action :authenticate_request!

  def google_callback
    user = User.from_omniauth(request.env["omniauth.auth"])
    token = JwtService.encode({ user_id: user.id })
    redirect_to "http://localhost:5173/auth/callback?token=#{token}", allow_other_host: true
  end

  def register
    user = User.new(register_params)
    if user.save
      token = JwtService.encode({ user_id: user.id })
      render json: { token: token, user: { id: user.id, name: user.name, email: user.email } }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      token = JwtService.encode({ user_id: user.id })
      render json: { token: token, user: { id: user.id, name: user.name, email: user.email } }
    else
      render json: { error: "Email o contraseña incorrectos" }, status: :unauthorized
    end
  end

  def failure
    render json: { error: "Autenticación fallida" }, status: :unauthorized
  end

  private

  def register_params
    params.permit(:name, :email, :password)
  end
end