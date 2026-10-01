module MedicationQrHelper
  # Returns inline SVG string for a medication's public QR
  def medication_qr_svg(medication, size: 100)
    return "" unless medication.respond_to?(:public_token) && medication.public_token.present?

    require "rqrcode"

    url = public_medication_url(medication.public_token)
    qr = RQRCode::QRCode.new(url)
    qr.as_svg(
      offset: 0,
      color: "0f172a",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true,
      use_path: true
    ).html_safe
  rescue => e
    Rails.logger.error("Medication QR failed for ##{medication.id}: #{e.message}")
    ""
  end

  # Returns a data URI version for use in <img> tags
  def medication_qr_data_uri(medication)
    return nil unless medication.respond_to?(:public_token) && medication.public_token.present?

    require "rqrcode"
    require "base64"

    url = public_medication_url(medication.public_token)
    qr = RQRCode::QRCode.new(url)
    svg = qr.as_svg(
      offset: 0,
      color: "0f172a",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true,
      use_path: true
    )
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  rescue => e
    Rails.logger.error("Medication QR failed for ##{medication.id}: #{e.message}")
    nil
  end
end
