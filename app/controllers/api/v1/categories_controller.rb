module Api
  module V1
    class CategoriesController < BaseController
      before_action :validate_difficulty!, only: [ :index ]
      before_action :validate_tag!, only: [ :index, :review_cards ]
      before_action :set_deck, only: [ :index, :create ]
      before_action :set_category, only: [ :show, :update, :destroy, :update_topic, :review_cards, :move ]

      def index
        scope = policy_scope(@deck.categories).order(created_at: :desc)
        scope = scope.where(difficulty: params[:difficulty]) if params[:difficulty].present?
        scope = scope.where(id: filter_by_tag(Card.all).select(:category_id)) if @filter_tag
        categories, meta = paginate(search_by_name(scope))

        render json: {
          categories: categories.map { |c| CategorySerializer.new(c, tag_id: @filter_tag&.id).as_json },
          meta: meta
        }
      end

      def show
        render json: CategorySerializer.new(@category).as_json
      end

      def create
        category = @deck.categories.build(category_params)
        authorize category
        if category.save
          render json: CategorySerializer.new(category).as_json, status: :created
        else
         render json: { errors: category.errors.map { |e| e.message } }, status: :unprocessable_entity
        end
      end

      def update
        if @category.update(category_params)
          render json: CategorySerializer.new(@category).as_json
        else
         render json: { errors: @category.errors.map { |e| e.message } }, status: :unprocessable_entity
        end
      end

      def review_cards
        cards = filter_by_tag(@category.cards).includes(:tags, :category)
        render json: cards.map { |c| CardStudySerializer.new(c, current_user).as_json }
      end

      def update_topic
        cards = @category.sync_topic!(attrs: { name: params[:name] }.merge(difficulty_attrs), cards_data: params[:cards] || [])

        render json: {
          category: CategorySerializer.new(@category).as_json,
          cards: cards.map { |c| CardSerializer.new(c).as_json }
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # Mueve el temario a otra asignatura del mismo usuario. Sus tarjetas, su
      # planificación SM-2 y su historial no cambian: cuelgan de las tarjetas.
      def move
        target = policy_scope(Deck).find(params.require(:deck_id))
        authorize target, :update?

        if target.categories.where.not(id: @category.id).exists?(name: @category.name)
          return render json: { errors: [ name_taken_message(target) ] }, status: :unprocessable_entity
        end

        @category.update!(deck: target)
        render json: CategorySerializer.new(@category).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Asignatura de destino no encontrada" }, status: :not_found
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        render json: { errors: [ name_taken_message(target) ] }, status: :unprocessable_entity
      end

      def destroy
        @category.destroy
        head :no_content
      end

      private

      def name_taken_message(target)
        "Ya existe un temario con ese nombre en «#{target.name}». Renómbralo antes de moverlo."
      end

      def set_deck
        @deck = policy_scope(Deck).find(params[:deck_id])
        authorize @deck, :show?
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mazo no encontrado" }, status: :not_found
      end

      def set_category
        @category = policy_scope(Category).find(params[:id])
        authorize @category
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Categoría no encontrada" }, status: :not_found
      end

      def category_params
        params.require(:category).permit(:name, :difficulty)
      end
    end
  end
end
