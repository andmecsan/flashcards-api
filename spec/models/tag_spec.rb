require "rails_helper"

RSpec.describe Tag, type: :model do
  let(:user)  { create(:user) }
  let(:other) { create(:user, email: "otro@test.com") }

  describe ".slugify" do
    it "pasa a minúsculas, quita tildes y colapsa espacios" do
      expect(Tag.slugify("  Exámen   FINAL ")).to eq("examen final")
    end

    it "no altera el chino ni el japonés" do
      expect(Tag.slugify("爸爸")).to eq("爸爸")
      expect(Tag.slugify("が")).to eq("が")
    end
  end

  describe ".for_user" do
    it "crea la etiqueta personal si no existe" do
      tag = Tag.for_user(user, "Examen")

      expect(tag).to be_persisted
      expect(tag).to be_personal
      expect(tag.user).to eq(user)
    end

    it "reutiliza la existente aunque cambien mayúsculas, tildes o espacios" do
      original = Tag.for_user(user, "Examen")

      expect(Tag.for_user(user, "examen")).to eq(original)
      expect(Tag.for_user(user, "  EXÁMEN ")).to eq(original)
      expect(Tag.where(user: user).count).to eq(1)
    end

    it "no comparte etiquetas entre usuarios" do
      expect(Tag.for_user(user, "Examen")).not_to eq(Tag.for_user(other, "Examen"))
    end

    it "rechaza nombres vacíos o demasiado largos" do
      expect { Tag.for_user(user, "   ") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { Tag.for_user(user, "a" * 31) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "validaciones por tipo" do
    it "una personal necesita usuario" do
      expect(Tag.new(name: "X", kind: :personal)).not_to be_valid
    end

    it "una predefinida no admite usuario" do
      expect(Tag.new(name: "X", kind: :area, user: user)).not_to be_valid
    end

    it "no admite dos personales con el mismo nombre normalizado para un usuario" do
      Tag.for_user(user, "Examen")

      expect(Tag.new(name: "examen", kind: :personal, user: user)).not_to be_valid
    end
  end

  describe ".sync_predefined!" do
    it "crea el vocabulario inicial: 7 áreas, 13 niveles y 6 cursos" do
      Tag.sync_predefined!

      expect(Tag.predefined.area.count).to eq(7)
      expect(Tag.predefined.level.count).to eq(13)
      expect(Tag.predefined.course.count).to eq(6)
    end

    it "es idempotente" do
      Tag.sync_predefined!

      expect { Tag.sync_predefined!; Tag.sync_predefined! }.not_to change(Tag, :count)
    end

    it "no toca las etiquetas personales" do
      Tag.for_user(user, "Ciencias")

      Tag.sync_predefined!

      expect(Tag.personal.where(user: user).pluck(:name)).to eq([ "Ciencias" ])
    end

    it "da color a cada etiqueta predefinida, hexadecimal y propio de cada área" do
      Tag.sync_predefined!

      expect(Tag.predefined.pluck(:color)).to all(match(/\A#\h{6}\z/))
      expect(Tag.predefined.area.pluck(:color).uniq.size).to eq(7)
    end

    it "las etiquetas personales no llevan color" do
      expect(Tag.for_user(user, "Examen").color).to be_nil
    end

    it "distingue niveles de idioma y etapas" do
      Tag.sync_predefined!

      expect(Tag.find_by(name: "B2", kind: :level)).to be_language_level
      expect(Tag.find_by(name: "Grado", kind: :level)).not_to be_language_level
    end
  end
end
