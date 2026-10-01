class CreateClinicInvitations < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:clinic_invitations)
      create_table :clinic_invitations do |t|
        t.references :clinic,  null: false, foreign_key: true
        t.references :invited_by, foreign_key: { to_table: :users }
        t.string  :email,      null: false
        t.string  :role,       null: false, default: "doctor"
        t.string  :token,      null: false
        t.datetime :accepted_at
        t.datetime :expires_at
        t.timestamps
      end

      add_index :clinic_invitations, :token,  unique: true
      add_index :clinic_invitations, :email
      add_index :clinic_invitations, [:clinic_id, :email], unique: true, name: "idx_invitations_clinic_email"
    end
  end
end
