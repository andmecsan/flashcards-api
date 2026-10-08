require "rails_helper"

# Red de seguridad: una acción que olvide autorizar debe fallar, no pasar
# desapercibida. Se prueba con un controlador anónimo que hereda del base.
RSpec.describe Api::V1::BaseController, type: :controller do
  let(:user) { create(:user) }

  before { request.headers.merge!(auth_headers(user)) }

  controller do
    def index
      render json: []
    end

    def show
      render json: {}
    end

    def update
      authorize Deck.new(user: current_user)
      render json: {}
    end
  end

  it "falla si un listado no pasa por policy_scope" do
    expect { get :index }.to raise_error(Pundit::PolicyScopingNotPerformedError)
  end

  it "falla si una acción no autoriza nada" do
    expect { get :show, params: { id: 1 } }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end

  it "acepta una acción que autoriza" do
    put :update, params: { id: 1 }

    expect(response).to have_http_status(:ok)
  end

  it "responde 404 si la policy deniega" do
    allow_any_instance_of(DeckPolicy).to receive(:update?).and_return(false)

    put :update, params: { id: 1 }

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["error"]).to eq("No encontrado")
  end
end
