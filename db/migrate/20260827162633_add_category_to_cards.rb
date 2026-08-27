class AddCategoryToCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :cards, :category, null: true, foreign_key: true
    remove_reference :cards, :deck, foreign_key: true
  end
end
