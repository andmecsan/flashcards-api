# Ranking según cómo lleva un usuario cada temario o cada una de sus etiquetas
# personales, para las nubes «Para reforzar» y «Puntos fuertes».
#
# Se miden tasas y no sumas, para no favorecer a lo que tiene más tarjetas:
#   debilidad = peso de dificultad por repaso (0..2), ver ReviewLog::DIFFICULTY_WEIGHT_SQL
#   fortaleza = media de (tasa de acierto, proporción de tarjetas dominadas)
# Solo se clasifica lo que tiene al menos MIN_REVIEWS repasos. Va a «reforzar» si
# su debilidad supera el umbral; si no, a «fuertes» si su fortaleza lo supera; en
# otro caso no aparece en ninguna lista.
class MasteryRanking
  MIN_REVIEWS = 5
  WEAK_THRESHOLD = 0.6
  STRONG_THRESHOLD = 0.6
  LIMIT = 30
  GROUPS = %i[category tag].freeze

  Entry = Struct.new(
    :id, :name, :deck_id, :deck_name, :reviews, :success_rate, :mastered, :total_cards,
    :weakness, :strength, keyword_init: true
  ) do
    def as_json(*)
      {
        id: id, name: name, deck_id: deck_id, deck_name: deck_name,
        reviews: reviews, success_rate: (success_rate * 100).round,
        mastered: mastered, total_cards: total_cards,
        weakness: weakness.round(2), strength: strength.round(2)
      }
    end
  end

  # @param user [User]
  # @param group [Symbol] :category (temarios) o :tag (etiquetas personales)
  def initialize(user, group: :category)
    raise ArgumentError, "group debe ser uno de #{GROUPS.join(', ')}" unless GROUPS.include?(group)

    @user = user
    @group = group
  end

  # @return [Hash] { weak: [...], strong: [...], total_reviews: Integer, min_reviews: Integer }
  def call
    entries = build_entries
    ranked  = entries.select { |e| e.reviews >= MIN_REVIEWS }

    weak   = ranked.select { |e| e.weakness >= WEAK_THRESHOLD }
    strong = (ranked - weak).select { |e| e.strength >= STRONG_THRESHOLD }

    {
      weak:          weak.sort_by { |e| [ -e.weakness, -e.reviews ] }.first(LIMIT).map(&:as_json),
      strong:        strong.sort_by { |e| [ -e.strength, -e.reviews ] }.first(LIMIT).map(&:as_json),
      total_reviews: entries.sum(&:reviews),
      min_reviews:   MIN_REVIEWS
    }
  end

  private

  def build_entries
    rows = @group == :tag ? tag_rows : category_rows
    ids = rows.map(&:first)
    totals   = @group == :tag ? tag_card_totals(ids) : Card.where(category_id: ids).group(:category_id).count
    mastered = @group == :tag ? tag_mastered_counts(ids) : category_mastered_counts(ids)

    rows.map do |id, name, deck_id, deck_name, reviews, weight, successes|
      total = totals.fetch(id, 0)
      done  = mastered.fetch(id, 0)
      success_rate = reviews.positive? ? successes.to_f / reviews : 0.0
      mastery      = total.positive? ? done.to_f / total : 0.0

      Entry.new(
        id: id, name: name, deck_id: deck_id, deck_name: deck_name,
        reviews: reviews, success_rate: success_rate, mastered: done, total_cards: total,
        weakness: reviews.positive? ? weight.to_f / reviews : 0.0,
        strength: (success_rate + mastery) / 2
      )
    end
  end

  # --- Por temario -----------------------------------------------------------

  def category_rows
    ReviewLog
      .joins(card_review: { card: { category: :deck } })
      .where(card_reviews: { user_id: @user.id })
      .group("categories.id", "categories.name", "decks.id", "decks.name")
      .pluck(
        "categories.id", "categories.name", "decks.id", "decks.name",
        Arel.sql("COUNT(review_logs.id)"), ReviewLog::DIFFICULTY_WEIGHT_SQL, ReviewLog::SUCCESS_COUNT_SQL
      )
      .map { |*head, reviews, weight, successes| [ *head, reviews.to_i, weight.to_i, successes.to_i ] }
  end

  def category_mastered_counts(category_ids)
    CardReview
      .joins(:card)
      .where(user_id: @user.id, cards: { category_id: category_ids })
      .where("card_reviews.interval > ?", Deck::MASTERY_THRESHOLD)
      .group("cards.category_id")
      .count
  end

  # --- Por etiqueta personal -------------------------------------------------

  def tag_rows
    rows = ReviewLog
      .joins(card_review: { card: :taggings })
      .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
      .where(card_reviews: { user_id: @user.id }, taggings: { taggable_type: "Card" }, tags: { user_id: @user.id })
      .group("tags.id", "tags.name")
      .pluck(
        "tags.id", "tags.name",
        Arel.sql("COUNT(review_logs.id)"), ReviewLog::DIFFICULTY_WEIGHT_SQL, ReviewLog::SUCCESS_COUNT_SQL
      )

    decks = main_decks(rows.map(&:first))
    rows.map do |id, name, reviews, weight, successes|
      deck_id, deck_name = decks[id]
      [ id, name, deck_id, deck_name, reviews.to_i, weight.to_i, successes.to_i ]
    end
  end

  def tag_card_totals(tag_ids)
    Tagging.where(taggable_type: "Card", tag_id: tag_ids).group(:tag_id).count
  end

  def tag_mastered_counts(tag_ids)
    CardReview
      .joins("INNER JOIN taggings ON taggings.taggable_type = 'Card' AND taggings.taggable_id = card_reviews.card_id")
      .where(user_id: @user.id, taggings: { tag_id: tag_ids })
      .where("card_reviews.interval > ?", Deck::MASTERY_THRESHOLD)
      .group("taggings.tag_id")
      .count
  end

  # Asignatura donde más tarjetas tiene cada etiqueta, para poder abrirla desde la nube.
  def main_decks(tag_ids)
    counts = Tagging
      .where(taggable_type: "Card", tag_id: tag_ids)
      .joins("INNER JOIN cards ON cards.id = taggings.taggable_id")
      .joins("INNER JOIN categories ON categories.id = cards.category_id")
      .joins("INNER JOIN decks ON decks.id = categories.deck_id")
      .group("taggings.tag_id", "decks.id", "decks.name")
      .count

    counts.group_by { |(tag_id, _), _| tag_id }.transform_values do |entries|
      (_, deck_id, deck_name), = entries.max_by { |(key, count)| [ count, -key[1] ] }
      [ deck_id, deck_name ]
    end
  end
end
