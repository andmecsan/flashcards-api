class Card < ApplicationRecord
  belongs_to :category
  has_one :deck, through: :category
  has_many :card_reviews, dependent: :destroy
  has_one :user, through: :deck

  validates :front, presence: true
  validates :back,  presence: true

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
