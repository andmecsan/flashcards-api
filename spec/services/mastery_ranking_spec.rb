require "rails_helper"

RSpec.describe MasteryRanking do
  let(:user)  { create(:user) }
  let(:other) { create(:user, email: "otro@test.com") }
  let(:deck)  { create(:deck, user: user, name: "Chino") }

  def category(name, cards: 1, deck: self.deck)
    cat = create(:category, deck: deck, name: name)
    Array.new(cards) { |i| create(:card, category: cat, front: "#{name}-#{i}", back: "R") }
    cat
  end

  # Aplica una secuencia de calificaciones a una tarjeta, generando un log por cada una.
  def study(card, qualities, owner: user)
    review = CardReview.create!(
      card: card, user: owner, repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current
    )
    qualities.each { |q| review.apply_review!(q) }
    review
  end

  subject(:result) { described_class.new(user).call }

  it "devuelve listas vacías y cero repasos si el usuario no ha estudiado" do
    category("Sin estudiar")

    expect(result).to include(weak: [], strong: [], total_reviews: 0, min_reviews: 5)
  end

  it "no clasifica temarios con menos repasos que el mínimo" do
    study(category("Poco").cards.first, [ 1, 1, 1, 1 ])

    expect(result[:weak]).to be_empty
    expect(result[:total_reviews]).to eq(4)
  end

  it "pone en «reforzar» el temario con muchos fallos y calcula sus datos" do
    cat = category("Difícil")
    study(cat.cards.first, [ 1, 1, 1, 1, 1 ])

    weak = result[:weak].first
    expect(weak).to include(id: cat.id, name: "Difícil", deck_name: "Chino", reviews: 5, success_rate: 0)
    expect(weak[:weakness]).to eq(2.0)
    expect(result[:strong]).to be_empty
  end

  it "pone en «fuertes» el temario con muchos aciertos y tarjetas dominadas" do
    cat = category("Fácil")
    study(cat.cards.first, [ 5, 5, 5, 5, 5 ])

    strong = result[:strong].first
    expect(strong).to include(id: cat.id, name: "Fácil", reviews: 5, success_rate: 100, mastered: 1, total_cards: 1)
    expect(strong[:strength]).to eq(1.0)
    expect(result[:weak]).to be_empty
  end

  it "deja fuera de ambas listas a los temarios intermedios" do
    cat = category("Regular", cards: 2)
    study(cat.cards.first, [ 5, 5, 5, 3, 3 ])

    expect(result[:weak]).to be_empty
    expect(result[:strong]).to be_empty
  end

  it "no mete un mismo temario en las dos listas" do
    cat = category("Mixto")
    study(cat.cards.first, [ 1, 1, 1, 5, 5, 5, 5, 5 ])

    names = (result[:weak] + result[:strong]).map { |e| e[:name] }
    expect(names).to eq(names.uniq)
  end

  it "ordena «reforzar» de más a menos débil y «fuertes» de más a menos fuerte" do
    peor   = category("Peor");   study(peor.cards.first,   [ 1, 1, 1, 1, 1 ])
    mejor  = category("Mejor");  study(mejor.cards.first,  [ 3, 3, 3, 3, 3 ])
    fuerte = category("Fuerte"); study(fuerte.cards.first, [ 5, 5, 5, 5, 5 ])

    expect(result[:weak].map { |e| e[:name] }).to eq([ "Peor", "Mejor" ])
    expect(result[:strong].map { |e| e[:name] }).to eq([ "Fuerte" ])
    expect([ peor, mejor, fuerte ]).to all(be_persisted)
  end

  it "usa tasas, no sumas: un temario grande con la misma tasa no pasa por delante" do
    pequeno = category("Pequeño"); study(pequeno.cards.first, [ 1, 1, 1, 1, 1 ])
    grande  = category("Grande", cards: 3)
    grande.cards.each { |c| study(c, [ 3, 3, 3, 3, 3 ]) }

    expect(result[:weak].first[:name]).to eq("Pequeño")
  end

  it "incluye temarios de varias asignaturas con el nombre de la asignatura" do
    otra = create(:deck, user: user, name: "Algoritmos")
    cat = category("Árboles", deck: otra)
    study(cat.cards.first, [ 1, 1, 1, 1, 1 ])

    expect(result[:weak].first).to include(name: "Árboles", deck_name: "Algoritmos", deck_id: otra.id)
  end

  it "no mezcla los repasos de otros usuarios" do
    cat = category("Compartido")
    study(cat.cards.first, [ 1, 1, 1, 1, 1 ], owner: other)

    expect(result[:weak]).to be_empty
    expect(result[:total_reviews]).to eq(0)
  end

  it "limita cada lista a 30 temarios" do
    35.times { |i| study(category("T#{i}").cards.first, [ 1, 1, 1, 1, 1 ]) }

    expect(result[:weak].size).to eq(30)
  end

  describe "agrupando por etiqueta personal" do
    subject(:by_tag) { described_class.new(user, group: :tag).call }

    def tagged_card(tag_names, category: category_for("Tema"), front: "Q")
      create(:card, category: category, front: front, back: "R").tap { |c| c.replace_personal_tags!(tag_names) }
    end

    def category_for(name, deck: self.deck)
      Category.find_by(deck: deck, name: name) || create(:category, deck: deck, name: name)
    end

    it "devuelve vacío si ninguna tarjeta repasada tiene etiquetas" do
      study(create(:card, category: category_for("Tema")), [ 1, 1, 1, 1, 1 ])

      expect(by_tag).to include(weak: [], strong: [], total_reviews: 0)
    end

    it "pone en «reforzar» la etiqueta cuyas tarjetas se fallan" do
      card = tagged_card([ "Fórmulas" ])
      study(card, [ 1, 1, 1, 1, 1 ])

      weak = by_tag[:weak].first
      expect(weak).to include(name: "Fórmulas", reviews: 5, success_rate: 0, total_cards: 1)
      expect(weak[:weakness]).to eq(2.0)
    end

    it "pone en «fuertes» la etiqueta con aciertos y tarjetas dominadas" do
      study(tagged_card([ "Fáciles" ]), [ 5, 5, 5, 5, 5 ])

      strong = by_tag[:strong].first
      expect(strong).to include(name: "Fáciles", reviews: 5, success_rate: 100, mastered: 1, total_cards: 1)
    end

    it "suma los repasos de todas las tarjetas con la etiqueta, aunque sean de distintos temarios" do
      study(tagged_card([ "Mixta" ], category: category_for("A"), front: "1"), [ 1, 1, 1 ])
      study(tagged_card([ "Mixta" ], category: category_for("B"), front: "2"), [ 1, 1, 1 ])

      expect(by_tag[:weak].first).to include(name: "Mixta", reviews: 6, total_cards: 2)
    end

    it "una tarjeta con dos etiquetas cuenta en ambas" do
      study(tagged_card([ "Uno", "Dos" ]), [ 1, 1, 1, 1, 1 ])

      expect(by_tag[:weak].map { |e| e[:name] }).to contain_exactly("Uno", "Dos")
    end

    it "indica la asignatura donde la etiqueta tiene más tarjetas" do
      otra = create(:deck, user: user, name: "Otra")
      principal = category_for("P")
      study(tagged_card([ "Viaja" ], category: principal, front: "1"), [ 1, 1, 1 ])
      study(tagged_card([ "Viaja" ], category: principal, front: "2"), [ 1, 1, 1 ])
      study(tagged_card([ "Viaja" ], category: category_for("O", deck: otra), front: "3"), [ 1, 1, 1 ])

      expect(by_tag[:weak].first).to include(deck_id: deck.id, deck_name: "Chino")
    end

    it "no cuenta etiquetas ni repasos de otros usuarios" do
      ajeno_deck = create(:deck, user: other, name: "Ajeno")
      ajena = create(:card, category: create(:category, deck: ajeno_deck, name: "T"))
      ajena.replace_personal_tags!([ "Privada" ])
      study(ajena, [ 1, 1, 1, 1, 1 ], owner: other)

      expect(by_tag).to include(weak: [], strong: [], total_reviews: 0)
    end

    it "no clasifica etiquetas con menos repasos que el mínimo" do
      study(tagged_card([ "Poco" ]), [ 1, 1 ])

      expect(by_tag[:weak]).to be_empty
      expect(by_tag[:total_reviews]).to eq(2)
    end

    it "rechaza una agrupación desconocida" do
      expect { described_class.new(user, group: :deck) }.to raise_error(ArgumentError)
    end
  end
end
