class NotificationsController < ApplicationController
  before_action :require_login

  def index
    @notifications = current_user.notifications.recent
    @notifications = @notifications.unread if params[:filter] == "unread"
    @unread_count  = current_user.notifications.unread.count
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_to notifications_path, notice: "Marked as read."
  end

  def mark_all_read
    current_user.notifications.unread.find_each(&:mark_read!)
    redirect_to notifications_path, notice: "All marked as read."
  end

  def destroy
    notification = current_user.notifications.find(params[:id])
    notification.destroy
    redirect_to notifications_path, notice: "Notification removed."
  end
end
