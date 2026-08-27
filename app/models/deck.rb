class Deck < ApplicationRecord
  belongs_to :user
  has_many :categories, dependent: :destroy
  has_many :cards, through: :categories

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, message: "ya existe un mazo con ese nombre" }


  # @param user [User]
  # @return [ActiveRecord::Relation<Card>]
  def due_cards_for(user)
    cards
      .left_joins(:card_reviews)
      .where(
        "card_reviews.id IS NULL OR (card_reviews.user_id = ? AND card_reviews.next_review_at <= ?)",
        user.id, Time.current
      )
      .order("card_reviews.next_review_at ASC NULLS FIRST")
  end

  def due_count_for(user)
    due_cards_for(user).count
  end
end
