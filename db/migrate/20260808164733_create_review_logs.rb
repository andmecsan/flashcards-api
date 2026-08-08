class CreateReviewLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :review_logs do |t|
      t.references :card_review, null: false, foreign_key: true
      t.integer    :quality,     null: false
      t.datetime   :reviewed_at, null: false
    end

    add_index :review_logs, :reviewed_at
  end
end