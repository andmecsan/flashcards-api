class Deck < ApplicationRecord
  belongs_to :user
  has_many   :cards, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, message: "ya existe un mazo con ese nombre" }


  # @param user [User]
  # @return [ActiveRecord::Relation<Card>]
  def due_cards_for(user)
    cards
      .joins(:card_reviews)
      .where(card_reviews: { user: user })
      .where("card_reviews.next_review_at <= ?", Time.current)
      .order("card_reviews.next_review_at ASC")
  end

  def due_count_for(user)
    due_cards_for(user).count
  end
end