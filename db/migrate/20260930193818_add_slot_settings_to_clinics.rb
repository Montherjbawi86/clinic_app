class AddSlotSettingsToClinics < ActiveRecord::Migration[7.2]
  def change
    add_column :clinics, :slot_duration_minutes, :integer, default: 30 unless column_exists?(:clinics, :slot_duration_minutes)
    add_column :clinics, :lunch_break_start, :string, default: "13:00" unless column_exists?(:clinics, :lunch_break_start)
    add_column :clinics, :lunch_break_end,   :string, default: "14:00" unless column_exists?(:clinics, :lunch_break_end)
  end
end
