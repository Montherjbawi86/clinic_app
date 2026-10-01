class Dashboard::CalendarsController < Dashboard::BaseController
  def index
    @start_date     = parse_date(params[:start]) || Date.current.beginning_of_month
    @months_to_show = (params[:months].presence || 1).to_i.clamp(1, 3)

    @month_ranges = @months_to_show.times.map do |i|
      m = (@start_date + i.months)
      m.beginning_of_month..m.end_of_month
    end

    range_start = @month_ranges.first.begin
    range_end   = @month_ranges.last.end

    @appointments = current_clinic.appointments
                                  .includes(:patient, :doctor)
                                  .where(appointment_date: range_start..range_end)
                                  .order(:appointment_date, :appointment_time)

    @appointments_by_date = @appointments.group_by(&:appointment_date)
    @working_hours        = current_clinic.working_hours || {}

    @doctors         = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
    @selected_doctor = params[:doctor_id].presence

    # For each day in the range, compute free-slot count
    @day_stats = {}
    @month_ranges.each do |range|
      (range.begin..range.end).each do |day|
        next unless in_working_hours?(day)
        av = Availability.new(
          clinic: current_clinic,
          date:   day,
          doctor: @selected_doctor ? User.find_by(id: @selected_doctor) : nil
        )
        @day_stats[day] = {
          free:   av.free_slots_count,
          total:  av.slots.count,
          booked: av.slots.count { |s| s[:status] == :booked }
        }
      end
    end

    @appointment = current_clinic.appointments.new
    @patients    = current_clinic.patients.order(:name)
  end

  def day
    @date    = Date.parse(params[:date]) rescue Date.current
    @clinic  = current_clinic
    @doctor  = params[:doctor_id].present? ? User.find_by(id: params[:doctor_id]) : nil

    @availability = Availability.new(clinic: @clinic, date: @date, doctor: @doctor)
    @slots        = @availability.slots

    @appointment  = current_clinic.appointments.new
    @patients     = current_clinic.patients.order(:name)
  end

  private

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str) rescue nil
  end

  def in_working_hours?(date)
    key = date.strftime("%A").downcase
    h = @working_hours[key]
    h.present? && h["open"].present? && h["close"].present?
  end
end
