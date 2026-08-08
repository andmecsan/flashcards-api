module Api
  module V1
    class DecksController < BaseController
      before_action :set_deck, only: [:show, :update, :destroy, :study, :import]

      def index
        decks = current_user.decks.order(created_at: :desc)
        render json: decks.map { |d| DeckSerializer.new(d, current_user).as_json }
      end

      def show
        render json: DeckSerializer.new(@deck, current_user).as_json
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
        render json: { message: "Próximamente" }, status: :not_implemented
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