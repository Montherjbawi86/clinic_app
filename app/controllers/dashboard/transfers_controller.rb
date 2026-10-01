class Dashboard::TransfersController < Dashboard::BaseController
  def index
    @transfers = current_clinic.transfers
                               .includes(:patient, :from_clinic, :to_clinic)
                               .order(created_at: :desc)
    @transfer = current_clinic.transfers.new
    @destination_clinics = Clinic.where.not(id: current_clinic.id).order(:name)

    # For the form dropdowns
    @patients = current_clinic.patients.order(:name)
  end

  def create
    @transfer = current_clinic.transfers.new(transfer_params)
    @transfer.from_clinic = current_clinic
    @transfer.status     ||= "pending"

    if @transfer.save
      redirect_to dashboard_transfers_path, notice: "Transfer request created."
    else
      @transfers = current_clinic.transfers
                                 .includes(:patient, :from_clinic, :to_clinic)
                                 .order(created_at: :desc)
      @destination_clinics = Clinic.where.not(id: current_clinic.id).order(:name)
      @patients = current_clinic.patients.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    transfer = current_clinic.transfers.find(params[:id])
    transfer.destroy
    redirect_to dashboard_transfers_path, notice: "Transfer removed."
  end

  private

  def transfer_params
    params.require(:transfer).permit(:patient_id, :to_clinic_id, :reason)
  end
end
