class AddQueueDisplayToClinics < ActiveRecord::Migration[7.2]
  def change
    add_column :clinics, :queue_display_enabled, :boolean, default: true unless column_exists?(:clinics, :queue_display_enabled)
    add_column :clinics, :queue_display_pin,     :string  unless column_exists?(:clinics, :queue_display_pin)
  end
end
