class CreateCardReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :card_reviews do |t|
      t.references :card,   null: false, foreign_key: true
      t.references :user,   null: false, foreign_key: true


      t.integer :repetitions,    null: false, default: 0
      t.integer :interval,       null: false, default: 1    # días hasta próximo repaso
      t.float   :easiness,       null: false, default: 2.5  # factor de facilidad, mín 1.3
      t.datetime :next_review_at, null: false

      t.timestamps
    end

    add_index :card_reviews, %i[card_id user_id], unique: true
    add_index :card_reviews, :next_review_at
  end
end