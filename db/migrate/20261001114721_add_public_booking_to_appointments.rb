class AddPublicBookingToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :source, :string, default: "staff" unless column_exists?(:appointments, :source)
    add_column :appointments, :patient_name, :string unless column_exists?(:appointments, :patient_name)
    add_column :appointments, :patient_phone, :string unless column_exists?(:appointments, :patient_phone)

    add_index :appointments, :source unless index_exists?(:appointments, :source)
  end
end
