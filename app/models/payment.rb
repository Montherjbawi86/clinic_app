class Payment < ApplicationRecord
  STATUSES   = %w[pending paid failed refunded cancelled].freeze
  CURRENCIES = %w[SYP USD].freeze
  METHODS    = %w[cash card transfer insurance stripe].freeze

  belongs_to :clinic
  belongs_to :user
  belongs_to :patient,     optional: true
  belongs_to :appointment, optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status,   inclusion: { in: STATUSES },   allow_nil: true
  validates :currency, inclusion: { in: CURRENCIES }, allow_nil: true
  validates :method,   inclusion: { in: METHODS },    allow_nil: true

  before_validation :default_currency
  before_validation :mark_paid_at

  scope :recent,  -> { order(created_at: :desc) }
  scope :paid,    -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }

  def display_amount
    "#{currency} #{'%.2f' % amount}"
  end

  private

  def default_currency
    self.currency ||= "SYP"
  end

  def mark_paid_at
    self.paid_at ||= Time.current if status == "paid" && paid_at.nil?
  end
end
