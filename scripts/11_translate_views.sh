#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Translating views…"

# ============================================================
# Sidebar in dashboard layout — use t() for nav items
# ============================================================
python3 - <<'PY'
import re
path = "app/views/layouts/dashboard.html.erb"
src = open(path).read()

# Replace group labels
src = src.replace('["الطبي", clinical]', '[t("nav.medical"), clinical]')
src = src.replace('["الإداري", business]', '[t("nav.admin"), business]')

# Replace nav tuples (icon, ar, en, path, exact) → (icon, key, path, exact)
nav_old = '''primary  = [
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
            ]'''
nav_new = '''primary  = [
              ["📊", "nav.overview",     dashboard_path,              true],
              ["👥", "nav.patients",     dashboard_patients_path,     false],
              ["📅", "nav.appointments", dashboard_appointments_path, false],
            ]
            clinical = [
              ["📋", "nav.reports",      dashboard_reports_path,      false],
              ["💊", "nav.medications",  dashboard_medications_path,  false],
              ["🚑", "nav.transfers",    dashboard_transfers_path,    false],
            ]
            business = [
              ["💳", "nav.payments",     dashboard_payments_path,     false],
              ["🏥", "nav.clinics",      dashboard_clinics_path,      false],
              ["⚙️", "nav.subscriptions",dashboard_subscriptions_path, false],
            ]
            extras   = [
              ["🤖", "nav.chat",         dashboard_chat_path,         false],
            ]'''
src = src.replace(nav_old, nav_new)

# Replace the items.each loop
src = src.replace(
  '<% items.each do |icon, ar, en, path, exact| %>',
  '<% items.each do |icon, key, path, exact| %>'
)
src = src.replace(
  '<span class="truncate"><%= I18n.locale == :ar ? ar : en %></span>',
  '<span class="truncate"><%= t(key) %></span>'
)

# Current clinic label
src = src.replace('<div class="text-xs text-slate-400 mb-1">العيادة الحالية</div>',
                  '<div class="text-xs text-slate-400 mb-1"><%= t("nav.current_clinic") %></div>')

# Search placeholder
src = src.replace('placeholder="ابحث عن مريض…"', 'placeholder="<%= t("nav.search_placeholder") %>"')

# User menu items
src = src.replace('👤 الملف الشخصي', '👤 <%= t("nav.profile") %>')
src = src.replace('🔔 الإشعارات',    '🔔 <%= t("nav.notifications") %>')
src = src.replace('🏠 لوحة التحكم',  '🏠 <%= t("nav.dashboard") %>')
src = src.replace('🚪 تسجيل الخروج', '🚪 <%= t("nav.logout") %>')

# Footer sections
src = src.replace('<div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2">الطبي</div>',
                  '<div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2"><%= t("nav.medical") %></div>')
src = src.replace('<div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2">الإداري</div>',
                  '<div class="text-xs font-semibold text-slate-800 uppercase tracking-wide mb-2"><%= t("nav.admin") %></div>')

# Footer link labels
src = src.replace('>المرضى</a>',    '><%= t("nav.patients") %></a>')
src = src.replace('>المواعيد</a>',  '><%= t("nav.appointments") %></a>')
src = src.replace('>التقارير</a>',  '><%= t("nav.reports") %></a>')
src = src.replace('>المدفوعات</a>', '><%= t("nav.payments") %></a>')
src = src.replace('>العيادات</a>',  '><%= t("nav.clinics") %></a>')
src = src.replace('>الإشعارات</a>', '><%= t("nav.notifications") %></a>')

# Footer blurb
src = src.replace('نظام إدارة العيادات الطبية — مرضى، مواعيد، تقارير، أدوية، ومدفوعات في مكان واحد.',
                  '<%= t("home.hero_subtitle") %>')

open(path, "w").write(src)
print("✅ dashboard layout translated")
PY

echo "==> Done."
echo ""
echo "==> Restart bin/dev and reload."
