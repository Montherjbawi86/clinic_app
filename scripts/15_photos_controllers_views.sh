#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Controllers + views for photos…"

# ============================================================
# MedicalImagesController
# ============================================================
cat > app/controllers/dashboard/medical_images_controller.rb <<'RUBY'
class Dashboard::MedicalImagesController < Dashboard::BaseController
  before_action :set_patient, only: [:index, :create]
  before_action :set_image,   only: [:show, :destroy]

  def index
    @images = current_clinic.medical_images.for_patient(@patient).recent
    @image  = current_clinic.medical_images.new(patient: @patient)
  end

  def create
    @image = current_clinic.medical_images.new(image_params)
    @image.patient     = @patient
    @image.uploaded_by = current_user

    if @image.save
      redirect_to dashboard_patient_medical_images_path(@patient), notice: t("medical_images.created", default: "تم رفع الصورة بنجاح.")
    else
      @images = current_clinic.medical_images.for_patient(@patient).recent
      render :index, status: :unprocessable_entity
    end
  end

  def show
    send_data @image.file.download,
              filename: @image.file.filename.to_s,
              type: @image.file.content_type,
              disposition: "inline"
  end

  def destroy
    @patient = @image.patient
    @image.destroy
    redirect_to dashboard_patient_medical_images_path(@patient), notice: t("medical_images.removed", default: "تم حذف الصورة.")
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:patient_id])
  end

  def set_image
    @image = current_clinic.medical_images.find(params[:id])
  end

  def image_params
    params.require(:medical_image).permit(
      :title, :title_ar, :image_type, :body_part, :taken_on,
      :notes, :notes_ar, :medical_report_id, :file
    )
  end
end
RUBY

# ============================================================
# Update PatientsController to handle photo upload
# ============================================================
cat > app/controllers/dashboard/patients_controller.rb <<'RUBY'
class Dashboard::PatientsController < Dashboard::BaseController
  before_action :set_patient, only: [:show, :edit, :update, :destroy, :timeline]

  def index
    @patients = current_clinic.patients.order(created_at: :desc)
    @patients = @patients.search(params[:q]) if params[:q].present?
  end

  def show
    @appointments   = @patient.appointments.includes(:doctor).recent.limit(10)
    @reports        = @patient.medical_reports.includes(:doctor).recent.limit(10)
    @medications    = @patient.medications.active.recent.limit(10)
    @payments       = @patient.payments.recent.limit(10)
    @medical_images = @patient.medical_images.recent.limit(12)
  end

  def timeline
    @events = []
    @patient.appointments.each    { |a| @events << { at: a.created_at, type: "appointment", record: a } }
    @patient.medical_reports.each { |r| @events << { at: r.created_at, type: "report",      record: r } }
    @patient.medications.each     { |m| @events << { at: m.created_at, type: "medication",  record: m } }
    @patient.payments.each        { |p| @events << { at: p.created_at, type: "payment",     record: p } }
    @patient.transfers.each       { |t| @events << { at: t.created_at, type: "transfer",    record: t } }
    @patient.medical_images.each  { |i| @events << { at: i.created_at, type: "image",       record: i } }
    @events.sort_by! { |e| -e[:at].to_i }
  end

  def new
    @patient = current_clinic.patients.new
  end

  def edit; end

  def create
    @patient = current_clinic.patients.new(patient_params)
    if @patient.save
      redirect_to dashboard_patient_path(@patient), notice: t("patients.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @patient.update(patient_params)
      redirect_to dashboard_patient_path(@patient), notice: t("patients.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.respond_to?(:discard) ? @patient.discard : @patient.destroy
    redirect_to dashboard_patients_path, notice: t("patients.archived")
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :name, :name_ar, :phone, :gender, :age, :date_of_birth, :medical_history,
      :national_id, :blood_type, :address, :emergency_name, :emergency_phone,
      :allergies, :chronic_conditions, :insurance_provider, :insurance_number,
      :photo
    )
  end
end
RUBY

# ============================================================
# Patient form — add photo upload
# ============================================================
mkdir -p app/views/dashboard/patients
cat > app/views/dashboard/patients/_form.html.erb <<'ERB'
<% if patient.errors.any? %>
  <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-4 rounded-r-xl">
    <ul class="text-sm list-disc ms-5">
      <% patient.errors.full_messages.each do |m| %><li><%= m %></li><% end %>
    </ul>
  </div>
<% end %>

<!-- Photo upload -->
<div class="flex items-center gap-5 pb-4 mb-4 border-b border-slate-100">
  <div class="shrink-0">
    <% if patient.persisted? && patient.photo.attached? %>
      <%= image_tag patient.photo, class: "w-20 h-20 rounded-full object-cover ring-2 ring-teal-200" %>
    <% else %>
      <div class="w-20 h-20 rounded-full bg-teal-50 text-teal-600 flex items-center justify-center text-2xl font-bold ring-2 ring-teal-100">
        <%= patient.display_name&.first&.upcase || "؟" %>
      </div>
    <% end %>
  </div>
  <div class="flex-1">
    <%= f.label :photo, "صورة المريض", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.file_field :photo, accept: "image/*",
          class: "block w-full text-sm text-slate-500 file:me-3 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-teal-50 file:text-teal-700 hover:file:bg-teal-100" %>
    <div class="text-xs text-slate-400 mt-1">JPG, PNG · بحد أقصى 5 ميغابايت</div>
  </div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <%= f.label :name, "Name (EN)", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :name, class: "w-full border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-teal-500" %>
  </div>
  <div>
    <%= f.label :name_ar, "الاسم (AR)", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :name_ar, dir: "rtl", class: "w-full border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-teal-500" %>
  </div>
  <div>
    <%= f.label :phone, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :phone, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :national_id, "National ID", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :national_id, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :gender, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.select :gender, [["Male","male"],["Female","female"]], { include_blank: true },
          class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :blood_type, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.select :blood_type, %w[A+ A- B+ B- AB+ AB- O+ O-], { include_blank: true },
          class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :date_of_birth, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.date_field :date_of_birth, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :age, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.number_field :age, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div class="md:col-span-2">
    <%= f.label :address, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :address, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :emergency_name, "Emergency Contact", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :emergency_name, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :emergency_phone, "Emergency Phone", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :emergency_phone, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :insurance_provider, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :insurance_provider, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= f.label :insurance_number, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :insurance_number, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div class="md:col-span-2">
    <%= f.label :allergies, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_area :allergies, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div class="md:col-span-2">
    <%= f.label :chronic_conditions, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_area :chronic_conditions, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
  <div class="md:col-span-2">
    <%= f.label :medical_history, class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_area :medical_history, rows: 4, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
  </div>
</div>
ERB

# ============================================================
# Medical images index view
# ============================================================
mkdir -p app/views/dashboard/medical_images
cat > app/views/dashboard/medical_images/index.html.erb <<'ERB'
<% content_for :title, "الصور الطبية — #{@patient.display_name}" %>

<div class="space-y-6">
  <%= link_to "← #{@patient.display_name}", dashboard_patient_path(@patient),
        class: "text-sm text-teal-600 hover:underline" %>

  <div>
    <h1 class="text-2xl font-bold text-slate-800">📷 الصور الطبية</h1>
    <p class="text-slate-500 mt-1">صور شعاعية، أشعة مقطعية، رنين مغناطيسي، وأي صور طبية أخرى</p>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

    <!-- Upload form -->
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">رفع صورة جديدة</h2>

      <%= form_with model: [:dashboard, @patient, @image], class: "space-y-3" do |f| %>
        <% if @image.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @image.errors.full_messages.to_sentence %>
          </div>
        <% end %>

        <div>
          <%= f.label :file, "الصورة", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.file_field :file, accept: "image/*", required: true,
                class: "block w-full text-sm text-slate-500 file:me-3 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-teal-50 file:text-teal-700 hover:file:bg-teal-100" %>
          <div class="text-xs text-slate-400 mt-1">JPG, PNG, DICOM · بحد أقصى 20 ميغابايت</div>
        </div>

        <div>
          <%= f.label :title, "العنوان", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_field :title, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= f.label :image_type, "النوع", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.select :image_type,
                [
                  ["أشعة سينية", "xray"],
                  ["رنين مغناطيسي", "mri"],
                  ["أشعة مقطعية", "ct"],
                  ["موجات فوق صوتية", "ultrasound"],
                  ["صورة عامة", "photo"],
                  ["أخرى", "other"]
                ],
                { include_blank: true },
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= f.label :body_part, "المنطقة", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_field :body_part, placeholder: "صدر، رأس، بطن…",
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= f.label :taken_on, "تاريخ الصورة", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.date_field :taken_on, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= f.label :notes, "ملاحظات", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :notes, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <%= f.submit "رفع الصورة",
              class: "w-full bg-teal-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-teal-700 cursor-pointer" %>
      <% end %>
    </div>

    <!-- Gallery -->
    <div class="lg:col-span-2">
      <% if @images.any? %>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <% @images.each do |img| %>
            <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden group">
              <div class="relative aspect-square bg-slate-100">
                <% if img.file.attached? && img.image? %>
                  <%= link_to url_for(img.file), target: "_blank" do %>
                    <%= image_tag img.file.variant(resize_to_limit: [400, 400]),
                          class: "w-full h-full object-cover group-hover:scale-105 transition" %>
                  <% end %>
                <% else %>
                  <div class="w-full h-full flex flex-col items-center justify-center text-slate-400">
                    <span class="text-4xl">📄</span>
                    <span class="text-xs mt-1"><%= img.file.filename.to_s.truncate(20) if img.file.attached? %></span>
                  </div>
                <% end %>
                <% if img.image_type.present? %>
                  <span class="absolute top-2 start-2 text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-600 text-white">
                    <%= img.image_type.upcase %>
                  </span>
                <% end %>
              </div>
              <div class="p-3">
                <div class="text-sm font-semibold text-slate-800 truncate"><%= img.display_title %></div>
                <div class="text-xs text-slate-500 truncate">
                  <%= img.body_part.presence || "—" %>
                  · <%= img.taken_on&.strftime("%Y-%m-%d") || img.created_at.strftime("%Y-%m-%d") %>
                </div>
                <div class="flex justify-between items-center mt-2">
                  <%= link_to "عرض", url_for(img.file), target: "_blank",
                        class: "text-xs text-teal-600 hover:underline font-semibold" %>
                  <%= button_to "حذف", dashboard_patient_medical_image_path(@patient, img),
                        method: :delete,
                        data: { turbo_confirm: "حذف هذه الصورة؟" },
                        class: "text-xs text-rose-600 hover:underline font-semibold" %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="bg-white rounded-2xl border-2 border-dashed border-slate-200 p-12 text-center">
          <div class="text-5xl mb-3">📷</div>
          <div class="text-slate-500">لا توجد صور طبية بعد</div>
          <div class="text-xs text-slate-400 mt-1">ارفع أول صورة من النموذج على اليسار</div>
        </div>
      <% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# Update patient show — add photo avatar + medical images section
# ============================================================
cat > app/views/dashboard/patients/show.html.erb <<'ERB'
<% content_for :title, "#{@patient.display_name} — ClinicApp" %>

<div class="space-y-6">
  <%= link_to "← #{t('patients.title')}", dashboard_patients_path, class: "text-sm text-teal-600 hover:underline" %>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <div class="flex flex-col sm:flex-row items-start gap-5">
      <!-- Avatar -->
      <div class="shrink-0">
        <% if @patient.photo.attached? %>
          <%= image_tag @patient.photo, class: "w-24 h-24 rounded-2xl object-cover ring-2 ring-teal-100 shadow-sm" %>
        <% else %>
          <div class="w-24 h-24 rounded-2xl bg-gradient-to-br from-teal-500 to-teal-700 text-white flex items-center justify-center text-3xl font-bold shadow-sm">
            <%= @patient.initials.presence || @patient.display_name&.first&.upcase || "؟" %>
          </div>
        <% end %>
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="text-2xl font-bold text-slate-800"><%= @patient.display_name %></h1>
            <% if @patient.name_ar.present? && @patient.name.present? %>
              <p class="text-slate-500 mt-1"><%= @patient.name %></p>
            <% end %>
            <div class="flex flex-wrap gap-2 mt-2">
              <% if @patient.gender.present? %>
                <span class="badge badge-teal"><%= @patient.gender.titleize %></span>
              <% end %>
              <% if @patient.blood_type.present? %>
                <span class="badge badge-red">🩸 <%= @patient.blood_type %></span>
              <% end %>
              <% if (@patient.age.presence || @patient.age_from_dob).present? %>
                <span class="badge badge-gray"><%= @patient.age.presence || @patient.age_from_dob %> سنة</span>
              <% end %>
            </div>
          </div>
          <div class="flex gap-2 flex-wrap">
            <%= link_to "📷 الصور الطبية", dashboard_patient_medical_images_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-teal-50 text-teal-700 font-semibold hover:bg-teal-100 text-sm" %>
            <%= link_to "📜 الخط الزمني", timeline_dashboard_patient_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200 text-sm" %>
            <%= link_to "✏️ تعديل", edit_dashboard_patient_path(@patient),
                  class: "px-3 py-2 rounded-lg bg-teal-600 text-white font-semibold hover:bg-teal-700 text-sm" %>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 text-sm">
      <div><div class="text-slate-500">الهاتف</div><div class="font-medium"><%= @patient.phone.presence || "—" %></div></div>
      <div><div class="text-slate-500">الرقم الوطني</div><div class="font-medium"><%= @patient.national_id.presence || "—" %></div></div>
      <div><div class="text-slate-500">التأمين</div><div class="font-medium"><%= @patient.insurance_provider.presence || "—" %></div></div>
      <div><div class="text-slate-500">جهة الطوارئ</div><div class="font-medium"><%= @patient.emergency_name.presence || "—" %></div></div>
      <div><div class="text-slate-500">الطوارئ</div><div class="font-medium"><%= @patient.emergency_phone.presence || "—" %></div></div>
      <div><div class="text-slate-500">إجمالي المدفوع</div><div class="font-medium text-emerald-600"><%= number_to_currency(@patient.total_paid, unit: "SYP ", precision: 0) %></div></div>
      <div><div class="text-slate-500">عمر</div><div class="font-medium"><%= @patient.age.presence || @patient.age_from_dob || "—" %></div></div>
      <div><div class="text-slate-500">فصيلة الدم</div><div class="font-medium"><%= @patient.blood_type.presence || "—" %></div></div>
    </div>

    <% if @patient.allergies.present? %>
      <div class="mt-6 p-4 rounded-xl bg-rose-50 border border-rose-200">
        <div class="text-sm font-semibold text-rose-800">⚠️ الحساسية</div>
        <div class="text-sm text-rose-700 mt-1"><%= @patient.allergies %></div>
      </div>
    <% end %>
    <% if @patient.chronic_conditions.present? %>
      <div class="mt-4 p-4 rounded-xl bg-amber-50 border border-amber-200">
        <div class="text-sm font-semibold text-amber-800">الأمراض المزمنة</div>
        <div class="text-sm text-amber-700 mt-1"><%= @patient.chronic_conditions %></div>
      </div>
    <% end %>
  </div>

  <!-- Medical Images row -->
  <% if @medical_images.present? && @medical_images.any? %>
    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200 flex items-center justify-between">
        <h2 class="font-semibold text-slate-800">📷 الصور الطبية</h2>
        <%= link_to "عرض الكل", dashboard_patient_medical_images_path(@patient),
              class: "text-sm text-teal-600 hover:underline" %>
      </div>
      <div class="p-5">
        <div class="grid grid-cols-3 md:grid-cols-6 gap-3">
          <% @medical_images.first(6).each do |img| %>
            <%= link_to url_for(img.file), target: "_blank", class: "block" do %>
              <div class="aspect-square rounded-xl overflow-hidden bg-slate-100 ring-1 ring-slate-200 hover:ring-teal-400 transition">
                <% if img.image? %>
                  <%= image_tag img.file.variant(resize_to_limit: [200, 200]),
                        class: "w-full h-full object-cover" %>
                <% else %>
                  <div class="w-full h-full flex items-center justify-center text-2xl text-slate-400">📄</div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
  <% end %>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">📅 المواعيد الأخيرة</h2></div>
      <% if @appointments.any? %>
        <ul class="divide-y divide-slate-100">
          <% @appointments.each do |a| %>
            <li class="p-4 flex justify-between">
              <div>
                <div class="text-sm font-medium"><%= a.appointment_date %> <%= format_time(a.appointment_time) %></div>
                <div class="text-xs text-slate-500"><%= a.reason.presence || "—" %></div>
              </div>
              <span class="badge badge-teal h-fit"><%= t("appointments.statuses.#{a.status}", default: a.status) %></span>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">لا يوجد</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">📋 التقارير الأخيرة</h2></div>
      <% if @reports.any? %>
        <ul class="divide-y divide-slate-100">
          <% @reports.each do |r| %>
            <li class="p-4">
              <div class="text-sm font-medium"><%= r.display_diagnosis %></div>
              <div class="text-xs text-slate-500 mt-1"><%= r.created_at.strftime("%Y-%m-%d") %> — د. <%= r.doctor&.name %></div>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">لا يوجد</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">💊 الأدوية الفعالة</h2></div>
      <% if @medications.any? %>
        <ul class="divide-y divide-slate-100">
          <% @medications.each do |m| %>
            <li class="p-4">
              <div class="text-sm font-medium"><%= m.display_name %></div>
              <div class="text-xs text-slate-500"><%= m.dosage %> · <%= m.frequency.presence || "—" %></div>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">لا يوجد</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">💳 المدفوعات الأخيرة</h2></div>
      <% if @payments.any? %>
        <ul class="divide-y divide-slate-100">
          <% @payments.each do |p| %>
            <li class="p-4 flex justify-between">
              <div>
                <div class="text-sm font-medium"><%= p.display_amount %></div>
                <div class="text-xs text-slate-500"><%= p.method.presence || "—" %> · <%= p.status %></div>
              </div>
              <div class="text-xs text-slate-500"><%= p.created_at.strftime("%Y-%m-%d") %></div>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">لا يوجد</p><% end %>
    </div>
  </div>
</div>
ERB

echo "==> Controllers + views written."

# ============================================================
# Routes — full rewrite to add medical_images
# ============================================================
cat > config/routes.rb <<'RUBY'
Rails.application.routes.draw do
  root "home#index"

  resource  :session,       only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  post "/switch_clinic", to: "clinics#switch", as: :switch_clinic
  post "/switch_locale", to: "locales#update", as: :switch_locale

  get   "/profile",           to: "profile#show",            as: :profile
  get   "/profile/edit",      to: "profile#edit",            as: :edit_profile
  patch "/profile",           to: "profile#update"
  patch "/profile/password",  to: "profile#update_password", as: :update_profile_password

  resources :notifications, only: [:index, :destroy] do
    member do
      post :mark_read
    end
    collection do
      post :mark_all_read
    end
  end

  namespace :dashboard do
    root to: "overview#index"

    resources :clinics, only: [:index, :show]

    resources :patients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
      end
      resources :medical_images, only: [:index, :create, :show, :destroy], controller: "medical_images"
    end

    resources :appointments, only: [:index, :show, :create, :destroy] do
      member do
        patch :check_in
        patch :start_visit
        patch :complete
        patch :cancel
        patch :no_show
      end
    end

    resources :reports,       only: [:index, :show, :create, :destroy]
    resources :medications,   only: [:index, :create, :destroy]
    resources :transfers,     only: [:index, :create, :destroy]
    resources :payments,      only: [:index, :create, :destroy]
    resources :subscriptions, only: [:index]

    get  "chat", to: "chat#index", as: :chat
    post "chat", to: "chat#create"
  end

  get "/dashboard", to: "dashboard/overview#index", as: :dashboard
end
RUBY

echo "✅ Routes updated with nested medical_images."

# ============================================================
# Verify
# ============================================================
echo "==> Verifying routes:"
bin/rails routes | grep medical_images

echo "==> Done."
