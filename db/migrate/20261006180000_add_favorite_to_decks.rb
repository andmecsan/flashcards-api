class AddFavoriteToDecks < ActiveRecord::Migration[8.1]
  def change
    add_column :decks, :favorite, :boolean, null: false, default: false
    add_index :decks, [ :user_id, :favorite ]
  end
end
