class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :clinic, null: false, foreign_key: true
      t.string :plan
      t.string :status
      t.datetime :expires_at

      t.timestamps
    end
  end
end
