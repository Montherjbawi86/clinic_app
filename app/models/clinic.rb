class Clinic < ApplicationRecord
  include ClinicOptions

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
  has_many :clinic_invitations, dependent: :destroy

  has_one_attached :logo

  validates :name, presence: true

  before_validation :generate_slug

  def display_name
    name_ar.presence || name
  end

  def address_display
    address_ar.presence || address
  end

  def open_now?
    return false if working_hours.blank?
    today_key = Date.current.strftime("%A").downcase
    hours = working_hours[today_key]
    return false unless hours && hours["open"].present?

    now = Time.current.strftime("%H:%M")
    now >= hours["open"] && now <= hours["close"].to_s
  end

  def working_hours_today
    return nil if working_hours.blank?
    today_key = Date.current.strftime("%A").downcase
    working_hours[today_key]
  end

  private

  def generate_slug
    return if slug.present?
    return if name.blank?

    base = name.downcase.gsub(/[^a-z0-9\s-]/, "").strip.gsub(/\s+/, "-")
    self.slug = base.presence || "clinic-#{SecureRandom.hex(4)}"

    # Ensure uniqueness
    if Clinic.where(slug: self.slug).where.not(id: id).exists?
      self.slug = "#{self.slug}-#{SecureRandom.hex(3)}"
    end
  end
end
