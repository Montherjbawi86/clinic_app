#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building clinic invitations…"

# ============================================================
# 1. Migration
# ============================================================
BASE=$(date +%Y%m%d%H%M)
cat > "db/migrate/${BASE}15_create_clinic_invitations.rb" <<'RUBY'
class CreateClinicInvitations < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:clinic_invitations)
      create_table :clinic_invitations do |t|
        t.references :clinic,  null: false, foreign_key: true
        t.references :invited_by, foreign_key: { to_table: :users }
        t.string  :email,      null: false
        t.string  :role,       null: false, default: "doctor"
        t.string  :token,      null: false
        t.datetime :accepted_at
        t.datetime :expires_at
        t.timestamps
      end

      add_index :clinic_invitations, :token,  unique: true
      add_index :clinic_invitations, :email
      add_index :clinic_invitations, [:clinic_id, :email], unique: true, name: "idx_invitations_clinic_email"
    end
  end
end
RUBY

bin/rails db:migrate

# ============================================================
# 2. Model
# ============================================================
cat > app/models/clinic_invitation.rb <<'RUBY'
class ClinicInvitation < ApplicationRecord
  ROLES = %w[owner doctor nurse receptionist accountant].freeze

  belongs_to :clinic
  belongs_to :invited_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,  inclusion: { in: ROLES }
  validates :email, uniqueness: { scope: :clinic_id, message: "already invited" }

  before_validation :normalize_email
  before_validation :generate_token, on: :create
  before_validation :set_expiry,     on: :create

  scope :pending,  -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired,  -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }

  def pending?;  accepted_at.nil? && expires_at&.future?; end
  def expired?;  accepted_at.nil? && expires_at&.past?;   end
  def accepted?; accepted_at.present?;                     end

  def accept!(user)
    transaction do
      clinic.clinic_members.find_or_create_by!(user: user) do |m|
        m.role = role
      end
      update!(accepted_at: Time.current)
    end
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def set_expiry
    self.expires_at ||= 7.days.from_now
  end
end
RUBY

# ============================================================
# 3. Add association to Clinic
# ============================================================
python3 <<'PY'
path = "app/models/clinic.rb"
src = open(path).read()

if "clinic_invitations" not in src:
    src = src.replace(
        "  has_many :medical_images,  dependent: :destroy",
        "  has_many :medical_images,  dependent: :destroy\n  has_many :clinic_invitations, dependent: :destroy"
    )
    open(path, "w").write(src)
    print("✅ Association added to Clinic")
else:
    print("Association already present")
PY

# ============================================================
# 4. Add association to User
# ============================================================
python3 <<'PY'
path = "app/models/user.rb"
src = open(path).read()

if "clinic_invitations" not in src:
    src = src.replace(
        "  has_many :chat_messages, dependent: :destroy",
        "  has_many :chat_messages, dependent: :destroy\n  has_many :sent_invitations, class_name: \"ClinicInvitation\", foreign_key: \"invited_by_id\", dependent: :nullify"
    )
    open(path, "w").write(src)
    print("✅ Association added to User")
else:
    print("Association already present")
PY

# ============================================================
# 5. Controller
# ============================================================
cat > app/controllers/dashboard/clinic_invitations_controller.rb <<'RUBY'
class Dashboard::ClinicInvitationsController < Dashboard::BaseController
  before_action :set_clinic
  before_action :set_invitation, only: [:destroy, :resend]

  def create
    email = params[:email].to_s.downcase.strip
    role  = params[:role].to_s.presence || "doctor"

    if email.blank?
      redirect_to dashboard_clinic_path(@clinic), alert: "البريد الإلكتروني مطلوب."
      return
    end

    # If user exists AND is already a member, short-circuit
    existing_user = User.find_by(email: email)
    if existing_user && @clinic.clinic_members.exists?(user: existing_user)
      redirect_to dashboard_clinic_path(@clinic), alert: "هذا المستخدم عضو بالفعل في العيادة."
      return
    end

    # If user exists and NOT a member, add directly (no invite needed)
    if existing_user
      @clinic.clinic_members.create!(user: existing_user, role: role)
      redirect_to dashboard_clinic_path(@clinic), notice: "تم إضافة #{existing_user.name} إلى الفريق."
      return
    end

    # Otherwise create an invitation
    invitation = @clinic.clinic_invitations.find_or_initialize_by(email: email)
    invitation.role       = role
    invitation.invited_by = current_user
    invitation.token      = nil  # regenerate
    invitation.accepted_at = nil
    invitation.expires_at  = nil

    if invitation.save
      # TODO: send email — for now just show the link
      redirect_to dashboard_clinic_path(@clinic),
                  notice: "تم إرسال دعوة إلى #{email}. سيتم إضافتهم عند التسجيل."
    else
      redirect_to dashboard_clinic_path(@clinic), alert: invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @invitation.destroy
    redirect_to dashboard_clinic_path(@clinic), notice: "تم إلغاء الدعوة."
  end

  def resend
    @invitation.update!(token: SecureRandom.urlsafe_base64(24), expires_at: 7.days.from_now)
    redirect_to dashboard_clinic_path(@clinic), notice: "تم تجديد الدعوة."
  end

  private

  def set_clinic
    @clinic = current_user.clinics.find(params[:clinic_id])
  end

  def set_invitation
    @invitation = @clinic.clinic_invitations.find(params[:id])
  end
end
RUBY

# ============================================================
# 6. Auto-accept on signup — update RegistrationsController
# ============================================================
cat > app/controllers/registrations_controller.rb <<'RUBY'
class RegistrationsController < ApplicationController
  def new
    @user = User.new(email: params[:email])
  end

  def create
    @user = User.new(user_params)
    @user.role ||= "doctor"
    @user.locale ||= "en"

    User.transaction do
      @user.save!

      # Auto-accept any pending invitations for this email
      pending_invites = ClinicInvitation.pending.where(email: @user.email.downcase)
      pending_invites.each { |inv| inv.accept!(@user) }

      # If no invitations, create own clinic
      if pending_invites.empty?
        clinic = Clinic.create!(name: "#{@user.name}'s Clinic", owner: @user)
        ClinicMember.create!(clinic: clinic, user: @user, role: "owner")
      end
    end

    session[:user_id] = @user.id
    session[:clinic_id] = @user.clinics.first.id
    redirect_to dashboard_path, notice: "Account created successfully!"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :locale)
  end
end
RUBY

# ============================================================
# 7. Routes — add invitations
# ============================================================
python3 <<'PY'
path = "config/routes.rb"
src = open(path).read()

if "clinic_invitations" not in src:
    old = '''    resources :clinics, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        post :add_member
        delete "remove_member/:member_id", to: "clinics#remove_member", as: :remove_member
      end
    end'''

    new = '''    resources :clinics, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        post :add_member
        delete "remove_member/:member_id", to: "clinics#remove_member", as: :remove_member
      end
      resources :clinic_invitations, only: [:create, :destroy], controller: "clinic_invitations" do
        member do
          post :resend
        end
      end
    end'''

    if old in src:
        src = src.replace(old, new)
        open(path, "w").write(src)
        print("✅ Routes updated")
    else:
        print("❌ Could not patch routes — need manual edit")
else:
    print("Routes already have clinic_invitations")
PY

# ============================================================
# 8. Update clinic show view — replace the add member form
# ============================================================
python3 <<'PY'
path = "app/views/dashboard/clinics/show.html.erb"
src = open(path).read()

# Find the current add-member form section
old = '''      <div class="p-4 border-t border-slate-200 bg-slate-50">
        <%= form_with url: add_member_dashboard_clinic_path(@clinic), method: :post, class: "space-y-2" do %>
          <div class="grid grid-cols-3 gap-2">
            <%= email_field_tag :email, nil, placeholder: "البريد الإلكتروني", required: true,
                  class: "col-span-2 border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
            <%= select_tag :role,
                  options_for_select([["طبيب","doctor"],["ممرض","nurse"],["استقبال","receptionist"],["محاسب","accountant"]]),
                  class: "border border-slate-300 rounded-lg px-2 py-2 text-sm" %>
          </div>
          <%= submit_tag "إضافة عضو",
                class: "w-full bg-teal-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-teal-700 cursor-pointer text-sm" %>
        <% end %>
      </div>'''

new = '''      <!-- Pending invitations -->
      <% pending = @clinic.clinic_invitations.pending %>
      <% if pending.any? %>
        <div class="border-t border-slate-200 p-4 bg-amber-50">
          <div class="text-xs font-semibold text-amber-800 mb-2">دعوات معلّقة</div>
          <ul class="space-y-1">
            <% pending.each do |inv| %>
              <li class="flex items-center justify-between text-sm">
                <span class="text-amber-900 truncate"><%= inv.email %> <span class="text-xs text-amber-600">(<%= inv.role %>)</span></span>
                <%= button_to "×", dashboard_clinic_clinic_invitation_path(@clinic, inv),
                      method: :delete,
                      data: { turbo_confirm: "إلغاء الدعوة؟" },
                      class: "text-rose-600 hover:text-rose-800 font-bold" %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="p-4 border-t border-slate-200 bg-slate-50">
        <div class="text-xs text-slate-500 mb-2">أضف عضواً — إذا لم يكن مسجلاً، سيتم إنشاء دعوة.</div>
        <%= form_with url: dashboard_clinic_clinic_invitations_path(@clinic), method: :post, class: "space-y-2" do %>
          <div class="grid grid-cols-3 gap-2">
            <%= email_field_tag :email, nil, placeholder: "البريد الإلكتروني", required: true,
                  class: "col-span-2 border border-slate-300 rounded-lg px-3 py-2 text-sm" %>
            <%= select_tag :role,
                  options_for_select([["طبيب","doctor"],["ممرض","nurse"],["استقبال","receptionist"],["محاسب","accountant"]]),
                  class: "border border-slate-300 rounded-lg px-2 py-2 text-sm" %>
          </div>
          <%= submit_tag "إضافة / دعوة",
                class: "w-full bg-teal-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-teal-700 cursor-pointer text-sm" %>
        <% end %>
      </div>'''

if old in src:
    src = src.replace(old, new)
    open(path, "w").write(src)
    print("✅ View updated with invitation form")
else:
    print("❌ View pattern not found")
    print("Looking for add-member form…")
    import re
    m = re.search(r'<div class="p-4 border-t[^>]*bg-slate-50[^>]*>.*?</div>', src, re.DOTALL)
    if m:
        print("Found something similar at position", m.start())
    else:
        print("No matching form found")
PY

echo "==> Done."
echo ""
echo "Next:"
echo "  1. pkill -9 -f 'rails server'; rm -f tmp/pids/server.pid"
echo "  2. bin/dev"
echo "  3. Test the form on /dashboard/clinics/1"
