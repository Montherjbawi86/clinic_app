#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Setting up photo + imaging support…"

# ============================================================
# 1. Ensure ActiveStorage is installed
# ============================================================
if [ ! -f db/migrate/*_create_active_storage_tables.rb ] && ! grep -q "active_storage_blobs" db/schema.rb 2>/dev/null; then
  echo "==> Installing ActiveStorage…"
  bin/rails active_storage:install
fi

# ============================================================
# 2. Migration: add photo + medical image tables
# ============================================================
BASE=$(date +%Y%m%d%H%M)
echo "==> Creating migration ${BASE}13_attach_photos.rb"

cat > "db/migrate/${BASE}13_attach_photos.rb" <<'RUBY'
class AttachPhotos < ActiveRecord::Migration[7.2]
  def change
    # Medical images table — one patient can have many images
    unless table_exists?(:medical_images)
      create_table :medical_images do |t|
        t.references :clinic,        null: false, foreign_key: true
        t.references :patient,       null: false, foreign_key: true
        t.references :medical_report, foreign_key: true
        t.references :uploaded_by,   foreign_key: { to_table: :users }

        t.string   :title
        t.string   :title_ar
        t.string   :image_type          # xray, mri, ct, ultrasound, photo, other
        t.string   :body_part           # chest, head, abdomen, etc.
        t.date     :taken_on
        t.text     :notes
        t.text     :notes_ar
        t.datetime :deleted_at

        t.timestamps
      end

      add_index :medical_images, :image_type
      add_index :medical_images, :deleted_at
      add_index :medical_images, [:patient_id, :created_at]
    end
  end
end
RUBY

echo "==> Running migrations…"
bin/rails db:migrate

# ============================================================
# 3. MedicalImage model
# ============================================================
cat > app/models/medical_image.rb <<'RUBY'
class MedicalImage < ApplicationRecord
  IMAGE_TYPES = %w[xray mri ct ultrasound photo other].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :medical_report, optional: true
  belongs_to :uploaded_by, class_name: "User", optional: true

  has_one_attached :file

  validates :file, presence: true
  validates :image_type, inclusion: { in: IMAGE_TYPES }, allow_nil: true

  validate :patient_belongs_to_clinic

  scope :recent, -> { order(created_at: :desc) }
  scope :for_patient, ->(p) { where(patient_id: p) }
  scope :xrays, -> { where(image_type: "xray") }

  def display_title
    title_ar.presence || title.presence || file.filename.to_s
  end

  def image?
    file.attached? && file.content_type.to_s.start_with?("image/")
  end

  private

  def patient_belongs_to_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "not in this clinic") if patient.clinic_id != clinic_id
  end
end
RUBY

# ============================================================
# 4. Add patient photo to Patient model
# ============================================================
cat > app/models/patient.rb <<'RUBY'
class Patient < ApplicationRecord
  belongs_to :clinic

  has_many :appointments,    dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications,     dependent: :destroy
  has_many :transfers,       dependent: :destroy
  has_many :payments,        dependent: :destroy
  has_many :medical_images,  dependent: :destroy

  has_one_attached :photo

  validates :name, presence: true
  validates :gender, inclusion: { in: %w[male female] }, allow_nil: true
  validates :age, numericality: { only_integer: true, in: 0..130 }, allow_nil: true

  scope :search, ->(q) {
    where("name ILIKE :q OR name_ar ILIKE :q OR phone ILIKE :q OR national_id ILIKE :q",
          q: "%#{q}%")
  }

  def display_name
    name_ar.presence || name
  end

  def age_from_dob
    return nil unless date_of_birth
    ((Date.current - date_of_birth) / 365.25).floor
  end

  def total_paid
    payments.where(status: "paid").sum(:amount)
  end

  def outstanding_balance
    payments.where(status: "pending").sum(:amount)
  end

  def initials
    display_name.to_s.split.map { |w| w[0] }.join.upcase[0, 2]
  end
end
RUBY

# ============================================================
# 5. Add photos association to clinic
# ============================================================
cat > app/models/clinic.rb <<'RUBY'
class Clinic < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  has_many :clinic_members, dependent: :destroy
  has_many :members, through: :clinic_members, source: :user
  has_many :patients,        dependent: :destroy
  has_many :appointments,    dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications,     dependent: :destroy
  has_many :transfers,       dependent: :destroy
  has_many :payments,        dependent: :destroy
  has_many :subscriptions,   dependent: :destroy
  has_many :medical_images,  dependent: :destroy

  validates :name, presence: true

  def display_name
    name_ar.presence || name
  end

  def address_display
    address_ar.presence || address
  end
end
RUBY

# ============================================================
# 6. Routes for medical images
# ============================================================
# (We'll add routes via full rewrite in a moment)

echo "==> Done with model layer."
