#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Adding QR code to patients…"

# ============================================================
# 1. Helper for QR generation
# ============================================================
cat > app/helpers/qr_helper.rb <<'RUBY'
require "rqrcode"

module QrHelper
  # Returns an inline SVG string for the given text
  def qr_svg(text, size: 200, color: "#0f172a")
    qr = RQRCode::QRCode.new(text)
    qr.as_svg(
      offset: 0,
      color: color,
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    ).html_safe
  end

  # Returns a data URI you can drop into an <img src="">
  def qr_data_uri(text, size: 200, color: "#0f172a")
    qr = RQRCode::QRCode.new(text)
    svg = qr.as_svg(
      offset: 0,
      color: color,
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
RUBY

# ============================================================
# 2. Route for the QR-only page
# ============================================================
python3 <<'PY'
path = "config/routes.rb"
src = open(path).read()

old = '''    resources :patients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
      end
      resources :medical_images, only: [:index, :create, :show, :destroy], controller: "medical_images"
    end'''

new = '''    resources :patients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
        get :qr
      end
      resources :medical_images, only: [:index, :create, :show, :destroy], controller: "medical_images"
    end'''

if old not in src:
    print("❌ Pattern not found — paste routes.rb if needed")
    exit(1)

src = src.replace(old, new)
open(path, "w").write(src)
print("✅ Route added: /dashboard/patients/:id/qr")
PY

# ============================================================
# 3. Controller action
# ============================================================
python3 <<'PY'
path = "app/controllers/dashboard/patients_controller.rb"
src = open(path).read()

if "def qr" in src:
    print("✅ qr action already exists")
    exit(0)

# Add qr to before_action list
src = src.replace(
    "before_action :set_patient, only: [:show, :edit, :update, :destroy, :timeline]",
    "before_action :set_patient, only: [:show, :edit, :update, :destroy, :timeline, :qr]"
)

# Insert qr action right after show
old = "  def timeline\n"
new = '''  def qr
    @qr_text = dashboard_patient_url(@patient)
    # qr_text is available in the view for rendering
  end

  def timeline
'''
src = src.replace(old, new, 1)
open(path, "w").write(src)
print("✅ qr action added")
PY

# ============================================================
# 4. QR view
# ============================================================
cat > app/views/dashboard/patients/qr.html.erb <<'ERB'
<% content_for :title, "QR — #{@patient.display_name}" %>

<div class="max-w-md mx-auto space-y-6">

  <div class="text-center">
    <%= link_to "← #{@patient.display_name}", dashboard_patient_path(@patient),
          class: "text-sm text-teal-600 hover:underline" %>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-8 shadow-sm text-center">
    <h1 class="text-xl font-bold text-slate-800 mb-1">QR المريض</h1>
    <p class="text-sm text-slate-500 mb-6">
      امسح الرمز لفتح ملف المريض على الجوال
    </p>

    <div class="inline-block p-4 bg-white rounded-2xl border-2 border-slate-100">
      <img src="<%= qr_data_uri(@qr_text, color: '#0f172a') %>"
           alt="QR Code"
           class="w-56 h-56">
    </div>

    <div class="mt-6">
      <div class="text-xs text-slate-400 mb-1">اسم المريض</div>
      <div class="font-bold text-slate-800"><%= @patient.display_name %></div>
      <% if @patient.phone.present? %>
        <div class="text-xs text-slate-500 mt-1"><%= @patient.phone %></div>
      <% end %>
      <% if @patient.blood_type.present? %>
        <div class="text-xs text-slate-500 mt-1">🩸 <%= @patient.blood_type %></div>
      <% end %>
    </div>

    <div class="mt-6 flex justify-center gap-2">
      <button onclick="window.print()"
              class="bg-teal-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-teal-700 text-sm cursor-pointer">
        🖨️ طباعة
      </button>
      <%= link_to "الملف الكامل", dashboard_patient_path(@patient),
            class: "bg-white border border-slate-300 text-slate-700 px-4 py-2 rounded-lg font-semibold hover:bg-slate-50 text-sm" %>
    </div>
  </div>

  <div class="bg-teal-50 border border-teal-200 rounded-2xl p-4 text-sm text-teal-800">
    <div class="font-semibold mb-1">💡 استخدمات الرمز</div>
    <ul class="list-disc ms-5 space-y-1 text-xs">
      <li>طبعه على بطاقة المريض</li>
      <li>لصقه على ملفه الورقي</li>
      <li>أرسله للمريض لفتح ملفه بسرعة</li>
      <li>استخدمه في الاستقبال للوصول السريع</li>
    </ul>
  </div>

</div>

<!-- Print-only styles -->
<style media="print">
  body { background: white !important; }
  nav, header, footer, button, .no-print { display: none !important; }
</style>
ERB

# ============================================================
# 5. Add QR button to patient show page
# ============================================================
python3 <<'PY'
path = "app/views/dashboard/patients/show.html.erb"
src = open(path).read()

old = '''            <%= link_to "📜 الخط الزمني", timeline_dashboard_patient_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200 text-sm" %>'''

new = '''            <%= link_to "📜 الخط الزمني", timeline_dashboard_patient_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200 text-sm" %>
            <%= link_to "📱 QR", qr_dashboard_patient_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200 text-sm" %>'''

if old in src:
    src = src.replace(old, new, 1)
    open(path, "w").write(src)
    print("✅ QR button added to show page")
else:
    print("⚠️  Pattern not found — try adding manually")
    print("Search for: 📜 الخط الزمني in show.html.erb")
PY

echo "==> Done."
