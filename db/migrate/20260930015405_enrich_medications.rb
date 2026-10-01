class EnrichMedications < ActiveRecord::Migration[7.2]
  def change
    add_reference :medications, :appointment, foreign_key: true, index: true unless column_exists?(:medications, :appointment_id)
    add_column    :medications, :name_ar,    :string   unless column_exists?(:medications, :name_ar)
    add_column    :medications, :route,      :string   unless column_exists?(:medications, :route)
    add_column    :medications, :quantity,   :integer  unless column_exists?(:medications, :quantity)
    add_column    :medications, :refills,    :integer, default: 0 unless column_exists?(:medications, :refills)
    add_column    :medications, :status,     :string, default: "active" unless column_exists?(:medications, :status)
    add_column    :medications, :deleted_at, :datetime unless column_exists?(:medications, :deleted_at)
    add_index     :medications, :deleted_at unless index_exists?(:medications, :deleted_at)
  end
end
