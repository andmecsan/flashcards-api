class Category < ApplicationRecord
  belongs_to :deck
  has_many :cards, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :deck_id, message: "ya existe una categoría con ese nombre" }
end
