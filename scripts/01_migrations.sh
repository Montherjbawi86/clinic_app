#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Base = YYYYMMDDHHMM (12 chars). We'll append a 2-digit suffix → 14 total.
BASE=$(date +%Y%m%d%H%M)
echo "==> Base: ${BASE} (will append 01…09)"

cat > "db/migrate/${BASE}01_enrich_payments.rb" <<'RUBY'
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
RUBY

cat > "db/migrate/${BASE}02_enrich_medical_reports.rb" <<'RUBY'
class EnrichMedicalReports < ActiveRecord::Migration[7.2]
  def change
    add_reference :medical_reports, :appointment, foreign_key: true, index: true unless column_exists?(:medical_reports, :appointment_id)
    add_column    :medical_reports, :vitals,         :jsonb, default: {} unless column_exists?(:medical_reports, :vitals)
    add_column    :medical_reports, :follow_up_date, :date   unless column_exists?(:medical_reports, :follow_up_date)
    add_column    :medical_reports, :diagnosis_ar,   :text   unless column_exists?(:medical_reports, :diagnosis_ar)
    add_column    :medical_reports, :treatment_ar,   :text   unless column_exists?(:medical_reports, :treatment_ar)
    add_column    :medical_reports, :notes_ar,       :text   unless column_exists?(:medical_reports, :notes_ar)
    add_column    :medical_reports, :status,         :string, default: "final" unless column_exists?(:medical_reports, :status)
    add_column    :medical_reports, :deleted_at,     :datetime unless column_exists?(:medical_reports, :deleted_at)
    add_index     :medical_reports, :deleted_at unless index_exists?(:medical_reports, :deleted_at)
  end
end
RUBY

cat > "db/migrate/${BASE}03_enrich_patients.rb" <<'RUBY'
class EnrichPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :national_id,        :string   unless column_exists?(:patients, :national_id)
    add_column :patients, :blood_type,         :string   unless column_exists?(:patients, :blood_type)
    add_column :patients, :address,            :string   unless column_exists?(:patients, :address)
    add_column :patients, :emergency_name,     :string   unless column_exists?(:patients, :emergency_name)
    add_column :patients, :emergency_phone,    :string   unless column_exists?(:patients, :emergency_phone)
    add_column :patients, :allergies,          :text     unless column_exists?(:patients, :allergies)
    add_column :patients, :chronic_conditions, :text     unless column_exists?(:patients, :chronic_conditions)
    add_column :patients, :insurance_provider, :string   unless column_exists?(:patients, :insurance_provider)
    add_column :patients, :insurance_number,   :string   unless column_exists?(:patients, :insurance_number)
    add_column :patients, :deleted_at,         :datetime unless column_exists?(:patients, :deleted_at)
    add_index  :patients, :national_id unless index_exists?(:patients, :national_id)
    add_index  :patients, :deleted_at  unless index_exists?(:patients, :deleted_at)
  end
end
RUBY

cat > "db/migrate/${BASE}04_enrich_appointments.rb" <<'RUBY'
class EnrichAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :duration_minutes, :integer, default: 30 unless column_exists?(:appointments, :duration_minutes)
    add_column :appointments, :notes,            :text unless column_exists?(:appointments, :notes)
    add_column :appointments, :checked_in_at,    :datetime unless column_exists?(:appointments, :checked_in_at)
    add_column :appointments, :completed_at,     :datetime unless column_exists?(:appointments, :completed_at)
    add_column :appointments, :deleted_at,       :datetime unless column_exists?(:appointments, :deleted_at)
    add_index  :appointments, :deleted_at unless index_exists?(:appointments, :deleted_at)
  end
end
RUBY

cat > "db/migrate/${BASE}05_enrich_medications.rb" <<'RUBY'
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
RUBY

cat > "db/migrate/${BASE}06_enrich_notifications.rb" <<'RUBY'
class EnrichNotifications < ActiveRecord::Migration[7.2]
  def change
    add_reference :notifications, :notifiable, polymorphic: true, index: true unless column_exists?(:notifications, :notifiable_id)
    add_column    :notifications, :title_ar,   :string   unless column_exists?(:notifications, :title_ar)
    add_column    :notifications, :message_ar, :string   unless column_exists?(:notifications, :message_ar)
    add_column    :notifications, :severity,   :string, default: "info" unless column_exists?(:notifications, :severity)
    add_column    :notifications, :read_at,    :datetime unless column_exists?(:notifications, :read_at)
    add_index     :notifications, :read_at unless index_exists?(:notifications, :read_at)
    add_index     :notifications, :created_at unless index_exists?(:notifications, :created_at)
  end
end
RUBY

cat > "db/migrate/${BASE}07_enrich_clinics.rb" <<'RUBY'
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
RUBY

cat > "db/migrate/${BASE}08_add_conversation_to_chat_messages.rb" <<'RUBY'
class AddConversationToChatMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :chat_messages, :conversation_id, :string  unless column_exists?(:chat_messages, :conversation_id)
    add_column :chat_messages, :tokens,          :integer unless column_exists?(:chat_messages, :tokens)
    add_column :chat_messages, :metadata,        :jsonb, default: {} unless column_exists?(:chat_messages, :metadata)
    add_index  :chat_messages, :conversation_id unless index_exists?(:chat_messages, :conversation_id)
  end
end
RUBY

cat > "db/migrate/${BASE}09_ensure_transfer_fks.rb" <<'RUBY'
class EnsureTransferFks < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:transfers, :from_clinic_id)
      add_reference :transfers, :from_clinic, foreign_key: { to_table: :clinics }, index: true
    end
    unless column_exists?(:transfers, :to_clinic_id)
      add_reference :transfers, :to_clinic, foreign_key: { to_table: :clinics }, index: true
    end
    if column_exists?(:transfers, :from_clinic)
      execute "UPDATE transfers t SET from_clinic_id = c.id FROM clinics c WHERE t.from_clinic = c.name"
      remove_column :transfers, :from_clinic, :string
    end
    if column_exists?(:transfers, :to_clinic)
      execute "UPDATE transfers t SET to_clinic_id = c.id FROM clinics c WHERE t.to_clinic = c.name"
      remove_column :transfers, :to_clinic, :string
    end
  end
end
RUBY

echo "==> Files created:"
ls db/migrate/ | grep "${BASE}" | sort

echo ""
echo "==> Running migrations…"
bin/rails db:migrate
echo "==> Done."
