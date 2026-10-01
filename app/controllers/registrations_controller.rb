class RegistrationsController < ApplicationController
  def new
    @user = User.new(email: params[:email])
  end

  def create
    @user = User.new(user_params)
    @user.role   ||= "doctor"
    @user.locale ||= "ar"

    User.transaction do
      @user.save!

      # Auto-accept any pending invitations for this email
      pending_invites = ClinicInvitation.pending.where(email: @user.email.downcase)
      pending_invites.each { |inv| inv.accept!(@user) }

      # If no invitations, create a minimal clinic so they have one
      # and set a flag so the dashboard prompts them to complete it
      if pending_invites.empty?
        clinic = Clinic.create!(
          name:    "#{@user.name}'s Clinic",
          owner:   @user,
          city:    nil,
          specialty: nil
        )
        ClinicMember.create!(clinic: clinic, user: @user, role: "owner")

        # Mark that this clinic is "incomplete"
        # (we can detect this by city being blank)
      end
    end

    session[:user_id] = @user.id
    session[:clinic_id] = @user.clinics.first.id

    # Redirect to complete clinic setup if city is empty
    first_clinic = @user.clinics.first
    if first_clinic.city.blank? || first_clinic.specialty.blank?
      redirect_to edit_dashboard_clinic_path(first_clinic),
                  notice: "مرحباً #{@user.name}! يرجى إكمال بيانات عيادتك."
    else
      redirect_to dashboard_path, notice: "تم إنشاء حسابك بنجاح!"
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :locale)
  end
end
