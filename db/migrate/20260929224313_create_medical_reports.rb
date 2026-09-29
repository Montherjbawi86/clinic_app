class CreateMedicalReports < ActiveRecord::Migration[7.2]
  def change
    create_table :medical_reports do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :doctor, null: false, foreign_key: { to_table: :users }
      t.text :diagnosis
      t.text :treatment
      t.text :notes

      t.timestamps
    end
  end
end
