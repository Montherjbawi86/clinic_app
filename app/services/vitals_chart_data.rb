class VitalsChartData
  METRICS = {
    "bp_systolic"  => "الضغط الانقباضي",
    "bp_diastolic" => "الضغط الانبساطي",
    "heart_rate"   => "النبض",
    "temperature"  => "الحرارة",
    "weight"       => "الوزن",
    "height"       => "الطول",
    "glucose"      => "السكر",
    "oxygen"       => "الأكسجين"
  }.freeze

  def initialize(patient)
    @patient = patient
  end

  def all_series
    METRICS.keys.index_with { |key| series_for(key) }
  end

  def series_for(metric)
    events = []

    # From appointment vitals
    @patient.appointments.where.not(vitals: [nil, {}]).order(:appointment_date).find_each do |appt|
      raw = appt.vitals || {}
      value = extract_value(raw, metric)
      next if value.nil?
      events << { date: appt.appointment_date.to_s, value: value }
    end

    # From medical reports vitals (if any)
    if @patient.medical_reports.column_names.include?("vitals")
      @patient.medical_reports.where.not(vitals: [nil, {}]).order(:created_at).find_each do |report|
        raw = report.vitals || {}
        value = extract_value(raw, metric)
        next if value.nil?
        events << { date: report.created_at.to_date.to_s, value: value }
      end
    end

    events.sort_by { |e| e[:date] }
  end

  def summary_for(metric)
    data = series_for(metric)
    return nil if data.empty?
    values = data.map { |d| d[:value] }
    {
      count:  values.size,
      first:  values.first,
      last:   values.last,
      min:    values.min,
      max:    values.max,
      avg:    (values.sum / values.size.to_f).round(1),
      change: (values.last - values.first).round(1)
    }
  end

  def any_data?
    METRICS.keys.any? { |m| series_for(m).any? }
  end

  private

  def extract_value(raw, metric)
    return raw[metric].to_f if raw[metric].present? && numeric?(raw[metric])

    if metric.start_with?("bp_")
      combined = raw["blood_pressure"] || raw["bp"]
      return parse_bp(combined, metric) if combined.present?
    end

    aliases = {
      "bp_systolic"  => %w[systolic sys],
      "bp_diastolic" => %w[diastolic dia],
      "heart_rate"   => %w[pulse hr],
      "temperature"  => %w[temp],
      "weight"       => %w[mass],
      "glucose"      => %w[blood_sugar sugar],
      "oxygen"       => %w[spo2 o2]
    }

    (aliases[metric] || []).each do |alt|
      return raw[alt].to_f if raw[alt].present? && numeric?(raw[alt])
    end

    nil
  end

  def parse_bp(combined, metric)
    parts = combined.to_s.split("/")
    return nil if parts.size < 2
    metric == "bp_systolic" ? parts[0].to_f : parts[1].to_f
  end

  def numeric?(val)
    val.to_s.match?(/\A-?\d+(\.\d+)?\z/)
  end
end
