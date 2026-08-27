require "pdf-reader"

class PdfExtractorService
  MAX_CHARS = 15_000

  def initialize(file)
    @file = file
  end

  def extract_text
    reader = PDF::Reader.new(@file.path)
    full_text = reader.pages.map(&:text).join("\n")
    full_text.truncate(MAX_CHARS)
  end
end
