class AddContactToPatient < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :email, :string unless column_exists?(:patients, :email)
  end
end
