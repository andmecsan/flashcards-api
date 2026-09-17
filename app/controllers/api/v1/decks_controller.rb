module Api
  module V1
    class DecksController < BaseController
      before_action :set_deck, only: [:show, :update, :destroy, :study, :create_topic, :stats]

      def index
        decks = current_user.decks.order(created_at: :desc)
        decks = decks.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 9).to_i
        total = decks.count

        decks = decks.offset((page - 1) * per_page).limit(per_page)

        render json: {
          decks: decks.map { |d| DeckSerializer.new(d, current_user).as_json },
          meta: { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
        }
      end

      def show
        render json: DeckSerializer.new(@deck, current_user).as_json
      end

      def create
        deck = current_user.decks.build(deck_params)
        if deck.save
          render json: DeckSerializer.new(deck, current_user).as_json, status: :created
        else
          render json: { errors: deck.errors.map { |e| e.message } }, status: :unprocessable_entity
        end
      end

      def update
        if @deck.update(deck_params)
          render json: DeckSerializer.new(@deck, current_user).as_json
        else
          render json: { errors: @deck.errors.map { |e| e.message } }, status: :unprocessable_entity
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

      def stats
        total = @deck.cards.count
        mastered = @deck.mastered_count_for(current_user)
        in_progress = @deck.in_progress_count_for(current_user)
        new_cards = total - mastered - in_progress
        logs = deck_review_logs

        render json: {
          total_cards:  total,
          due_today:    @deck.due_count_for(current_user),
          mastered:     mastered,
          in_progress:  in_progress,
          new_cards:    new_cards,
          success_rate: logs.any? ? (logs.where("quality >= 4").count.to_f / logs.count * 100).round(1) : nil,
          next_review:  next_category_review
        }
      end

      def create_topic
        cards = []

        ActiveRecord::Base.transaction do
          category = @deck.categories.create!(name: params[:name])

          cards = (params[:cards] || []).map do |card_data|
            category.cards.create!(front: card_data[:front], back: card_data[:back])
          end

          render json: {
            category: CategorySerializer.new(category).as_json,
            cards: cards.map { |c| CardSerializer.new(c).as_json }
          }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.record.errors.map { |err| err.message }].flatten }, status: :unprocessable_entity
      end

      private

      def set_deck
        @deck = current_user.decks.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mazo no encontrado" }, status: :not_found
      end

      def deck_params
        params.require(:deck).permit(:name, :icon, :color)
      end

      def deck_review_logs
        ReviewLog
          .joins(card_review: { card: { category: :deck } })
          .where(decks: { id: @deck.id })
          .where(card_reviews: { user: current_user })
      end

      def next_category_review
        counts = @deck.cards.due_for(current_user)
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