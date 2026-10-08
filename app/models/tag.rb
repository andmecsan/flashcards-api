# Etiqueta de dos tipos:
#   * personal: la crea libremente un usuario, es solo suya y va en sus tarjetas.
#   * predefinida (area / level / course): vocabulario controlado del sistema,
#     sin usuario, que se elige al describir un temario.
class Tag < ApplicationRecord
  MAX_NAME_LENGTH = 30

  # Vocabulario controlado inicial. Se carga con `Tag.sync_predefined!` (seeds).
  PREDEFINED = {
    area: [
      "Ciencias", "Ciencias de la Salud", "Ciencias Sociales y Jurídicas",
      "Ingeniería y Arquitectura", "Artes y Humanidades", "Idiomas", "Otros"
    ],
    level: [
      "ESO", "Bachillerato", "Formación Profesional", "Grado", "Máster y doctorado",
      "Oposiciones", "Otro", "A1", "A2", "B1", "B2", "C1", "C2"
    ],
    course: [ "1.º", "2.º", "3.º", "4.º", "5.º", "6.º" ]
  }.freeze

  # Color (hex) de cada etiqueta predefinida, para mostrarla como chip. Las que
  # no aparecen aquí usan el color de su tipo.
  COLORS = {
    area: {
      "Ciencias" => "#2563EB", "Ciencias de la Salud" => "#E11D48", "Ciencias Sociales y Jurídicas" => "#D97706",
      "Ingeniería y Arquitectura" => "#EA580C", "Artes y Humanidades" => "#C026D3", "Idiomas" => "#059669",
      "Otros" => "#64748B"
    },
    level: {
      "ESO" => "#0EA5E9", "Bachillerato" => "#3B82F6", "Formación Profesional" => "#6366F1", "Grado" => "#8B5CF6",
      "Máster y doctorado" => "#A855F7", "Oposiciones" => "#D946EF", "Otro" => "#64748B",
      "A1" => "#65A30D", "A2" => "#16A34A", "B1" => "#0D9488", "B2" => "#0891B2", "C1" => "#0284C7", "C2" => "#4F46E5"
    },
    course: Hash.new("#64748B")
  }.freeze

  # Niveles que son de idioma (MCER); el resto son etapas académicas.
  LANGUAGE_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

  enum :kind, { personal: 0, area: 1, level: 2, course: 3 }

  belongs_to :user, optional: true
  has_many :taggings, dependent: :destroy

  before_validation :assign_slug

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :slug, presence: true
  validates :slug, uniqueness: { scope: [ :user_id, :kind ], message: "ya existe" }
  validate :user_matches_kind

  scope :predefined, -> { where.not(kind: :personal).where(user_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  # Forma normalizada para comparar nombres: sin mayúsculas, sin tildes en
  # letras latinas (conserva ñ→n pero no toca CJK ni kana) y con espacios colapsados.
  def self.slugify(name)
    name.to_s.unicode_normalize(:nfkd)
        .gsub(/(?<=\p{Latin})\p{Mn}+/, "")
        .downcase
        .gsub(/\s+/, " ")
        .strip
        .unicode_normalize(:nfc)
  end

  # Devuelve la etiqueta personal del usuario con ese nombre (creándola si no
  # existe), de modo que «Examen», «examen» y «exámen» son la misma.
  #
  # @raise [ActiveRecord::RecordInvalid] si el nombre está vacío o es demasiado largo
  def self.for_user(user, name)
    clean = name.to_s.squish
    existing = personal.find_by(user_id: user.id, slug: slugify(clean))
    existing || create!(user: user, kind: :personal, name: clean)
  end

  # Crea o actualiza el vocabulario controlado. Idempotente.
  def self.sync_predefined!
    PREDEFINED.each do |kind, names|
      names.each_with_index do |name, position|
        tag = find_or_initialize_by(kind: kind, user_id: nil, slug: slugify(name))
        tag.update!(name: name, position: position, color: COLORS.dig(kind, name))
      end
    end
  end

  def predefined?
    !personal? && user_id.nil?
  end

  def language_level?
    level? && LANGUAGE_LEVELS.include?(name)
  end

  private

  def assign_slug
    self.slug = self.class.slugify(name) if name_changed? || slug.blank?
  end

  def user_matches_kind
    if personal? && user_id.nil?
      errors.add(:user, "es obligatorio en una etiqueta personal")
    elsif !personal? && user_id.present?
      errors.add(:user, "no se permite en una etiqueta predefinida")
    end
  end
end
