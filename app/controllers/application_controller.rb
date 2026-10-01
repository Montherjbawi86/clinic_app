class ApplicationController < ActionController::Base
  around_action :switch_locale

  helper_method :current_user, :logged_in?, :current_clinic

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def current_clinic
    @current_clinic
  end

  def require_login
    return if logged_in?
    redirect_to new_session_path, alert: "Please log in to continue."
  end

  def switch_locale(&action)
    locale =
      params[:locale].presence ||
      session[:locale].presence ||
      current_user&.locale.presence ||
      I18n.default_locale

    locale = locale.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)

    session[:locale] = locale
    I18n.with_locale(locale, &action)
  end
end
