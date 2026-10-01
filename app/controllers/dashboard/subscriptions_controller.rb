class Dashboard::SubscriptionsController < Dashboard::BaseController
  def index
    @subscriptions = current_clinic.subscriptions.order(created_at: :desc)
  end
end
