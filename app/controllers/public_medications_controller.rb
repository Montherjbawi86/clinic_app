class PublicMedicationsController < ApplicationController
  layout "public"

  def show
    @medication = Medication.find_by!(public_token: params[:token])
    @patient    = @medication.patient
    @clinic     = @medication.clinic
    @doctor     = @medication.doctor
  rescue ActiveRecord::RecordNotFound
    render plain: "الوصفة غير موجودة", status: :not_found
  end
end
