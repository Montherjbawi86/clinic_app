class HardenSchema < ActiveRecord::Migration[7.2]
  def change
    # users — unique index on email
    add_index :users, :email, unique: true unless index_exists?(:users, :email)

    # clinic_members — unique (clinic_id, user_id)
    unless index_exists?(:clinic_members, [:clinic_id, :user_id])
      add_index :clinic_members, [:clinic_id, :user_id], unique: true
    end

    # appointments — prevent double-booking + fast date queries
    unless index_exists?(:appointments, [:doctor_id, :appointment_date, :appointment_time], name: "idx_appt_unique_slot")
      add_index :appointments, [:doctor_id, :appointment_date, :appointment_time],
                unique: true, name: "idx_appt_unique_slot"
    end
    add_index :appointments, :appointment_date unless index_exists?(:appointments, :appointment_date)

    # patients — phone lookup + tenant-scoped name search
    add_index :patients, :phone unless index_exists?(:patients, :phone)
    add_index :patients, [:clinic_id, :name] unless index_exists?(:patients, [:clinic_id, :name])

    # payments — currency
    add_column :payments, :currency, :string, default: "SYP", null: false unless column_exists?(:payments, :currency)

    # notifications — default read = false
    change_column_default :notifications, :read, false

    # chat_messages — rename role -> sender_role, add index
    if column_exists?(:chat_messages, :role) && !column_exists?(:chat_messages, :sender_role)
      rename_column :chat_messages, :role, :sender_role
    end
    add_index :chat_messages, [:user_id, :created_at] unless index_exists?(:chat_messages, [:user_id, :created_at])

    # subscriptions — stripe id
    add_column :subscriptions, :stripe_subscription_id, :string unless column_exists?(:subscriptions, :stripe_subscription_id)

    # soft delete columns
    %i[patients appointments medical_reports medications].each do |t|
      unless column_exists?(t, :deleted_at)
        add_column t, :deleted_at, :datetime
        add_index  t, :deleted_at
      end
    end

    # extra patient fields + chat tokens
    add_column :patients, :national_id, :string unless column_exists?(:patients, :national_id)
    add_column :patients, :blood_type, :string unless column_exists?(:patients, :blood_type)
    add_column :chat_messages, :tokens, :integer unless column_exists?(:chat_messages, :tokens)
  end
end
