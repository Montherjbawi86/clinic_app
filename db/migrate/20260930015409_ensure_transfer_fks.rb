class EnsureTransferFks < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:transfers, :from_clinic_id)
      add_reference :transfers, :from_clinic, foreign_key: { to_table: :clinics }, index: true
    end
    unless column_exists?(:transfers, :to_clinic_id)
      add_reference :transfers, :to_clinic, foreign_key: { to_table: :clinics }, index: true
    end
    if column_exists?(:transfers, :from_clinic)
      execute "UPDATE transfers t SET from_clinic_id = c.id FROM clinics c WHERE t.from_clinic = c.name"
      remove_column :transfers, :from_clinic, :string
    end
    if column_exists?(:transfers, :to_clinic)
      execute "UPDATE transfers t SET to_clinic_id = c.id FROM clinics c WHERE t.to_clinic = c.name"
      remove_column :transfers, :to_clinic, :string
    end
  end
end
