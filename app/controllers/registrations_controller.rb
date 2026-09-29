class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.role ||= "doctor"
    @user.locale ||= "en"

    if @user.save
      # Automatically create a default clinic for the new doctor
      @user.clinics.create!(name: "#{@user.name}'s Clinic")
      
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: "Account created successfully!"
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :locale)
  end
end
