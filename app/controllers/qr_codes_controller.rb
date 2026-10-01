class QrCodesController < ApplicationController
  # GET /qr/:text — returns an SVG QR code for the given text
  def show
    require "rqrcode"

    text = params[:text].to_s
    return head :bad_request if text.blank?

    qr = RQRCode::QRCode.new(text)
    svg = qr.as_svg(
      offset: 0,
      color: "0f172a",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )

    send_data svg,
              type: "image/svg+xml",
              disposition: "inline"
  end
end
