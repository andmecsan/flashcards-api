class GeminiService
  URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

  def initialize(text)
    @text = text
  end

  def generate_cards
    response = Faraday.post(
      "#{URL}?key=#{api_key}",
      request_body.to_json,
      "Content-Type" => "application/json"
    )

    parse_response(response)
  end

  private

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
