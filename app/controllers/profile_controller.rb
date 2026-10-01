class ProfileController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
    @clinics = current_user.clinics.order(:created_at)
    @has_incomplete_clinic = @clinics.any? { |c| c.city.blank? || c.specialty.blank? }
    @role_here = @user.role_in(@clinics.first) rescue "doctor"
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to profile_path, notice: "تم تحديث الملف الشخصي."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_password
    @user = current_user
    if @user.authenticate(params[:current_password])
      if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        redirect_to profile_path, notice: "تم تغيير كلمة المرور."
      else
        redirect_to profile_path, alert: @user.errors.full_messages.to_sentence
      end
    else
      redirect_to profile_path, alert: "كلمة المرور الحالية غير صحيحة."
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :locale)
  end
end
