class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed checked_in in_progress completed cancelled no_show].freeze

  # Statuses that mean "not active anymore"
  CLOSED_STATUSES = %w[completed cancelled no_show].freeze
  OPEN_STATUSES   = %w[scheduled confirmed checked_in in_progress].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User", optional: true

  # Audit fields
  belongs_to :checked_in_by, class_name: "User", optional: true
  belongs_to :cancelled_by,  class_name: "User", optional: true
  belongs_to :completed_by,  class_name: "User", optional: true

  has_one  :medical_report, dependent: :nullify
  has_many :medications,    dependent: :nullify
  has_one  :payment,        dependent: :nullify

  validates :appointment_date, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  validate :patient_belongs_to_clinic
  validate :doctor_is_clinic_member

  before_validation :default_status
  before_validation :default_duration
  before_validation :generate_booking_ref, on: :create
  before_validation :generate_public_token, on: :create

  scope :upcoming,   -> { where("appointment_date >= ?", Date.current).order(:appointment_date, :appointment_time) }
  scope :for_today,  -> { where(appointment_date: Date.current) }
  scope :recent,     -> { order(appointment_date: :desc, appointment_time: :desc) }
  scope :open,       -> { where(status: OPEN_STATUSES) }
  scope :closed,     -> { where(status: CLOSED_STATUSES) }
  scope :cancelled,  -> { where(status: %w[cancelled no_show]) }
  scope :completed,  -> { where(status: "completed") }

  # -------- State transitions (all return true/false) --------

  def check_in!(user)
    update!(status: "checked_in", checked_in_at: Time.current, checked_in_by: user)
  end

  def start_visit!(user)
    update!(status: "in_progress")
  end

  def complete!(user, notes: nil, notes_ar: nil, vitals: nil, follow_up_date: nil)
    update!(
      status: "completed",
      completed_at: Time.current,
      completed_by: user,
      visit_notes: notes.presence || visit_notes,
      visit_notes_ar: notes_ar.presence || visit_notes_ar,
      vitals: vitals.presence || self.vitals,
      follow_up_date: follow_up_date.presence || self.follow_up_date
    )
  end

  def cancel!(user, reason: nil)
    update!(
      status: "cancelled",
      cancelled_at: Time.current,
      cancelled_by: user,
      cancellation_reason: reason
    )
  end

  def mark_no_show!(user)
    update!(status: "no_show", cancelled_by: user, cancelled_at: Time.current)
  end

  # -------- Convenience --------

  def closed?;  CLOSED_STATUSES.include?(status); end
  def open?;    OPEN_STATUSES.include?(status);   end
  def checked_in?; status == "checked_in";        end
  def completed?;  status == "completed";         end
  def cancelled?;  status == "cancelled";         end

  def starts_at
    return nil unless appointment_date && appointment_time
    Time.zone.parse("#{appointment_date} #{appointment_time}")
  end

  def ends_at
    starts_at&.+((duration_minutes || 30).minutes)
  end

  private

  def default_status
    self.status ||= "scheduled"
  end

  def default_duration
    self.duration_minutes ||= 30
  end

  def generate_booking_ref
    return if booking_ref.present?
    self.booking_ref = "BK-#{SecureRandom.alphanumeric(8).upcase}"
  end

  def generate_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(16)
  end

  def patient_belongs_to_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "does not belong to this clinic") if patient.clinic_id != clinic_id
  end

  def doctor_is_clinic_member
    return if doctor.nil? || clinic.nil?
    errors.add(:doctor, "is not a member of this clinic") unless doctor.member_of?(clinic)
  end
end
