#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Redesigning layout: top navbar + dashboard sidebar…"

# ============================================================
# 1) New dashboard layout (top nav + sidebar)
# ============================================================
mkdir -p app/views/layouts

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
      /* thin scrollbar for sidebar */
      .sidebar-scroll::-webkit-scrollbar { width: 6px; }
      .sidebar-scroll::-webkit-scrollbar-thumb { background: rgba(148,163,184,.4); border-radius: 9999px; }
    </style>
  </head>

  <body class="bg-slate-50 antialiased min-h-screen">

    <div class="flex min-h-screen">

      <!-- ===================== SIDEBAR ===================== -->
      <aside id="sidebar"
             class="fixed inset-y-0 start-0 z-40 w-64 bg-slate-900 text-slate-200 flex flex-col
                    -translate-x-full rtl:translate-x-full
                    lg:translate-x-0 lg:rtl:translate-x-0
                    transition-transform duration-200 ease-out">

        <!-- Brand -->
        <div class="h-16 flex items-center px-5 border-b border-slate-800">
          <%= link_to root_path, class: "flex items-center gap-2 text-white font-extrabold text-lg" do %>
            <svg class="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round"
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
            </svg>
            <span>ClinicApp</span>
          <% end %>
        </div>

        <!-- Clinic badge -->
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

        <!-- Nav groups -->
        <nav class="flex-1 overflow-y-auto sidebar-scroll px-3 py-4 space-y-6">
          <%
            primary = [
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
            extras = [
              ["🤖", "المساعد الذكي", "AI Assistant", dashboard_chat_path,         false],
            ]
          %>

          <% [["", primary], ["الطبي", clinical], ["الإداري", business], ["", extras]].each do |group_label, items| %>
            <div>
              <% if group_label.present? %>
                <div class="px-3 mb-2 text-xs font-semibold uppercase tracking-wider text-slate-500">
                  <%= group_label %>
                </div>
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
                      <% if active %>
                        <span class="ms-auto w-1.5 h-1.5 rounded-full bg-white/80"></span>
                      <% end %>
                    <% end %>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </nav>

        <!-- Bottom: user info -->
        <div class="border-t border-slate-800 p-3">
          <%
            role = (current_user.role_in(current_clinic) rescue nil) || current_user.role || "member"
            prefix = role == "doctor" ? "Dr. " : ""
          %>
          <div class="flex items-center gap-3 px-2 py-2 rounded-lg hover:bg-slate-800 transition">
            <div class="w-9 h-9 rounded-full bg-blue-500 text-white flex items-center justify-center font-bold">
              <%= current_user.name.to_s[0]&.upcase %>
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-semibold text-white truncate">
                <%= prefix %><%= current_user.name %>
              </div>
              <div class="text-xs text-slate-400 truncate"><%= role.titleize %></div>
            </div>
          </div>
        </div>
      </aside>

      <!-- Backdrop for mobile -->
      <div id="sidebar-backdrop"
           onclick="document.getElementById('sidebar').classList.add('-translate-x-full','rtl:translate-x-full'); this.classList.add('hidden')"
           class="hidden fixed inset-0 bg-black/40 z-30 lg:hidden"></div>

      <!-- ===================== MAIN AREA ===================== -->
      <div class="flex-1 lg:ms-64 flex flex-col min-h-screen">

        <!-- ============ TOP NAVBAR (short) ============ -->
        <header class="sticky top-0 z-30 h-16 bg-white border-b border-slate-200 flex items-center px-4 lg:px-6 gap-4">

          <!-- Mobile: open sidebar -->
          <button type="button"
                  onclick="document.getElementById('sidebar').classList.remove('-translate-x-full','rtl:translate-x-full'); document.getElementById('sidebar-backdrop').classList.remove('hidden')"
                  class="lg:hidden p-2 rounded-lg hover:bg-slate-100 text-slate-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>

          <!-- Page title (mobile) -->
          <div class="lg:hidden font-semibold text-slate-800 truncate">
            <%= content_for?(:title) ? yield(:title) : "لوحة التحكم" %>
          </div>

          <!-- Search (desktop) -->
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

          <!-- Right: notifications + user -->
          <div class="ms-auto flex items-center gap-2">

            <!-- Notifications -->
            <button type="button"
                    class="relative p-2 rounded-lg hover:bg-slate-100 text-slate-600"
                    title="الإشعارات">
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
            </button>

            <!-- User menu (dropdown) -->
            <div class="relative" data-controller="dropdown">
              <button type="button"
                      onclick="this.nextElementSibling.classList.toggle('hidden')"
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
                <%= link_to dashboard_root_path, class: "block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50" do %>
                  🏠 لوحة التحكم
                <% end %>
                <%= link_to dashboard_chat_path, class: "block px-4 py-2 text-sm text-slate-700 hover:bg-slate-50" do %>
                  🤖 المساعد الذكي
                <% end %>
                <div class="border-t border-slate-100 my-1"></div>
                <%= button_to "🚪 تسجيل الخروج", session_path, method: :delete,
                      class: "w-full text-start px-4 py-2 text-sm text-rose-600 hover:bg-rose-50" %>
              </div>
            </div>

          </div>
        </header>

        <!-- ============ PAGE CONTENT ============ -->
        <main class="flex-1 p-4 lg:p-6">

          <!-- Flash -->
          <% [:notice, :alert].each do |type| %>
            <% next unless flash[type].present? %>
            <% colors = type.to_sym == :notice ?
                 { bg: "bg-emerald-50", border: "border-emerald-500", text: "text-emerald-800" } :
                 { bg: "bg-rose-50",    border: "border-rose-500",    text: "text-rose-800" } %>
            <div class="<%= colors[:bg] %> border-l-4 <%= colors[:border] %> <%= colors[:text] %> p-4 rounded-r-xl shadow-sm mb-6 flex items-center justify-between">
              <span class="font-medium"><%= flash[type] %></span>
              <button type="button" onclick="this.parentElement.remove()"
                      class="ms-4 text-xl leading-none cursor-pointer bg-transparent border-0">
                &times;
              </button>
            </div>
          <% end %>

          <%= yield %>
        </main>

        <!-- ============ FOOTER (short) ============ -->
        <footer class="border-t border-slate-200 py-4 px-6 text-xs text-slate-400 flex flex-col sm:flex-row items-center justify-between gap-2">
          <p>&copy; <%= Time.current.year %> ClinicApp</p>
          <p>Built with Ruby on Rails &amp; Tailwind CSS</p>
        </footer>
      </div>
    </div>

  </body>
</html>
ERB

# ============================================================
# 2) Base controller switches layout for dashboard
# ============================================================
cat > app/controllers/dashboard/base_controller.rb <<'RUBY'
class Dashboard::BaseController < ApplicationController
  layout "dashboard"

  before_action :require_login
  before_action :set_current_clinic

  helper_method :current_clinic

  private

  def current_clinic
    @current_clinic
  end

  def set_current_clinic
    clinic_id = session[:clinic_id] || current_user.clinic_members.first&.clinic_id

    @current_clinic =
      if clinic_id
        current_user.clinics.find_by(id: clinic_id)
      else
        current_user.clinics.first
      end

    unless @current_clinic
      if current_user.owned_clinics.empty?
        @current_clinic = Clinic.create!(name: "Main Clinic", owner: current_user, name_ar: "العيادة الرئيسية")
        ClinicMember.find_or_create_by!(clinic: @current_clinic, user: current_user) { |m| m.role = "owner" }
      else
        @current_clinic = current_user.clinics.first || current_user.owned_clinics.first
      end
    end

    session[:clinic_id] = @current_clinic.id
  end
end
RUBY

# ============================================================
# 3) Slim down the main layout (only for home / login / signup)
# ============================================================
cat > app/views/layouts/application.html.erb <<'ERB'
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" dir="<%= I18n.locale == :ar ? 'rtl' : 'ltr' %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "ClinicApp — إدارة العيادات" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <script src="https://cdn.tailwindcss.com"></script>
    <%= javascript_importmap_tags %>
    <style>
      html[dir="rtl"] body { font-family: "Segoe UI", "Tahoma", "Arial", sans-serif; }
      html[dir="ltr"] body { font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; }
    </style>
  </head>

  <body class="bg-slate-50 antialiased min-h-screen flex flex-col">

    <!-- Simple nav for marketing pages -->
    <nav class="bg-white border-b border-slate-200 sticky top-0 z-40">
      <div class="max-w-7xl mx-auto px-6 h-16 flex justify-between items-center">
        <%= link_to root_path, class: "flex items-center gap-2 text-blue-600 font-extrabold text-lg" do %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round"
                  d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
          </svg>
          ClinicApp
        <% end %>

        <div class="flex items-center gap-2">
          <% if logged_in? %>
            <%= link_to "لوحة التحكم", dashboard_root_path,
                  class: "text-sm bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition" %>
          <% else %>
            <%= link_to "تسجيل الدخول", new_session_path,
                  class: "text-sm text-slate-700 hover:text-blue-600 font-semibold px-3 py-2" %>
            <%= link_to "إنشاء حساب", new_registration_path,
                  class: "text-sm bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition shadow-md shadow-blue-500/20" %>
          <% end %>
        </div>
      </div>
    </nav>

    <main class="flex-1">
      <% [:notice, :alert].each do |type| %>
        <% next unless flash[type].present? %>
        <% colors = type.to_sym == :notice ?
             { bg: "bg-emerald-50", border: "border-emerald-500", text: "text-emerald-800" } :
             { bg: "bg-rose-50",    border: "border-rose-500",    text: "text-rose-800" } %>
        <div class="max-w-7xl mx-auto px-6 pt-6">
          <div class="<%= colors[:bg] %> border-l-4 <%= colors[:border] %> <%= colors[:text] %> p-4 rounded-r-xl shadow-sm flex items-center justify-between">
            <span class="font-medium"><%= flash[type] %></span>
            <button type="button" onclick="this.parentElement.parentElement.remove()"
                    class="ms-4 text-xl leading-none cursor-pointer bg-transparent border-0">
              &times;
            </button>
          </div>
        </div>
      <% end %>

      <%= yield %>
    </main>

    <footer class="bg-white border-t border-slate-200">
      <div class="max-w-7xl mx-auto px-6 py-8 flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-slate-500">
        <div class="flex items-center gap-2 text-blue-600 font-bold">
          ClinicApp
        </div>
        <div class="flex gap-4">
          <%= link_to "تسجيل الدخول", new_session_path, class: "hover:text-blue-600" %>
          <%= link_to "إنشاء حساب", new_registration_path, class: "hover:text-blue-600" %>
        </div>
        <p class="text-xs text-slate-400">&copy; <%= Time.current.year %> ClinicApp. جميع الحقوق محفوظة.</p>
      </div>
    </footer>

  </body>
</html>
ERB

echo "==> Layout redesign written."
echo ""
echo "==> Files updated:"
ls -la app/views/layouts/dashboard.html.erb
ls -la app/views/layouts/application.html.erb
ls -la app/controllers/dashboard/base_controller.rb
echo "==> Done."
