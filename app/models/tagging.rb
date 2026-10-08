# Unión entre una etiqueta y una tarjeta o una asignatura. Aquí está la única
# fuente de verdad de qué etiquetas admite cada cosa.
class Tagging < ApplicationRecord
  MAX_TAGS_PER_CARD = 5

  belongs_to :tag
  belongs_to :taggable, polymorphic: true

  validates :tag_id, uniqueness: { scope: [ :taggable_type, :taggable_id ] }
  validate :tag_fits_taggable

  private

  def tag_fits_taggable
    case taggable
    when Card then validate_for_card
    when Deck then validate_for_deck
    else errors.add(:taggable, "no admite etiquetas")
    end
  end

  # Una tarjeta solo admite etiquetas personales de su propietario (máx. 5).
  def validate_for_card
    unless tag.personal? && tag.user_id == taggable.owner&.id
      errors.add(:tag, "debe ser una etiqueta personal del propietario de la tarjeta")
    end

    if taggable.taggings.where.not(id: id).count >= MAX_TAGS_PER_CARD
      errors.add(:base, "Una tarjeta admite como máximo #{MAX_TAGS_PER_CARD} etiquetas")
    end
  end

  # Una asignatura solo admite etiquetas predefinidas, como mucho una de cada tipo.
  def validate_for_deck
    unless tag.predefined?
      errors.add(:tag, "debe ser un área, un nivel o un curso")
      return
    end

    same_kind = taggable.taggings.joins(:tag).where(tags: { kind: Tag.kinds[tag.kind] }).where.not(id: id)
    errors.add(:base, "Una asignatura solo admite un #{tag.kind} a la vez") if same_kind.exists?
  end
end
