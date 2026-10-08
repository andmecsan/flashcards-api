module Api
  module V1
    class DecksController < BaseController
      before_action :validate_difficulty!, only: [ :study ]
      before_action :validate_tag!, only: [ :study ]
      before_action :set_deck, only: [ :show, :update, :destroy, :study, :create_topic, :stats, :favorite ]

      def index
        scope = policy_scope(Deck)
        scope = scope.where(favorite: true) if params[:favorites].present?
        decks, meta = paginate(search_by_name(scope.order(favorite: :desc, created_at: :desc)))

        render json: {
          decks: decks.includes(:tags).map { |d| DeckSerializer.new(d, current_user).as_json },
          meta: meta
        }
      end

      def show
        render json: DeckSerializer.new(@deck, current_user).as_json
      end

      def create
        deck = current_user.decks.build(deck_params)
        authorize deck
        save_with_tags(deck, status: :created)
      end

      def update
        @deck.assign_attributes(deck_params)
        save_with_tags(@deck)
      end

      def destroy
        @deck.destroy
        head :no_content
      end

      def study
        cards = filter_cards(@deck.due_cards_for(current_user)).includes(:card_reviews, :tags, :category)
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
          next_review:  next_category_review,
          difficulty_counts: difficulty_counts,
          tags:         tag_counts,
          weak_cards:   @deck.weak_cards_for(current_user)
        }
      end

      # Marca o desmarca la asignatura como favorita. Es idempotente: se envía el
      # valor deseado (`favorite: true|false`), no un conmutador.
      def favorite
        @deck.update!(favorite: ActiveModel::Type::Boolean.new.cast(params.require(:favorite)))
        render json: DeckSerializer.new(@deck, current_user).as_json
      end

      def create_topic
        cards = []

        ActiveRecord::Base.transaction do
          category = @deck.categories.create!({ name: params[:name] }.merge(difficulty_attrs))

          cards = (params[:cards] || []).map do |card_data|
            card = category.cards.create!(front: card_data[:front], back: card_data[:back])
            card.replace_personal_tags!(card_data[:tags]) if card_data.key?(:tags)
            card
          end

          render json: {
            category: CategorySerializer.new(category).as_json,
            cards: cards.map { |c| CardSerializer.new(c).as_json }
          }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.record.errors.map { |err| err.message } ].flatten }, status: :unprocessable_entity
      end

      private

      def set_deck
        @deck = policy_scope(Deck).find(params[:id])
        authorize @deck
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mazo no encontrado" }, status: :not_found
      end

      def deck_params
        params.require(:deck).permit(:name, :icon, :color)
      end

      # Guarda la asignatura y su área, nivel y curso (opcionales) en una sola
      # transacción: si algo falla, no queda nada a medias.
      def save_with_tags(deck, status: :ok)
        saved = false
        ActiveRecord::Base.transaction do
          saved = deck.save
          deck.assign_predefined_tags!(predefined_tag_ids(params.require(:deck))) if saved
        end

        if saved
          render json: DeckSerializer.new(deck, current_user).as_json, status: status
        else
          render json: { errors: deck.errors.map { |e| e.message } }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.map { |err| err.message } }, status: :unprocessable_entity
      end

      def deck_review_logs
        ReviewLog
          .joins(card_review: { card: { category: :deck } })
          .where(decks: { id: @deck.id })
          .where(card_reviews: { user: current_user })
      end

      # Etiquetas personales usadas en esta asignatura, con su nº de tarjetas.
      def tag_counts
        Tagging.joins(:tag)
               .where(taggable_type: "Card", taggable_id: @deck.cards.select(:id), tags: { user_id: current_user.id })
               .group("tags.id", "tags.name").order("tags.name").count
               .map { |(id, name), count| { id: id, name: name, count: count } }
      end

      # Nº de temarios por dificultad marcada por el usuario; `none` = sin definir.
      def difficulty_counts
        counts = @deck.categories.group(:difficulty).count
        Category.difficulties.keys.to_h { |key| [ key.to_sym, counts.fetch(key, 0) ] }
            .merge(none: counts.fetch(nil, 0))
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
