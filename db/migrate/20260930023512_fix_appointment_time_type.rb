class FixAppointmentTimeType < ActiveRecord::Migration[7.2]
  def up
    # Add a proper time column
    add_column :appointments, :appointment_time_new, :time unless column_exists?(:appointments, :appointment_time_new)

    # Convert existing strings like "04:39" or "04:39:00" into real times
    execute <<~SQL
      UPDATE appointments
      SET appointment_time_new = NULLIF(TRIM(appointment_time), '')::time
      WHERE appointment_time IS NOT NULL
        AND TRIM(appointment_time) <> ''
        AND TRIM(appointment_time) ~ '^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$'
    SQL

    # Drop the string column, rename the new one
    if column_exists?(:appointments, :appointment_time)
      remove_column :appointments, :appointment_time
    end
    rename_column :appointments, :appointment_time_new, :appointment_time
  end

  def down
    add_column :appointments, :appointment_time_new, :string unless column_exists?(:appointments, :appointment_time_new)
    execute "UPDATE appointments SET appointment_time_new = TO_CHAR(appointment_time, 'HH24:MI') WHERE appointment_time IS NOT NULL"
    remove_column :appointments, :appointment_time
    rename_column :appointments, :appointment_time_new, :appointment_time
  end
end
