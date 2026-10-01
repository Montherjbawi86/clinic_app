class ConvertTransfersToFk < ActiveRecord::Migration[7.2]
  def change
    # 1. Add new FK columns
    unless column_exists?(:transfers, :from_clinic_id)
      add_reference :transfers, :from_clinic, foreign_key: { to_table: :clinics }, index: true
    end
    unless column_exists?(:transfers, :to_clinic_id)
      add_reference :transfers, :to_clinic, foreign_key: { to_table: :clinics }, index: true
    end

    # 2. Backfill from string columns (best-effort — only if old columns exist)
    reversible do |dir|
      dir.up do
        if column_exists?(:transfers, :from_clinic)
          execute <<~SQL
            UPDATE transfers t
            SET from_clinic_id = c.id
            FROM clinics c
            WHERE t.from_clinic = c.name
          SQL
        end
        if column_exists?(:transfers, :to_clinic)
          execute <<~SQL
            UPDATE transfers t
            SET to_clinic_id = c.id
            FROM clinics c
            WHERE t.to_clinic = c.name
          SQL
        end
      end
    end

    # 3. Drop old string columns
    remove_column :transfers, :from_clinic, :string if column_exists?(:transfers, :from_clinic)
    remove_column :transfers, :to_clinic,   :string if column_exists?(:transfers, :to_clinic)
  end
end
