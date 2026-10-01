module PublicNamesHelper
  # Shows only first name + last initial for privacy
  # "أحمد محمد الأحمد" → "أحمد ا."
  def public_name_helper(patient)
    return "—" unless patient
    full = patient.display_name.to_s.strip
    return full if full.blank?
    parts = full.split
    return full if parts.size <= 1
    "#{parts.first} #{parts.last[0]}."
  end
end
