
RSpec.describe "Api::V1::Decks", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/decks" do
    it "devuelve los mazos del usuario" do
      create(:deck, user: user, name: "Chino HSK-1")
      create(:deck, user: user, name: "Algoritmos")

      get "/api/v1/decks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["decks"].size).to eq(2)
    end

    it "no devuelve mazos de otro usuario" do
      otro_usuario = create(:user, email: "otro@test.com")
      create(:deck, user: otro_usuario, name: "Privado")

      get "/api/v1/decks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["decks"].size).to eq(0)
    end

    it "devuelve 401 sin token" do
      get "/api/v1/decks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/decks" do
    it "crea un mazo" do
      params = { deck: { name: "Nuevo mazo", description: "Descripción" } }

      post "/api/v1/decks", params: params, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Nuevo mazo")
      expect(body["card_count"]).to eq(0)
    end

    it "no permite nombres duplicados" do
      create(:deck, user: user, name: "Duplicado")
      params = { deck: { name: "Duplicado" } }

      post "/api/v1/decks", params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/decks/:id" do
    it "elimina el mazo" do
      deck = create(:deck, user: user)

      delete "/api/v1/decks/#{deck.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Deck.exists?(deck.id)).to be false
    end

    it "no permite eliminar mazos de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      deck = create(:deck, user: otro)

      delete "/api/v1/decks/#{deck.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/decks/:id" do
    it "muestra un mazo propio" do
      deck = create(:deck, user: user, name: "Chino HSK-1")

      get "/api/v1/decks/#{deck.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Chino HSK-1")
    end

    it "no permite ver un mazo de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      deck = create(:deck, user: otro)

      get "/api/v1/decks/#{deck.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/decks/:id" do
    it "actualiza un mazo" do
      deck = create(:deck, user: user, name: "Nombre viejo")

      patch "/api/v1/decks/#{deck.id}", params: { deck: { name: "Nombre nuevo" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Nombre nuevo")
    end

    it "no permite actualizar un mazo de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      deck = create(:deck, user: otro, name: "Original")

      patch "/api/v1/decks/#{deck.id}", params: { deck: { name: "Hackeado" } }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(deck.reload.name).to eq("Original")
    end
  end

  describe "GET /api/v1/decks/:id/study" do
    it "devuelve las tarjetas pendientes de repaso de un mazo propio" do
      deck = create(:deck, user: user)
      category = create(:category, deck: deck)
      create(:card, category: category)

      get "/api/v1/decks/#{deck.id}/study", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "no permite estudiar un mazo de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      deck = create(:deck, user: otro)

      get "/api/v1/decks/#{deck.id}/study", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/decks/:id/create_topic" do
    it "crea un temario con sus tarjetas en una sola petición" do
      deck = create(:deck, user: user)
      params = { name: "Verbos", cards: [ { front: "Ser", back: "To be" }, { front: "Estar", back: "To be" } ] }

      post "/api/v1/decks/#{deck.id}/create_topic", params: params, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["category"]["name"]).to eq("Verbos")
      expect(body["cards"].size).to eq(2)
    end

    it "no permite crear un temario en un mazo de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      deck = create(:deck, user: otro)
      params = { name: "Intruso", cards: [] }

      post "/api/v1/decks/#{deck.id}/create_topic", params: params, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(deck.categories.count).to eq(0)
    end
  end
end
