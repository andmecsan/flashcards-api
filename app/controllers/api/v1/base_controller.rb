module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_request!

      private

      def current_user
        @current_user
      end
    end
  end
end