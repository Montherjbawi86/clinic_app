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

ActiveRecord::Schema[7.2].define(version: 2026_09_29_224326) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "doctor_id", null: false
    t.date "appointment_date"
    t.string "appointment_time"
    t.text "reason"
    t.text "reason_ar"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_appointments_on_clinic_id"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role"
    t.text "content"
    t.string "language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "clinic_members", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["user_id"], name: "index_clinics_on_user_id"
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
    t.index ["clinic_id"], name: "index_medical_reports_on_clinic_id"
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
    t.index ["clinic_id"], name: "index_medications_on_clinic_id"
    t.index ["doctor_id"], name: "index_medications_on_doctor_id"
    t.index ["patient_id"], name: "index_medications_on_patient_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type"
    t.string "title"
    t.string "message"
    t.boolean "read"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["clinic_id"], name: "index_patients_on_clinic_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.string "status"
    t.string "stripe_payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_payments_on_clinic_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.string "plan"
    t.string "status"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_subscriptions_on_clinic_id"
  end

  create_table "transfers", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "patient_id", null: false
    t.string "from_clinic"
    t.string "to_clinic"
    t.text "reason"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_transfers_on_clinic_id"
    t.index ["patient_id"], name: "index_transfers_on_patient_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.string "locale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "appointments", "clinics"
  add_foreign_key "appointments", "patients"
  add_foreign_key "appointments", "users", column: "doctor_id"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "clinic_members", "clinics"
  add_foreign_key "clinic_members", "users"
  add_foreign_key "clinics", "users"
  add_foreign_key "medical_reports", "clinics"
  add_foreign_key "medical_reports", "patients"
  add_foreign_key "medical_reports", "users", column: "doctor_id"
  add_foreign_key "medications", "clinics"
  add_foreign_key "medications", "patients"
  add_foreign_key "medications", "users", column: "doctor_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "patients", "clinics"
  add_foreign_key "payments", "clinics"
  add_foreign_key "payments", "users"
  add_foreign_key "subscriptions", "clinics"
  add_foreign_key "transfers", "clinics"
  add_foreign_key "transfers", "patients"
end
