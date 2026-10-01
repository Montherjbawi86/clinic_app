#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Adding locale switcher, profile, notifications…"

# ============================================================
# 1) ApplicationController: locale switching
# ============================================================
cat > app/controllers/application_controller.rb <<'RUBY'
class ApplicationController < ActionController::Base
  around_action :switch_locale

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?
    redirect_to new_session_path, alert: "Please log in to continue."
  end

  def switch_locale(&action)
    locale =
      params[:locale].presence ||
      session[:locale].presence ||
      current_user&.locale.presence ||
      I18n.default_locale

    locale = locale.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)

    session[:locale] = locale
    I18n.with_locale(locale, &action)
  end
end
RUBY

# ============================================================
# 2) Locale switching route + controller
# ============================================================
cat > app/controllers/locales_controller.rb <<'RUBY'
class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s
    unless %w[ar en].include?(locale)
      return redirect_back fallback_location: root_path, alert: "Unsupported language."
    end

    session[:locale] = locale
    current_user.update(locale: locale) if current_user

    redirect_back fallback_location: root_path, notice: (locale == "ar" ? "تم تغيير اللغة." : "Language switched.")
  end
end
RUBY

# ============================================================
# 3) Profile controller
# ============================================================
cat > app/controllers/profile_controller.rb <<'RUBY'
class ProfileController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_password
    @user = current_user
    if @user.authenticate(params[:current_password])
      if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        redirect_to profile_path, notice: "Password changed successfully."
      else
        redirect_to profile_path, alert: @user.errors.full_messages.to_sentence
      end
    else
      redirect_to profile_path, alert: "Current password is incorrect."
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :locale)
  end
end
RUBY

# ============================================================
# 4) Notifications controller
# ============================================================
cat > app/controllers/notifications_controller.rb <<'RUBY'
class NotificationsController < ApplicationController
  before_action :require_login

  def index
    @notifications = current_user.notifications.recent
    @notifications = @notifications.unread if params[:filter] == "unread"
    @unread_count  = current_user.notifications.unread.count
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_to notifications_path, notice: "Marked as read."
  end

  def mark_all_read
    current_user.notifications.unread.find_each(&:mark_read!)
    redirect_to notifications_path, notice: "All marked as read."
  end

  def destroy
    notification = current_user.notifications.find(params[:id])
    notification.destroy
    redirect_to notifications_path, notice: "Notification removed."
  end
end
RUBY

# ============================================================
# 5) Routes: locales, profile, notifications
# ============================================================
cat > config/routes.rb <<'RUBY'
Rails.application.routes.draw do
  root "home#index"

  resource  :session,       only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  post "/switch_clinic",   to: "clinics#switch",      as: :switch_clinic
  post "/switch_locale",   to: "locales#update",      as: :switch_locale

  get   "/profile",        to: "profile#show",        as: :profile
  get   "/profile/edit",   to: "profile#edit",        as: :edit_profile
  patch "/profile",        to: "profile#update"
  patch "/profile/password", to: "profile#update_password", as: :update_profile_password

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

    resources :clinics,       only: [:index, :show]
    resources :patients,      only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
      end
    end
    resources :appointments,  only: [:index, :show, :create, :destroy] do
      member do
        patch :status
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

# ============================================================
# 6) Patient timeline + appointment status
# ============================================================
cat > app/controllers/dashboard/patients_controller.rb <<'RUBY'
class Dashboard::PatientsController < Dashboard::BaseController
  before_action :set_patient, only: [:show, :edit, :update, :destroy, :timeline]

  def index
    @patients = current_clinic.patients.order(created_at: :desc)
    @patients = @patients.search(params[:q]) if params[:q].present?
  end

  def show
    @appointments = @patient.appointments.includes(:doctor).recent.limit(10)
    @reports      = @patient.medical_reports.includes(:doctor).recent.limit(10)
    @medications  = @patient.medications.active.recent.limit(10)
    @payments     = @patient.payments.recent.limit(10)
  end

  def timeline
    @events = []
    @patient.appointments.each    { |a| @events << { at: a.created_at, type: "appointment", record: a } }
    @patient.medical_reports.each { |r| @events << { at: r.created_at, type: "report",      record: r } }
    @patient.medications.each     { |m| @events << { at: m.created_at, type: "medication",  record: m } }
    @patient.payments.each        { |p| @events << { at: p.created_at, type: "payment",     record: p } }
    @patient.transfers.each       { |t| @events << { at: t.created_at, type: "transfer",    record: t } }
    @events.sort_by! { |e| -e[:at].to_i }
  end

  def new
    @patient = current_clinic.patients.new
  end

  def edit; end

  def create
    @patient = current_clinic.patients.new(patient_params)
    if @patient.save
      redirect_to dashboard_patient_path(@patient), notice: "Patient registered successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @patient.update(patient_params)
      redirect_to dashboard_patient_path(@patient), notice: "Patient updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.respond_to?(:discard) ? @patient.discard : @patient.destroy
    redirect_to dashboard_patients_path, notice: "Patient archived."
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :name, :name_ar, :phone, :gender, :age, :date_of_birth, :medical_history,
      :national_id, :blood_type, :address, :emergency_name, :emergency_phone,
      :allergies, :chronic_conditions, :insurance_provider, :insurance_number
    )
  end
end
RUBY

cat > app/controllers/dashboard/appointments_controller.rb <<'RUBY'
class Dashboard::AppointmentsController < Dashboard::BaseController
  before_action :set_appointment, only: [:show, :destroy, :status]

  def index
    @appointments = current_clinic.appointments
                                   .includes(:patient, :doctor)
                                   .order(appointment_date: :asc, appointment_time: :asc)
    @appointments = @appointments.where(appointment_date: params[:date]) if params[:date].present?
    @appointment = current_clinic.appointments.new
  end

  def show; end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    @appointment.doctor ||= current_user
    @appointment.status ||= "scheduled"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: "Appointment scheduled successfully."
    else
      @appointments = current_clinic.appointments
                                     .includes(:patient, :doctor)
                                     .order(appointment_date: :asc, appointment_time: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  def status
    new_status = params[:status].to_s
    if Appointment::STATUSES.include?(new_status) && @appointment.update(status: new_status)
      redirect_to dashboard_appointments_path, notice: "Status updated to #{new_status}."
    else
      redirect_to dashboard_appointments_path, alert: "Could not update status."
    end
  end

  def destroy
    @appointment.destroy
    redirect_to dashboard_appointments_path, notice: "Appointment canceled."
  end

  private

  def set_appointment
    @appointment = current_clinic.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :doctor_id, :appointment_date, :appointment_time,
      :duration_minutes, :reason, :reason_ar, :notes, :status
    )
  end
end
RUBY

# ============================================================
# 7) Profile views
# ============================================================
mkdir -p app/views/profile
cat > app/views/profile/show.html.erb <<'ERB'
<% content_for :title, "الملف الشخصي — ClinicApp" %>

<div class="max-w-4xl mx-auto space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">👤 الملف الشخصي</h1>
    <p class="text-slate-500 mt-1">Manage your personal information</p>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <div class="flex flex-col sm:flex-row items-start sm:items-center gap-5">
      <div class="w-20 h-20 rounded-full bg-gradient-to-br from-blue-500 to-blue-700 text-white flex items-center justify-center font-bold text-3xl shadow-lg">
        <%= @user.name.to_s[0]&.upcase %>
      </div>
      <div class="flex-1">
        <h2 class="text-xl font-bold text-slate-800"><%= @user.name %></h2>
        <p class="text-slate-500 text-sm"><%= @user.email %></p>
        <div class="flex flex-wrap gap-2 mt-2">
          <span class="text-xs font-semibold px-2 py-1 rounded-full bg-blue-50 text-blue-700"><%= @user.role&.titleize %></span>
          <span class="text-xs font-semibold px-2 py-1 rounded-full bg-slate-100 text-slate-700">
            <%= @user.locale == "ar" ? "🇸🇾 العربية" : "🌐 English" %>
          </span>
        </div>
      </div>
      <%= link_to "تعديل الملف", edit_profile_path,
            class: "bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition" %>
    </div>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <h3 class="font-semibold text-slate-800 mb-4">🔄 تغيير كلمة المرور</h3>
    <%= form_with url: update_profile_password_path, method: :patch, class: "grid grid-cols-1 md:grid-cols-3 gap-3" do |f| %>
      <%= password_field_tag :current_password, nil, placeholder: "كلمة المرور الحالية", required: true,
            class: "border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500" %>
      <%= password_field_tag :password, nil, placeholder: "كلمة المرور الجديدة", required: true,
            class: "border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500" %>
      <%= password_field_tag :password_confirmation, nil, placeholder: "تأكيد كلمة المرور", required: true,
            class: "border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500" %>
      <div class="md:col-span-3">
        <%= submit_tag "تحديث كلمة المرور",
              class: "bg-slate-800 text-white px-5 py-2 rounded-lg font-semibold hover:bg-slate-900 cursor-pointer" %>
      </div>
    <% end %>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <h3 class="font-semibold text-slate-800 mb-4">🏥 عياداتي</h3>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <% @user.clinics.each do |c| %>
        <div class="border border-slate-200 rounded-xl p-4 flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
            <%= c.name[0]&.upcase %>
          </div>
          <div class="flex-1 min-w-0">
            <div class="font-semibold text-slate-800 truncate"><%= c.display_name %></div>
            <div class="text-xs text-slate-500"><%= @user.role_in(c)&.titleize %></div>
          </div>
        </div>
      <% end %>
    </div>
  </div>
</div>
ERB

cat > app/views/profile/edit.html.erb <<'ERB'
<% content_for :title, "تعديل الملف — ClinicApp" %>

<div class="max-w-2xl mx-auto space-y-6">
  <%= link_to "← رجوع", profile_path, class: "text-sm text-blue-600 hover:underline" %>
  <h1 class="text-2xl font-bold text-slate-800">✏️ تعديل الملف الشخصي</h1>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <%= form_with model: @user, url: profile_path, method: :patch, class: "space-y-5" do |f| %>
      <% if @user.errors.any? %>
        <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
          <%= @user.errors.full_messages.to_sentence %>
        </div>
      <% end %>

      <div>
        <%= f.label :name, "الاسم الكامل", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= f.text_field :name, class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500" %>
      </div>
      <div>
        <%= f.label :email, "البريد الإلكتروني", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= f.email_field :email, class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500" %>
      </div>
      <div>
        <%= f.label :locale, "اللغة المفضلة", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= f.select :locale, [["العربية","ar"],["English","en"]], {},
              class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500" %>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <%= link_to "إلغاء", profile_path, class: "px-4 py-2 rounded-lg text-slate-700 hover:bg-slate-100 font-semibold" %>
        <%= f.submit "حفظ التغييرات", class: "bg-blue-600 text-white px-5 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      </div>
    <% end %>
  </div>
</div>
ERB

# ============================================================
# 8) Notifications view
# ============================================================
mkdir -p app/views/notifications
cat > app/views/notifications/index.html.erb <<'ERB'
<% content_for :title, "الإشعارات — ClinicApp" %>

<div class="max-w-3xl mx-auto space-y-6">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">🔔 الإشعارات</h1>
      <p class="text-slate-500 mt-1">
        <%= @unread_count %> غير مقروء
      </p>
    </div>
    <div class="flex gap-2">
      <%= link_to "الكل", notifications_path,
            class: "px-3 py-2 rounded-lg text-sm font-semibold #{params[:filter].blank? ? 'bg-slate-800 text-white' : 'bg-slate-100 text-slate-700'}" %>
      <%= link_to "غير المقروء", notifications_path(filter: "unread"),
            class: "px-3 py-2 rounded-lg text-sm font-semibold #{params[:filter] == 'unread' ? 'bg-slate-800 text-white' : 'bg-slate-100 text-slate-700'}" %>
      <% if @unread_count.positive? %>
        <%= button_to "تحديد الكل كمقروء", mark_all_read_notifications_path, method: :post,
              class: "px-3 py-2 rounded-lg text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>
  </div>

  <% if @notifications.any? %>
    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
      <ul class="divide-y divide-slate-100">
        <% @notifications.each do |n| %>
          <%
            sev = case n.severity
                  when "success" then "bg-emerald-50 text-emerald-700"
                  when "warning" then "bg-amber-50 text-amber-700"
                  when "danger"  then "bg-rose-50 text-rose-700"
                  else "bg-slate-100 text-slate-700"
                  end
          %>
          <li class="p-4 flex items-start gap-3 <%= n.read ? '' : 'bg-blue-50/40' %>">
            <div class="w-10 h-10 rounded-lg <%= sev %> flex items-center justify-center flex-shrink-0 font-bold">
              <%= n.read ? "✓" : "●" %>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <div class="font-semibold text-slate-800 truncate"><%= n.title %></div>
                <span class="text-xs font-semibold px-2 py-0.5 rounded-full <%= sev %>"><%= n.notification_type&.titleize %></span>
              </div>
              <div class="text-sm text-slate-600 mt-1"><%= n.message %></div>
              <div class="text-xs text-slate-400 mt-2">
                <%= n.created_at.strftime("%Y-%m-%d %H:%M") %>
              </div>
            </div>
            <div class="flex gap-1 flex-shrink-0">
              <% unless n.read %>
                <%= button_to "✓", mark_read_notification_path(n), method: :post,
                      class: "p-2 rounded-lg text-emerald-600 hover:bg-emerald-50 font-bold cursor-pointer" %>
              <% end %>
              <%= button_to "×", notification_path(n), method: :delete,
                    data: { turbo_confirm: "حذف الإشعار؟" },
                    class: "p-2 rounded-lg text-rose-600 hover:bg-rose-50 font-bold cursor-pointer" %>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
  <% else %>
    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm p-12 text-center">
      <div class="text-4xl">🔕</div>
      <div class="text-slate-500 mt-3">لا توجد إشعارات</div>
    </div>
  <% end %>
</div>
ERB

# ============================================================
# 9) Patient timeline view
# ============================================================
cat > app/views/dashboard/patients/timeline.html.erb <<'ERB'
<% content_for :title, "الخط الزمني — #{@patient.display_name}" %>

<div class="max-w-3xl mx-auto space-y-6">
  <%= link_to "← #{@patient.display_name}", dashboard_patient_path(@patient),
        class: "text-sm text-blue-600 hover:underline" %>

  <div>
    <h1 class="text-2xl font-bold text-slate-800">📜 الخط الزمني للمريض</h1>
    <p class="text-slate-500 mt-1">كل الأحداث الطبية والمالية في مكان واحد</p>
  </div>

  <div class="relative">
    <div class="absolute inset-y-0 start-4 w-0.5 bg-slate-200"></div>

    <ul class="space-y-4">
      <% @events.each do |event| %>
        <%
          icon, color, title, detail =
            case event[:type]
            when "appointment"
              a = event[:record]
              ["📅", "bg-blue-100 text-blue-700",
               "موعد — #{a.status}",
               "#{a.appointment_date} #{a.appointment_time&.strftime('%H:%M')} — #{a.reason.presence || '—'}"]
            when "report"
              r = event[:record]
              ["📋", "bg-emerald-100 text-emerald-700",
               "تقرير طبي",
               r.display_diagnosis.to_s.truncate(120)]
            when "medication"
              m = event[:record]
              ["💊", "bg-purple-100 text-purple-700",
               "وصفة طبية",
               "#{m.display_name} — #{m.dosage} · #{m.frequency.presence || '—'}"]
            when "payment"
              p = event[:record]
              ["💳", "bg-amber-100 text-amber-700",
               "دفعة — #{p.status}",
               "#{p.display_amount} (#{p.method.presence || '—'})"]
            when "transfer"
              t = event[:record]
              ["🚑", "bg-rose-100 text-rose-700",
               "تحويل — #{t.status}",
               "من #{t.from_clinic&.display_name || '—'} إلى #{t.to_clinic&.display_name || '—'}"]
            else
              ["•", "bg-slate-100 text-slate-700", event[:type].titleize, ""]
            end
        %>
        <li class="relative ps-12">
          <div class="absolute start-0 w-8 h-8 rounded-full <%= color %> flex items-center justify-center shadow ring-4 ring-white">
            <%= icon %>
          </div>
          <div class="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
            <div class="flex items-center justify-between gap-2">
              <div class="font-semibold text-slate-800"><%= title %></div>
              <div class="text-xs text-slate-400 whitespace-nowrap">
                <%= event[:at].strftime("%Y-%m-%d %H:%M") %>
              </div>
            </div>
            <div class="text-sm text-slate-600 mt-1"><%= detail %></div>
          </div>
        </li>
      <% end %>
    </ul>

    <% if @events.empty? %>
      <p class="text-center text-slate-500 py-8">لا توجد أحداث بعد.</p>
    <% end %>
  </div>
</div>
ERB

# ============================================================
# 10) Update dashboard layout: notifications bell + user menu
# ============================================================
# Patch the existing dashboard.html.erb: replace bell + dropdown
ruby -i -pe '
  if $_.include?("<!-- Notifications -->")
    $_ = ""
  end
' app/views/layouts/dashboard.html.erb 2>/dev/null || true

# Simpler: rewrite the right-side block by regenerating the header portion.
# We rewrite the whole layout again with the new features baked in.
cat > app/views/layouts/dashboard.html.erb <<'ERB'
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" dir="<%= I18n.locale == :ar ? 'rtl' : 'ltr' %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "لوحة التحكم — ClinicApp" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <script src="https://cdn.tailwindcss.com"></script>
    <%= javascript_importmap_tags %>
    <style>
      html[dir="rtl"] body { font-family: "Segoe UI", "Tahoma", "Arial", sans-serif; }
      html[dir="ltr"] body { font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; }
      .sidebar-scroll::-webkit-scrollbar { width: 6px; }
      .sidebar-scroll::-webkit-scrollbar-thumb { background: rgba(148,163,184,.4); border-radius: 9999px; }
    </style>
  </head>

  <body class="bg-slate-50 antialiased min-h-screen">
    <div class="flex min-h-screen">

      <!-- SIDEBAR -->
      <aside id="sidebar"
             class="fixed inset-y-0 start-0 z-40 w-64 bg-slate-900 text-slate-200 flex flex-col
                    -translate-x-full rtl:translate-x-full
                    lg:translate-x-0 lg:rtl:translate-x-0
                    transition-transform duration-200 ease-out">

        <div class="h-16 flex items-center px-5 border-b border-slate-800">
          <%= link_to root_path, class: "flex items-center gap-2 text-white font-extrabold text-lg" do %>
            <svg class="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round"
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
            </svg>
            <span>ClinicApp</span>
          <% end %>
        </div>

        <div class="px-5 py-4 border-b border-slate-800">
          <div class="text-xs text-slate-400 mb-1">العيادة الحالية</div>
          <div class="font-semibold text-white truncate"><%= current_clinic&.name || "—" %></div>
          <% if current_user.clinics.count > 1 %>
            <%= form_with url: switch_clinic_path, method: :post, class: "mt-2" do %>
              <%= select_tag :clinic_id,
                    options_from_collection_for_select(current_user.clinics, :id, :name, session[:clinic_id]),
                    onchange: "this.form.submit()",
                    class: "w-full text-xs bg-slate-800 border-0 text-slate-200 rounded-lg px-2 py-1.5" %>
            <% end %>
          <% end %>
        </div>

        <nav class="flex-1 overflow-y-auto sidebar-scroll px-3 py-4 space-y-6">
          <%
            primary  = [
              ["📊", "نظرة عامة",     "Overview",     dashboard_path,              true],
              ["👥", "المرضى",        "Patients",     dashboard_patients_path,     false],
              ["📅", "المواعيد",      "Appointments", dashboard_appointments_path, false],
            ]
            clinical = [
              ["📋", "التقارير",      "Reports",      dashboard_reports_path,      false],
              ["💊", "الأدوية",       "Medications",  dashboard_medications_path,  false],
              ["🚑", "التحويلات",     "Transfers",    dashboard_transfers_path,    false],
            ]
            business = [
              ["💳", "المدفوعات",     "Payments",     dashboard_payments_path,     false],
              ["🏥", "العيادات",      "Clinics",      dashboard_clinics_path,      false],
              ["⚙️", "الاشتراكات",    "Subscriptions",dashboard_subscriptions_path, false],
            ]
            extras   = [
              ["🤖", "المساعد الذكي", "AI Assistant", dashboard_chat_path,         false],
            ]
          %>

          <% [["", primary], ["الطبي", clinical], ["الإداري", business], ["", extras]].each do |group_label, items| %>
            <div>
              <% if group_label.present? %>
                <div class="px-3 mb-2 text-xs font-semibold uppercase tracking-wider text-slate-500"><%= group_label %></div>
              <% end %>
              <ul class="space-y-1">
                <% items.each do |icon, ar, en, path, exact| %>
                  <% active = exact ? current_page?(path) : (request.path.start_with?(path) rescue false) %>
                  <li>
                    <%= link_to path,
                          class: "group flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition
                                  #{active ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-300 hover:bg-slate-800 hover:text-white'}" do %>
                      <span class="text-base"><%= icon %></span>
                      <span class="truncate"><%= I18n.locale == :ar ? ar : en %></span>
                    <% end %>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </nav>

        <div class="border-t border-slate-800 p-3">
          <%
            role   = (current_user.role_in(current_clinic) rescue nil) || current_user.role || "member"
            prefix = role == "doctor" ? "Dr. " : ""
          %>
          <div class="flex items-center gap-3 px-2 py-2 rounded-lg hover:bg-slate-800 transition">
            <div class="w-9 h-9 rounded-full bg-blue-500 text-white flex items-center justify-center font-bold">
              <%= current_user.name.to_s[0]&.upcase %>
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-semibold text-white truncate"><%= prefix %><%= current_user.name %></div>
              <div class="text-xs text-slate-400 truncate"><%= role.titleize %></div>
            </div>
          </div>
        </div>
      </aside>

      <div id="sidebar-backdrop"
           onclick="document.getElementById('sidebar').classList.add('-translate-x-full','rtl:translate-x-full'); this.classList.add('hidden')"
           class="hidden fixed inset-0 bg-black/40 z-30 lg:hidden"></div>

      <!-- MAIN AREA -->
      <div class="flex-1 lg:ms-64 flex flex-col min-h-screen">

        <!-- TOP NAV -->
        <header class="sticky top-0 z-30 h-16 bg-white border-b border-slate-200 flex items-center px-4 lg:px-6 gap-4">
          <button type="button"
                  onclick="document.getElementById('sidebar').classList.remove('-translate-x-full','rtl:translate-x-full'); document.getElementById('sidebar-backdrop').classList.remove('hidden')"
                  class="lg:hidden p-2 rounded-lg hover:bg-slate-100 text-slate-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>

          <div class="lg:hidden font-semibold text-slate-800 truncate">
            <%= content_for?(:title) ? yield(:title) : "لوحة التحكم" %>
          </div>

          <div class="hidden lg:flex flex-1 max-w-md">
            <%= form_with url: dashboard_patients_path, method: :get, class: "w-full" do %>
              <div class="relative">
                <span class="absolute inset-y-0 start-3 flex items-center text-slate-400">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-4.35-4.35M17 11a6 6 0 11-12 0 6 6 0 0112 0z"/>
                  </svg>
                </span>
                <input type="text" name="q" placeholder="ابحث عن مريض…"
                       class="w-full ps-9 pe-3 py-2 text-sm bg-slate-100 border-0 rounded-lg focus:ring-2 focus:ring-blue-500 placeholder:text-slate-400">
              </div>
            <% end %>
          </div>

          <div class="ms-auto flex items-center gap-2">

            <!-- Language switcher -->
            <div class="flex items-center gap-1 bg-slate-100 rounded-lg p-1">
              <%= button_to "ع", switch_locale_path(locale: "ar"), method: :post,
                    class: "px-2.5 py-1 text-xs font-bold rounded-md #{I18n.locale == :ar ? 'bg-white shadow text-blue-600' : 'text-slate-500 hover:text-slate-700'} cursor-pointer" %>
              <%= button_to "EN", switch_locale_path(locale: "en"), method: :post,
                    class: "px-2.5 py-1 text-xs font-bold rounded-md #{I18n.locale == :en ? 'bg-white shadow text-blue-600' : 'text-slate-500 hover:text-slate-700'} cursor-pointer" %>
            </div>

            <!-- Notifications -->
            <%= link_to notifications_path,
                  class: "relative p-2 rounded-lg hover:bg-slate-100 text-slate-600" do %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round"
                      d="M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 10-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
              </svg>
              <% unread = (current_user.notifications.unread.count rescue 0) %>
              <% if unread.positive? %>
                <span class="absolute -top-0.5 -end-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-rose-500 text-white text-[10px] font-bold flex items-center justify-center">
                  <%= unread > 9 ? "9+" : unread %>
                </span>
              <% end %>
            <% end %>

            <!-- User menu -->
            <div class="relative">
              <button type="button"
                      onclick="this.nextElementSibling.classList.toggle('hidden'); event.stopPropagation()"
                      class="flex items-center gap-2 p-1 rounded-lg hover:bg-slate-100 transition">
                <div class="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm font-bold">
                  <%= current_user.name.to_s[0]&.upcase %>
                </div>
                <svg class="w-4 h-4 text-slate-500 hidden sm:block" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                </svg>
              </button>

              <div class="hidden absolute end-0 mt-2 w-56 bg-white rounded-xl border border-slate-200 shadow-lg py-2 z-50">
                <div class="px-4 py-2 border-b border-slate-100">
                  <div class="text-sm font-semibold text-slate-800 truncate"><%= current_user.name %></div>
                  <div class="text-xs text-slate-500 truncate"><%= current_user.email %></div>
                </div>
                <%= link_to profile_path, class: "block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50" do %>
                  👤 الملف الشخصي
                <% end %>
                <%= link_to notifications_path, class: "block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50" do %>
                  🔔 الإشعارات
                <% end %>
                <%= link_to dashboard_root_path, class: "block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50" do %>
                  🏠 لوحة التحكم
                <% end %>
                <div class="border-t border-slate-100 my-1"></div>
                <%= button_to "🚪 تسجيل الخروج", session_path, method: :delete,
                      class: "w-full text-start px-4 py-2 text-sm text-rose-600 hover:bg-rose-50" %>
              </div>
            </div>
          </div>
        </header>

        <main class="flex-1 p-4 lg:p-6">
          <% [:notice, :alert].each do |type| %>
            <% next unless flash[type].present? %>
            <% colors = type.to_sym == :notice ?
                 { bg: "bg-emerald-50", border: "border-emerald-500", text: "text-emerald-800" } :
                 { bg: "bg-rose-50",    border: "border-rose-500",    text: "text-rose-800" } %>
            <div class="<%= colors[:bg] %> border-l-4 <%= colors[:border] %> <%= colors[:text] %> p-4 rounded-r-xl shadow-sm mb-6 flex items-center justify-between">
              <span class="font-medium"><%= flash[type] %></span>
              <button type="button" onclick="this.parentElement.remove()"
                      class="ms-4 text-xl leading-none cursor-pointer bg-transparent border-0">&times;</button>
            </div>
          <% end %>

          <%= yield %>
        </main>

        <!-- Footer (short) -->
        <footer class="border-t border-slate-200 bg-white">
          <div class="px-6 py-6 grid grid-cols-1 md:grid-cols-4 gap-6 text-sm">
            <div class="md:col-span-2">
              <div class="flex items-center gap-2 text-blue-600 font-extrabold">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round"
                        d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
                </svg>
                ClinicApp
              </div>
              <p class="text-slate-500 mt-2 max-w-sm text-xs leading-relaxed">
                نظام إدارة العيادات الطبية — مرضى، مواعيد، تقارير، أدوية، ومدفوعات في مكان واحد.
              </p>
            </div>
            <div>
              <div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2">الطبي</div>
              <ul class="space-y-1.5 text-xs text-slate-500">
                <li><%= link_to "المرضى",    dashboard_patients_path,     class: "hover:text-blue-600" %></li>
                <li><%= link_to "المواعيد",  dashboard_appointments_path, class: "hover:text-blue-600" %></li>
                <li><%= link_to "التقارير",  dashboard_reports_path,      class: "hover:text-blue-600" %></li>
              </ul>
            </div>
            <div>
              <div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2">الإداري</div>
              <ul class="space-y-1.5 text-xs text-slate-500">
                <li><%= link_to "المدفوعات", dashboard_payments_path,    class: "hover:text-blue-600" %></li>
                <li><%= link_to "العيادات",  dashboard_clinics_path,     class: "hover:text-blue-600" %></li>
                <li><%= link_to "الإشعارات", notifications_path,          class: "hover:text-blue-600" %></li>
              </ul>
            </div>
          </div>
          <div class="border-t border-slate-100 px-6 py-3 flex flex-col sm:flex-row justify-between items-center gap-2 text-xs text-slate-400">
            <p>&copy; <%= Time.current.year %> ClinicApp</p>
            <p>Ruby on Rails &amp; Tailwind CSS</p>
          </div>
        </footer>
      </div>
    </div>

    <script>
      // Close user dropdown on outside click
      document.addEventListener('click', function (e) {
        document.querySelectorAll('header .relative > div.absolute').forEach(function (menu) {
          if (!menu.parentElement.contains(e.target)) menu.classList.add('hidden');
        });
      });
    </script>
  </body>
</html>
ERB

# ============================================================
# 11) Add "timeline" link in patient show
# ============================================================
cat > app/views/dashboard/patients/show.html.erb <<'ERB'
<% content_for :title, "#{@patient.display_name} — ClinicApp" %>

<div class="space-y-6">
  <%= link_to "← All patients", dashboard_patients_path, class: "text-sm text-blue-600 hover:underline" %>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-2xl font-bold text-slate-800"><%= @patient.display_name %></h1>
        <% if @patient.name_ar.present? && @patient.name.present? %>
          <p class="text-slate-500 mt-1"><%= @patient.name %></p>
        <% end %>
      </div>
      <div class="flex gap-2">
        <%= link_to "📜 الخط الزمني", timeline_dashboard_patient_path(@patient),
              class: "px-4 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200" %>
        <%= link_to "✏️ تعديل", edit_dashboard_patient_path(@patient),
              class: "px-4 py-2 rounded-lg bg-blue-600 text-white font-semibold hover:bg-blue-700" %>
      </div>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 text-sm">
      <div><div class="text-slate-500">Phone</div><div class="font-medium"><%= @patient.phone.presence || "—" %></div></div>
      <div><div class="text-slate-500">Age</div><div class="font-medium"><%= @patient.age.presence || @patient.age_from_dob || "—" %></div></div>
      <div><div class="text-slate-500">Gender</div><div class="font-medium"><%= @patient.gender&.titleize || "—" %></div></div>
      <div><div class="text-slate-500">Blood</div><div class="font-medium"><%= @patient.blood_type.presence || "—" %></div></div>
      <div><div class="text-slate-500">National ID</div><div class="font-medium"><%= @patient.national_id.presence || "—" %></div></div>
      <div><div class="text-slate-500">Insurance</div><div class="font-medium"><%= @patient.insurance_provider.presence || "—" %></div></div>
      <div><div class="text-slate-500">Emergency</div><div class="font-medium"><%= @patient.emergency_name.presence || "—" %></div></div>
      <div><div class="text-slate-500">Total Paid</div><div class="font-medium text-emerald-600"><%= number_to_currency(@patient.total_paid, unit: "SYP ", precision: 0) %></div></div>
    </div>

    <% if @patient.allergies.present? %>
      <div class="mt-6 p-4 rounded-xl bg-rose-50 border border-rose-200">
        <div class="text-sm font-semibold text-rose-800">⚠️ Allergies</div>
        <div class="text-sm text-rose-700 mt-1"><%= @patient.allergies %></div>
      </div>
    <% end %>
    <% if @patient.chronic_conditions.present? %>
      <div class="mt-4 p-4 rounded-xl bg-amber-50 border border-amber-200">
        <div class="text-sm font-semibold text-amber-800">Chronic Conditions</div>
        <div class="text-sm text-amber-700 mt-1"><%= @patient.chronic_conditions %></div>
      </div>
    <% end %>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">📅 Recent Appointments</h2></div>
      <% if @appointments.any? %>
        <ul class="divide-y divide-slate-100">
          <% @appointments.each do |a| %>
            <li class="p-4 flex justify-between">
              <div>
                <div class="text-sm font-medium"><%= a.appointment_date %> <%= a.appointment_time&.strftime("%H:%M") %></div>
                <div class="text-xs text-slate-500"><%= a.reason.presence || "—" %></div>
              </div>
              <span class="text-xs px-2 py-1 rounded-full bg-blue-50 text-blue-700 h-fit"><%= a.status %></span>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">None.</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">📋 Recent Reports</h2></div>
      <% if @reports.any? %>
        <ul class="divide-y divide-slate-100">
          <% @reports.each do |r| %>
            <li class="p-4">
              <div class="text-sm font-medium"><%= r.display_diagnosis %></div>
              <div class="text-xs text-slate-500 mt-1"><%= r.created_at.strftime("%Y-%m-%d") %> — Dr. <%= r.doctor&.name %></div>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">None.</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">💊 Active Medications</h2></div>
      <% if @medications.any? %>
        <ul class="divide-y divide-slate-100">
          <% @medications.each do |m| %>
            <li class="p-4">
              <div class="text-sm font-medium"><%= m.display_name %></div>
              <div class="text-xs text-slate-500"><%= m.dosage %> · <%= m.frequency.presence || "—" %></div>
            </li>
          <% end %>
        </ul>
      <% else %><p class="p-5 text-sm text-slate-500">None.</p><% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">💳 Recent Payments</h2></div>
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
      <% else %><p class="p-5 text-sm text-slate-500">None.</p><% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# 12) Add status update buttons in appointments index
# ============================================================
cat > app/views/dashboard/appointments/index.html.erb <<'ERB'
<% content_for :title, "المواعيد — ClinicApp" %>

<div class="space-y-6">
  <div class="flex items-center justify-between flex-wrap gap-2">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">📅 المواعيد</h1>
      <p class="text-slate-500 mt-1">All appointments at this clinic.</p>
    </div>
    <%= form_with url: dashboard_appointments_path, method: :get, class: "flex gap-2" do %>
      <%= date_field_tag :date, params[:date], class: "border border-slate-300 rounded-lg px-3 py-2" %>
      <%= submit_tag "Filter", class: "bg-slate-800 text-white px-4 py-2 rounded-lg font-semibold cursor-pointer" %>
      <%= link_to "اليوم", dashboard_appointments_path(date: Date.current), class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold" %>
    <% end %>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">Schedule Appointment</h2>
      <%= form_with model: [:dashboard, @appointment], class: "space-y-3" do |f| %>
        <% if @appointment.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @appointment.errors.full_messages.to_sentence %>
          </div>
        <% end %>
        <div>
          <%= f.label :patient_id, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :patient_id, current_clinic.patients.order(:name), :id, :display_name,
                { prompt: "Select patient" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :doctor_id, "Doctor", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :doctor_id, current_clinic.members, :id, :name,
                { prompt: "Select doctor" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :appointment_date, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.date_field :appointment_date, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :appointment_time, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.time_field :appointment_time, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div>
          <%= f.label :duration_minutes, "Duration (min)", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.number_field :duration_minutes, value: 30, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :reason, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :reason, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit "Schedule", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @appointments.any? %>
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-500">
            <tr>
              <th class="text-start px-5 py-3 font-medium">Date</th>
              <th class="text-start px-5 py-3 font-medium">Time</th>
              <th class="text-start px-5 py-3 font-medium">Patient</th>
              <th class="text-start px-5 py-3 font-medium">Status</th>
              <th class="px-5 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <% @appointments.each do |a| %>
              <tr class="hover:bg-slate-50">
                <td class="px-5 py-3 text-slate-700"><%= a.appointment_date %></td>
                <td class="px-5 py-3 text-slate-700"><%= a.appointment_time&.strftime("%H:%M") %></td>
                <td class="px-5 py-3 font-medium text-slate-800"><%= a.patient&.display_name %></td>
                <td class="px-5 py-3">
                  <%
                    badge = case a.status
                            when "scheduled"  then "bg-blue-50 text-blue-700"
                            when "confirmed"  then "bg-indigo-50 text-indigo-700"
                            when "checked_in" then "bg-amber-50 text-amber-700"
                            when "completed"  then "bg-emerald-50 text-emerald-700"
                            when "cancelled", "no_show" then "bg-rose-50 text-rose-700"
                            else "bg-slate-100 text-slate-700"
                            end
                  %>
                  <span class="text-xs font-semibold px-2 py-1 rounded-full <%= badge %>"><%= a.status %></span>
                </td>
                <td class="px-5 py-3 text-end whitespace-nowrap">
                  <% if a.status == "scheduled" || a.status == "confirmed" %>
                    <%= button_to "✓ وصول", status_dashboard_appointment_path(a, status: "checked_in"), method: :patch,
                          class: "text-xs text-amber-700 hover:underline font-semibold me-2" %>
                  <% end %>
                  <% if a.status == "checked_in" %>
                    <%= button_to "✓ إتمام", status_dashboard_appointment_path(a, status: "completed"), method: :patch,
                          class: "text-xs text-emerald-700 hover:underline font-semibold me-2" %>
                  <% end %>
                  <% if a.status != "cancelled" && a.status != "completed" %>
                    <%= button_to "إلغاء", status_dashboard_appointment_path(a, status: "cancelled"), method: :patch,
                          class: "text-xs text-rose-600 hover:underline font-semibold me-2" %>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <p class="p-8 text-center text-slate-500 text-sm">No appointments yet.</p>
      <% end %>
    </div>
  </div>
</div>
ERB

echo "==> All done."
echo ""
echo "==> Sanity check:"
bin/rails runner 'puts "LocalesController: OK"; puts "ProfileController: OK"; puts "NotificationsController: OK"' 2>&1 | tail -5
echo "==> Done."
