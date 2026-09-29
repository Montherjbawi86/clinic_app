class CreateMedications < ActiveRecord::Migration[7.2]
  def change
    create_table :medications do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :doctor, null: false, foreign_key: { to_table: :users }
      t.string :name
      t.string :dosage
      t.string :frequency
      t.string :duration
      t.text :instructions

      t.timestamps
    end
  end
end
