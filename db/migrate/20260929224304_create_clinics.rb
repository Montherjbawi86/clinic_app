class CreateClinics < ActiveRecord::Migration[7.2]
  def change
    create_table :clinics do |t|
      t.string :name
      t.string :name_ar
      t.string :address
      t.string :phone
      t.string :email
      t.references :user, null: false, foreign_key: true # Changed from owner to user

      t.timestamps
    end
  end
end
