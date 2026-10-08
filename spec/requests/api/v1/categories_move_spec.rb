require "rails_helper"

RSpec.describe "PATCH /api/v1/categories/:id/move", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:origen)  { create(:deck, user: user, name: "Origen") }
  let(:destino) { create(:deck, user: user, name: "Destino") }
  let(:category) { create(:category, deck: origen, name: "Tema") }
  let(:otro) { create(:user, email: "otro@test.com") }

  def move(cat, deck_id, as: headers)
    patch "/api/v1/categories/#{cat.id}/move", params: { deck_id: deck_id }, headers: as
  end

  it "mueve el temario a otra asignatura propia" do
    move(category, destino.id)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("id" => category.id, "deck_id" => destino.id)
    expect(category.reload.deck).to eq(destino)
  end

  it "conserva las tarjetas, su planificación SM-2 y su historial" do
    card = create(:card, category: category)
    review = CardReview.create!(card: card, user: user, repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current)
    review.apply_review!(5)

    move(category, destino.id)

    expect(category.reload.cards).to contain_exactly(card)
    expect(CardReview.exists?(review.id)).to be(true)
    expect(review.reload.review_logs.count).to eq(1)
  end

  it "las estadísticas de ambas asignaturas se recalculan" do
    create(:card, category: category)

    move(category, destino.id)

    get "/api/v1/decks/#{origen.id}/stats", headers: headers
    expect(JSON.parse(response.body)["total_cards"]).to eq(0)
    get "/api/v1/decks/#{destino.id}/stats", headers: headers
    expect(JSON.parse(response.body)["total_cards"]).to eq(1)
  end

  it "mover a la misma asignatura no cambia nada" do
    move(category, origen.id)

    expect(response).to have_http_status(:ok)
    expect(category.reload.deck).to eq(origen)
  end

  it "rechaza el movimiento si el destino ya tiene un temario con ese nombre" do
    create(:category, deck: destino, name: "Tema")

    move(category, destino.id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"].first).to include("Ya existe un temario con ese nombre en «Destino»")
    expect(category.reload.deck).to eq(origen)
  end

  it "permite mover si el nombre repetido está en otra asignatura distinta del destino" do
    create(:category, deck: create(:deck, user: user, name: "Tercera"), name: "Tema")

    move(category, destino.id)

    expect(response).to have_http_status(:ok)
  end

  it "no permite mover a una asignatura de otro usuario" do
    ajeno = create(:deck, user: otro, name: "Ajena")

    move(category, ajeno.id)

    expect(response).to have_http_status(:not_found)
    expect(category.reload.deck).to eq(origen)
  end

  it "no permite mover el temario de otro usuario" do
    ajena = create(:category, deck: create(:deck, user: otro), name: "Privado")

    move(ajena, destino.id)

    expect(response).to have_http_status(:not_found)
    expect(ajena.reload.deck.user).to eq(otro)
  end

  it "devuelve 404 si la asignatura de destino no existe" do
    move(category, 0)

    expect(response).to have_http_status(:not_found)
    expect(category.reload.deck).to eq(origen)
  end

  it "devuelve 400 si no se indica el destino" do
    patch "/api/v1/categories/#{category.id}/move", headers: headers

    expect(response).to have_http_status(:bad_request)
  end

  it "devuelve 401 sin token" do
    patch "/api/v1/categories/#{category.id}/move", params: { deck_id: destino.id }

    expect(response).to have_http_status(:unauthorized)
  end
end
