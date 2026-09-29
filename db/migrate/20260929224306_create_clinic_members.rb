class CreateClinicMembers < ActiveRecord::Migration[7.2]
  def change
    create_table :clinic_members do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
