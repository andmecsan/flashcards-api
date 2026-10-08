module Api
  module V1
    class CardsController < BaseController
      before_action :set_category, only: [ :index, :create ]
      before_action :set_card, only: [ :show, :update, :destroy, :review ]

      def index
        cards = policy_scope(@category.cards).includes(:tags).order(created_at: :desc)
        render json: cards.map { |c| CardSerializer.new(c).as_json }
      end

      def show
        render json: CardSerializer.new(@card).as_json
      end

      def create
        card = @category.cards.build(card_params)
        authorize card
        Card.transaction do
          card.save!
          card.replace_personal_tags!(card_tags) unless card_tags.nil?
        end
        render json: CardSerializer.new(card).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        Card.transaction do
          @card.update!(card_params)
          @card.replace_personal_tags!(card_tags) unless card_tags.nil?
        end
        render json: CardSerializer.new(@card.reload).as_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
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
        authorize Card

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
      rescue GeminiService::RateLimitError
        render json: { error: "Se ha alcanzado el límite de peticiones a la IA. Inténtalo de nuevo en unos minutos." }, status: :too_many_requests
      rescue GeminiService::UnavailableError
        render json: { error: "El servicio de generación con IA no está disponible ahora mismo. Inténtalo más tarde." }, status: :service_unavailable
      end

      private

      def set_category
        @category = policy_scope(Category).find(params[:category_id])
        authorize @category, :show?
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Categoría no encontrada" }, status: :not_found
      end

      def set_card
        @card = policy_scope(Card).find(params[:id])
        authorize @card
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Tarjeta no encontrada" }, status: :not_found
      end

      # Etiquetas personales enviadas (`card: { tags: [...] }`); nil si el cliente no las envía.
      def card_tags
        params.dig(:card, :tags)&.then { |tags| Array(tags) }
      end

      def card_params
        params.require(:card).permit(:front, :back)
      end
    end
  end
end
