class Dashboard::PaymentsController < ApplicationController
  before_action :require_login

  def index
    @payments = Payment.all.order(created_at: :desc)
    @payment = Payment.new
  end

  def create
    default_clinic = current_user.clinics.first || current_user.clinics.create!(name: "Main Clinic")
    @payment = Payment.new(payment_params)
    @payment.clinic_id = default_clinic.id
    @payment.user_id = current_user.id
    @payment.status ||= "completed"

    if @payment.save
      redirect_to dashboard_payments_path, notice: "Payment invoice recorded."
    else
      @payments = Payment.all.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def payment_params
    params.require(:payment).permit(:amount, :status)
  end
end
