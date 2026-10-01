class MedicalImage < ApplicationRecord
  IMAGE_TYPES = %w[xray mri ct ultrasound photo other].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :medical_report, optional: true
  belongs_to :uploaded_by, class_name: "User", optional: true

  has_one_attached :file

  validates :image_type, inclusion: { in: IMAGE_TYPES }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_patient, ->(p) { where(patient_id: p) }

  def display_title
    title_ar.presence || title.presence || (file.attached? ? file.filename.to_s : "—")
  end

  def image?
    file.attached? && file.content_type.to_s.start_with?("image/")
  end
end
