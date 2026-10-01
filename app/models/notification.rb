class Notification < ApplicationRecord
  TYPES    = %w[appointment_reminder payment_due transfer_request system].freeze
  SEVERITY = %w[info success warning danger].freeze

  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :title,    presence: true
  validates :severity, inclusion: { in: SEVERITY }, allow_nil: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_read!
    update!(read: true, read_at: Time.current)
  end
end
