class ReviewSerializer
  def initialize(review)
    @review = review
  end

  def as_json(*)
    {
      next_review_at: @review.next_review_at,
      interval:       @review.interval,
      easiness:       @review.easiness,
      repetitions:    @review.repetitions
    }
  end
end
