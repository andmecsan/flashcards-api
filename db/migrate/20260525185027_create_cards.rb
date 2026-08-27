class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :deck,    null: false, foreign_key: true
      t.text       :front,   null: false  # Pregunta / anverso
      t.text       :back,    null: false  # Respuesta / reverso

      t.timestamps
    end
  end
end
