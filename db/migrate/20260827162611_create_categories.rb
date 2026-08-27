class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :deck, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :categories, %i[deck_id name], unique: true
  end
end
