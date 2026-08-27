class CardSerializer
  def initialize(card)
    @card = card
  end

  def as_json(*)
    {
      id:          @card.id,
      front:       @card.front,
      back:        @card.back,
      category_id: @card.category_id,
      created_at:  @card.created_at
    }
  end
end
