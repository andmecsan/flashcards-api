class ReviewLog < ApplicationRecord
  # Calificación mínima que cuenta como acierto en las estadísticas ("Lo sabía").
  SUCCESS_QUALITY = 4
  SUCCESS_COUNT_SQL = Arel.sql(
    "SUM(CASE WHEN review_logs.quality >= #{SUCCESS_QUALITY} THEN 1 ELSE 0 END)"
  )

  # Peso de dificultad de un repaso: 2 por cada "No lo sabía" (quality < 3) y 1
  # por cada "Más o menos" (quality 3). Se define como nodo Arel para reutilizarlo
  # en SUM / HAVING / ORDER sin interpolar SQL.
  DIFFICULTY_WEIGHT_SQL = Arel.sql(
    "SUM(CASE WHEN review_logs.quality < 3 THEN 2 WHEN review_logs.quality = 3 THEN 1 ELSE 0 END)"
  )

  belongs_to :card_review

  validates :quality,     presence: true,
                          inclusion: { in: 0..5, message: "debe ser entre 0 y 5" }
  validates :reviewed_at, presence: true
end
