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
