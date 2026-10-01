class PublicClinicsController < ApplicationController
  layout "public"

  def show
    @clinic = Clinic.find_by!(slug: params[:slug])
    @owner  = @clinic.owner

    # Working hours
    @working_hours = @clinic.working_hours || {}

    # Recent public activity (stats only — no private data)
    @stats = {
      patients:     @clinic.patients.count,
      appointments: @clinic.appointments.where("appointment_date >= ?", 30.days.ago).count,
      doctors:      @clinic.clinic_members.where(role: %w[doctor owner]).count
    }
  rescue ActiveRecord::RecordNotFound
    render plain: "العيادة غير موجودة", status: :not_found
  end
end
