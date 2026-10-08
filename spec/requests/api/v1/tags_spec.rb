require "rails_helper"

RSpec.describe "Etiquetas", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user, email: "otro@test.com") }
  let(:headers) { auth_headers(user) }
  let(:deck)    { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck, name: "Tema") }

  before { Tag.sync_predefined! }

  def json = JSON.parse(response.body)

  describe "GET /api/v1/tags/system" do
    it "devuelve áreas, niveles (con su grupo) y cursos, en orden" do
      get "/api/v1/tags/system", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["areas"].map { |t| t["name"] }.first(2)).to eq([ "Ciencias", "Ciencias de la Salud" ])
      expect(json["levels"].size).to eq(13)
      expect(json["levels"].find { |t| t["name"] == "B2" }["group"]).to eq("idiomas")
      expect(json["levels"].find { |t| t["name"] == "Grado" }["group"]).to eq("etapa")
      expect(json["courses"].map { |t| t["name"] }).to eq([ "1.º", "2.º", "3.º", "4.º", "5.º", "6.º" ])
    end

    it "exige autenticación" do
      get "/api/v1/tags/system"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/tags" do
    it "lista solo las etiquetas personales del usuario con su nº de tarjetas" do
      card = create(:card, category: category)
      card.replace_personal_tags!([ "Examen", "Fórmula" ])
      Tag.for_user(other, "Ajena")

      get "/api/v1/tags", headers: headers

      expect(json.map { |t| [ t["name"], t["cards_count"] ] }).to eq([ [ "Examen", 1 ], [ "Fórmula", 1 ] ])
    end

    it "no incluye las predefinidas" do
      get "/api/v1/tags", headers: headers

      expect(json).to eq([])
    end

    it "filtra por texto con ?q=" do
      Tag.for_user(user, "Examen")
      Tag.for_user(user, "Teoría")

      get "/api/v1/tags", params: { q: "exa" }, headers: headers

      expect(json.map { |t| t["name"] }).to eq([ "Examen" ])
    end
  end

  describe "PATCH /api/v1/tags/:id" do
    it "renombra una etiqueta propia" do
      tag = Tag.for_user(user, "Examen")

      patch "/api/v1/tags/#{tag.id}", params: { name: "Final" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(tag.reload.name).to eq("Final")
    end

    it "rechaza un nombre que ya tienes, aunque cambien mayúsculas o tildes" do
      Tag.for_user(user, "Examen")
      tag = Tag.for_user(user, "Final")

      patch "/api/v1/tags/#{tag.id}", params: { name: "EXÁMEN" }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"].first).to include("Fusiónalas")
      expect(tag.reload.name).to eq("Final")
    end

    it "no permite renombrar la de otro usuario ni una predefinida" do
      ajena = Tag.for_user(other, "Ajena")
      area = Tag.find_by!(kind: :area, name: "Ciencias")

      patch "/api/v1/tags/#{ajena.id}", params: { name: "X" }, headers: headers
      expect(response).to have_http_status(:not_found)

      patch "/api/v1/tags/#{area.id}", params: { name: "X" }, headers: headers
      expect(response).to have_http_status(:not_found)
      expect(area.reload.name).to eq("Ciencias")
    end
  end

  describe "DELETE /api/v1/tags/:id" do
    it "borra la etiqueta y la quita de sus tarjetas" do
      card = create(:card, category: category)
      card.replace_personal_tags!([ "Examen" ])

      delete "/api/v1/tags/#{Tag.for_user(user, 'Examen').id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(card.reload.tags).to be_empty
    end

    it "no borra la de otro usuario" do
      ajena = Tag.for_user(other, "Ajena")

      delete "/api/v1/tags/#{ajena.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(Tag.exists?(ajena.id)).to be(true)
    end
  end

  describe "POST /api/v1/tags/:id/merge" do
    it "pasa las tarjetas a la etiqueta de destino y elimina la origen" do
      a = create(:card, category: category, front: "A")
      a.replace_personal_tags!([ "Mates" ])
      b = create(:card, category: category, front: "B")
      b.replace_personal_tags!([ "Matematicas" ])
      origen = Tag.for_user(user, "Mates")
      destino = Tag.for_user(user, "Matematicas")

      post "/api/v1/tags/#{origen.id}/merge", params: { into_id: destino.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(Tag.exists?(origen.id)).to be(false)
      expect(a.reload.tags.map(&:name)).to eq([ "Matematicas" ])
      expect(b.reload.tags.map(&:name)).to eq([ "Matematicas" ])
    end

    it "no duplica si una tarjeta ya tenía ambas" do
      card = create(:card, category: category)
      card.replace_personal_tags!([ "Mates", "Matematicas" ])

      post "/api/v1/tags/#{Tag.for_user(user, 'Mates').id}/merge",
           params: { into_id: Tag.for_user(user, "Matematicas").id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(card.reload.tags.map(&:name)).to eq([ "Matematicas" ])
    end

    it "rechaza fusionar una etiqueta consigo misma" do
      tag = Tag.for_user(user, "Mates")

      post "/api/v1/tags/#{tag.id}/merge", params: { into_id: tag.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Tag.exists?(tag.id)).to be(true)
    end

    it "no permite fusionar en la etiqueta de otro usuario" do
      origen = Tag.for_user(user, "Mates")
      ajena = Tag.for_user(other, "Ajena")

      post "/api/v1/tags/#{origen.id}/merge", params: { into_id: ajena.id }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(Tag.exists?(origen.id)).to be(true)
    end
  end

  describe "etiquetas en las tarjetas" do
    it "se asignan al crear una tarjeta y salen en la respuesta" do
      post "/api/v1/categories/#{category.id}/cards",
           params: { card: { front: "Q", back: "A", tags: [ "Examen", "Teoría" ] } }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["tags"]).to eq([ "Examen", "Teoría" ])
    end

    it "se reemplazan al editar y se conservan si no se envían" do
      card = create(:card, category: category)
      card.replace_personal_tags!([ "Viejo" ])

      patch "/api/v1/cards/#{card.id}", params: { card: { front: "Nuevo" } }, headers: headers, as: :json
      expect(json["tags"]).to eq([ "Viejo" ])

      patch "/api/v1/cards/#{card.id}", params: { card: { tags: [ "Nuevo" ] } }, headers: headers, as: :json
      expect(json["tags"]).to eq([ "Nuevo" ])

      patch "/api/v1/cards/#{card.id}", params: { card: { tags: [] } }, headers: headers, as: :json
      expect(json["tags"]).to eq([])
    end

    it "responde 422 con más de 5 etiquetas y no cambia la tarjeta" do
      card = create(:card, category: category, front: "Original")

      patch "/api/v1/cards/#{card.id}", params: { card: { front: "Cambio", tags: %w[a b c d e f] } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(card.reload.front).to eq("Original")
    end

    it "las etiquetas de un usuario no aparecen en la tarjeta de otro" do
      create(:card, category: category).replace_personal_tags!([ "Mia" ])

      get "/api/v1/categories/#{category.id}/cards", headers: auth_headers(other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "área, nivel y curso en las asignaturas" do
    let(:ciencias) { Tag.find_by!(kind: :area, name: "Ciencias") }
    let(:grado)    { Tag.find_by!(kind: :level, name: "Grado") }
    let(:primero)  { Tag.find_by!(kind: :course, name: "1.º") }

    def names(body)
      body.slice("area", "level", "course").transform_values { |t| t && t["name"] }
    end

    it "crear una asignatura guarda área, nivel y curso" do
      post "/api/v1/decks", params: {
        deck: { name: "Biología", icon: "🧬", color: "#10B981", area_id: ciencias.id, level_id: grado.id, course_id: primero.id }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(names(json)).to eq("area" => "Ciencias", "level" => "Grado", "course" => "1.º")
      expect(json["area"]["color"]).to match(/\A#\h{6}\z/)
    end

    it "todo es opcional: sin etiquetas la asignatura se crea igual" do
      post "/api/v1/decks", params: { deck: { name: "Sin nada" } }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("area" => nil, "level" => nil, "course" => nil)
    end

    it "editar cambia el área, la quita con vacío y respeta lo que no se envía" do
      deck.assign_predefined_tags!(area: ciencias.id, level: grado.id)

      patch "/api/v1/decks/#{deck.id}", params: { deck: { name: "Otra", area_id: "" } }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(names(json)).to eq("area" => nil, "level" => "Grado", "course" => nil)
    end

    it "rechaza un área que es en realidad un nivel, sin dejar cambios a medias" do
      patch "/api/v1/decks/#{deck.id}", params: { deck: { name: "Renombrada", area_id: grado.id } },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(deck.reload.name).not_to eq("Renombrada")
    end

    it "al crear con un id inválido no se crea la asignatura" do
      expect {
        post "/api/v1/decks", params: { deck: { name: "Fallida", area_id: grado.id } }, headers: headers, as: :json
      }.not_to change(Deck, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "el listado de asignaturas incluye sus etiquetas" do
      deck.assign_predefined_tags!(area: ciencias.id)

      get "/api/v1/decks", headers: headers

      expect(json["decks"].find { |d| d["id"] == deck.id }["area"]).to include("name" => "Ciencias")
    end

    it "los temarios ya no llevan etiquetas predefinidas" do
      category
      get "/api/v1/decks/#{deck.id}/categories", headers: headers

      expect(json["categories"].first).not_to have_key("area")
    end
  end

  describe "filtro ?tag_id=" do
    let!(:examen)  { Tag.for_user(user, "Examen") }
    let!(:tagged)  { create(:card, category: category, front: "Con etiqueta") }
    let!(:plain)   { create(:card, category: category, front: "Sin etiqueta") }
    let!(:otra_cat) { create(:category, deck: deck, name: "Otro tema") }

    before do
      tagged.replace_personal_tags!([ "Examen" ])
      create(:card, category: otra_cat, front: "Libre")
    end

    it "Estudiar devuelve solo las tarjetas con la etiqueta" do
      get "/api/v1/decks/#{deck.id}/study", params: { tag_id: examen.id }, headers: headers

      expect(json.map { |c| c["front"] }).to eq([ "Con etiqueta" ])
    end

    it "Repasar también filtra" do
      get "/api/v1/categories/#{category.id}/review_cards", params: { tag_id: examen.id }, headers: headers

      expect(json.map { |c| c["front"] }).to eq([ "Con etiqueta" ])
    end

    it "se combina con la dificultad del temario" do
      category.update!(difficulty: :hard)

      get "/api/v1/decks/#{deck.id}/study", params: { tag_id: examen.id, difficulty: "easy" }, headers: headers

      expect(json).to eq([])
    end

    it "el listado de temarios solo muestra los que tienen tarjetas con la etiqueta, y las cuenta" do
      get "/api/v1/decks/#{deck.id}/categories", params: { tag_id: examen.id }, headers: headers

      expect(json["categories"].map { |c| [ c["name"], c["card_count"] ] }).to eq([ [ "Tema", 1 ] ])
    end

    it "responde 404 con una etiqueta de otro usuario" do
      ajena = Tag.for_user(other, "Examen")

      get "/api/v1/decks/#{deck.id}/study", params: { tag_id: ajena.id }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "las estadísticas de la asignatura listan las etiquetas usadas con su recuento" do
      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      expect(json["tags"]).to eq([ { "id" => examen.id, "name" => "Examen", "count" => 1 } ])
    end
  end
end
