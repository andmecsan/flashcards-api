class Category < ApplicationRecord
  belongs_to :deck
  has_many :cards, dependent: :destroy

  # Dificultad que el usuario asigna al temario (opcional y privada: no se
  # publica ni se copia al importar).
  enum :difficulty, { easy: 0, medium: 1, hard: 2 }, validate: { allow_nil: true }

  validates :name, presence: true,
                   uniqueness: { scope: :deck_id, message: "ya existe una categoría con ese nombre" }

  # Propietario del recurso, usado por las policies.
  def owner = deck&.user

  # Reemplaza el nombre y las tarjetas del temario en una sola transacción,
  # conservando las tarjetas que ya existían. Una tarjeta que llega con `id`
  # de este temario se actualiza en el sitio, de modo que su planificación
  # SM-2 y su historial de repasos no se pierden. Las que llegan sin `id`
  # (o con un `id` ajeno) se crean, y las que ya no aparecen se borran.
  # Las etiquetas personales de cada tarjeta solo se modifican si llegan en los datos.
  #
  # @param attrs [Hash] atributos del temario (`name` y, si se quiere cambiar, `difficulty`)
  # @param cards_data [Array<Hash, ActionController::Parameters>] con front, back y opcionalmente id
  # @return [Array<Card>] las tarjetas resultantes, en el orden recibido
  # @raise [ActiveRecord::RecordInvalid] si el nombre o alguna tarjeta no son válidos
  def sync_topic!(attrs:, cards_data:)
    transaction do
      update!(attrs)

      kept = cards_data.map do |data|
        card = data[:id].present? ? cards.find_by(id: data[:id]) : nil
        card_attrs = { front: data[:front], back: data[:back] }

        saved = card ? card.tap { |c| c.update!(card_attrs) } : cards.create!(card_attrs)
        saved.replace_personal_tags!(data[:tags]) if data.key?(:tags)
        saved
      end

      cards.where.not(id: kept.map(&:id)).destroy_all
      kept
    end
  end
end
