module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: [ :update, :destroy, :merge ]

      # Etiquetas personales del usuario, con cuántas tarjetas usan cada una.
      def index
        tags = policy_scope(Tag).order(:name)
        tags = tags.where("tags.name ILIKE ?", "%#{Tag.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
        counts = Tagging.where(tag_id: tags.select(:id), taggable_type: "Card").group(:tag_id).count

        render json: tags.map { |tag| TagSerializer.new(tag, cards_count: counts.fetch(tag.id, 0)).as_json }
      end

      # Vocabulario controlado (área, nivel, curso) para elegir al describir un temario.
      def system
        authorize Tag, :system?
        tags = Tag.predefined.ordered.group_by(&:kind)

        render json: {
          areas:   tags.fetch("area", []).map { |t| TagSerializer.new(t).as_json },
          levels:  tags.fetch("level", []).map { |t| TagSerializer.new(t).as_json },
          courses: tags.fetch("course", []).map { |t| TagSerializer.new(t).as_json }
        }
      end

      def update
        if @tag.update(name: params.require(:name).to_s.squish)
          render json: TagSerializer.new(@tag).as_json
        else
          render json: { errors: rename_errors }, status: :unprocessable_entity
        end
      end

      def destroy
        @tag.destroy
        head :no_content
      end

      # Fusiona esta etiqueta en otra del mismo usuario: las tarjetas pasan a la
      # de destino (sin duplicar) y esta se elimina.
      def merge
        target = policy_scope(Tag).find(params.require(:into_id))
        authorize target, :update?
        return render json: { errors: [ "Elige otra etiqueta distinta" ] }, status: :unprocessable_entity if target.id == @tag.id

        Tag.transaction do
          already = Tagging.where(tag_id: target.id).pluck(:taggable_type, :taggable_id)
          @tag.taggings.where(taggable_type: "Card", taggable_id: already.map(&:last)).destroy_all
          @tag.taggings.update_all(tag_id: target.id)
          @tag.reload.destroy!
        end

        render json: TagSerializer.new(target).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Etiqueta de destino no encontrada" }, status: :not_found
      end

      private

      def set_tag
        @tag = policy_scope(Tag).find(params[:id])
        authorize @tag
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Etiqueta no encontrada" }, status: :not_found
      end

      def rename_errors
        if @tag.errors.of_kind?(:slug, :taken)
          [ "Ya tienes una etiqueta con ese nombre. Fusiónalas si quieres unirlas." ]
        else
          @tag.errors.full_messages
        end
      end
    end
  end
end
