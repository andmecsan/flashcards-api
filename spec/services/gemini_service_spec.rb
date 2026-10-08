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

  it "ignora las partes de razonamiento y junta el texto" do
    body = { candidates: [ { content: { parts: [
      { text: "pensando…", thought: true },
      { text: '{"name":"Tema",' }, { text: '"cards":[]}' }
    ] } } ] }.to_json
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 200, body: body))

    expect(service.generate_cards).to eq("name" => "Tema", "cards" => [])
  end

  it "pide la respuesta en JSON" do
    expect(service.send(:request_body)[:generationConfig]).to include(responseMimeType: "application/json")
  end

  describe "reintentos" do
    let(:ok_body) { { candidates: [ { content: { parts: [ { text: '{"name":"T","cards":[]}' } ] } } ] }.to_json }

    before { allow(service).to receive(:sleep) }

    it "reintenta un 503 y devuelve el resultado si luego responde bien" do
      calls = [ fake_response(status: 503, body: "{}"), fake_response(status: 200, body: ok_body) ]
      allow_any_instance_of(Faraday::Connection).to receive(:post) { calls.shift }

      expect(service.generate_cards).to eq("name" => "T", "cards" => [])
      expect(calls).to be_empty
    end

    it "reintenta un timeout" do
      calls = [ Faraday::TimeoutError.new("timeout"), fake_response(status: 200, body: ok_body) ]
      allow_any_instance_of(Faraday::Connection).to receive(:post) { calls.shift.then { |c| c.is_a?(Exception) ? raise(c) : c } }

      expect(service.generate_cards).to eq("name" => "T", "cards" => [])
    end

    it "se rinde tras #{GeminiService::MAX_ATTEMPTS} intentos con UnavailableError" do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .exactly(GeminiService::MAX_ATTEMPTS).times.and_return(fake_response(status: 503, body: "{}"))

      expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
    end

    it "no reintenta un 429 ni un 500" do
      expect_any_instance_of(Faraday::Connection).to receive(:post).once.and_return(fake_response(status: 500, body: "{}"))

      expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
    end
  end

  it "lanza UnavailableError con otros códigos de error HTTP" do
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response(status: 500, body: "{}"))

    expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
  end

  it "lanza UnavailableError si falla la conexión" do
    allow(service).to receive(:sleep)
    allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed.new("fallo de red"))

    expect { service.generate_cards }.to raise_error(GeminiService::UnavailableError)
  end
end
