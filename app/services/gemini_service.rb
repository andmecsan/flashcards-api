class GeminiService
  URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

  class RateLimitError < StandardError; end
  class UnavailableError < StandardError; end

  def initialize(text)
    @text = text
  end

  def generate_cards
    response = connection.post(
      "#{URL}?key=#{api_key}",
      request_body.to_json,
      "Content-Type" => "application/json"
    )

    raise RateLimitError if response.status == 429
    raise UnavailableError, "Gemini respondió #{response.status}" unless response.success?

    parse_response(response)
  rescue Faraday::Error => e
    raise UnavailableError, e.message
  end

  private

  def connection
    Faraday.new(request: { open_timeout: 5, timeout: 15 })
  end

  def api_key
    Rails.application.credentials.gemini[:api_key]
  end

  def request_body
    {
      contents: [ {
        parts: [ {
          text: prompt
        } ]
      } ]
    }
  end
 
  def prompt
    <<~PROMPT
      A partir del siguiente texto, genera tarjetas de estudio (flashcards).
      Cada tarjeta tiene una pregunta (front) y una respuesta (back).
      Genera entre 5 y 15 tarjetas según la cantidad de contenido.
      Las preguntas deben ser claras y las respuestas concisas.
      También genera un nombre corto y descriptivo para el tema basándote en el contenido.

      Responde SOLO con un JSON válido, sin markdown ni texto adicional:
      {"name": "nombre del tema", "cards": [{"front": "pregunta", "back": "respuesta"}]}

      Texto:
      #{@text}
    PROMPT
  end

  def parse_response(response)
    body = JSON.parse(response.body)
    text = body.dig("candidates", 0, "content", "parts", 0, "text")
    cleaned = text.gsub(/```json\n?/, '').gsub(/```\n?/, '').strip
    JSON.parse(cleaned)
    rescue JSON::ParserError, NoMethodError
        nil
  end
end
