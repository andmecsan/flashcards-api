class CategorySerializer
  # @param tag_id [Integer, String, nil] si se indica, solo las tarjetas con esa etiqueta personal
  def initialize(category, tag_id: nil)
    @category = category
    @tag_id = tag_id.presence
  end

  def as_json(*)
    {
      id:         @category.id,
      name:       @category.name,
      deck_id:    @category.deck_id,
      difficulty: @category.difficulty,
      card_count: cards.count,
      created_at: @category.created_at
    }
  end

  private

  def cards
    scope = @category.cards
    scope = scope.where(id: Tagging.where(tag_id: @tag_id, taggable_type: "Card").select(:taggable_id)) if @tag_id
    scope
  end
end
