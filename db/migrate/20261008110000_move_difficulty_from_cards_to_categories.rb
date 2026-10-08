# La dificultad pasa de la tarjeta al temario. No se migran los valores: la
# dificultad por tarjeta no se llegó a desplegar.
class MoveDifficultyFromCardsToCategories < ActiveRecord::Migration[8.1]
  def change
    remove_index :cards, [ :category_id, :difficulty ], if_exists: true
    remove_column :cards, :difficulty, :integer

    add_column :categories, :difficulty, :integer
    add_index :categories, [ :deck_id, :difficulty ]
  end
end
