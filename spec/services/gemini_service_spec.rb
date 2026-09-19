require "rails_helper"

RSpec.describe GeminiService do
  let(:service) { described_class.new("Contenido de ejemplo para generar tarjetas.") }

  def fake_response(status:, body:)
    instance_double(Faraday::Response, status: status, success?: status == 200, body: body)
  end

  it "devuelve el nombre y las tarjetas cuando Gemini responde correctamente" do
    body = {
      candidates: [ { content: { parts: [ { text: '{"name":"Tema","cards":[{"front":"P","back":"R"}]}' } ] } } ]
    }.to_json
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 200, body: body))

    result = service.generate_cards

    expect(result["name"]).to eq("Tema")
    expect(result["cards"]).to eq([ { "front" => "P", "back" => "R" } ])
  end

  it "devuelve nil si la respuesta no contiene JSON válido" do
    body = { candidates: [ { content: { parts: [ { text: "esto no es JSON" } ] } } ] }.to_json
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 200, body: body))

    expect(service.generate_cards).to be_nil
  end

  it "lanza RateLimitError cuando Gemini responde 429" do
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 429, body: "{}"))

    expect { service.generate_cards }.to raise_error(GeminiService::RateLimitError)
  end

  it "lanza UnavailableError con otros códigos de error HTTP" do
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 500, body: "{}"))

    expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
  end

  it "lanza UnavailableError si falla la conexión" do
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed.new("fallo de red"))

    expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
  end
end
