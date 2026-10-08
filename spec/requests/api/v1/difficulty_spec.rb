require "rails_helper"

RSpec.describe "Dificultad de los temarios", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user, email: "otro@test.com") }
  let(:headers) { auth_headers(user) }
  let(:deck) { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck, name: "Tema") }

  def json = JSON.parse(response.body)

  describe "asignación" do
    it "los temarios nuevos no tienen dificultad (es opcional)" do
      post "/api/v1/decks/#{deck.id}/categories", params: { category: { name: "Nuevo" } }, headers: headers

      expect(response).to have_http_status(:created)
      expect(json["difficulty"]).to be_nil
    end

    it "PATCH /categories/:id la asigna y la quita enviándola vacía" do
      patch "/api/v1/categories/#{category.id}", params: { category: { difficulty: "hard" } }, headers: headers
      expect(json["difficulty"]).to eq("hard")
      expect(category.reload).to be_hard

      patch "/api/v1/categories/#{category.id}", params: { category: { difficulty: "" } }, headers: headers
      expect(category.reload.difficulty).to be_nil
    end

    it "rechaza un valor que no existe" do
      patch "/api/v1/categories/#{category.id}", params: { category: { difficulty: "imposible" } }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(category.reload.difficulty).to be_nil
    end

    it "no permite cambiar la dificultad del temario de otro usuario" do
      ajena = create(:category, deck: create(:deck, user: other))

      patch "/api/v1/categories/#{ajena.id}", params: { category: { difficulty: "hard" } }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(ajena.reload.difficulty).to be_nil
    end

    it "las tarjetas ya no llevan dificultad" do
      create(:card, category: category)

      get "/api/v1/categories/#{category.id}/cards", headers: headers

      expect(json.first).not_to have_key("difficulty")
    end
  end

  describe "create_topic y update_topic" do
    it "create_topic guarda la dificultad enviada" do
      post "/api/v1/decks/#{deck.id}/create_topic",
           params: { name: "Nuevo", difficulty: "easy", cards: [ { front: "A", back: "a" } ] },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["category"]["difficulty"]).to eq("easy")
    end

    it "create_topic con un valor inválido no crea nada" do
      expect {
        post "/api/v1/decks/#{deck.id}/create_topic",
             params: { name: "Nuevo", difficulty: "x", cards: [ { front: "A", back: "a" } ] },
             headers: headers, as: :json
      }.not_to change(Category, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "update_topic cambia la dificultad cuando llega" do
      patch "/api/v1/categories/#{category.id}/update_topic",
            params: { name: "Tema", difficulty: "hard", cards: [] }, headers: headers, as: :json

      expect(category.reload).to be_hard
    end

    it "update_topic conserva la dificultad si el cliente no la envía" do
      category.update!(difficulty: :medium)

      patch "/api/v1/categories/#{category.id}/update_topic",
            params: { name: "Renombrado", cards: [] }, headers: headers, as: :json

      expect(category.reload.name).to eq("Renombrado")
      expect(category).to be_medium
    end

    it "update_topic la quita si llega vacía" do
      category.update!(difficulty: :medium)

      patch "/api/v1/categories/#{category.id}/update_topic",
            params: { name: "Tema", difficulty: "", cards: [] }, headers: headers, as: :json

      expect(category.reload.difficulty).to be_nil
    end
  end

  describe "listado de temarios con ?difficulty=" do
    before do
      create(:category, deck: deck, name: "Fácil", difficulty: :easy)
      create(:category, deck: deck, name: "Difícil", difficulty: :hard)
      create(:category, deck: deck, name: "Sin definir")
    end

    it "solo devuelve los temarios de esa dificultad" do
      get "/api/v1/decks/#{deck.id}/categories", params: { difficulty: "hard" }, headers: headers

      expect(json["categories"].map { |c| c["name"] }).to eq([ "Difícil" ])
      expect(json["categories"].first["difficulty"]).to eq("hard")
    end

    it "sin filtro devuelve todos" do
      get "/api/v1/decks/#{deck.id}/categories", headers: headers

      expect(json["categories"].size).to eq(3)
    end

    it "devuelve una lista vacía si ninguno tiene esa dificultad" do
      get "/api/v1/decks/#{deck.id}/categories", params: { difficulty: "medium" }, headers: headers

      expect(json["categories"]).to eq([])
    end

    it "responde 400 con una dificultad no válida" do
      get "/api/v1/decks/#{deck.id}/categories", params: { difficulty: "x" }, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("Dificultad no válida")
    end
  end

  describe "Estudiar con ?difficulty=" do
    before do
      create(:card, category: create(:category, deck: deck, name: "Fácil", difficulty: :easy), front: "De fácil")
      create(:card, category: create(:category, deck: deck, name: "Difícil", difficulty: :hard), front: "De difícil")
      create(:card, category: create(:category, deck: deck, name: "Sin definir"), front: "De sin definir")
    end

    it "devuelve solo las pendientes de los temarios de esa dificultad" do
      get "/api/v1/decks/#{deck.id}/study", params: { difficulty: "hard" }, headers: headers

      expect(json.map { |c| c["front"] }).to eq([ "De difícil" ])
    end

    it "sin filtro devuelve todas" do
      get "/api/v1/decks/#{deck.id}/study", headers: headers

      expect(json.size).to eq(3)
    end

    it "responde 400 si la dificultad no es válida" do
      get "/api/v1/decks/#{deck.id}/study", params: { difficulty: "extrema" }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "no filtra los temarios de otro usuario" do
      otro_deck = create(:deck, user: other)

      get "/api/v1/decks/#{otro_deck.id}/study", params: { difficulty: "hard" }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/decks/:id/stats — difficulty_counts" do
    it "cuenta los temarios por dificultad y los que no tienen" do
      create(:category, deck: deck, name: "A", difficulty: :easy)
      create(:category, deck: deck, name: "B", difficulty: :hard)
      create(:category, deck: deck, name: "C", difficulty: :hard)
      create(:category, deck: deck, name: "D")

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      expect(json["difficulty_counts"]).to eq("easy" => 1, "medium" => 0, "hard" => 2, "none" => 1)
    end

    it "no cuenta temarios de otra asignatura" do
      create(:category, deck: create(:deck, user: user, name: "Otra"), difficulty: :hard)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      expect(json["difficulty_counts"]["hard"]).to eq(0)
    end
  end
end
