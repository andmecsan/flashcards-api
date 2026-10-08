require "rails_helper"

RSpec.describe "Asignaturas favoritas", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:other) { create(:user, email: "otro@test.com") }

  describe "PATCH /api/v1/decks/:id/favorite" do
    it "marca la asignatura como favorita" do
      deck = create(:deck, user: user)

      patch "/api/v1/decks/#{deck.id}/favorite", params: { favorite: true }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["favorite"]).to be(true)
      expect(deck.reload.favorite).to be(true)
    end

    it "la desmarca y es idempotente" do
      deck = create(:deck, user: user, favorite: true)

      2.times { patch "/api/v1/decks/#{deck.id}/favorite", params: { favorite: false }, headers: headers }

      expect(response).to have_http_status(:ok)
      expect(deck.reload.favorite).to be(false)
    end

    it "exige indicar el valor deseado" do
      deck = create(:deck, user: user)

      patch "/api/v1/decks/#{deck.id}/favorite", headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(deck.reload.favorite).to be(false)
    end

    it "no permite marcar la asignatura de otro usuario" do
      deck = create(:deck, user: other)

      patch "/api/v1/decks/#{deck.id}/favorite", params: { favorite: true }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(deck.reload.favorite).to be(false)
    end

    it "devuelve 401 sin token" do
      deck = create(:deck, user: user)

      patch "/api/v1/decks/#{deck.id}/favorite", params: { favorite: true }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/decks" do
    let!(:normal)   { create(:deck, user: user, name: "Normal", created_at: 1.day.ago) }
    let!(:favorita) { create(:deck, user: user, name: "Favorita", favorite: true, created_at: 2.days.ago) }

    it "incluye el campo favorite en cada asignatura" do
      get "/api/v1/decks", headers: headers

      by_name = JSON.parse(response.body)["decks"].to_h { |d| [ d["name"], d["favorite"] ] }
      expect(by_name).to eq("Normal" => false, "Favorita" => true)
    end

    it "ordena primero las favoritas aunque sean más antiguas" do
      get "/api/v1/decks", headers: headers

      expect(JSON.parse(response.body)["decks"].map { |d| d["name"] }).to eq([ "Favorita", "Normal" ])
    end

    it "filtra solo las favoritas con ?favorites=1" do
      get "/api/v1/decks", params: { favorites: 1 }, headers: headers

      expect(JSON.parse(response.body)["decks"].map { |d| d["name"] }).to eq([ "Favorita" ])
    end

    it "combina el filtro de favoritas con la búsqueda" do
      create(:deck, user: user, name: "Favorita 2", favorite: true)

      get "/api/v1/decks", params: { favorites: 1, q: "2" }, headers: headers

      expect(JSON.parse(response.body)["decks"].map { |d| d["name"] }).to eq([ "Favorita 2" ])
    end

    it "no cuenta las favoritas de otro usuario" do
      create(:deck, user: other, name: "Ajena", favorite: true)

      get "/api/v1/decks", params: { favorites: 1 }, headers: headers

      expect(JSON.parse(response.body)["decks"].map { |d| d["name"] }).to eq([ "Favorita" ])
    end
  end
end
