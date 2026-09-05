module Api
  module V1
    class CardsController < BaseController
      before_action :set_category, only: [ :index, :create ]
      before_action :set_card, only: [ :show, :update, :destroy, :review ]

      def index
        cards = @category.cards.order(created_at: :desc)
        render json: cards.map { |c| CardSerializer.new(c).as_json }
      end

      def show
        render json: CardSerializer.new(@card).as_json
      end

      def create
        card = @category.cards.build(card_params)
        if card.save
          render json: CardSerializer.new(card).as_json, status: :created
        else
          render json: { errors: card.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @card.update(card_params)
          render json: CardSerializer.new(@card).as_json
        else
          render json: { errors: @card.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @card.destroy
        head :no_content
      end

      def review
        quality = params[:quality].to_i
        review  = @card.review_for(current_user)
        review.save! unless review.persisted?
        review.apply_review!(quality)
        render json: ReviewSerializer.new(review).as_json
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def generate
        unless params[:file].present?
          return render json: { error: "Debes subir un archivo PDF" }, status: :unprocessable_entity
        end

        text = PdfExtractorService.new(params[:file]).extract_text

        if text.blank?
          return render json: { error: "No se pudo extraer texto del PDF" }, status: :unprocessable_entity
        end

        result = GeminiService.new(text).generate_cards

        if result.nil?
          return render json: { error: "No se pudieron generar tarjetas" }, status: :unprocessable_entity
        end

        if result.is_a?(Array)
          cards = result
          name = nil
        else
          cards = result["cards"] || []
          name = result["name"]
        end

        render json: { name: name, cards: cards }
      end

      private

      def set_category
        @category = Category.joins(:deck).where(decks: { user: current_user }).find(params[:category_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Categoría no encontrada" }, status: :not_found
      end

      def set_card
        @card = Card.joins(category: :deck).where(decks: { user: current_user }).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Tarjeta no encontrada" }, status: :not_found
      end

      def card_params
        params.require(:card).permit(:front, :back)
      end
    end
  end
end
