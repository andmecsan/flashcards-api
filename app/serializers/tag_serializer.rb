class TagSerializer
  def initialize(tag, cards_count: nil)
    @tag = tag
    @cards_count = cards_count
  end

  def as_json(*)
    json = { id: @tag.id, name: @tag.name }
    json[:color] = @tag.color if @tag.color
    json[:group] = @tag.language_level? ? "idiomas" : "etapa" if @tag.level?
    json[:cards_count] = @cards_count unless @cards_count.nil?
    json
  end
end
