#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building clinic detail page…"

# ============================================================
# 1. Migration: logo, working hours, public slug
# ============================================================
BASE=$(date +%Y%m%d%H%M)
cat > "db/migrate/${BASE}14_enrich_clinics_again.rb" <<'RUBY'
class EnrichClinicsAgain < ActiveRecord::Migration[7.2]
  def change
    add_column :clinics, :working_hours, :jsonb, default: {} unless column_exists?(:clinics, :working_hours)
    add_column :clinics, :slug,          :string unless column_exists?(:clinics, :slug)
    add_column :clinics, :about,         :text   unless column_exists?(:clinics, :about)
    add_column :clinics, :about_ar,      :text   unless column_exists?(:clinics, :about_ar)
    add_column :clinics, :is_public,     :boolean, default: false unless column_exists?(:clinics, :is_public)

    add_index :clinics, :slug, unique: true unless index_exists?(:clinics, :slug)
  end
end
RUBY

bin/rails db:migrate

# ============================================================
# 2. Add logo attachment + slug generation
# ============================================================
cat > app/models/clinic.rb <<'RUBY'
class Clinic < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  has_many :clinic_members, dependent: :destroy
  has_many :members, through: :clinic_members, source: :user
  has_many :patients,        dependent: :destroy
  has_many :appointments,    dependent: :destroy
  has_many :medical_reports, dependent: :destroy
  has_many :medications,     dependent: :destroy
  has_many :transfers,       dependent: :destroy
  has_many :payments,        dependent: :destroy
  has_many :subscriptions,   dependent: :destroy
  has_many :medical_images,  dependent: :destroy

  has_one_attached :logo

  validates :name, presence: true

  before_validation :generate_slug

  def display_name
    name_ar.presence || name
  end

  def address_display
    address_ar.presence || address
  end

  def open_now?
    return false if working_hours.blank?
    today_key = Date.current.strftime("%A").downcase
    hours = working_hours[today_key]
    return false unless hours && hours["open"].present?

    now = Time.current.strftime("%H:%M")
    now >= hours["open"] && now <= hours["close"].to_s
  end

  def working_hours_today
    return nil if working_hours.blank?
    today_key = Date.current.strftime("%A").downcase
    working_hours[today_key]
  end

  private

  def generate_slug
    return if slug.present?
    return if name.blank?

    base = name.downcase.gsub(/[^a-z0-9\s-]/, "").strip.gsub(/\s+/, "-")
    self.slug = base.presence || "clinic-#{SecureRandom.hex(4)}"

    # Ensure uniqueness
    if Clinic.where(slug: self.slug).where.not(id: id).exists?
      self.slug = "#{self.slug}-#{SecureRandom.hex(3)}"
    end
  end
end
RUBY

# ============================================================
# 3. Controller — add edit/update/staff actions
# ============================================================
cat > app/controllers/dashboard/clinics_controller.rb <<'RUBY'
class Dashboard::ClinicsController < Dashboard::BaseController
  before_action :set_clinic, only: [:show, :edit, :update, :add_member, :remove_member]

  def index
    @clinics = current_user.clinics.includes(:owner).order(:name)
    @clinic  = Clinic.new
  end

  def show
    @members = @clinic.clinic_members.includes(:user)
    @stats = {
      patients:          @clinic.patients.count,
      appointments:      @clinic.appointments.count,
      today_appointments: @clinic.appointments.for_today.count,
      reports:           @clinic.medical_reports.count,
      revenue_month:     @clinic.payments.paid.where(created_at: Time.current.all_month).sum(:amount),
      pending_payments:  @clinic.payments.pending.sum(:amount)
    }
    @recent_activity = @clinic.appointments.includes(:patient, :doctor).order(created_at: :desc).limit(5)
  end

  def new
    @clinic = Clinic.new
  end

  def create
    @clinic = Clinic.new(clinic_params)
    @clinic.owner = current_user

    if @clinic.save
      ClinicMember.find_or_create_by!(clinic: @clinic, user: current_user) { |m| m.role = "owner" }
      redirect_to dashboard_clinic_path(@clinic), notice: "تم إنشاء العيادة."
    else
      @clinics = current_user.clinics
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @clinic.update(clinic_params)
      redirect_to dashboard_clinic_path(@clinic), notice: "تم تحديث بيانات العيادة."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def add_member
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user.nil?
      redirect_to dashboard_clinic_path(@clinic), alert: "لا يوجد مستخدم بهذا البريد."
      return
    end

    member = @clinic.clinic_members.find_or_initialize_by(user: user)
    member.role = params[:role].presence || "doctor"

    if member.save
      redirect_to dashboard_clinic_path(@clinic), notice: "تم إضافة العضو."
    else
      redirect_to dashboard_clinic_path(@clinic), alert: member.errors.full_messages.to_sentence
    end
  end

  def remove_member
    member = @clinic.clinic_members.find(params[:member_id])

    if member.role == "owner"
      redirect_to dashboard_clinic_path(@clinic), alert: "لا يمكن إزالة المالك."
      return
    end

    member.destroy
    redirect_to dashboard_clinic_path(@clinic), notice: "تم إزالة العضو."
  end

  private

  def set_clinic
    @clinic = current_user.clinics.find(params[:id])
  end

  def clinic_params
    params.require(:clinic).permit(
      :name, :name_ar, :address, :address_ar, :phone, :email,
      :city, :specialty, :about, :about_ar, :is_public, :logo,
      working_hours: {}
    )
  end
end
RUBY

# ============================================================
# 4. Routes — add edit/update + staff actions
# ============================================================
cat > config/routes.rb <<'ROUTES'
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

    resources :clinics, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        post :add_member
        delete "remove_member/:member_id", to: "clinics#remove_member", as: :remove_member
      end
    end

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
        get   :prescription
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
ROUTES

echo "✅ Controller + routes updated"

echo "==> Done."
