require "rails_helper"

# Auditoría de rutas: cada acción de la API autenticada debe tener su regla en
# la policy del recurso. Si alguien añade una ruta nueva y olvida la regla,
# este test falla antes de que llegue a producción.
RSpec.describe "Cobertura de permisos de las rutas de la API" do
  # Controladores que solo operan sobre el propio usuario autenticado y se
  # eximen explícitamente (`self_service_only!`). Cualquier otro debe tener policy.
  SELF_SERVICE = %w[api/v1/stats api/v1/profiles].freeze

  POLICY_FOR = {
    "api/v1/tags"       => TagPolicy,
    "api/v1/decks"      => DeckPolicy,
    "api/v1/categories" => CategoryPolicy,
    "api/v1/cards"      => CardPolicy
  }.freeze

  let(:api_routes) do
    Rails.application.routes.routes
         .map { |r| r.defaults.slice(:controller, :action) }
         .select { |d| d[:controller].to_s.start_with?("api/v1/") }
         .uniq
  end

  it "encuentra rutas de la API (el test no es vacío)" do
    expect(api_routes.size).to be > 15
  end

  it "todas las acciones tienen su regla en la policy o están eximidas" do
    missing = api_routes.reject do |d|
      controller = d[:controller].to_s
      next true if SELF_SERVICE.include?(controller)

      policy = POLICY_FOR[controller]
      policy&.method_defined?("#{d[:action]}?")
    end

    expect(missing).to be_empty, "Acciones sin regla de permisos: #{missing.map { |d| "#{d[:controller]}##{d[:action]}" }.join(', ')}"
  end

  it "los controladores eximidos existen y siguen en la lista de la API" do
    controllers = api_routes.map { |d| d[:controller].to_s }.uniq
    expect(controllers).to include(*SELF_SERVICE)
  end
end
