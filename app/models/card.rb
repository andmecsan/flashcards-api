class Card < ApplicationRecord
  include Taggable

  belongs_to :category
  has_one :deck, through: :category
  has_many :card_reviews, dependent: :destroy
  has_one :user, through: :deck

  # Propietario del recurso, usado por las policies.
  def owner = category&.deck&.user

  # Sustituye las etiquetas personales de la tarjeta por las de `names`,
  # creando las que no existan. `names` vacío las quita todas.
  #
  # @param names [Array<String>]
  # @raise [ActiveRecord::RecordInvalid] si hay más de MAX_TAGS_PER_CARD o algún nombre no es válido
  def replace_personal_tags!(names)
    transaction do
      wanted = Array(names).map { |name| Tag.for_user(owner, name) }.uniq
      if wanted.size > Tagging::MAX_TAGS_PER_CARD
        errors.add(:base, "Una tarjeta admite como máximo #{Tagging::MAX_TAGS_PER_CARD} etiquetas")
        raise ActiveRecord::RecordInvalid, self
      end

      taggings.where.not(tag_id: wanted.map(&:id)).destroy_all
      (wanted.map(&:id) - taggings.reload.map(&:tag_id)).each { |tag_id| taggings.create!(tag_id: tag_id) }
    end
  end

  validates :front, presence: true
  validates :back,  presence: true

  # Tarjetas pendientes para un usuario: las que nunca ha estudiado o cuya fecha
  # de repaso ya ha llegado. El JOIN se limita a las reviews de ese usuario;
  # sin ese filtro, la review de otro usuario sobre la misma tarjeta la
  # excluiría de las pendientes.
  scope :due_for, ->(user) {
    joins(
      sanitize_sql_array([
        "LEFT JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = ?",
        user.id
      ])
    ).where("card_reviews.id IS NULL OR card_reviews.next_review_at <= ?", Time.current)
  }

  # @param user [User]
  # @return [CardReview]
  def review_for(user)
    card_reviews.find_or_initialize_by(user: user) do |review|
      review.repetitions    = 0 # Numero de repeticiones del mazo
      review.interval       = 1 # Dias hasta la proxima revision
      review.easiness       = 2.5 # Factor de facilidad neutro.
      review.next_review_at = Time.current # La disponibilidad de la tarjeta
    end
  end
end
