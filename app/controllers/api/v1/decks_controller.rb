module Api
  module V1
    class DecksController < BaseController
      before_action :set_deck, only: [:show, :update, :destroy, :study, :import, :create_topic]
      
      def index
        decks = current_user.decks.order(created_at: :desc)
        render json: decks.map { |d| DeckSerializer.new(d, current_user).as_json }
      end

      def show
        render json: DeckSerializer.new(@deck, current_user).as_json
      end

      def create_topic
      category = @deck.categories.build(name: params[:name])

      unless category.save
        return render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end

      cards = (params[:cards] || []).map do |card_data|
        category.cards.create!(front: card_data[:front], back: card_data[:back])
      end

      render json: {
        category: CategorySerializer.new(category).as_json,
        cards: cards.map { |c| CardSerializer.new(c).as_json }
      }, status: :created
      end

      def create
        deck = current_user.decks.build(deck_params)
        if deck.save
          render json: DeckSerializer.new(deck, current_user).as_json, status: :created
        else
          render json: { errors: deck.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @deck.update(deck_params)
          render json: DeckSerializer.new(@deck, current_user).as_json
        else
          render json: { errors: @deck.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @deck.destroy
        head :no_content
      end

      def study
        cards = @deck.due_cards_for(current_user).includes(:card_reviews)
        render json: cards.map { |c| CardStudySerializer.new(c, current_user).as_json }
      end

      def import
  unless params[:file].present?
    return render json: { error: "Debes subir un archivo PDF" }, status: :unprocessable_entity
  end

  text = PdfExtractorService.new(params[:file]).extract_text

  if text.blank?
    return render json: { error: "No se pudo extraer texto del PDF" }, status: :unprocessable_entity
  end

  generated = GeminiService.new(text).generate_cards

  if generated.empty?
    return render json: { error: "No se pudieron generar tarjetas" }, status: :unprocessable_entity
  end

  category = @deck.categories.create!(name: "Importación #{Time.current.strftime('%d/%m/%Y %H:%M')}")

  cards = generated.map do |card_data|
    category.cards.create!(front: card_data["front"], back: card_data["back"])
  end

  render json: cards.map { |c| CardSerializer.new(c).as_json }, status: :created
end

      private

      def set_deck
        @deck = current_user.decks.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mazo no encontrado" }, status: :not_found
      end

      def deck_params
        params.require(:deck).permit(:name, :description)
      end
    end
  end
end
