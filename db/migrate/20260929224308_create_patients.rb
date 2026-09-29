class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.references :clinic, null: false, foreign_key: true
      t.string :name
      t.string :name_ar
      t.string :phone
      t.string :gender
      t.integer :age
      t.date :date_of_birth
      t.text :medical_history

      t.timestamps
    end
  end
end
