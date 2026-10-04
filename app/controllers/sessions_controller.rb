class SessionsController < ApplicationController
  def new; end

  def create
    user = User.with_discarded.find_by(email: params[:email]&.downcase)

    if user&.authenticate(params[:password])
      if user.suspended?
        flash.now[:alert] = "Your account has been deactivated. Contact support."
        render :new, status: :unauthorized
        return
      end

      session[:user_id] = user.id

      if user.super_admin?
        redirect_to admin_root_path, notice: "Logged in as admin"
      else
        redirect_to dashboard_path, notice: "Logged in successfully"
      end
    else
      flash.now[:alert] = "Invalid credentials"
      render :new, status: :unauthorized
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully"
  end
end
