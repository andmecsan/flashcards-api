require "rails_helper"

RSpec.describe Tagging, type: :model do
  let(:user)  { create(:user) }
  let(:other) { create(:user, email: "otro@test.com") }
  let(:deck) { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck) }
  let(:card) { create(:card, category: category) }

  before { Tag.sync_predefined! }

  def predefined(kind, name)
    Tag.find_by!(kind: kind, name: name, user_id: nil)
  end

  describe "tarjetas" do
    it "admiten etiquetas personales de su propietario" do
      expect(Tagging.new(taggable: card, tag: Tag.for_user(user, "Examen"))).to be_valid
    end

    it "no admiten etiquetas personales de otro usuario" do
      tagging = Tagging.new(taggable: card, tag: Tag.for_user(other, "Examen"))

      expect(tagging).not_to be_valid
      expect(tagging.errors[:tag]).to be_present
    end

    it "no admiten etiquetas predefinidas" do
      expect(Tagging.new(taggable: card, tag: predefined(:area, "Ciencias"))).not_to be_valid
    end

    it "admiten como máximo 5 etiquetas" do
      5.times { |i| Tagging.create!(taggable: card, tag: Tag.for_user(user, "t#{i}")) }

      sexta = Tagging.new(taggable: card, tag: Tag.for_user(user, "t5"))

      expect(sexta).not_to be_valid
      expect(sexta.errors[:base].first).to include("como máximo 5")
    end

    it "no admiten la misma etiqueta dos veces" do
      tag = Tag.for_user(user, "Examen")
      Tagging.create!(taggable: card, tag: tag)

      expect(Tagging.new(taggable: card, tag: tag)).not_to be_valid
    end
  end

  describe "asignaturas" do
    it "admiten área, nivel y curso" do
      expect(Tagging.new(taggable: deck, tag: predefined(:area, "Idiomas"))).to be_valid
      expect(Tagging.new(taggable: deck, tag: predefined(:level, "B2"))).to be_valid
      expect(Tagging.new(taggable: deck, tag: predefined(:course, "2.º"))).to be_valid
    end

    it "los temarios no admiten ninguna etiqueta" do
      expect(Tagging.new(taggable: category, tag: predefined(:area, "Idiomas"))).not_to be_valid
    end

    it "no admiten etiquetas personales" do
      expect(Tagging.new(taggable: deck, tag: Tag.for_user(user, "Examen"))).not_to be_valid
    end

    it "solo admiten una de cada tipo" do
      Tagging.create!(taggable: deck, tag: predefined(:level, "Grado"))

      segundo = Tagging.new(taggable: deck, tag: predefined(:level, "Bachillerato"))

      expect(segundo).not_to be_valid
      expect(segundo.errors[:base].first).to include("solo admite un level")
    end

    it "admiten a la vez un área, un nivel y un curso" do
      [ predefined(:area, "Ciencias"), predefined(:level, "Grado"), predefined(:course, "1.º") ].each do |tag|
        Tagging.create!(taggable: deck, tag: tag)
      end

      expect(deck.reload.tags.map(&:kind)).to contain_exactly("area", "level", "course")
    end
  end

  describe "Card#replace_personal_tags!" do
    it "sustituye las etiquetas y crea las nuevas" do
      card.replace_personal_tags!([ "A", "B" ])
      card.replace_personal_tags!([ "B", "C" ])

      expect(card.reload.tags.map(&:name)).to contain_exactly("B", "C")
    end

    it "vacío quita todas" do
      card.replace_personal_tags!([ "A" ])
      card.replace_personal_tags!([])

      expect(card.reload.tags).to be_empty
    end

    it "no duplica por mayúsculas o tildes" do
      card.replace_personal_tags!([ "Examen", "examen", "EXÁMEN" ])

      expect(card.reload.tags.size).to eq(1)
    end

    it "rechaza más de 5 etiquetas sin dejar cambios a medias" do
      card.replace_personal_tags!([ "A" ])

      expect { card.replace_personal_tags!(%w[a b c d e f]) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(card.reload.tags.map(&:name)).to eq([ "A" ])
    end
  end

  describe "Deck#assign_predefined_tags!" do
    it "asigna y cambia el área, y la quita con vacío" do
      ciencias = predefined(:area, "Ciencias")
      idiomas  = predefined(:area, "Idiomas")

      deck.assign_predefined_tags!(area: ciencias.id)
      deck.assign_predefined_tags!(area: idiomas.id)
      expect(deck.reload.tags.map(&:name)).to eq([ "Idiomas" ])

      deck.assign_predefined_tags!(area: "")
      expect(deck.reload.tags).to be_empty
    end

    it "no toca los tipos que no se envían" do
      deck.assign_predefined_tags!(area: predefined(:area, "Ciencias").id, level: predefined(:level, "Grado").id)

      deck.assign_predefined_tags!(level: predefined(:level, "ESO").id)

      expect(deck.reload.tags.map(&:name)).to contain_exactly("Ciencias", "ESO")
    end

    it "rechaza un id de otro tipo" do
      expect { deck.assign_predefined_tags!(area: predefined(:level, "Grado").id) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "rechaza una etiqueta personal" do
      expect { deck.assign_predefined_tags!(area: Tag.for_user(user, "X").id) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  it "al borrar la cuenta se eliminan sus etiquetas y uniones" do
    card.replace_personal_tags!([ "A" ])

    expect { user.destroy }.to change(Tag, :count).by(-1).and change(Tagging, :count).by(-1)
  end
end
