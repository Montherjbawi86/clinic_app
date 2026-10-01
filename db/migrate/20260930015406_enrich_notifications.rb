class EnrichNotifications < ActiveRecord::Migration[7.2]
  def change
    add_reference :notifications, :notifiable, polymorphic: true, index: true unless column_exists?(:notifications, :notifiable_id)
    add_column    :notifications, :title_ar,   :string   unless column_exists?(:notifications, :title_ar)
    add_column    :notifications, :message_ar, :string   unless column_exists?(:notifications, :message_ar)
    add_column    :notifications, :severity,   :string, default: "info" unless column_exists?(:notifications, :severity)
    add_column    :notifications, :read_at,    :datetime unless column_exists?(:notifications, :read_at)
    add_index     :notifications, :read_at unless index_exists?(:notifications, :read_at)
    add_index     :notifications, :created_at unless index_exists?(:notifications, :created_at)
  end
end
