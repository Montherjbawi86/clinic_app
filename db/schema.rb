# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_10_03_012350) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "doctor_id", null: false
    t.date "appointment_date"
    t.text "reason"
    t.text "reason_ar"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer "duration_minutes", default: 30
    t.text "notes"
    t.datetime "checked_in_at"
    t.datetime "completed_at"
    t.bigint "checked_in_by_id"
    t.bigint "cancelled_by_id"
    t.bigint "completed_by_id"
    t.text "cancellation_reason"
    t.text "visit_notes"
    t.text "visit_notes_ar"
    t.jsonb "vitals", default: {}
    t.date "follow_up_date"
    t.datetime "cancelled_at"
    t.time "appointment_time"
    t.string "public_token"
    t.string "source", default: "staff"
    t.string "patient_name"
    t.string "patient_phone"
    t.string "booking_ref"
    t.index ["appointment_date"], name: "index_appointments_on_appointment_date"
    t.index ["booking_ref"], name: "index_appointments_on_booking_ref", unique: true
    t.index ["cancelled_by_id"], name: "index_appointments_on_cancelled_by_id"
    t.index ["checked_in_by_id"], name: "index_appointments_on_checked_in_by_id"
    t.index ["clinic_id", "appointment_date", "status"], name: "idx_appt_clinic_date_status"
    t.index ["clinic_id"], name: "index_appointments_on_clinic_id"
    t.index ["completed_by_id"], name: "index_appointments_on_completed_by_id"
    t.index ["deleted_at"], name: "index_appointments_on_deleted_at"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.index ["public_token"], name: "index_appointments_on_public_token", unique: true
    t.index ["source"], name: "index_appointments_on_source"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "sender_role"
    t.text "content"
    t.string "language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tokens"
    t.string "conversation_id"
    t.jsonb "metadata", default: {}
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["user_id", "created_at"], name: "index_chat_messages_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "clinic_invitations", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "invited_by_id"
    t.string "email", null: false
    t.string "role", default: "doctor", null: false
    t.string "token", null: false
    t.datetime "accepted_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id", "email"], name: "idx_invitations_clinic_email", unique: true
    t.index ["clinic_id"], name: "index_clinic_invitations_on_clinic_id"
    t.index ["email"], name: "index_clinic_invitations_on_email"
    t.index ["invited_by_id"], name: "index_clinic_invitations_on_invited_by_id"
    t.index ["token"], name: "index_clinic_invitations_on_token", unique: true
  end

  create_table "clinic_members", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id", "user_id"], name: "index_clinic_members_on_clinic_id_and_user_id", unique: true
    t.index ["clinic_id"], name: "index_clinic_members_on_clinic_id"
    t.index ["user_id"], name: "index_clinic_members_on_user_id"
  end

  create_table "clinics", force: :cascade do |t|
    t.string "name"
    t.string "name_ar"
    t.string "address"
    t.string "phone"
    t.string "email"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address_ar"
    t.string "specialty"
    t.string "city"
    t.string "timezone", default: "Asia/Damascus"
    t.string "logo_url"
    t.jsonb "settings", default: {}
    t.datetime "discarded_at"
    t.jsonb "working_hours", default: {}
    t.string "slug"
    t.text "about"
    t.text "about_ar"
    t.boolean "is_public", default: false
    t.boolean "queue_display_enabled", default: true
    t.string "queue_display_pin"
    t.integer "slot_duration_minutes", default: 30
    t.string "lunch_break_start", default: "13:00"
    t.string "lunch_break_end", default: "14:00"
    t.index ["slug"], name: "index_clinics_on_slug", unique: true
    t.index ["user_id"], name: "index_clinics_on_user_id"
  end

  create_table "medical_images", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "medical_report_id"
    t.bigint "uploaded_by_id"
    t.string "title"
    t.string "title_ar"
    t.string "image_type"
    t.string "body_part"
    t.date "taken_on"
    t.text "notes"
    t.text "notes_ar"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_medical_images_on_clinic_id"
    t.index ["deleted_at"], name: "index_medical_images_on_deleted_at"
    t.index ["image_type"], name: "index_medical_images_on_image_type"
    t.index ["medical_report_id"], name: "index_medical_images_on_medical_report_id"
    t.index ["patient_id", "created_at"], name: "index_medical_images_on_patient_id_and_created_at"
    t.index ["patient_id"], name: "index_medical_images_on_patient_id"
    t.index ["uploaded_by_id"], name: "index_medical_images_on_uploaded_by_id"
  end

  create_table "medical_reports", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "doctor_id", null: false
    t.text "diagnosis"
    t.text "treatment"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.bigint "appointment_id"
    t.jsonb "vitals", default: {}
    t.date "follow_up_date"
    t.text "diagnosis_ar"
    t.text "treatment_ar"
    t.text "notes_ar"
    t.string "status", default: "final"
    t.index ["appointment_id"], name: "index_medical_reports_on_appointment_id"
    t.index ["clinic_id"], name: "index_medical_reports_on_clinic_id"
    t.index ["deleted_at"], name: "index_medical_reports_on_deleted_at"
    t.index ["doctor_id"], name: "index_medical_reports_on_doctor_id"
    t.index ["patient_id"], name: "index_medical_reports_on_patient_id"
  end

  create_table "medications", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "doctor_id", null: false
    t.string "name"
    t.string "dosage"
    t.string "frequency"
    t.string "duration"
    t.text "instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.bigint "appointment_id"
    t.string "name_ar"
    t.string "route"
    t.integer "quantity"
    t.integer "refills", default: 0
    t.string "status", default: "active"
    t.string "public_token"
    t.index ["appointment_id"], name: "index_medications_on_appointment_id"
    t.index ["clinic_id"], name: "index_medications_on_clinic_id"
    t.index ["deleted_at"], name: "index_medications_on_deleted_at"
    t.index ["doctor_id"], name: "index_medications_on_doctor_id"
    t.index ["patient_id"], name: "index_medications_on_patient_id"
    t.index ["public_token"], name: "index_medications_on_public_token", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type"
    t.string "title"
    t.string "message"
    t.boolean "read", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "title_ar"
    t.string "message_ar"
    t.string "severity", default: "info"
    t.datetime "read_at"
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["read_at"], name: "index_notifications_on_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.string "name"
    t.string "name_ar"
    t.string "phone"
    t.string "gender"
    t.integer "age"
    t.date "date_of_birth"
    t.text "medical_history"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "national_id"
    t.string "blood_type"
    t.string "address"
    t.string "emergency_name"
    t.string "emergency_phone"
    t.text "allergies"
    t.text "chronic_conditions"
    t.string "insurance_provider"
    t.string "insurance_number"
    t.string "email"
    t.index ["clinic_id", "name"], name: "index_patients_on_clinic_id_and_name"
    t.index ["clinic_id"], name: "index_patients_on_clinic_id"
    t.index ["deleted_at"], name: "index_patients_on_deleted_at"
    t.index ["national_id"], name: "index_patients_on_national_id"
    t.index ["phone"], name: "index_patients_on_phone"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.string "status"
    t.string "stripe_payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "SYP", null: false
    t.bigint "patient_id"
    t.bigint "appointment_id"
    t.string "method"
    t.string "reference"
    t.text "notes"
    t.datetime "paid_at"
    t.index ["appointment_id"], name: "index_payments_on_appointment_id"
    t.index ["clinic_id"], name: "index_payments_on_clinic_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["patient_id"], name: "index_payments_on_patient_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.string "plan"
    t.string "status"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_subscription_id"
    t.text "payment_proof_note"
    t.string "payment_method"
    t.string "transaction_reference"
    t.datetime "submitted_at"
    t.datetime "confirmed_at"
    t.bigint "confirmed_by_id"
    t.index ["clinic_id"], name: "index_subscriptions_on_clinic_id"
  end

  create_table "transfers", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.text "reason"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "from_clinic_id"
    t.bigint "to_clinic_id"
    t.index ["clinic_id"], name: "index_transfers_on_clinic_id"
    t.index ["from_clinic_id"], name: "index_transfers_on_from_clinic_id"
    t.index ["patient_id"], name: "index_transfers_on_patient_id"
    t.index ["to_clinic_id"], name: "index_transfers_on_to_clinic_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.string "locale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "clinics"
  add_foreign_key "appointments", "patients"
  add_foreign_key "appointments", "users", column: "cancelled_by_id"
  add_foreign_key "appointments", "users", column: "checked_in_by_id"
  add_foreign_key "appointments", "users", column: "completed_by_id"
  add_foreign_key "appointments", "users", column: "doctor_id"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "clinic_invitations", "clinics"
  add_foreign_key "clinic_invitations", "users", column: "invited_by_id"
  add_foreign_key "clinic_members", "clinics"
  add_foreign_key "clinic_members", "users"
  add_foreign_key "clinics", "users"
  add_foreign_key "medical_images", "clinics"
  add_foreign_key "medical_images", "medical_reports"
  add_foreign_key "medical_images", "patients"
  add_foreign_key "medical_images", "users", column: "uploaded_by_id"
  add_foreign_key "medical_reports", "appointments"
  add_foreign_key "medical_reports", "clinics"
  add_foreign_key "medical_reports", "patients"
  add_foreign_key "medical_reports", "users", column: "doctor_id"
  add_foreign_key "medications", "appointments"
  add_foreign_key "medications", "clinics"
  add_foreign_key "medications", "patients"
  add_foreign_key "medications", "users", column: "doctor_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "patients", "clinics"
  add_foreign_key "payments", "appointments"
  add_foreign_key "payments", "clinics"
  add_foreign_key "payments", "patients"
  add_foreign_key "payments", "users"
  add_foreign_key "subscriptions", "clinics"
  add_foreign_key "transfers", "clinics"
  add_foreign_key "transfers", "clinics", column: "from_clinic_id"
  add_foreign_key "transfers", "clinics", column: "to_clinic_id"
  add_foreign_key "transfers", "patients"
end
