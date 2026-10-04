class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :impersonate, :deactivate, :activate, :reset_password]

  def index
    scope = User.with_discarded.order(created_at: :desc)
    scope = scope.where("name ILIKE :q OR email ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(role: params[:role]) if params[:role].present?
    scope = case params[:state]
            when "active"    then scope.kept
            when "suspended" then scope.discarded
            else scope
            end
    @users = scope
  end

  def show
    @clinics = @user.clinics
  end

  def impersonate
    if @user.super_admin?
      return redirect_to admin_users_path, alert: "Cannot impersonate a super admin"
    end
    session[:original_user_id] = current_user.id
    session[:user_id] = @user.id
    redirect_to dashboard_path, notice: "Now viewing as #{@user.name}"
  end

  def deactivate
    if @user.super_admin?
      return redirect_to admin_user_path(@user), alert: "Cannot deactivate a super admin"
    end
    @user.deactivate!
    redirect_to admin_user_path(@user), notice: "User deactivated"
  end

  def activate
    @user.activate!
    redirect_to admin_user_path(@user), notice: "User reactivated"
  end

  def reset_password
    temp = SecureRandom.base58(12)
    @user.update!(password: temp, password_confirmation: temp)
    redirect_to admin_user_path(@user),
                notice: "Temporary password: #{temp} (copy it now)"
  end

  private

  def set_user
    @user = User.with_discarded.find(params[:id])
  end
end
