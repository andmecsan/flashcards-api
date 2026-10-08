# Búsqueda por nombre y paginación compartidas por los listados de la API.
module Searchable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 9
  MAX_PER_PAGE = 100

  private

  # Filtra por `name` con `?q=`, escapando % y _ para que se busquen como texto.
  def search_by_name(scope)
    return scope if params[:q].blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
    scope.where("#{scope.table_name}.name ILIKE ?", pattern)
  end

  # @return [Array(ActiveRecord::Relation, Hash)] la página pedida y su `meta`
  def paginate(scope)
    page     = [ params.fetch(:page, 1).to_i, 1 ].max
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    total    = scope.count

    records = scope.offset((page - 1) * per_page).limit(per_page)
    meta = { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
    [ records, meta ]
  end
end
