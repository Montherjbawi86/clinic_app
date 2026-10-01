class PublicPrescriptionsController < ApplicationController
  layout "public"

  def show
    @appointment = Appointment.find_by!(public_token: params[:token])
    @patient     = @appointment.patient
    @clinic      = @appointment.clinic
    @doctor      = @appointment.doctor
    @medications = @appointment.medications
  rescue ActiveRecord::RecordNotFound
    render plain: "الوصفة غير موجودة أو منتهية الصلاحية", status: :not_found
  end
end
