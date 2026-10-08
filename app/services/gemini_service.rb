class GeminiService
  URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

  class RateLimitError < StandardError; end
  class UnavailableError < StandardError; end

  # Gemini tarda entre 5 y 15 s con un PDF normal y a veces responde 503 («high
  # demand») o no contesta a tiempo: se espera más y se reintenta un par de veces,
  # sin pasar de ~50 s en total para no chocar con el límite del hosting.
  REQUEST_TIMEOUT = 30
  MAX_ATTEMPTS = 3
  RETRY_DELAY = 2
  RETRY_DEADLINE = 50
  RETRYABLE_STATUSES = [ 503, 504 ].freeze

  def initialize(text)
    @text = text
  end

  def generate_cards
    response = post_with_retries

    raise RateLimitError if response.status == 429

    unless response.success?
      Rails.logger.warn("[Gemini] respondió #{response.status}: #{response.body.to_s.squish.first(300)}")
      raise UnavailableError, "Gemini respondió #{response.status}"
    end

    parse_response(response)
  end

  private

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 5, timeout: REQUEST_TIMEOUT })
  end

  # Reintenta los 503/504 y los fallos de red o de tiempo, con una pausa corta.
  def post_with_retries
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    attempt = 0

    begin
      attempt += 1
      response = connection.post("#{URL}?key=#{api_key}", request_body.to_json, "Content-Type" => "application/json")
      raise UnavailableError, "Gemini respondió #{response.status}" if retry?(response.status, attempt, started)

      response
    rescue UnavailableError
      sleep(RETRY_DELAY)
      retry
    rescue Faraday::Error => e
      Rails.logger.warn("[Gemini] #{e.class}: #{e.message}")
      raise UnavailableError, e.message unless attempt < MAX_ATTEMPTS && within_deadline?(started)

      sleep(RETRY_DELAY)
      retry
    end
  end

  def retry?(status, attempt, started)
    RETRYABLE_STATUSES.include?(status) && attempt < MAX_ATTEMPTS && within_deadline?(started)
  end

  def within_deadline?(started)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < RETRY_DEADLINE
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
      } ],
      # Respuesta en JSON puro y con poco «razonamiento»: es más rápida y no hay
      # que limpiar vallas de markdown.
      generationConfig: {
        responseMimeType: "application/json",
        thinkingConfig: { thinkingLevel: "low" }
      }
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
    parts = JSON.parse(response.body).dig("candidates", 0, "content", "parts") || []
    text = parts.reject { |part| part["thought"] }.filter_map { |part| part["text"] }.join
    JSON.parse(text.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip)
  rescue JSON::ParserError, NoMethodError
    nil
  end
end
