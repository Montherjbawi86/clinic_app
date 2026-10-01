#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Writing layout + auth views…"

# ============================================================
# Main layout
# ============================================================
cat > app/views/layouts/application.html.erb <<'ERB'
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" dir="<%= I18n.locale == :ar ? 'rtl' : 'ltr' %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "ClinicApp — إدارة العيادات" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="description" content="نظام إدارة العيادات الطبية — مرضى، مواعيد، تقارير، أدوية، مدفوعات.">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <script src="https://cdn.tailwindcss.com"></script>
    <%= javascript_importmap_tags %>

    <style>
      html[dir="rtl"] body { font-family: "Segoe UI", "Tahoma", "Arial", sans-serif; }
      html[dir="ltr"] body { font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; }
    </style>
  </head>

  <body class="bg-slate-50 antialiased min-h-screen flex flex-col selection:bg-blue-600 selection:text-white">

    <!-- ============ NAVBAR ============ -->
    <nav class="bg-white border-b border-slate-200 shadow-sm sticky top-0 z-50">
      <div class="max-w-7xl mx-auto px-6 h-16 flex justify-between items-center gap-4">

        <div class="flex items-center gap-6 min-w-0">
          <%= link_to root_path, class: "text-xl font-extrabold text-blue-600 tracking-tight flex items-center gap-2 shrink-0" do %>
            <svg class="w-7 h-7" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round"
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
            </svg>
            <span>ClinicApp</span>
          <% end %>

          <% if logged_in? %>
            <%
              nav_items = []
              nav_items << ["نظرة عامة",    "Overview",     dashboard_path]             if defined?(dashboard_path)
              nav_items << ["العيادات",     "Clinics",      dashboard_clinics_path]     if defined?(dashboard_clinics_path)
              nav_items << ["المرضى",       "Patients",     dashboard_patients_path]    if defined?(dashboard_patients_path)
              nav_items << ["المواعيد",     "Appointments", dashboard_appointments_path] if defined?(dashboard_appointments_path)
              nav_items << ["التقارير",     "Reports",      dashboard_reports_path]     if defined?(dashboard_reports_path)
              nav_items << ["الأدوية",      "Medications",  dashboard_medications_path] if defined?(dashboard_medications_path)
              nav_items << ["التحويلات",    "Transfers",    dashboard_transfers_path]   if defined?(dashboard_transfers_path)
              nav_items << ["المدفوعات",    "Payments",     dashboard_payments_path]    if defined?(dashboard_payments_path)
              nav_items << ["المساعد الذكي","AI Assistant", dashboard_chat_path]        if defined?(dashboard_chat_path)
            %>
            <div class="hidden xl:flex items-center gap-1">
              <% nav_items.each do |ar, en, path| %>
                <% active = current_page?(path) rescue false %>
                <%= link_to path,
                      class: "px-3 py-2 text-sm font-medium rounded-lg transition #{active ? 'bg-blue-50 text-blue-700' : 'text-slate-600 hover:text-blue-600 hover:bg-blue-50'}" do %>
                  <%= I18n.locale == :ar ? ar : en %>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex items-center gap-3 shrink-0">
          <% if logged_in? %>
            <%
              user_clinics = current_user.clinics rescue []
              show_switcher = user_clinics.respond_to?(:count) && user_clinics.count > 1 && defined?(switch_clinic_path)
            %>
            <% if show_switcher %>
              <%= form_with url: switch_clinic_path, method: :post, class: "hidden sm:block" do %>
                <%= select_tag :clinic_id,
                      options_from_collection_for_select(user_clinics, :id, :name, session[:clinic_id]),
                      onchange: "this.form.submit()",
                      class: "text-sm bg-slate-100 border-0 rounded-lg px-3 py-2 font-medium text-slate-700 focus:ring-2 focus:ring-blue-500" %>
              <% end %>
            <% end %>

            <%
              role = (current_user.role_in(@current_clinic) rescue nil) ||
                     (current_user.role rescue nil) ||
                     "member"
              prefix = role == "doctor" ? "Dr. " : ""
            %>
            <div class="hidden sm:flex items-center gap-2 bg-slate-100 px-3 py-1.5 rounded-full">
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              <span class="text-sm font-semibold text-slate-700 whitespace-nowrap">
                <%= prefix %><%= current_user.name %>
                <span class="text-xs font-normal text-slate-400 ms-1 hidden md:inline"><%= role.to_s.titleize %></span>
              </span>
            </div>

            <%= button_to "Log Out",
                  (defined?(session_path) ? session_path : "/session"),
                  method: :delete,
                  class: "text-sm bg-rose-50 text-rose-600 border border-rose-200 px-4 py-2 rounded-lg hover:bg-rose-100 font-semibold transition cursor-pointer shadow-sm whitespace-nowrap" %>

          <% else %>
            <%= link_to "Log In",
                  (defined?(new_session_path) ? new_session_path : "/session/new"),
                  class: "text-sm text-slate-700 hover:text-blue-600 font-semibold px-4 py-2 transition" %>
            <%= link_to "Sign Up Free",
                  (defined?(new_registration_path) ? new_registration_path : "/registrations/new"),
                  class: "text-sm bg-blue-600 text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-blue-700 transition shadow-md shadow-blue-500/20 whitespace-nowrap" %>
          <% end %>
        </div>
      </div>
    </nav>

    <!-- ============ FLASH ============ -->
    <main class="flex-1 max-w-7xl w-full mx-auto px-6 py-8">
      <% [:notice, :alert].each do |type| %>
        <% next unless flash[type].present? %>
        <% colors = type.to_sym == :notice ?
             { bg: "bg-emerald-50", border: "border-emerald-500", text: "text-emerald-800", btn: "text-emerald-600 hover:text-emerald-800" } :
             { bg: "bg-rose-50",    border: "border-rose-500",    text: "text-rose-800",    btn: "text-rose-600 hover:text-rose-800" } %>
        <div class="<%= colors[:bg] %> border-l-4 <%= colors[:border] %> <%= colors[:text] %> p-4 rounded-r-xl shadow-sm mb-6 flex items-center justify-between">
          <span class="font-medium"><%= flash[type] %></span>
          <button type="button"
                  onclick="this.parentElement.remove()"
                  class="<%= colors[:btn] %> ms-4 text-xl leading-none cursor-pointer bg-transparent border-0">
            &times;
          </button>
        </div>
      <% end %>

      <%= yield %>
    </main>

    <!-- ============ FOOTER ============ -->
    <footer class="bg-white border-t border-slate-200 mt-12">
      <div class="max-w-7xl mx-auto px-6 py-10 grid grid-cols-1 md:grid-cols-4 gap-8">

        <div class="md:col-span-2">
          <div class="flex items-center gap-2 text-blue-600 font-extrabold text-lg">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round"
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
            </svg>
            ClinicApp
          </div>
          <p class="text-sm text-slate-500 mt-3 max-w-md">
            نظام إدارة العيادات الطبية — مرضى، مواعيد، تقارير، أدوية، ومدفوعات في مكان واحد.
            Modern clinic management for Syrian healthcare.
          </p>
          <div class="flex gap-3 mt-4">
            <span class="inline-flex items-center gap-1 text-xs font-medium text-emerald-700 bg-emerald-50 px-2 py-1 rounded-full">
              ● مؤمّن
            </span>
            <span class="inline-flex items-center gap-1 text-xs font-medium text-blue-700 bg-blue-50 px-2 py-1 rounded-full">
              ● عربي / English
            </span>
          </div>
        </div>

        <div>
          <h4 class="text-sm font-semibold text-slate-800 mb-3">المنتج</h4>
          <ul class="space-y-2 text-sm text-slate-500">
            <% if logged_in? %>
              <li><%= link_to "نظرة عامة", dashboard_path, class: "hover:text-blue-600" %></li>
              <li><%= link_to "المرضى", dashboard_patients_path, class: "hover:text-blue-600" %></li>
              <li><%= link_to "المواعيد", dashboard_appointments_path, class: "hover:text-blue-600" %></li>
              <li><%= link_to "المساعد الذكي", dashboard_chat_path, class: "hover:text-blue-600" %></li>
            <% else %>
              <li><%= link_to "تسجيل الدخول", new_session_path, class: "hover:text-blue-600" %></li>
              <li><%= link_to "إنشاء حساب", new_registration_path, class: "hover:text-blue-600" %></li>
            <% end %>
          </ul>
        </div>

        <div>
          <h4 class="text-sm font-semibold text-slate-800 mb-3">الدعم</h4>
          <ul class="space-y-2 text-sm text-slate-500">
            <li><a href="mailto:support@clinicapp.sy" class="hover:text-blue-600">support@clinicapp.sy</a></li>
            <li><span class="text-slate-400">+963 000 000 000</span></li>
            <li><span class="text-slate-400">دمشق، سوريا</span></li>
          </ul>
        </div>
      </div>

      <div class="border-t border-slate-100">
        <div class="max-w-7xl mx-auto px-6 py-4 flex flex-col md:flex-row items-center justify-between gap-2 text-xs text-slate-400">
          <p>&copy; <%= Time.current.year %> ClinicApp. جميع الحقوق محفوظة.</p>
          <p>Built with Ruby on Rails &amp; Tailwind CSS</p>
        </div>
      </div>
    </footer>

  </body>
</html>
ERB

# ============================================================
# Home page — hero + features
# ============================================================
cat > app/views/home/index.html.erb <<'ERB'
<% content_for :title, "ClinicApp — إدارة العيادات" %>

<div class="space-y-16 py-8">
  <section class="text-center space-y-6 max-w-3xl mx-auto">
    <div class="inline-flex items-center gap-2 bg-blue-50 text-blue-700 text-xs font-semibold px-3 py-1 rounded-full">
      <span class="w-2 h-2 rounded-full bg-blue-600 animate-pulse"></span>
      متوفر الآن — Available Now
    </div>
    <h1 class="text-4xl md:text-6xl font-extrabold text-slate-900 tracking-tight leading-tight">
      نظام إدارة العيادات
      <span class="block text-blue-600">الحديث</span>
    </h1>
    <p class="text-slate-500 text-lg">
      أدر مرضاك، مواعيدك، تقاريرك الطبية، أدويتك، ومدفوعاتك — كل شيء في مكان واحد.
      مصمم للعيادات السورية، بالعربية والإنجليزية.
    </p>
    <div class="flex justify-center gap-3 pt-2">
      <%= link_to "ابدأ مجاناً", new_registration_path,
            class: "bg-blue-600 text-white px-7 py-3 rounded-xl font-semibold hover:bg-blue-700 transition shadow-lg shadow-blue-500/20" %>
      <%= link_to "تسجيل الدخول", new_session_path,
            class: "bg-white text-slate-700 border border-slate-300 px-7 py-3 rounded-xl font-semibold hover:bg-slate-50 transition" %>
    </div>
  </section>

  <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
    <%
      features = [
        ["👥", "المرضى",       "سجل كامل لكل مريض مع التاريخ الطبي والحساسية والتأمين."],
        ["📅", "المواعيد",     "جدولة ذكية مع منع التعارض وتذكيرات تلقائية."],
        ["📋", "التقارير",     "تقارير طبية مفصلة مع متابعة وتشخيص ثنائي اللغة."],
        ["💊", "الأدوية",      "وصفات طبية مع الجرعة ومدة العلاج وعدد المرات."],
        ["🚑", "التحويلات",    "حوّل المرضى بين العيادات مع سبب واضح وتتبع الحالة."],
        ["💳", "المدفوعات",    "تابع الإيرادات والمبالغ المعلقة بالعملة المحلية."],
        ["🤖", "مساعد ذكي",   "مساعد طبي بالذكاء الاصطناعي لفهم سجلاتك."],
        ["📊", "تقارير حية",   "لوحة تحكم مع إحصائيات فورية لكل عيادة."]
      ]
    %>
    <% features.each do |icon, title, desc| %>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition">
        <div class="text-3xl"><%= icon %></div>
        <div class="font-semibold text-slate-800 mt-3"><%= title %></div>
        <div class="text-sm text-slate-500 mt-1 leading-relaxed"><%= desc %></div>
      </div>
    <% end %>
  </section>

  <section class="bg-gradient-to-br from-blue-600 to-blue-700 rounded-3xl p-10 text-center text-white">
    <h2 class="text-3xl font-bold">جاهز للبدء؟</h2>
    <p class="mt-3 text-blue-100 max-w-xl mx-auto">
      أنشئ حسابك في دقيقة واحدة، واحصل على عيادتك الأولى جاهزة للعمل.
    </p>
    <div class="mt-6">
      <%= link_to "إنشاء حساب مجاني", new_registration_path,
            class: "inline-block bg-white text-blue-700 px-7 py-3 rounded-xl font-bold hover:bg-blue-50 transition shadow-lg" %>
    </div>
  </section>
</div>
ERB

# ============================================================
# Sessions#new — login
# ============================================================
cat > app/views/sessions/new.html.erb <<'ERB'
<% content_for :title, "تسجيل الدخول — ClinicApp" %>

<div class="max-w-md mx-auto py-12">
  <div class="text-center mb-8">
    <h1 class="text-3xl font-bold text-slate-800">تسجيل الدخول</h1>
    <p class="text-slate-500 mt-2">أدخل بياناتك للمتابعة</p>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-8 shadow-sm">
    <%= form_with url: session_path, class: "space-y-5" do |f| %>
      <div>
        <%= label_tag :email, "البريد الإلكتروني", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= email_field_tag :email, params[:email], required: true, autofocus: true,
              placeholder: "you@example.com",
              class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
      </div>

      <div>
        <%= label_tag :password, "كلمة المرور", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= password_field_tag :password, nil, required: true,
              placeholder: "••••••••",
              class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
      </div>

      <%= submit_tag "دخول",
            class: "w-full bg-blue-600 text-white px-4 py-3 rounded-xl font-semibold hover:bg-blue-700 cursor-pointer shadow-md shadow-blue-500/20 transition" %>
    <% end %>

    <div class="relative my-6">
      <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-slate-200"></div></div>
      <div class="relative flex justify-center text-xs">
        <span class="bg-white px-3 text-slate-400">أو</span>
      </div>
    </div>

    <p class="text-center text-sm text-slate-500">
      ليس لديك حساب؟
      <%= link_to "أنشئ حساباً مجاناً", new_registration_path, class: "text-blue-600 hover:underline font-semibold" %>
    </p>
  </div>

  <p class="text-center text-xs text-slate-400 mt-6">
    بتسجيل الدخول، أنت توافق على شروط الاستخدام وسياسة الخصوصية.
  </p>
</div>
ERB

# ============================================================
# Registrations#new — signup
# ============================================================
cat > app/views/registrations/new.html.erb <<'ERB'
<% content_for :title, "إنشاء حساب — ClinicApp" %>

<div class="max-w-lg mx-auto py-12">
  <div class="text-center mb-8">
    <h1 class="text-3xl font-bold text-slate-800">إنشاء حساب جديد</h1>
    <p class="text-slate-500 mt-2">ابدأ بإدارة عيادتك في دقائق</p>
  </div>

  <div class="bg-white rounded-2xl border border-slate-200 p-8 shadow-sm">
    <%= form_with model: @user, url: registrations_path, class: "space-y-5" do |f| %>
      <% if @user.errors.any? %>
        <div class="bg-rose-50 border-l-4 border-rose-500 text-rose-800 p-4 rounded-r-xl text-sm">
          <div class="font-semibold mb-1">يوجد خطأ في البيانات:</div>
          <ul class="list-disc ms-5 space-y-0.5">
            <% @user.errors.full_messages.each do |m| %><li><%= m %></li><% end %>
          </ul>
        </div>
      <% end %>

      <div>
        <%= f.label :name, "الاسم الكامل", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= f.text_field :name, required: true, autofocus: true,
              placeholder: "د. محمد الأحمد",
              class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
      </div>

      <div>
        <%= f.label :email, "البريد الإلكتروني", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
        <%= f.email_field :email, required: true,
              placeholder: "doctor@clinic.sy",
              class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <%= f.label :password, "كلمة المرور", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
          <%= f.password_field :password, required: true,
                placeholder: "8 أحرف على الأقل",
                class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
        </div>
        <div>
          <%= f.label :password_confirmation, "تأكيد كلمة المرور", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
          <%= f.password_field :password_confirmation, required: true,
                placeholder: "أعد كلمة المرور",
                class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <%= f.label :role, "الدور", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
          <%= f.select :role,
                [["طبيب","doctor"],["مالك عيادة","owner"],["ممرض/ة","nurse"],["استقبال","receptionist"],["محاسب","accountant"]],
                { selected: "doctor" },
                class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
        </div>
        <div>
          <%= f.label :locale, "اللغة", class: "block text-sm font-semibold text-slate-700 mb-1.5" %>
          <%= f.select :locale, [["العربية","ar"],["English","en"]], { selected: "ar" },
                class: "w-full border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" %>
        </div>
      </div>

      <div class="flex items-start gap-2 text-sm">
        <%= check_box_tag :terms, "1", false, required: true,
              class: "mt-1 rounded border-slate-300 text-blue-600 focus:ring-blue-500" %>
        <label for="terms" class="text-slate-600">
          أوافق على <%= link_to "الشروط والأحكام", "#", class: "text-blue-600 hover:underline" %> وسياسة الخصوصية.
        </label>
      </div>

      <%= f.submit "إنشاء الحساب",
            class: "w-full bg-blue-600 text-white px-4 py-3 rounded-xl font-semibold hover:bg-blue-700 cursor-pointer shadow-md shadow-blue-500/20 transition" %>
    <% end %>

    <div class="relative my-6">
      <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-slate-200"></div></div>
      <div class="relative flex justify-center text-xs">
        <span class="bg-white px-3 text-slate-400">أو</span>
      </div>
    </div>

    <p class="text-center text-sm text-slate-500">
      لديك حساب بالفعل؟
      <%= link_to "سجّل دخولك", new_session_path, class: "text-blue-600 hover:underline font-semibold" %>
    </p>
  </div>

  <div class="mt-6 grid grid-cols-3 gap-4 text-center text-xs text-slate-500">
    <div class="bg-white rounded-xl border border-slate-200 p-3">
      <div class="text-lg">🔒</div>
      <div class="mt-1">بيانات مشفّرة</div>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-3">
      <div class="text-lg">🇸🇾</div>
      <div class="mt-1">مصمم لسوريا</div>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-3">
      <div class="text-lg">⚡</div>
      <div class="mt-1">إعداد فوري</div>
    </div>
  </div>
</div>
ERB

echo "==> Layout + auth views written."
echo ""
echo "==> Files updated:"
ls -la app/views/layouts/application.html.erb
ls -la app/views/home/index.html.erb
ls -la app/views/sessions/new.html.erb
ls -la app/views/registrations/new.html.erb
echo "==> Done."
