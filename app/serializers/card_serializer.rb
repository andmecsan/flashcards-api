class CardSerializer
  def initialize(card)
    @card = card
  end

  def as_json(*)
    {
      id:         @card.id,
      front:      @card.front,
      back:       @card.back,
      deck_id:    @card.deck_id,
      created_at: @card.created_at
    }
  end
end