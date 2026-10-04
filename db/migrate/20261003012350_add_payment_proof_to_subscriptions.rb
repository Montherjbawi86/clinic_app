class AddPaymentProofToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :payment_proof_note, :text
    add_column :subscriptions, :payment_method, :string
    add_column :subscriptions, :transaction_reference, :string
    add_column :subscriptions, :submitted_at, :datetime
    add_column :subscriptions, :confirmed_at, :datetime
    add_column :subscriptions, :confirmed_by_id, :bigint
  end
end
