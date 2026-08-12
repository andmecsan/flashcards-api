
RSpec.describe "Api::V1::Decks", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/decks" do
    it "devuelve los mazos del usuario" do
      create(:deck, user: user, name: "Chino HSK-1")
      create(:deck, user: user, name: "Algoritmos")

      get "/api/v1/decks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)
    end

    it "no devuelve mazos de otro usuario" do
      otro_usuario = create(:user, email: "otro@test.com")
      create(:deck, user: otro_usuario, name: "Privado")

      get "/api/v1/decks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(0)
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
end