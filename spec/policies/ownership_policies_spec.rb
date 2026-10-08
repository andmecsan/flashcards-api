require "rails_helper"

# Matriz de permisos: propietario / otro usuario / anónimo, para cada acción de
# cada recurso. Mientras no existan temarios públicos, todo es solo del propietario.
RSpec.describe "Policies de propiedad" do
  let(:owner)    { create(:user, email: "dueno@test.com") }
  let(:stranger) { create(:user, email: "otro@test.com") }

  let(:deck)     { create(:deck, user: owner) }
  let(:category) { create(:category, deck: deck) }
  let(:card)     { create(:card, category: category) }

  def allowed?(policy_class, user, record, action)
    policy_class.new(user, record).public_send("#{action}?")
  end

  {
    DeckPolicy     => { record: :deck,     actions: %i[show update destroy study stats create_topic create] },
    CategoryPolicy => { record: :category, actions: %i[show update destroy update_topic review_cards move create] },
    CardPolicy     => { record: :card,     actions: %i[show update destroy review create] }
  }.each do |policy_class, config|
    describe policy_class do
      config[:actions].each do |action|
        context "##{action}?" do
          it "permite al propietario" do
            expect(allowed?(policy_class, owner, send(config[:record]), action)).to be(true)
          end

          it "deniega a otro usuario" do
            expect(allowed?(policy_class, stranger, send(config[:record]), action)).to be(false)
          end

          it "deniega a un usuario anónimo" do
            expect(allowed?(policy_class, nil, send(config[:record]), action)).to be(false)
          end
        end
      end
    end
  end

  describe "listados (index?)" do
    it "se permiten a cualquier usuario autenticado y se deniegan al anónimo" do
      [ DeckPolicy, CategoryPolicy, CardPolicy ].each do |policy_class|
        expect(policy_class.new(owner, nil).index?).to be(true)
        expect(policy_class.new(nil, nil).index?).to be(false)
      end
    end
  end

  describe "CardPolicy#generate?" do
    it "solo exige estar autenticado" do
      expect(CardPolicy.new(stranger, Card).generate?).to be(true)
      expect(CardPolicy.new(nil, Card).generate?).to be(false)
    end
  end

  describe "scopes" do
    before { card }

    it "DeckPolicy::Scope devuelve solo las asignaturas del usuario" do
      expect(DeckPolicy::Scope.new(owner, Deck).resolve).to contain_exactly(deck)
      expect(DeckPolicy::Scope.new(stranger, Deck).resolve).to be_empty
    end

    it "CategoryPolicy::Scope devuelve solo los temarios del usuario" do
      expect(CategoryPolicy::Scope.new(owner, Category).resolve).to contain_exactly(category)
      expect(CategoryPolicy::Scope.new(stranger, Category).resolve).to be_empty
    end

    it "CardPolicy::Scope devuelve solo las tarjetas del usuario" do
      expect(CardPolicy::Scope.new(owner, Card).resolve).to contain_exactly(card)
      expect(CardPolicy::Scope.new(stranger, Card).resolve).to be_empty
    end

    it "los scopes devuelven vacío para un usuario anónimo" do
      expect(DeckPolicy::Scope.new(nil, Deck).resolve).to be_empty
      expect(CategoryPolicy::Scope.new(nil, Category).resolve).to be_empty
      expect(CardPolicy::Scope.new(nil, Card).resolve).to be_empty
    end
  end
end
