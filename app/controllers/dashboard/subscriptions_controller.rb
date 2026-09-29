class Dashboard::SubscriptionsController < ApplicationController
  before_action :require_login
  def index
    @subscriptions = Subscription.all
  end
end
