class AddColorToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :color, :string
  end
end
