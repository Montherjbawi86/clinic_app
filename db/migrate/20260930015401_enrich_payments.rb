class EnrichPayments < ActiveRecord::Migration[7.2]
  def change
    add_reference :payments, :patient,     foreign_key: true, index: true unless column_exists?(:payments, :patient_id)
    add_reference :payments, :appointment, foreign_key: true, index: true unless column_exists?(:payments, :appointment_id)
    add_column    :payments, :method,      :string   unless column_exists?(:payments, :method)
    add_column    :payments, :reference,   :string   unless column_exists?(:payments, :reference)
    add_column    :payments, :notes,       :text     unless column_exists?(:payments, :notes)
    add_column    :payments, :paid_at,     :datetime unless column_exists?(:payments, :paid_at)
    add_index     :payments, :paid_at unless index_exists?(:payments, :paid_at)
  end
end
