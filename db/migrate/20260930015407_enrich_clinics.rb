class EnrichClinics < ActiveRecord::Migration[7.2]
  def change
    add_column :clinics, :name_ar,    :string   unless column_exists?(:clinics, :name_ar)
    add_column :clinics, :address_ar, :string   unless column_exists?(:clinics, :address_ar)
    add_column :clinics, :specialty,  :string   unless column_exists?(:clinics, :specialty)
    add_column :clinics, :city,       :string   unless column_exists?(:clinics, :city)
    add_column :clinics, :timezone,   :string, default: "Asia/Damascus" unless column_exists?(:clinics, :timezone)
    add_column :clinics, :logo_url,   :string   unless column_exists?(:clinics, :logo_url)
    add_column :clinics, :settings,   :jsonb, default: {} unless column_exists?(:clinics, :settings)
    add_column :clinics, :deleted_at, :datetime unless column_exists?(:clinics, :deleted_at)
  end
end
