class DeckSerializer
  def initialize(deck, user)
    @deck = deck
    @user = user
  end

  def as_json(*)
    total = @deck.cards.count
    mastered = @deck.mastered_count_for(@user)
    in_progress = @deck.in_progress_count_for(@user)
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
end