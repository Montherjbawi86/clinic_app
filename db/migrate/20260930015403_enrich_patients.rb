class EnrichPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :national_id,        :string   unless column_exists?(:patients, :national_id)
    add_column :patients, :blood_type,         :string   unless column_exists?(:patients, :blood_type)
    add_column :patients, :address,            :string   unless column_exists?(:patients, :address)
    add_column :patients, :emergency_name,     :string   unless column_exists?(:patients, :emergency_name)
    add_column :patients, :emergency_phone,    :string   unless column_exists?(:patients, :emergency_phone)
    add_column :patients, :allergies,          :text     unless column_exists?(:patients, :allergies)
    add_column :patients, :chronic_conditions, :text     unless column_exists?(:patients, :chronic_conditions)
    add_column :patients, :insurance_provider, :string   unless column_exists?(:patients, :insurance_provider)
    add_column :patients, :insurance_number,   :string   unless column_exists?(:patients, :insurance_number)
    add_column :patients, :deleted_at,         :datetime unless column_exists?(:patients, :deleted_at)
    add_index  :patients, :national_id unless index_exists?(:patients, :national_id)
    add_index  :patients, :deleted_at  unless index_exists?(:patients, :deleted_at)
  end
end
