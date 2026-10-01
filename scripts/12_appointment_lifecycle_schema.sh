#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BASE=$(date +%Y%m%d%H%M)
echo "==> Creating appointment lifecycle migration…"

cat > "db/migrate/${BASE}11_enrich_appointments_lifecycle.rb" <<'RUBY'
class EnrichAppointmentsLifecycle < ActiveRecord::Migration[7.2]
  def change
    # Who did what
    add_reference :appointments, :checked_in_by, foreign_key: { to_table: :users }, index: true unless column_exists?(:appointments, :checked_in_by_id)
    add_reference :appointments, :cancelled_by,  foreign_key: { to_table: :users }, index: true unless column_exists?(:appointments, :cancelled_by_id)
    add_reference :appointments, :completed_by,  foreign_key: { to_table: :users }, index: true unless column_exists?(:appointments, :completed_by_id)

    # Visit details
    add_column :appointments, :cancellation_reason, :text     unless column_exists?(:appointments, :cancellation_reason)
    add_column :appointments, :visit_notes,         :text     unless column_exists?(:appointments, :visit_notes)
    add_column :appointments, :visit_notes_ar,      :text     unless column_exists?(:appointments, :visit_notes_ar)
    add_column :appointments, :vitals,              :jsonb, default: {} unless column_exists?(:appointments, :vitals)
    add_column :appointments, :follow_up_date,      :date     unless column_exists?(:appointments, :follow_up_date)
    add_column :appointments, :cancelled_at,        :datetime unless column_exists?(:appointments, :cancelled_at)

    # Quick indexes for filtering
    add_index :appointments, [:clinic_id, :appointment_date, :status],
              name: "idx_appt_clinic_date_status" unless index_exists?(:appointments, name: "idx_appt_clinic_date_status")
  end
end
RUBY

echo "==> Migration written. Running…"
bin/rails db:migrate
echo "==> Done."
