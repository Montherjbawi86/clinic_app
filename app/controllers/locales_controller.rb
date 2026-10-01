class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s
    unless %w[ar en].include?(locale)
      return redirect_back fallback_location: root_path, alert: "Unsupported language."
    end

    session[:locale] = locale
    current_user.update(locale: locale) if current_user

    redirect_back fallback_location: root_path, notice: (locale == "ar" ? "تم تغيير اللغة." : "Language switched.")
  end
end
