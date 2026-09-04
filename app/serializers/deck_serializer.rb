class DeckSerializer
  def initialize(deck, user)
    @deck = deck
    @user = user
  end

  def as_json(*)
    total = @deck.cards.count
    mastered = mastered_count
    in_progress = in_progress_count
    new_cards = total - mastered - in_progress

    {
      id:          @deck.id,
      name:        @deck.name,
      icon:        @deck.icon,
      color:       @deck.color,
      card_count:  total,
      due_count:   @deck.due_count_for(@user),
      mastered:    mastered,
      in_progress: in_progress,
      new_cards:   new_cards,
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

  def in_progress_count
    CardReview
      .joins(card: { category: :deck })
      .where(decks: { id: @deck.id })
      .where(card_reviews: { user: @user })
      .where("card_reviews.interval <= ?", 21)
      .count
  end
end