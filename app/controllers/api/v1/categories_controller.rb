module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_deck, only: [ :index, :create ]
      before_action :set_category, only: [ :show, :update, :destroy, :update_topic, :review_cards ]

    def index
      categories = @deck.categories.order(created_at: :desc)
      categories = categories.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
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

      def review_cards
        cards = @category.cards
        render json: cards.map { |c| CardStudySerializer.new(c, current_user).as_json }
      end

      def update_topic
        unless @category.update(name: params[:name])
          return render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end

        @category.cards.destroy_all

        cards = (params[:cards] || []).map do |card_data|
          @category.cards.create!(front: card_data[:front], back: card_data[:back])
        end

        render json: {
          category: CategorySerializer.new(@category).as_json,
          cards: cards.map { |c| CardSerializer.new(c).as_json }
        }
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
