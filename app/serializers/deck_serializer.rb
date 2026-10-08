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
      favorite:    @deck.favorite,
      area:        predefined(:area),
      level:       predefined(:level),
      course:      predefined(:course),
      card_count:  total,
      due_count:   @deck.due_count_for(@user),
      mastered:    mastered,
      in_progress: in_progress,
      new_cards:   new_cards,
      created_at:  @deck.created_at
    }
  end

  private

  # Etiqueta predefinida (área, nivel o curso) de la asignatura, o nil si no la tiene.
  def predefined(kind)
    tag = @deck.tags.detect { |t| t.kind == kind.to_s }
    tag && TagSerializer.new(tag).as_json
  end
end
