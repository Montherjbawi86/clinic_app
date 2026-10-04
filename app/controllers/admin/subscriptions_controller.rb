class Admin::SubscriptionsController < Admin::BaseController
  before_action :set_subscription, only: [:show, :update, :confirm_payment, :reject_payment]

  def index
    scope = Subscription.includes(clinic: :owner).order(created_at: :desc)
    scope = scope.where(plan: params[:plan])     if params[:plan].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    @subscriptions = scope
    @plan_counts   = Subscription.group(:plan).count
    @pending_count = Subscription.pending_payment.count
  end

  def show; end

  def update
    if @subscription.update(subscription_params)
      redirect_to admin_subscription_path(@subscription), notice: "Updated"
    else
      redirect_to admin_subscription_path(@subscription), alert: @subscription.errors.full_messages.to_sentence
    end
  end

  def confirm_payment
    @subscription.confirm!(current_user)
    redirect_to admin_subscription_path(@subscription),
                notice: "✅ Payment confirmed — subscription activated"
  end

  def reject_payment
    @subscription.reject!
    redirect_to admin_subscription_path(@subscription),
                notice: "Payment rejected"
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:plan, :status, :expires_at)
  end
end
