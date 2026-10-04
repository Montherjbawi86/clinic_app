class AddBookingRef < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :booking_ref, :string unless column_exists?(:appointments, :booking_ref)
    add_index  :appointments, :booking_ref, unique: true unless index_exists?(:appointments, :booking_ref)
  end
end
