#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Updating Appointment model…"

cat > app/models/appointment.rb <<'RUBY'
class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed checked_in in_progress completed cancelled no_show].freeze

  # Statuses that mean "not active anymore"
  CLOSED_STATUSES = %w[completed cancelled no_show].freeze
  OPEN_STATUSES   = %w[scheduled confirmed checked_in in_progress].freeze

  belongs_to :clinic
  belongs_to :patient
  belongs_to :doctor, class_name: "User", optional: true

  # Audit fields
  belongs_to :checked_in_by, class_name: "User", optional: true
  belongs_to :cancelled_by,  class_name: "User", optional: true
  belongs_to :completed_by,  class_name: "User", optional: true

  has_one  :medical_report, dependent: :nullify
  has_many :medications,    dependent: :nullify
  has_one  :payment,        dependent: :nullify

  validates :appointment_date, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  validate :patient_belongs_to_clinic
  validate :doctor_is_clinic_member

  before_validation :default_status
  before_validation :default_duration

  scope :upcoming,   -> { where("appointment_date >= ?", Date.current).order(:appointment_date, :appointment_time) }
  scope :for_today,  -> { where(appointment_date: Date.current) }
  scope :recent,     -> { order(appointment_date: :desc, appointment_time: :desc) }
  scope :open,       -> { where(status: OPEN_STATUSES) }
  scope :closed,     -> { where(status: CLOSED_STATUSES) }
  scope :cancelled,  -> { where(status: %w[cancelled no_show]) }
  scope :completed,  -> { where(status: "completed") }

  # -------- State transitions (all return true/false) --------

  def check_in!(user)
    update!(status: "checked_in", checked_in_at: Time.current, checked_in_by: user)
  end

  def start_visit!(user)
    update!(status: "in_progress")
  end

  def complete!(user, notes: nil, notes_ar: nil, vitals: nil, follow_up_date: nil)
    update!(
      status: "completed",
      completed_at: Time.current,
      completed_by: user,
      visit_notes: notes.presence || visit_notes,
      visit_notes_ar: notes_ar.presence || visit_notes_ar,
      vitals: vitals.presence || self.vitals,
      follow_up_date: follow_up_date.presence || self.follow_up_date
    )
  end

  def cancel!(user, reason: nil)
    update!(
      status: "cancelled",
      cancelled_at: Time.current,
      cancelled_by: user,
      cancellation_reason: reason
    )
  end

  def mark_no_show!(user)
    update!(status: "no_show", cancelled_by: user, cancelled_at: Time.current)
  end

  # -------- Convenience --------

  def closed?;  CLOSED_STATUSES.include?(status); end
  def open?;    OPEN_STATUSES.include?(status);   end
  def checked_in?; status == "checked_in";        end
  def completed?;  status == "completed";         end
  def cancelled?;  status == "cancelled";         end

  def starts_at
    return nil unless appointment_date && appointment_time
    Time.zone.parse("#{appointment_date} #{appointment_time}")
  end

  def ends_at
    starts_at&.+((duration_minutes || 30).minutes)
  end

  private

  def default_status
    self.status ||= "scheduled"
  end

  def default_duration
    self.duration_minutes ||= 30
  end

  def patient_belongs_to_clinic
    return if patient.nil? || clinic.nil?
    errors.add(:patient, "does not belong to this clinic") if patient.clinic_id != clinic_id
  end

  def doctor_is_clinic_member
    return if doctor.nil? || clinic.nil?
    errors.add(:doctor, "is not a member of this clinic") unless doctor.member_of?(clinic)
  end
end
RUBY

echo "==> Updating AppointmentsController…"

cat > app/controllers/dashboard/appointments_controller.rb <<'RUBY'
class Dashboard::AppointmentsController < Dashboard::BaseController
  before_action :set_appointment, only: [:show, :destroy, :check_in, :start_visit, :complete, :cancel, :no_show]

  def index
    base = current_clinic.appointments.includes(:patient, :doctor, :checked_in_by, :cancelled_by)

    # Filters: status, date, doctor
    base = base.where(status: params[:status])               if params[:status].present?
    base = base.where(appointment_date: params[:date])       if params[:date].present?
    base = base.where(doctor_id: params[:doctor_id])         if params[:doctor_id].present?

    @filter = params[:filter].presence || "all"
    base =
      case @filter
      when "today"     then base.for_today
      when "upcoming"  then base.upcoming.open
      when "open"      then base.open
      when "completed" then base.completed
      when "cancelled" then base.cancelled
      else base
      end

    @appointments = base.order(appointment_date: :asc, appointment_time: :asc)

    @appointment = current_clinic.appointments.new
    @doctors     = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
    @counts = {
      all:       current_clinic.appointments.count,
      today:     current_clinic.appointments.for_today.count,
      upcoming:  current_clinic.appointments.upcoming.open.count,
      open:      current_clinic.appointments.open.count,
      completed: current_clinic.appointments.completed.count,
      cancelled: current_clinic.appointments.cancelled.count
    }
  end

  def show
    @report     = @appointment.medical_report || current_clinic.medical_reports.new(appointment: @appointment)
    @medication = current_clinic.medications.new(appointment: @appointment, patient: @appointment.patient)
    @medications = @appointment.medications
  end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    @appointment.doctor ||= current_user
    @appointment.status ||= "scheduled"

    if @appointment.save
      redirect_to dashboard_appointments_path, notice: t("appointments.scheduled")
    else
      @doctors = current_clinic.members.where(clinic_members: { role: %w[doctor owner] })
      @appointments = current_clinic.appointments.includes(:patient, :doctor).order(appointment_date: :asc, appointment_time: :asc)
      @counts = { all: 0, today: 0, upcoming: 0, open: 0, completed: 0, cancelled: 0 }
      render :index, status: :unprocessable_entity
    end
  end

  # ---- Status transitions ----

  def check_in
    if @appointment.check_in!(current_user)
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.checked_in_notice")
    else
      redirect_to dashboard_appointments_path, alert: @appointment.errors.full_messages.to_sentence
    end
  end

  def start_visit
    if @appointment.start_visit!(current_user)
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.started_notice")
    else
      redirect_to dashboard_appointments_path, alert: "Could not start visit."
    end
  end

  def complete
    if @appointment.complete!(current_user,
                              notes: params[:visit_notes],
                              notes_ar: params[:visit_notes_ar],
                              vitals: params[:vitals],
                              follow_up_date: params[:follow_up_date])
      redirect_to dashboard_appointment_path(@appointment), notice: t("appointments.completed_notice")
    else
      redirect_to dashboard_appointment_path(@appointment), alert: @appointment.errors.full_messages.to_sentence
    end
  end

  def cancel
    if @appointment.cancel!(current_user, reason: params[:cancellation_reason])
      redirect_to dashboard_appointments_path, notice: t("appointments.cancelled_notice")
    else
      redirect_to dashboard_appointment_path(@appointment), alert: "Could not cancel."
    end
  end

  def no_show
    @appointment.mark_no_show!(current_user)
    redirect_to dashboard_appointments_path, notice: t("appointments.no_show_notice")
  end

  def destroy
    @appointment.destroy
    redirect_to dashboard_appointments_path, notice: t("appointments.destroyed_notice")
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

echo "==> Updating routes…"

# Append new member routes to the appointments resource
python3 - <<'PY'
import re
path = "config/routes.rb"
src = open(path).read()

new_block = '''    resources :appointments,  only: [:index, :show, :create, :destroy] do
      member do
        patch :check_in
        patch :start_visit
        patch :complete
        patch :cancel
        patch :no_show
      end
    end'''

# Replace existing appointment line
src = re.sub(r'    resources :appointments,\s+only: \[:index, :show, :create, :destroy\](?: do[\s\S]*?end)?', new_block, src)

open(path, "w").write(src)
print("✅ routes updated")
PY

echo "==> Writing views…"

mkdir -p app/views/dashboard/appointments

# ---------- INDEX ----------
cat > app/views/dashboard/appointments/index.html.erb <<'ERB'
<% content_for :title, "#{t('appointments.title')} — ClinicApp" %>

<div class="space-y-6">
  <div class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">📅 <%= t("appointments.title") %></h1>
      <p class="text-slate-500 mt-1"><%= t("appointments.subtitle") %></p>
    </div>

    <%= form_with url: dashboard_appointments_path, method: :get, class: "flex gap-2 flex-wrap" do %>
      <%= hidden_field_tag :filter, @filter %>
      <%= date_field_tag :date, params[:date],
            class: "border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
      <%= submit_tag t("actions.filter"),
            class: "bg-slate-800 text-white px-4 py-2 rounded-lg font-semibold cursor-pointer text-sm" %>
      <%= link_to t("actions.today"),
            dashboard_appointments_path(filter: "today"),
            class: "px-3 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold text-sm hover:bg-slate-200" %>
    <% end %>
  </div>

  <!-- Filter tabs -->
  <div class="flex flex-wrap gap-2">
    <%
      tabs = [
        ["all",       t("actions.all"),                    @counts[:all]],
        ["today",     t("actions.today"),                  @counts[:today]],
        ["upcoming",  t("appointments.filters.upcoming"),  @counts[:upcoming]],
        ["open",      t("appointments.filters.open"),      @counts[:open]],
        ["completed", t("appointments.filters.completed"), @counts[:completed]],
        ["cancelled", t("appointments.filters.cancelled"), @counts[:cancelled]],
      ]
    %>
    <% tabs.each do |key, label, count| %>
      <% active = @filter == key %>
      <%= link_to dashboard_appointments_path(filter: key),
            class: "px-3 py-2 rounded-lg text-sm font-semibold flex items-center gap-2 transition #{active ? 'bg-blue-600 text-white shadow-sm' : 'bg-white border border-slate-200 text-slate-700 hover:bg-slate-50'}" do %>
        <%= label %>
        <span class="text-xs px-1.5 py-0.5 rounded-full <%= active ? 'bg-white/20' : 'bg-slate-100 text-slate-600' %>">
          <%= count %>
        </span>
      <% end %>
    <% end %>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4"><%= t("appointments.new") %></h2>
      <%= form_with model: [:dashboard, @appointment], class: "space-y-3" do |f| %>
        <% if @appointment.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @appointment.errors.full_messages.to_sentence %>
          </div>
        <% end %>

        <div>
          <%= f.label :patient_id, t("appointments.patient"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :patient_id, current_clinic.patients.order(:name), :id, :display_name,
                { prompt: t("appointments.select_patient") },
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :doctor_id, t("appointments.doctor"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :doctor_id, @doctors, :id, :name,
                { prompt: t("appointments.select_doctor") },
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :appointment_date, t("appointments.date"), class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.date_field :appointment_date, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :appointment_time, t("appointments.time"), class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.time_field :appointment_time, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div>
          <%= f.label :duration_minutes, t("appointments.duration"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.number_field :duration_minutes, value: 30, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :reason, t("appointments.reason"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :reason, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit t("appointments.new"),
              class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @appointments.any? %>
        <ul class="divide-y divide-slate-100">
          <% @appointments.each do |a| %>
            <%
              badge = case a.status
                      when "scheduled"  then "bg-blue-50 text-blue-700"
                      when "confirmed"  then "bg-indigo-50 text-indigo-700"
                      when "checked_in" then "bg-amber-50 text-amber-700"
                      when "in_progress"then "bg-purple-50 text-purple-700"
                      when "completed"  then "bg-emerald-50 text-emerald-700"
                      when "cancelled", "no_show" then "bg-rose-50 text-rose-700"
                      else "bg-slate-100 text-slate-700"
                      end
            %>
            <li class="p-4 hover:bg-slate-50 transition">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <%= link_to dashboard_appointment_path(a),
                          class: "font-semibold text-slate-800 hover:text-blue-600 truncate" do %>
                      <%= a.patient&.display_name %>
                    <% end %>
                    <span class="text-xs font-semibold px-2 py-1 rounded-full <%= badge %>">
                      <%= t("appointments.statuses.#{a.status}", default: a.status) %>
                    </span>
                  </div>
                  <div class="text-sm text-slate-500 mt-1">
                    <%= a.appointment_date %> · <%= a.appointment_time&.strftime("%H:%M") %>
                    · <%= t("appointments.doctor") %>: <%= a.doctor&.name || "—" %>
                  </div>
                  <% if a.reason.present? %>
                    <div class="text-sm text-slate-600 mt-1 truncate"><%= a.reason %></div>
                  <% end %>

                  <%# Audit trail %>
                  <% if a.cancelled_by %>
                    <div class="text-xs text-rose-500 mt-1">
                      <%= t("appointments.cancelled_by") %>: <%= a.cancelled_by.name %>
                      <%= "· #{a.cancelled_at.strftime('%Y-%m-%d %H:%M')}" if a.cancelled_at %>
                      <% if a.cancellation_reason.present? %> — <%= a.cancellation_reason %><% end %>
                    </div>
                  <% end %>
                  <% if a.checked_in_by %>
                    <div class="text-xs text-emerald-600 mt-1">
                      <%= t("appointments.checked_in_by") %>: <%= a.checked_in_by.name %>
                      <%= "· #{a.checked_in_at.strftime('%H:%M')}" if a.checked_in_at %>
                    </div>
                  <% end %>
                </div>

                <!-- Action buttons -->
                <div class="flex flex-col gap-1 items-end flex-shrink-0">
                  <% if a.status == "scheduled" || a.status == "confirmed" %>
                    <%= button_to "✓ #{t('appointments.actions.check_in')}",
                          check_in_dashboard_appointment_path(a), method: :patch,
                          class: "text-xs bg-amber-500 text-white px-3 py-1.5 rounded-lg font-semibold hover:bg-amber-600" %>
                  <% end %>
                  <% if a.status == "checked_in" %>
                    <%= button_to "▶ #{t('appointments.actions.start')}",
                          start_visit_dashboard_appointment_path(a), method: :patch,
                          class: "text-xs bg-purple-500 text-white px-3 py-1.5 rounded-lg font-semibold hover:bg-purple-600" %>
                  <% end %>
                  <% if a.status == "in_progress" %>
                    <%= link_to "📝 #{t('appointments.actions.complete')}",
                          dashboard_appointment_path(a),
                          class: "text-xs bg-emerald-500 text-white px-3 py-1.5 rounded-lg font-semibold hover:bg-emerald-600" %>
                  <% end %>
                  <% if a.open? %>
                    <%= link_to t("actions.view"),
                          dashboard_appointment_path(a),
                          class: "text-xs text-blue-600 hover:underline font-semibold" %>
                  <% end %>
                </div>
              </div>
            </li>
          <% end %>
        </ul>
      <% else %>
        <div class="p-12 text-center">
          <div class="text-5xl">📅</div>
          <p class="text-slate-500 mt-3 text-sm"><%= t("appointments.no_appointments") %></p>
        </div>
      <% end %>
    </div>
  </div>
</div>
ERB

# ---------- SHOW (visit details + report + meds) ----------
cat > app/views/dashboard/appointments/show.html.erb <<'ERB'
<% content_for :title, "#{@appointment.patient&.display_name} — #{@appointment.appointment_date}" %>

<div class="space-y-6">
  <%= link_to "← #{t('appointments.title')}", dashboard_appointments_path,
        class: "text-sm text-blue-600 hover:underline" %>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <div class="flex items-start justify-between flex-wrap gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-800">
          <%= @appointment.patient&.display_name %>
        </h1>
        <p class="text-slate-500 mt-1">
          <%= @appointment.appointment_date %> ·
          <%= @appointment.appointment_time&.strftime("%H:%M") %>
          · <%= @appointment.duration_minutes %> <%= t("appointments.duration_unit") %>
        </p>
      </div>
      <%
        badge = case @appointment.status
                when "scheduled"  then "bg-blue-50 text-blue-700"
                when "confirmed"  then "bg-indigo-50 text-indigo-700"
                when "checked_in" then "bg-amber-50 text-amber-700"
                when "in_progress"then "bg-purple-50 text-purple-700"
                when "completed"  then "bg-emerald-50 text-emerald-700"
                when "cancelled", "no_show" then "bg-rose-50 text-rose-700"
                else "bg-slate-100 text-slate-700"
                end
      %>
      <span class="text-sm font-semibold px-3 py-1.5 rounded-full <%= badge %>">
        <%= t("appointments.statuses.#{@appointment.status}", default: @appointment.status) %>
      </span>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 text-sm">
      <div>
        <div class="text-slate-500"><%= t("appointments.doctor") %></div>
        <div class="font-medium"><%= @appointment.doctor&.name || "—" %></div>
      </div>
      <div>
        <div class="text-slate-500"><%= t("appointments.reason") %></div>
        <div class="font-medium"><%= @appointment.reason.presence || "—" %></div>
      </div>
      <% if @appointment.checked_in_by %>
        <div>
          <div class="text-slate-500"><%= t("appointments.checked_in_by") %></div>
          <div class="font-medium text-amber-700"><%= @appointment.checked_in_by.name %></div>
        </div>
      <% end %>
      <% if @appointment.completed_by %>
        <div>
          <div class="text-slate-500"><%= t("appointments.completed_by") %></div>
          <div class="font-medium text-emerald-700"><%= @appointment.completed_by.name %></div>
        </div>
      <% end %>
      <% if @appointment.cancelled_by %>
        <div>
          <div class="text-slate-500"><%= t("appointments.cancelled_by") %></div>
          <div class="font-medium text-rose-700"><%= @appointment.cancelled_by.name %></div>
        </div>
      <% end %>
    </div>

    <% if @appointment.cancellation_reason.present? %>
      <div class="mt-6 p-4 rounded-xl bg-rose-50 border border-rose-200">
        <div class="text-sm font-semibold text-rose-800"><%= t("appointments.cancellation_reason") %></div>
        <div class="text-sm text-rose-700 mt-1"><%= @appointment.cancellation_reason %></div>
      </div>
    <% end %>

    <!-- Action bar -->
    <div class="flex flex-wrap gap-2 mt-6 pt-4 border-t border-slate-100">
      <% if @appointment.status == "scheduled" || @appointment.status == "confirmed" %>
        <%= button_to "✓ #{t('appointments.actions.check_in')}",
              check_in_dashboard_appointment_path(@appointment), method: :patch,
              class: "bg-amber-500 text-white px-4 py-2 rounded-lg font-semibold hover:bg-amber-600" %>
      <% end %>
      <% if @appointment.status == "checked_in" %>
        <%= button_to "▶ #{t('appointments.actions.start')}",
              start_visit_dashboard_appointment_path(@appointment), method: :patch,
              class: "bg-purple-500 text-white px-4 py-2 rounded-lg font-semibold hover:bg-purple-600" %>
      <% end %>
      <% if @appointment.status == "in_progress" %>
        <%= form_with url: complete_dashboard_appointment_path(@appointment), method: :patch, class: "flex gap-2" do %>
          <%= submit_tag "✓ #{t('appointments.actions.complete')}",
                class: "bg-emerald-500 text-white px-4 py-2 rounded-lg font-semibold hover:bg-emerald-600 cursor-pointer" %>
        <% end %>
      <% end %>
      <% if @appointment.open? %>
        <%= link_to "✕ #{t('appointments.actions.no_show')}",
              "#", onclick: "document.getElementById('no-show-form').classList.toggle('hidden'); return false;",
              class: "text-rose-600 px-4 py-2 rounded-lg font-semibold hover:bg-rose-50" %>
        <%= link_to "🚫 #{t('appointments.actions.cancel')}",
              "#", onclick: "document.getElementById('cancel-form').classList.toggle('hidden'); return false;",
              class: "text-rose-600 px-4 py-2 rounded-lg font-semibold hover:bg-rose-50" %>
      <% end %>
    </div>

    <!-- Cancel form (hidden by default) -->
    <div id="cancel-form" class="hidden mt-4 p-4 bg-rose-50 border border-rose-200 rounded-xl">
      <%= form_with url: cancel_dashboard_appointment_path(@appointment), method: :patch, class: "space-y-2" do %>
        <%= text_area_tag :cancellation_reason, nil, rows: 2, required: true,
              placeholder: t("appointments.cancellation_reason_placeholder"),
              class: "w-full border border-rose-300 rounded-lg px-3 py-2" %>
        <%= submit_tag t("appointments.actions.confirm_cancel"),
              class: "bg-rose-600 text-white px-4 py-2 rounded-lg font-semibold cursor-pointer hover:bg-rose-700" %>
      <% end %>
    </div>

    <div id="no-show-form" class="hidden mt-4">
      <%= button_to t("appointments.actions.confirm_no_show"),
            no_show_dashboard_appointment_path(@appointment), method: :patch,
            data: { turbo_confirm: t("appointments.no_show_confirm") },
            class: "bg-rose-600 text-white px-4 py-2 rounded-lg font-semibold cursor-pointer hover:bg-rose-700" %>
    </div>
  </div>

  <!-- Visit notes / completion -->
  <% if @appointment.status == "in_progress" || @appointment.status == "completed" %>
    <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
      <h2 class="font-semibold text-slate-800 mb-4">📝 <%= t("appointments.visit_notes") %></h2>

      <%= form_with url: complete_dashboard_appointment_path(@appointment), method: :patch, class: "space-y-4" do %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div>
            <%= label_tag :vitals_bp, t("appointments.vitals.bp"), class: "block text-xs font-medium text-slate-600 mb-1" %>
            <%= text_field_tag "vitals[blood_pressure]", @appointment.vitals&.dig("blood_pressure"),
                  placeholder: "120/80", class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
          </div>
          <div>
            <%= label_tag :vitals_hr, t("appointments.vitals.hr"), class: "block text-xs font-medium text-slate-600 mb-1" %>
            <%= text_field_tag "vitals[heart_rate]", @appointment.vitals&.dig("heart_rate"),
                  placeholder: "72", class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
          </div>
          <div>
            <%= label_tag :vitals_temp, t("appointments.vitals.temp"), class: "block text-xs font-medium text-slate-600 mb-1" %>
            <%= text_field_tag "vitals[temperature]", @appointment.vitals&.dig("temperature"),
                  placeholder: "36.8", class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
          </div>
        </div>

        <div>
          <%= label_tag :visit_notes, t("appointments.visit_notes_ar"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= text_area_tag :visit_notes_ar, @appointment.visit_notes_ar, rows: 3, dir: "rtl",
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= label_tag :visit_notes, t("appointments.visit_notes_en"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= text_area_tag :visit_notes, @appointment.visit_notes, rows: 3,
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= label_tag :follow_up_date, t("appointments.follow_up"), class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= date_field_tag :follow_up_date, @appointment.follow_up_date,
                class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>

        <% if @appointment.status == "in_progress" %>
          <%= submit_tag "✓ #{t('appointments.actions.complete_visit')}",
                class: "bg-emerald-600 text-white px-5 py-2 rounded-lg font-semibold cursor-pointer hover:bg-emerald-700" %>
        <% else %>
          <%= submit_tag t("actions.save"),
                class: "bg-slate-800 text-white px-5 py-2 rounded-lg font-semibold cursor-pointer hover:bg-slate-900" %>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <!-- Link to create report -->
  <% if @appointment.completed? || @appointment.status == "in_progress" %>
    <div class="bg-blue-50 border border-blue-200 rounded-2xl p-5 flex items-center justify-between flex-wrap gap-3">
      <div>
        <div class="font-semibold text-blue-900"><%= t("appointments.create_report_prompt") %></div>
        <div class="text-sm text-blue-700 mt-1"><%= t("appointments.create_report_hint") %></div>
      </div>
      <%= link_to "📋 #{t('reports.new')}",
            dashboard_reports_path(patient_id: @appointment.patient_id, appointment_id: @appointment.id),
            class: "bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700" %>
    </div>
  <% end %>

  <!-- Medications for this visit -->
  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
    <div class="p-5 border-b border-slate-200 flex items-center justify-between">
      <h2 class="font-semibold text-slate-800">💊 <%= t("medications.title") %></h2>
      <%= link_to "＋ #{t('medications.new')}",
            dashboard_medications_path(patient_id: @appointment.patient_id, appointment_id: @appointment.id),
            class: "text-sm text-blue-600 hover:underline" %>
    </div>
    <% if @medications.any? %>
      <ul class="divide-y divide-slate-100">
        <% @medications.each do |m| %>
          <li class="p-4">
            <div class="font-medium text-slate-800"><%= m.display_name %></div>
            <div class="text-xs text-slate-500">
              <%= m.dosage %> · <%= m.frequency.presence || "—" %> · <%= m.duration.presence || "—" %>
            </div>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="p-6 text-sm text-slate-500"><%= t("medications.no_medications") %></p>
    <% end %>
  </div>
</div>
ERB

echo "==> Views written."
echo "==> Done."
