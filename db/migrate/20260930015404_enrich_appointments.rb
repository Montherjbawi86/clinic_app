class EnrichAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :duration_minutes, :integer, default: 30 unless column_exists?(:appointments, :duration_minutes)
    add_column :appointments, :notes,            :text unless column_exists?(:appointments, :notes)
    add_column :appointments, :checked_in_at,    :datetime unless column_exists?(:appointments, :checked_in_at)
    add_column :appointments, :completed_at,     :datetime unless column_exists?(:appointments, :completed_at)
    add_column :appointments, :deleted_at,       :datetime unless column_exists?(:appointments, :deleted_at)
    add_index  :appointments, :deleted_at unless index_exists?(:appointments, :deleted_at)
  end
end
