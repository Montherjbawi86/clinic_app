class AddPublicTokenToMedications < ActiveRecord::Migration[7.2]
  def change
    add_column :medications, :public_token, :string unless column_exists?(:medications, :public_token)
    add_index  :medications, :public_token, unique: true unless index_exists?(:medications, :public_token)
  end
end
