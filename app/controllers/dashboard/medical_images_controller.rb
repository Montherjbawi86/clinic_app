class Dashboard::MedicalImagesController < Dashboard::BaseController
  before_action :set_patient, only: [:index, :create]
  before_action :set_image,   only: [:show, :destroy]

  def index
    @images = current_clinic.medical_images.for_patient(@patient).recent
    @image  = current_clinic.medical_images.new(patient: @patient)
  end

  def create
    @image = current_clinic.medical_images.new(image_params)
    @image.patient     = @patient
    @image.uploaded_by = current_user

    if @image.save
      redirect_to dashboard_patient_medical_images_path(@patient), notice: "تم رفع الصورة."
    else
      @images = current_clinic.medical_images.for_patient(@patient).recent
      render :index, status: :unprocessable_entity
    end
  end

  def show
    send_data @image.file.download,
              filename: @image.file.filename.to_s,
              type: @image.file.content_type,
              disposition: "inline"
  end

  def destroy
    @patient = @image.patient
    @image.destroy
    redirect_to dashboard_patient_medical_images_path(@patient), notice: "تم حذف الصورة."
  end

  private

  def set_patient
    @patient = current_clinic.patients.find(params[:patient_id])
  end

  def set_image
    @image = current_clinic.medical_images.find(params[:id])
  end

  def image_params
    params.require(:medical_image).permit(:title, :title_ar, :image_type, :body_part, :taken_on, :notes, :medical_report_id, :file)
  end
end
