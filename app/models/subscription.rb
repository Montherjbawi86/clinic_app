class Subscription < ApplicationRecord
  PLANS    = %w[free basic pro enterprise].freeze
  STATUSES = %w[active trialing past_due cancelled expired].freeze

  belongs_to :clinic

  validates :plan,   inclusion: { in: PLANS },    allow_nil: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :active, -> { where(status: "active").where("expires_at > ?", Time.current) }

  def active?
    status == "active" && expires_at&.future?
  end
end
