class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :doctor, null: false, foreign_key: { to_table: :users }
      t.date :appointment_date
      t.string :appointment_time
      t.text :reason
      t.text :reason_ar
      t.string :status

      t.timestamps
    end
  end
end
