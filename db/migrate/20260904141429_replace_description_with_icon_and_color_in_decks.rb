class ReplaceDescriptionWithIconAndColorInDecks < ActiveRecord::Migration[8.1]
  def change
    remove_column :decks, :description, :text
    add_column :decks, :icon, :string, default: "📝"
    add_column :decks, :color, :string, default: "#7C3AED"
  end
end