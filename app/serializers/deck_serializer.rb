class DeckSerializer
  def initialize(deck, user)
    @deck = deck
    @user = user
  end

  def as_json(*)
    {
      id:          @deck.id,
      name:        @deck.name,
      description: @deck.description,
      card_count:  @deck.cards.count,
      due_count:   @deck.due_count_for(@user),
      created_at:  @deck.created_at
    }
  end
end
