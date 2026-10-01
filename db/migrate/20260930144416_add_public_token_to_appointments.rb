class AddPublicTokenToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :public_token, :string unless column_exists?(:appointments, :public_token)
    add_index  :appointments, :public_token, unique: true unless index_exists?(:appointments, :public_token)
  end
end
