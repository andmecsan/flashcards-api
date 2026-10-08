module Api
  module V1
    # Base de la API autenticada. Aquí vive la frontera de permisos: toda acción
    # debe autorizar el recurso (`authorize`) y todo listado debe pasar por
    # `policy_scope`. Si una acción nueva lo olvida, Pundit lanza un error y los
    # tests fallan, en lugar de dejar el recurso expuesto sin que nadie lo note.
    class BaseController < ApplicationController
      include Searchable
      include Pundit::Authorization

      before_action :authenticate_request!

      # Condiciones en lugar de `only:`/`except:` porque Rails exige que la
      # acción nombrada exista en cada controlador hijo (el perfil no tiene `index`).
      after_action :verify_authorized,    unless: -> { action_name == "index" }
      after_action :verify_policy_scoped, if:     -> { action_name == "index" }

      # Acceso denegado a un recurso que no es tuyo: se responde como si no
      # existiera, para no revelar que está ahí.
      rescue_from Pundit::NotAuthorizedError do
        render json: { error: "No encontrado" }, status: :not_found
      end

      private

      def current_user
        @current_user
      end

      # `?difficulty=easy|medium|hard` acota los temarios del listado y las tarjetas de Estudiar.
      def validate_difficulty!
        return if params[:difficulty].blank? || Category.difficulties.key?(params[:difficulty])

        render json: { error: "Dificultad no válida" }, status: :bad_request
      end

      def filter_by_difficulty(cards)
        return cards if params[:difficulty].blank?

        cards.where(category_id: Category.where(difficulty: params[:difficulty]).select(:id))
      end

      # `difficulty` de la petición como atributo del temario; vacío si el cliente
      # no la envía (se conserva la actual) y nil si la envía en blanco (se quita).
      def difficulty_attrs
        params.key?(:difficulty) ? { difficulty: params[:difficulty].presence } : {}
      end

      # `?tag_id=` solo admite etiquetas personales del propio usuario.
      def validate_tag!
        return if params[:tag_id].blank?

        @filter_tag = policy_scope(Tag).find_by(id: params[:tag_id])
        render json: { error: "Etiqueta no encontrada" }, status: :not_found if @filter_tag.nil?
      end

      def filter_by_tag(cards)
        return cards if @filter_tag.nil?

        cards.where(id: Tagging.where(tag_id: @filter_tag.id, taggable_type: "Card").select(:taggable_id))
      end

      # Área, nivel y curso de la asignatura enviados en `source` (solo los presentes).
      def predefined_tag_ids(source)
        { area: :area_id, level: :level_id, course: :course_id }.each_with_object({}) do |(kind, key), ids|
          ids[kind] = source[key] if source.key?(key)
        end
      end

      # Aplica los filtros opcionales de dificultad del temario y etiqueta al estudiar.
      def filter_cards(cards)
        filter_by_tag(filter_by_difficulty(cards))
      end

      # Para controladores que solo operan sobre el propio usuario autenticado
      # (perfil, estadísticas): no hay recurso ajeno que autorizar.
      def self_service_only!
        skip_authorization
        skip_policy_scope
      end
    end
  end
end
