module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_deck, only: [ :index, :create ]
      before_action :set_category, only: [ :show, :update, :destroy ]

      def index
        categories = @deck.categories.order(created_at: :desc)
        render json: categories.map { |c| CategorySerializer.new(c).as_json }
      end

      def show
        render json: CategorySerializer.new(@category).as_json
      end

      def create
        category = @deck.categories.build(category_params)
        if category.save
          render json: CategorySerializer.new(category).as_json, status: :created
        else
          render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @category.update(category_params)
          render json: CategorySerializer.new(@category).as_json
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @category.destroy
        head :no_content
      end

      private

      def set_deck
        @deck = current_user.decks.find(params[:deck_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mazo no encontrado" }, status: :not_found
      end

      def set_category
        @category = Category.joins(:deck).where(decks: { user: current_user }).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Categoría no encontrada" }, status: :not_found
      end

      def category_params
        params.require(:category).permit(:name)
      end
    end
  end
end
