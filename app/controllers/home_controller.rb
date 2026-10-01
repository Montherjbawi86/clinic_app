class HomeController < ApplicationController
  def index
    base = Clinic.where(is_public: true).includes(:owner)

    # Search
    if params[:q].present?
      q = "%#{params[:q]}%"
      base = base.where(
        "clinics.name ILIKE :q OR clinics.name_ar ILIKE :q " \
        "OR clinics.city ILIKE :q OR clinics.specialty ILIKE :q " \
        "OR clinics.address ILIKE :q OR clinics.address_ar ILIKE :q",
        q: q
      )
    end

    # Filters
    @selected_city      = params[:city].presence
    @selected_specialty = params[:specialty].presence
    base = base.where(city: @selected_city)           if @selected_city
    base = base.where(specialty: @selected_specialty) if @selected_specialty

    @clinics = base.order(:city, :specialty, :name)

    # Group by city (for "browse by city" view)
    @clinics_by_city = @clinics.group_by(&:city)

    # For the filter sidebar — only cities that actually have public clinics
    @available_cities = Clinic.where(is_public: true)
                              .distinct
                              .pluck(:city)
                              .compact
                              .reject(&:blank?)
                              .sort

    # Same for specialties
    @available_specialties = Clinic.where(is_public: true)
                                   .distinct
                                   .pluck(:specialty)
                                   .compact
                                   .reject(&:blank?)
                                   .sort

    # Stats
    @total_clinics      = Clinic.where(is_public: true).count
    @total_cities       = @available_cities.count
    @total_specialties  = @available_specialties.count

    # Featured clinics (with logo, most recent)
    @featured_clinics = Clinic.where(is_public: true)
                              .where.not(logo_url: nil)
                              .limit(3)
  end
end
