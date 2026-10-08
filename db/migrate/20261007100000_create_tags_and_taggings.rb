class CreateTagsAndTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      # 0 personal, 1 area, 2 level, 3 course. Las del sistema no tienen user_id.
      t.integer :kind, null: false, default: 0
      t.references :user, foreign_key: true, null: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    # Una etiqueta personal es única por usuario; una del sistema, por tipo.
    add_index :tags, [ :user_id, :slug ], unique: true, where: "user_id IS NOT NULL", name: "index_tags_on_user_and_slug"
    add_index :tags, [ :kind, :slug ], unique: true, where: "user_id IS NULL", name: "index_tags_on_system_kind_and_slug"

    create_table :taggings do |t|
      t.references :tag, foreign_key: true, null: false
      t.string :taggable_type, null: false
      t.bigint :taggable_id, null: false
      t.timestamps
    end

    add_index :taggings, [ :tag_id, :taggable_type, :taggable_id ], unique: true, name: "index_taggings_uniqueness"
    add_index :taggings, [ :taggable_type, :taggable_id ]
  end
end
