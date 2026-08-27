class CategorySerializer
  def initialize(category)
    @category = category
  end

  def as_json(*)
    {
      id:         @category.id,
      name:       @category.name,
      deck_id:    @category.deck_id,
      card_count: @category.cards.count,
      created_at: @category.created_at
    }
  end
end
