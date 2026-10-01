require "prawn"
require "prawn/table"

::PrescriptionPdf = Class.new do
  FONT_PATH = Rails.root.join("app/assets/fonts/NotoSansArabic-Regular.ttf")
  FONT_BOLD = Rails.root.join("app/assets/fonts/NotoSansArabic-Regular.ttf")

  def initialize(appointment:, clinic:, doctor:, patient:, medications:)
    @appointment = appointment
    @clinic      = clinic
    @doctor      = doctor
    @patient     = patient
    @medications = medications
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
      register_fonts(pdf)
      draw_header(pdf)
      draw_patient_info(pdf)
      draw_diagnosis(pdf)
      draw_medications(pdf)
      draw_footer(pdf)
    end.render
  end

  private

  def register_fonts(pdf)
    unless File.exist?(FONT_PATH)
      raise "Arabic font not found at #{FONT_PATH}"
    end

    pdf.font_families.update(
      "AppFont" => {
        normal: FONT_PATH.to_s,
        bold:   File.exist?(FONT_BOLD) ? FONT_BOLD.to_s : FONT_PATH.to_s,
      }
    )
    pdf.font "AppFont"
  end

  def draw_header(pdf)
    pdf.text @clinic.name.to_s, size: 20, style: :bold, align: :center
    pdf.text @clinic.address.to_s, size: 10, align: :center
    pdf.text "هاتف: #{@clinic.phone}", size: 10, align: :center if @clinic.phone.present?
    pdf.move_down 10
    pdf.stroke_horizontal_rule
    pdf.move_down 15
    pdf.text "وصفة طبية", size: 16, style: :bold, align: :center
    pdf.move_down 15
  end

  def draw_patient_info(pdf)
    data = [
      ["اسم المريض:", @patient.display_name.to_s, "التاريخ:", @appointment.appointment_date.to_s],
      ["العمر:", (@patient.age.presence || @patient.age_from_dob).to_s, "الطبيب:", "د. #{@doctor.name}"],
    ]
    pdf.table(data, width: pdf.bounds.width, cell_style: { border_width: 0, size: 11 }) do
      cells.padding = [4, 6]
      column(0).style(style: :bold)
      column(2).style(style: :bold)
    end
    pdf.move_down 15
  end

  def draw_diagnosis(pdf)
    return unless @appointment.respond_to?(:visit_notes) && @appointment.visit_notes.present?
    pdf.text "ملاحظات الزيارة:", style: :bold
    pdf.text @appointment.visit_notes, size: 11
    pdf.move_down 15
  end

  def draw_medications(pdf)
    pdf.text "الأدوية الموصوفة:", style: :bold, size: 13
    pdf.move_down 8

    if @medications.any?
      rows = [["#", "الدواء", "الجرعة", "التكرار", "المدة", "ملاحظات"]]
      @medications.each_with_index do |m, i|
        rows << [
          i + 1,
          m.display_name.to_s,
          m.dosage.to_s,
          m.frequency.to_s,
          m.duration.to_s,
          m.instructions.to_s.truncate(40)
        ]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do
        row(0).style(background_color: "0D9488", text_color: "FFFFFF", font_style: :bold, align: :center)
        cells.padding = [6, 8]
        cells.size   = 10
        cells.border_color = "E2E8F0"
      end
    else
      pdf.text "لا توجد أدوية موصوفة.", size: 11, color: "888888"
    end
  end

  def draw_footer(pdf)
    pdf.move_down 40
    pdf.stroke_horizontal_rule
    pdf.move_down 20
    pdf.text "توقيع الطبيب: ____________________", size: 11, align: :right
    pdf.move_down 10
    pdf.text "هذه الوصفة صادرة إلكترونياً من نظام ClinicApp", size: 9, align: :center, color: "888888"
  end
end unless defined?(::PrescriptionPdf)
