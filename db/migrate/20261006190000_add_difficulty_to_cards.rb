class AddDifficultyToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :difficulty, :integer
    add_index :cards, [ :category_id, :difficulty ]
  end
end
