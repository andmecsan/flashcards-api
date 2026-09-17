class Deck < ApplicationRecord
  MASTERY_THRESHOLD = 21

  belongs_to :user
  has_many :categories, dependent: :destroy
  has_many :cards, through: :categories

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, message: "ya existe un mazo con ese nombre" }

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

  private

  def card_reviews_for(user)
    CardReview
      .joins(card: { category: :deck })
      .where(decks: { id: id })
      .where(card_reviews: { user: user })
  end
end
