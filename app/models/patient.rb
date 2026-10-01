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
