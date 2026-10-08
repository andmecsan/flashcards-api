class CardSerializer
  def initialize(card)
    @card = card
  end

  def as_json(*)
    {
      id:          @card.id,
      front:       @card.front,
      back:        @card.back,
      tags:        @card.tags.map(&:name).sort_by(&:downcase),
      category_id: @card.category_id,
      created_at:  @card.created_at
    }
  end
end
