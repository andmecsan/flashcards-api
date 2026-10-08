require "rails_helper"

RSpec.describe "Búsqueda y paginación de listados", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  def names(key)
    JSON.parse(response.body)[key].map { |r| r["name"] }
  end

  describe "GET /api/v1/decks" do
    before do
      create(:deck, user: user, name: "Chino HSK-1")
      create(:deck, user: user, name: "100% Álgebra")
      create(:deck, user: user, name: "Cálculo_II")
    end

    it "busca sin distinguir mayúsculas" do
      get "/api/v1/decks", params: { q: "chino" }, headers: headers

      expect(names("decks")).to eq([ "Chino HSK-1" ])
    end

    it "trata % como texto y no como comodín" do
      get "/api/v1/decks", params: { q: "%" }, headers: headers

      expect(names("decks")).to eq([ "100% Álgebra" ])
    end

    it "trata _ como texto y no como comodín" do
      get "/api/v1/decks", params: { q: "_" }, headers: headers

      expect(names("decks")).to eq([ "Cálculo_II" ])
    end

    it "limita per_page a 100 y corrige valores no válidos" do
      get "/api/v1/decks", params: { per_page: 5000, page: -3 }, headers: headers

      meta = JSON.parse(response.body)["meta"]
      expect(meta["per_page"]).to eq(100)
      expect(meta["page"]).to eq(1)
      expect(meta["total"]).to eq(3)
    end

    it "pagina y calcula total_pages" do
      get "/api/v1/decks", params: { per_page: 2, page: 2 }, headers: headers

      body = JSON.parse(response.body)
      expect(body["decks"].size).to eq(1)
      expect(body["meta"]).to include("page" => 2, "per_page" => 2, "total" => 3, "total_pages" => 2)
    end
  end

  describe "GET /api/v1/decks/:deck_id/categories" do
    it "aplica el mismo escapado de comodines" do
      deck = create(:deck, user: user)
      create(:category, deck: deck, name: "Tema 1")
      create(:category, deck: deck, name: "Mitad 50%")

      get "/api/v1/decks/#{deck.id}/categories", params: { q: "%" }, headers: headers

      expect(names("categories")).to eq([ "Mitad 50%" ])
    end
  end
end
