class DeckSerializer
  def initialize(deck, user)
    @deck = deck
    @user = user
  end

  def as_json(*)
    total = @deck.cards.count
    mastered = mastered_count

    {
      id:          @deck.id,
      name:        @deck.name,
      description: @deck.description,
      card_count:  total,
      due_count:   @deck.due_count_for(@user),
      mastered:    mastered,
      progress:    total > 0 ? (mastered.to_f / total * 100).round(1) : 0,
      created_at:  @deck.created_at
    }
  end

  private

  def mastered_count
    CardReview
      .joins(card: { category: :deck })
      .where(decks: { id: @deck.id })
      .where(card_reviews: { user: @user })
      .where("card_reviews.interval > ?", 21)
      .count
  end
end