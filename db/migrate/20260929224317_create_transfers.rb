class CreateTransfers < ActiveRecord::Migration[7.2]
  def change
    create_table :transfers do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.string :from_clinic
      t.string :to_clinic
      t.text :reason
      t.string :status

      t.timestamps
    end
  end
end
