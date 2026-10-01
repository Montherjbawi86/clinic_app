class EnrichClinicsAgain < ActiveRecord::Migration[7.2]
  def change
    add_column :clinics, :working_hours, :jsonb, default: {} unless column_exists?(:clinics, :working_hours)
    add_column :clinics, :slug,          :string unless column_exists?(:clinics, :slug)
    add_column :clinics, :about,         :text   unless column_exists?(:clinics, :about)
    add_column :clinics, :about_ar,      :text   unless column_exists?(:clinics, :about_ar)
    add_column :clinics, :is_public,     :boolean, default: false unless column_exists?(:clinics, :is_public)

    add_index :clinics, :slug, unique: true unless index_exists?(:clinics, :slug)
  end
end
