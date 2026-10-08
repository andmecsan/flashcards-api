# Permite etiquetar un modelo. Las reglas de qué etiquetas admite viven en Tagging.
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings
  end
end
