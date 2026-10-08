class Deck < ApplicationRecord
  include Taggable

  MASTERY_THRESHOLD = 21
  WEAK_CARDS_LIMIT = 20

  belongs_to :user
  has_many :categories, dependent: :destroy
  has_many :cards, through: :categories

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, message: "ya existe un mazo con ese nombre" }

  # Propietario del recurso, usado por las policies.
  def owner = user

  # Asigna el área, el nivel y el curso de la asignatura (todos opcionales). Solo se
  # tocan los tipos que llegan en `ids`: un valor vacío quita esa etiqueta.
  #
  # @param ids [Hash{Symbol=>String,Integer,nil}] :area, :level, :course
  # @raise [ActiveRecord::RecordInvalid] si algún id no es del tipo esperado
  def assign_predefined_tags!(ids)
    transaction do
      ids.slice(:area, :level, :course).each do |kind, tag_id|
        taggings.joins(:tag).where(tags: { kind: Tag.kinds[kind] }).destroy_all
        next if tag_id.blank?

        tag = Tag.predefined.public_send(kind).find_by(id: tag_id)
        if tag.nil?
          errors.add(:base, "El #{kind} elegido no es válido")
          raise ActiveRecord::RecordInvalid, self
        end

        taggings.create!(tag: tag)
      end
    end
  end

  # @param user [User]
  # @return [ActiveRecord::Relation<Card>]
  def due_cards_for(user)
    cards.due_for(user).order("card_reviews.next_review_at ASC NULLS FIRST")
  end

  def due_count_for(user)
    due_cards_for(user).count
  end

  def mastered_count_for(user)
    card_reviews_for(user).where("card_reviews.interval > ?", MASTERY_THRESHOLD).count
  end

  def in_progress_count_for(user)
    card_reviews_for(user).where("card_reviews.interval <= ?", MASTERY_THRESHOLD).count
  end

  # Tarjetas que más cuesta recordar, para la nube de repaso. El peso de cada
  # una suma 2 por cada "No lo sabía" (quality < 3) y 1 por cada "Más o menos"
  # (quality 3). Se excluyen las ya dominadas y las que nunca se han fallado.
  #
  # @param user [User]
  # @param limit [Integer]
  # @return [Array<Hash>] ordenadas de más a menos difíciles
  def weak_cards_for(user, limit: WEAK_CARDS_LIMIT)
    ReviewLog
      .joins(card_review: { card: { category: :deck } })
      .where(decks: { id: id })
      .where(card_reviews: { user_id: user.id })
      .where("card_reviews.interval <= ?", MASTERY_THRESHOLD)
      .group("cards.id", "cards.front")
      .having(ReviewLog::DIFFICULTY_WEIGHT_SQL.gt(0))
      .order(ReviewLog::DIFFICULTY_WEIGHT_SQL.desc, "cards.id")
      .limit(limit)
      .pluck("cards.id", "cards.front", ReviewLog::DIFFICULTY_WEIGHT_SQL)
      .map { |id, front, weight| { card_id: id, front: front, weight: weight.to_i } }
  end

  private

  def card_reviews_for(user)
    CardReview
      .joins(card: { category: :deck })
      .where(decks: { id: id })
      .where(card_reviews: { user: user })
  end
end
