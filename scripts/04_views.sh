#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Writing views…"

mkdir -p app/views/dashboard/{overview,patients,appointments,reports,medications,payments,transfers,clinics,subscriptions,chat}
mkdir -p app/views/shared

# ============================================================
# Shared partials
# ============================================================
cat > app/views/shared/_stat_card.html.erb <<'ERB'
<%
  accent ||= "text-slate-800"
%>
<div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
  <div class="flex items-center justify-between">
    <div class="text-sm font-medium text-slate-500"><%= label %></div>
    <div class="text-xl"><%= icon %></div>
  </div>
  <div class="text-3xl font-bold <%= accent %> mt-2"><%= value %></div>
</div>
ERB

# ============================================================
# Overview
# ============================================================
cat > app/views/dashboard/overview/index.html.erb <<'ERB'
<% content_for :title, "نظرة عامة — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">📊 نظرة عامة</h1>
    <p class="text-slate-500 mt-1">Overview of <%= current_clinic.name %></p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <%= render "shared/stat_card", label: "Patients",     value: @patients_count,     icon: "👥" %>
    <%= render "shared/stat_card", label: "Today",        value: @appointments_today, icon: "📅" %>
    <%= render "shared/stat_card", label: "This Week",    value: @appointments_week,  icon: "🗓️" %>
    <%= render "shared/stat_card", label: "Unread",       value: @unread_count,       icon: "🔔" %>
    <%= render "shared/stat_card", label: "Revenue (Month)",
          value: number_to_currency(@revenue_this_month, unit: "SYP ", precision: 0),
          icon: "💰", accent: "text-emerald-600" %>
    <%= render "shared/stat_card", label: "Pending Payments",
          value: number_to_currency(@pending_payments, unit: "SYP ", precision: 0),
          icon: "⏳", accent: "text-amber-600" %>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200 flex items-center justify-between">
        <h2 class="font-semibold text-slate-800">Today's Schedule</h2>
        <%= link_to "View all", dashboard_appointments_path, class: "text-sm text-blue-600 hover:underline" %>
      </div>
      <% if @today_appointments.any? %>
        <ul class="divide-y divide-slate-100">
          <% @today_appointments.each do |a| %>
            <li class="p-4 flex items-center justify-between">
              <div>
                <div class="font-medium text-slate-800"><%= a.patient&.display_name %></div>
                <div class="text-sm text-slate-500">
                  <%= a.appointment_time&.strftime("%H:%M") %> — <%= a.reason.presence || "—" %>
                </div>
              </div>
              <span class="text-xs font-semibold px-2 py-1 rounded-full bg-blue-50 text-blue-700"><%= a.status %></span>
            </li>
          <% end %>
        </ul>
      <% else %>
        <p class="p-6 text-center text-slate-500 text-sm">No appointments today.</p>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
      <div class="p-5 border-b border-slate-200">
        <h2 class="font-semibold text-slate-800">New Patients</h2>
      </div>
      <% if @recent_patients.any? %>
        <ul class="divide-y divide-slate-100">
          <% @recent_patients.each do |p| %>
            <li class="p-4">
              <%= link_to p.display_name, dashboard_patient_path(p),
                    class: "font-medium text-slate-800 hover:text-blue-600" %>
              <div class="text-xs text-slate-500"><%= p.phone.presence || "—" %></div>
            </li>
          <% end %>
        </ul>
      <% else %>
        <p class="p-6 text-center text-slate-500 text-sm">No patients yet.</p>
      <% end %>
    </div>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
    <div class="p-5 border-b border-slate-200 flex items-center justify-between">
      <h2 class="font-semibold text-slate-800">Recent Payments</h2>
      <%= link_to "View all", dashboard_payments_path, class: "text-sm text-blue-600 hover:underline" %>
    </div>
    <% if @recent_payments.any? %>
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
          <tr>
            <th class="text-start px-5 py-3 font-medium">Patient</th>
            <th class="text-start px-5 py-3 font-medium">Amount</th>
            <th class="text-start px-5 py-3 font-medium">By</th>
            <th class="text-start px-5 py-3 font-medium">When</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <% @recent_payments.each do |p| %>
            <tr>
              <td class="px-5 py-3 font-medium text-slate-800"><%= p.patient&.display_name || "—" %></td>
              <td class="px-5 py-3 text-emerald-600 font-semibold"><%= p.display_amount %></td>
              <td class="px-5 py-3 text-slate-600"><%= p.user&.name %></td>
              <td class="px-5 py-3 text-slate-500"><%= p.paid_at&.strftime("%Y-%m-%d %H:%M") || p.created_at.strftime("%Y-%m-%d %H:%M") %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="p-6 text-center text-slate-500 text-sm">No payments yet.</p>
    <% end %>
  </div>
</div>
ERB

# ============================================================
# Patients
# ============================================================
cat > app/views/dashboard/patients/index.html.erb <<'ERB'
<% content_for :title, "المرضى — ClinicApp" %>

<div class="space-y-6">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">👥 المرضى</h1>
      <p class="text-slate-500 mt-1">Patients registered at <%= current_clinic.name %></p>
    </div>
    <%= link_to "New Patient", new_dashboard_patient_path,
          class: "bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition shadow-sm" %>
  </div>

  <%= form_with url: dashboard_patients_path, method: :get, class: "flex gap-2" do %>
    <%= text_field_tag :q, params[:q], placeholder: "Search by name, phone or national ID…",
          class: "flex-1 border border-slate-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500" %>
    <%= submit_tag "Search", class: "bg-slate-800 text-white px-4 py-2 rounded-lg font-semibold hover:bg-slate-900 cursor-pointer" %>
  <% end %>

  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
    <% if @patients.any? %>
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
          <tr>
            <th class="text-start px-5 py-3 font-medium">Name</th>
            <th class="text-start px-5 py-3 font-medium">Phone</th>
            <th class="text-start px-5 py-3 font-medium">Age</th>
            <th class="text-start px-5 py-3 font-medium">Blood</th>
            <th class="text-start px-5 py-3 font-medium">Allergies</th>
            <th class="px-5 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <% @patients.each do |p| %>
            <tr class="hover:bg-slate-50">
              <td class="px-5 py-3">
                <%= link_to p.display_name, dashboard_patient_path(p),
                      class: "font-medium text-slate-800 hover:text-blue-600" %>
              </td>
              <td class="px-5 py-3 text-slate-600"><%= p.phone.presence || "—" %></td>
              <td class="px-5 py-3 text-slate-600"><%= p.age.presence || p.age_from_dob || "—" %></td>
              <td class="px-5 py-3 text-slate-600"><%= p.blood_type.presence || "—" %></td>
              <td class="px-5 py-3 text-slate-600 truncate max-w-xs"><%= p.allergies.presence || "—" %></td>
              <td class="px-5 py-3 text-end whitespace-nowrap">
                <%= link_to "View", dashboard_patient_path(p), class: "text-xs text-blue-600 hover:underline me-2" %>
                <%= link_to "Edit", edit_dashboard_patient_path(p), class: "text-xs text-slate-600 hover:underline me-2" %>
                <%= button_to "Archive", dashboard_patient_path(p), method: :delete,
                      data: { turbo_confirm: "Archive this patient?" },
                      class: "text-xs text-rose-600 hover:text-rose-800 font-semibold inline" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="p-8 text-center text-slate-500 text-sm">No patients yet.</p>
    <% end %>
  </div>
</div>
ERB

cat > app/views/dashboard/patients/_form.html.erb <<'ERB'
<% if patient.errors.any? %>
  <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-4 rounded-r-xl">
    <ul class="text-sm list-disc ms-5">
      <% patient.errors.full_messages.each do |m| %><li><%= m %></li><% end %>
    </ul>
  </div>
<% end %>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <%= f.label :name, "Name (EN)", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :name, class: "w-full border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500" %>
  </div>
  <div>
    <%= f.label :name_ar, "الاسم (AR)", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :name_ar, dir: "rtl", class: "w-full border border-slate-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500" %>
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

cat > app/views/dashboard/patients/new.html.erb <<'ERB'
<% content_for :title, "New Patient — ClinicApp" %>

<div class="max-w-3xl mx-auto space-y-6">
  <%= link_to "← Back", dashboard_patients_path, class: "text-sm text-blue-600 hover:underline" %>
  <h1 class="text-2xl font-bold text-slate-800">👥 New Patient</h1>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <%= form_with model: [:dashboard, @patient], class: "space-y-4" do |f| %>
      <%= render "form", f: f, patient: @patient %>
      <div class="flex justify-end gap-2 pt-2">
        <%= link_to "Cancel", dashboard_patients_path, class: "px-4 py-2 rounded-lg text-slate-700 hover:bg-slate-100 font-semibold" %>
        <%= f.submit "Create Patient", class: "bg-blue-600 text-white px-5 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer shadow-sm" %>
      </div>
    <% end %>
  </div>
</div>
ERB

cat > app/views/dashboard/patients/edit.html.erb <<'ERB'
<% content_for :title, "Edit #{@patient.display_name} — ClinicApp" %>

<div class="max-w-3xl mx-auto space-y-6">
  <%= link_to "← Back", dashboard_patient_path(@patient), class: "text-sm text-blue-600 hover:underline" %>
  <h1 class="text-2xl font-bold text-slate-800">✏️ Edit <%= @patient.display_name %></h1>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <%= form_with model: [:dashboard, @patient], class: "space-y-4" do |f| %>
      <%= render "form", f: f, patient: @patient %>
      <div class="flex justify-end gap-2 pt-2">
        <%= link_to "Cancel", dashboard_patient_path(@patient), class: "px-4 py-2 rounded-lg text-slate-700 hover:bg-slate-100 font-semibold" %>
        <%= f.submit "Update Patient", class: "bg-blue-600 text-white px-5 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer shadow-sm" %>
      </div>
    <% end %>
  </div>
</div>
ERB

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
        <%= link_to "Edit", edit_dashboard_patient_path(@patient),
              class: "px-4 py-2 rounded-lg bg-slate-100 text-slate-700 font-semibold hover:bg-slate-200" %>
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
# Appointments
# ============================================================
cat > app/views/dashboard/appointments/index.html.erb <<'ERB'
<% content_for :title, "المواعيد — ClinicApp" %>

<div class="space-y-6">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">📅 المواعيد</h1>
      <p class="text-slate-500 mt-1">All appointments at this clinic.</p>
    </div>
    <%= form_with url: dashboard_appointments_path, method: :get, class: "flex gap-2" do %>
      <%= date_field_tag :date, params[:date], class: "border border-slate-300 rounded-lg px-3 py-2" %>
      <%= submit_tag "Filter", class: "bg-slate-800 text-white px-4 py-2 rounded-lg font-semibold cursor-pointer" %>
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
              <th class="text-start px-5 py-3 font-medium">Doctor</th>
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
                <td class="px-5 py-3 text-slate-600"><%= a.doctor&.name || "—" %></td>
                <td class="px-5 py-3">
                  <span class="text-xs font-semibold px-2 py-1 rounded-full bg-blue-50 text-blue-700"><%= a.status %></span>
                </td>
                <td class="px-5 py-3 text-end">
                  <%= button_to "Cancel", dashboard_appointment_path(a), method: :delete,
                        data: { turbo_confirm: "Cancel this appointment?" },
                        class: "text-xs text-rose-600 hover:text-rose-800 font-semibold" %>
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

# ============================================================
# Reports
# ============================================================
cat > app/views/dashboard/reports/index.html.erb <<'ERB'
<% content_for :title, "التقارير — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">📋 التقارير الطبية</h1>
    <p class="text-slate-500 mt-1">Medical reports for your patients.</p>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">New Report</h2>
      <%= form_with model: @report, url: dashboard_reports_path, method: :post, class: "space-y-3" do |f| %>
        <% if @report.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @report.errors.full_messages.to_sentence %>
          </div>
        <% end %>
        <div>
          <%= f.label :patient_id, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :patient_id, @patients, :id, :display_name,
                { prompt: "Select patient" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :diagnosis, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :diagnosis, rows: 3, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :treatment, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :treatment, rows: 3, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :follow_up_date, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.date_field :follow_up_date, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :notes, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :notes, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit "Save Report", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @reports.any? %>
        <ul class="divide-y divide-slate-100">
          <% @reports.each do |r| %>
            <li class="p-5">
              <div class="font-semibold text-slate-800"><%= r.patient&.display_name %></div>
              <div class="text-xs text-slate-500 mt-1">
                <%= r.created_at.strftime("%Y-%m-%d %H:%M") %> — Dr. <%= r.doctor&.name %>
              </div>
              <div class="mt-3 text-sm space-y-1">
                <div><span class="font-medium text-slate-600">Diagnosis:</span> <%= r.display_diagnosis %></div>
                <% if r.display_treatment.present? %><div><span class="font-medium text-slate-600">Treatment:</span> <%= r.display_treatment %></div><% end %>
                <% if r.follow_up_date.present? %><div class="text-amber-700"><span class="font-medium">Follow-up:</span> <%= r.follow_up_date %></div><% end %>
              </div>
            </li>
          <% end %>
        </ul>
      <% else %>
        <p class="p-8 text-center text-slate-500 text-sm">No reports yet.</p>
      <% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# Medications
# ============================================================
cat > app/views/dashboard/medications/index.html.erb <<'ERB'
<% content_for :title, "الأدوية — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">💊 الأدوية</h1>
    <p class="text-slate-500 mt-1">Prescriptions issued to patients.</p>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">Prescribe</h2>
      <%= form_with model: [:dashboard, @medication], class: "space-y-3" do |f| %>
        <% if @medication.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @medication.errors.full_messages.to_sentence %>
          </div>
        <% end %>
        <div>
          <%= f.label :patient_id, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :patient_id, @patients, :id, :display_name,
                { prompt: "Select patient" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :name, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_field :name, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :name_ar, "الاسم (AR)", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_field :name_ar, dir: "rtl", class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :dosage, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.text_field :dosage, placeholder: "500mg", class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :route, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.select :route, Medication::ROUTES, { include_blank: true }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :frequency, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.text_field :frequency, placeholder: "2x daily", class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :duration, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.text_field :duration, placeholder: "7 days", class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :quantity, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.number_field :quantity, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :refills, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.number_field :refills, value: 0, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div>
          <%= f.label :instructions, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :instructions, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit "Prescribe", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @medications.any? %>
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-500">
            <tr>
              <th class="text-start px-5 py-3 font-medium">Patient</th>
              <th class="text-start px-5 py-3 font-medium">Medication</th>
              <th class="text-start px-5 py-3 font-medium">Dosage</th>
              <th class="text-start px-5 py-3 font-medium">Frequency</th>
              <th class="text-start px-5 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <% @medications.each do |m| %>
              <tr>
                <td class="px-5 py-3 font-medium text-slate-800"><%= m.patient&.display_name %></td>
                <td class="px-5 py-3 text-slate-700"><%= m.display_name %></td>
                <td class="px-5 py-3 text-slate-600"><%= m.dosage %></td>
                <td class="px-5 py-3 text-slate-600"><%= m.frequency.presence || "—" %></td>
                <td class="px-5 py-3">
                  <span class="text-xs font-semibold px-2 py-1 rounded-full bg-emerald-50 text-emerald-700"><%= m.status %></span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <p class="p-8 text-center text-slate-500 text-sm">No prescriptions yet.</p>
      <% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# Payments
# ============================================================
cat > app/views/dashboard/payments/index.html.erb <<'ERB'
<% content_for :title, "المدفوعات — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">💳 المدفوعات</h1>
    <p class="text-slate-500 mt-1">Payment records.</p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <%= render "shared/stat_card", label: "Total Paid",
          value: number_to_currency(@total_paid, unit: "SYP ", precision: 0),
          icon: "✅", accent: "text-emerald-600" %>
    <%= render "shared/stat_card", label: "Pending",
          value: number_to_currency(@total_pending, unit: "SYP ", precision: 0),
          icon: "⏳", accent: "text-amber-600" %>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">Record Payment</h2>
      <%= form_with model: [:dashboard, @payment], class: "space-y-3" do |f| %>
        <% if @payment.errors.any? %>
          <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
            <%= @payment.errors.full_messages.to_sentence %>
          </div>
        <% end %>
        <div>
          <%= f.label :patient_id, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.collection_select :patient_id, @patients, :id, :display_name,
                { prompt: "Select patient (optional)" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <%= f.label :amount, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.number_field :amount, step: "0.01", class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :currency, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.select :currency, Payment::CURRENCIES, { selected: "SYP" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
        <div>
          <%= f.label :method, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.select :method, Payment::METHODS, { include_blank: true }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :status, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.select :status, Payment::STATUSES, { selected: "paid" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :reference, "Reference", class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_field :reference, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <div>
          <%= f.label :notes, class: "block text-sm font-medium text-slate-700 mb-1" %>
          <%= f.text_area :notes, rows: 2, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit "Record", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @payments.any? %>
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-500">
            <tr>
              <th class="text-start px-5 py-3 font-medium">Date</th>
              <th class="text-start px-5 py-3 font-medium">Patient</th>
              <th class="text-start px-5 py-3 font-medium">Amount</th>
              <th class="text-start px-5 py-3 font-medium">Method</th>
              <th class="text-start px-5 py-3 font-medium">Status</th>
              <th class="text-start px-5 py-3 font-medium">By</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <% @payments.each do |p| %>
              <tr>
                <td class="px-5 py-3 text-slate-600"><%= p.created_at.strftime("%Y-%m-%d %H:%M") %></td>
                <td class="px-5 py-3 text-slate-700"><%= p.patient&.display_name || "—" %></td>
                <td class="px-5 py-3 font-semibold text-slate-800"><%= p.display_amount %></td>
                <td class="px-5 py-3 text-slate-600"><%= p.method.presence || "—" %></td>
                <td class="px-5 py-3">
                  <%
                    badge =
                      case p.status
                      when "paid"     then "bg-emerald-50 text-emerald-700"
                      when "pending"  then "bg-amber-50 text-amber-700"
                      when "failed"   then "bg-rose-50 text-rose-700"
                      when "refunded" then "bg-blue-50 text-blue-700"
                      else "bg-slate-100 text-slate-700"
                      end
                  %>
                  <span class="text-xs font-semibold px-2 py-1 rounded-full <%= badge %>"><%= p.status %></span>
                </td>
                <td class="px-5 py-3 text-slate-600"><%= p.user&.name %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <p class="p-8 text-center text-slate-500 text-sm">No payments yet.</p>
      <% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# Transfers (overwrite — assuming it's empty)
# ============================================================
cat > app/views/dashboard/transfers/index.html.erb <<'ERB'
<% content_for :title, "التحويلات — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">🚑 التحويلات</h1>
    <p class="text-slate-500 mt-1">Transfer patients to another clinic.</p>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm lg:col-span-1 h-fit">
      <h2 class="font-semibold text-slate-800 mb-4">New Transfer</h2>
      <% if @destination_clinics.empty? %>
        <p class="text-sm text-slate-500">No other clinics available to transfer to.</p>
      <% else %>
        <%= form_with model: [:dashboard, @transfer], class: "space-y-3" do |f| %>
          <% if @transfer.errors.any? %>
            <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-3 rounded-r-lg text-sm">
              <%= @transfer.errors.full_messages.to_sentence %>
            </div>
          <% end %>
          <div>
            <%= f.label :patient_id, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.collection_select :patient_id, current_clinic.patients.order(:name), :id, :display_name,
                  { prompt: "Select patient" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :to_clinic_id, "Destination Clinic", class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.collection_select :to_clinic_id, @destination_clinics, :id, :name,
                  { prompt: "Select destination" }, class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <div>
            <%= f.label :reason, class: "block text-sm font-medium text-slate-700 mb-1" %>
            <%= f.text_area :reason, rows: 3, placeholder: "Reason for transfer…",
                  class: "w-full border border-slate-300 rounded-lg px-3 py-2" %>
          </div>
          <%= f.submit "Create Transfer", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
        <% end %>
      <% end %>
    </div>

    <div class="bg-white rounded-2xl border border-slate-200 shadow-sm lg:col-span-2 overflow-hidden">
      <% if @transfers.any? %>
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-500">
            <tr>
              <th class="text-start px-5 py-3 font-medium">Patient</th>
              <th class="text-start px-5 py-3 font-medium">From</th>
              <th class="text-start px-5 py-3 font-medium">To</th>
              <th class="text-start px-5 py-3 font-medium">Status</th>
              <th class="text-start px-5 py-3 font-medium">Created</th>
              <th class="px-5 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <% @transfers.each do |t| %>
              <tr class="hover:bg-slate-50">
                <td class="px-5 py-3 font-medium text-slate-800"><%= t.patient&.display_name %></td>
                <td class="px-5 py-3 text-slate-600"><%= t.from_clinic&.display_name || "—" %></td>
                <td class="px-5 py-3 text-slate-600"><%= t.to_clinic&.display_name || "—" %></td>
                <td class="px-5 py-3">
                  <%
                    badge =
                      case t.status
                      when "pending"   then "bg-amber-50 text-amber-700"
                      when "accepted"  then "bg-emerald-50 text-emerald-700"
                      when "rejected", "cancelled" then "bg-rose-50 text-rose-700"
                      when "completed" then "bg-blue-50 text-blue-700"
                      else "bg-slate-100 text-slate-700"
                      end
                  %>
                  <span class="text-xs font-semibold px-2 py-1 rounded-full <%= badge %>"><%= t.status %></span>
                </td>
                <td class="px-5 py-3 text-slate-500"><%= t.created_at.strftime("%Y-%m-%d") %></td>
                <td class="px-5 py-3 text-end">
                  <%= button_to "Delete", dashboard_transfer_path(t), method: :delete,
                        data: { turbo_confirm: "Delete this transfer?" },
                        class: "text-xs text-rose-600 hover:text-rose-800 font-semibold" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <p class="p-8 text-center text-slate-500 text-sm">No transfers yet.</p>
      <% end %>
    </div>
  </div>
</div>
ERB

# ============================================================
# Clinics
# ============================================================
cat > app/views/dashboard/clinics/index.html.erb <<'ERB'
<% content_for :title, "العيادات — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">🏥 العيادات</h1>
    <p class="text-slate-500 mt-1">Clinics you belong to.</p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <% @clinics.each do |clinic| %>
      <%= link_to dashboard_clinic_path(clinic), class: "block bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition" do %>
        <div class="font-semibold text-slate-800"><%= clinic.display_name %></div>
        <div class="text-sm text-slate-500 mt-1"><%= clinic.address_display.presence || "—" %></div>
        <div class="text-xs text-slate-400 mt-3">Owner: <%= clinic.owner&.name %></div>
      <% end %>
    <% end %>
  </div>
</div>
ERB

cat > app/views/dashboard/clinics/show.html.erb <<'ERB'
<% content_for :title, "#{@clinic.display_name} — ClinicApp" %>

<div class="space-y-6">
  <%= link_to "← All clinics", dashboard_clinics_path, class: "text-sm text-blue-600 hover:underline" %>

  <div class="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
    <h1 class="text-2xl font-bold text-slate-800"><%= @clinic.display_name %></h1>
    <p class="text-slate-500 mt-1"><%= @clinic.address_display %></p>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 text-sm">
      <div><div class="text-slate-500">Phone</div><div class="font-medium"><%= @clinic.phone.presence || "—" %></div></div>
      <div><div class="text-slate-500">Email</div><div class="font-medium"><%= @clinic.email.presence || "—" %></div></div>
      <div><div class="text-slate-500">City</div><div class="font-medium"><%= @clinic.city.presence || "—" %></div></div>
      <div><div class="text-slate-500">Specialty</div><div class="font-medium"><%= @clinic.specialty.presence || "—" %></div></div>
    </div>
  </div>

  <div class="grid grid-cols-3 gap-4">
    <%= render "shared/stat_card", label: "Patients",     value: @stats[:patients],     icon: "👥" %>
    <%= render "shared/stat_card", label: "Appointments", value: @stats[:appointments], icon: "📅" %>
    <%= render "shared/stat_card", label: "Reports",      value: @stats[:reports],      icon: "📋" %>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
    <div class="p-5 border-b border-slate-200"><h2 class="font-semibold text-slate-800">Members</h2></div>
    <ul class="divide-y divide-slate-100">
      <% @members.each do |m| %>
        <li class="p-4 flex items-center justify-between">
          <div>
            <div class="font-medium text-slate-800"><%= m.user.name %></div>
            <div class="text-xs text-slate-500"><%= m.user.email %></div>
          </div>
          <span class="text-xs font-semibold px-2 py-1 rounded-full bg-slate-100 text-slate-700"><%= m.role %></span>
        </li>
      <% end %>
    </ul>
  </div>
</div>
ERB

# ============================================================
# Subscriptions
# ============================================================
cat > app/views/dashboard/subscriptions/index.html.erb <<'ERB'
<% content_for :title, "الاشتراكات — ClinicApp" %>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">💳 الاشتراكات</h1>
    <p class="text-slate-500 mt-1">Your clinic's subscription.</p>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
    <% if @subscriptions.any? %>
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
          <tr>
            <th class="text-start px-5 py-3 font-medium">Plan</th>
            <th class="text-start px-5 py-3 font-medium">Status</th>
            <th class="text-start px-5 py-3 font-medium">Expires</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <% @subscriptions.each do |s| %>
            <tr>
              <td class="px-5 py-3 font-medium text-slate-800"><%= s.plan %></td>
              <td class="px-5 py-3 text-slate-600"><%= s.status %></td>
              <td class="px-5 py-3 text-slate-600"><%= s.expires_at&.strftime("%Y-%m-%d") || "—" %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="p-8 text-center text-slate-500 text-sm">No subscription on file.</p>
    <% end %>
  </div>
</div>
ERB

# ============================================================
# Chat
# ============================================================
cat > app/views/dashboard/chat/index.html.erb <<'ERB'
<% content_for :title, "المساعد الذكي — ClinicApp" %>

<div class="max-w-3xl mx-auto space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-slate-800">🤖 المساعد الذكي</h1>
    <p class="text-slate-500 mt-1">AI medical assistant. Ask about your clinic records.</p>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
    <div id="chat-messages" class="h-[28rem] overflow-y-auto p-5 space-y-3 bg-slate-50"></div>

    <%= form_with url: dashboard_chat_path, method: :post, id: "chat-form", class: "p-4 border-t border-slate-200 flex gap-2" do %>
      <%= text_field_tag :message, nil, placeholder: "Type a message…", autocomplete: "off",
            class: "flex-1 border border-slate-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500" %>
      <%= submit_tag "Send", class: "bg-blue-600 text-white px-5 py-2 rounded-lg font-semibold hover:bg-blue-700 cursor-pointer" %>
    <% end %>
  </div>
</div>

<script>
  (function () {
    const box = document.getElementById("chat-messages");
    const form = document.getElementById("chat-form");
    if (!box || !form) return;

    function add(role, text) {
      const wrap = document.createElement("div");
      wrap.className = role === "user" ? "text-end" : "text-start";
      const bubble = document.createElement("div");
      bubble.className = "inline-block max-w-[80%] px-4 py-2 rounded-2xl text-sm " +
        (role === "user" ? "bg-blue-600 text-white" : "bg-white border border-slate-200 text-slate-800");
      bubble.textContent = text;
      wrap.appendChild(bubble);
      box.appendChild(wrap);
      box.scrollTop = box.scrollHeight;
    }

    fetch("<%= dashboard_chat_path %>", { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => (data.messages || []).forEach(m => add(m.sender_role || m.role, m.content)))
      .catch(() => {});

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const input = form.querySelector("input[name=message]");
      const text = input.value.trim();
      if (!text) return;
      add("user", text);
      input.value = "";

      const csrf = document.querySelector("meta[name=csrf-token]").content;
      const res = await fetch("<%= dashboard_chat_path %>", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf, Accept: "application/json" },
        body: JSON.stringify({ message: text, language: "<%= I18n.locale %>" })
      });
      const data = await res.json();
      if (data.reply) add("assistant", data.reply);
    });
  })();
</script>
ERB

echo "==> Views written."
echo ""
echo "==> Verifying files:"
ls app/views/dashboard/*/ | head -40
echo "==> Done."
