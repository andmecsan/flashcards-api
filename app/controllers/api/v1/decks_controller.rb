module Api
  module V1
    class DecksController < BaseController
      before_action :set_deck, only: [:show, :update, :destroy, :study, :import, :create_topic, :stats]
    
      def stats
        total = @deck.cards.count
        due = @deck.due_count_for(current_user)
        in_progress = in_progress_count
        mastered = mastered_count
        logs = deck_review_logs

        render json: {
          total_cards:  total,
          due_today:    due,
          mastered:     mastered,
          in_progress:     in_progress,
          success_rate: logs.any? ? (logs.where("quality >= 4").count.to_f / logs.count * 100).round(1) : nil,
          next_review:  next_category_review
        }
      end

      def index
        decks = current_user.decks.order(created_at: :desc)
        decks = decks.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
        render json: decks.map { |d| DeckSerializer.new(d, current_user).as_json }
      end

      def show
        render json: DeckSerializer.new(@deck, current_user).as_json
      end

      def in_progress_count
        CardReview
          .joins(card: { category: :deck })
          .where(decks: { id: @deck.id })
          .where(card_reviews: { user: current_user })
          .where("card_reviews.interval <= ?", 21)
          .count
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

        result = GeminiService.new(text).generate_cards

        if result.nil?
          return render json: { error: "No se pudieron generar tarjetas" }, status: :unprocessable_entity
        end

        if result.is_a?(Array)
          category_name = "Importación #{Time.current.strftime('%d/%m/%Y %H:%M')}"
          cards_data = result
        else
          category_name = result["name"] || "Importación #{Time.current.strftime('%d/%m/%Y %H:%M')}"
          cards_data = result["cards"] || []
        end

        if cards_data.empty?
          return render json: { error: "No se pudieron generar tarjetas" }, status: :unprocessable_entity
        end

        cards = []

        ActiveRecord::Base.transaction do
          category = @deck.categories.create!(name: category_name)

          cards = cards_data.map do |card_data|
            category.cards.create!(front: card_data["front"], back: card_data["back"])
          end
        end

        render json: cards.map { |c| CardSerializer.new(c).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
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

      def mastered_count
        CardReview
          .joins(card: { category: :deck })
          .where(decks: { id: @deck.id })
          .where(card_reviews: { user: current_user })
          .where("card_reviews.interval > ?", 21)
          .count
      end

      def deck_review_logs
        ReviewLog
          .joins(card_review: { card: { category: :deck } })
          .where(decks: { id: @deck.id })
          .where(card_reviews: { user: current_user })
      end

      def next_category_review
        due_cards = @deck.cards
          .left_joins(:card_reviews)
          .where(
            "card_reviews.id IS NULL OR (card_reviews.user_id = ? AND card_reviews.next_review_at <= ?)",
            current_user.id, Time.current
          )

        counts = due_cards
          .group("categories.id", "categories.name")
          .count

        return nil if counts.empty?

        top = counts.max_by { |_, count| count }
        key, count = top
        category_id, category_name = key

        { category_id: category_id, category_name: category_name, due_count: count }
      end
    end
  end
end
