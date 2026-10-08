class CardStudySerializer
  def initialize(card, user)
    @card = card
    @user = user
  end

  def as_json(*)
    review = @card.review_for(@user)
    {
      id:          @card.id,
      front:       @card.front,
      back:        @card.back,
      tags:        @card.tags.map(&:name).sort_by(&:downcase),
      category:    @card.category.name,
      interval:    review.interval,
      repetitions: review.repetitions,
      easiness:    review.easiness
    }
  end
end
