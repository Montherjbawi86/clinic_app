class EnrichMedicalReports < ActiveRecord::Migration[7.2]
  def change
    add_reference :medical_reports, :appointment, foreign_key: true, index: true unless column_exists?(:medical_reports, :appointment_id)
    add_column    :medical_reports, :vitals,         :jsonb, default: {} unless column_exists?(:medical_reports, :vitals)
    add_column    :medical_reports, :follow_up_date, :date   unless column_exists?(:medical_reports, :follow_up_date)
    add_column    :medical_reports, :diagnosis_ar,   :text   unless column_exists?(:medical_reports, :diagnosis_ar)
    add_column    :medical_reports, :treatment_ar,   :text   unless column_exists?(:medical_reports, :treatment_ar)
    add_column    :medical_reports, :notes_ar,       :text   unless column_exists?(:medical_reports, :notes_ar)
    add_column    :medical_reports, :status,         :string, default: "final" unless column_exists?(:medical_reports, :status)
    add_column    :medical_reports, :deleted_at,     :datetime unless column_exists?(:medical_reports, :deleted_at)
    add_index     :medical_reports, :deleted_at unless index_exists?(:medical_reports, :deleted_at)
  end
end
