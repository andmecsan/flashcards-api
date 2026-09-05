module Api
  module V1
    class ProfilesController < BaseController
      def show
        render json: {
          id:    current_user.id,
          name:  current_user.name,
          email: current_user.email,
          has_password: current_user.password_digest.present?,
          has_google: current_user.uid.present?
        }
      end

      def update
        if params[:current_password].present?
          unless current_user.authenticate(params[:current_password])
            return render json: { error: "Contraseña actual incorrecta" }, status: :unprocessable_entity
          end
        end

        if current_user.update(profile_params)
          render json: { message: "Perfil actualizado" }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        current_user.destroy
        render json: { message: "Cuenta eliminada" }
      end

      private

      def profile_params
        params.permit(:name, :password)
      end
    end
  end
end