class Dashboard::ChatController < Dashboard::BaseController
  def index
    messages = current_user.chat_messages.recent.limit(50)
    render json: { messages: messages }
  end

  def create
    text     = params[:message].to_s.strip
    language = params[:language] == "en" ? "en" : "ar"

    return render json: { error: "Empty message" }, status: :unprocessable_entity if text.blank?

    reply = language == "en" ?
      "Hello! I am your medical assistant. How can I help you with your clinic records today?" :
      "مرحباً! أنا مساعدك الطبي. كيف يمكنني مساعدتك في سجلات عيادتك اليوم؟"

    ChatMessage.create!(user: current_user, sender_role: "user",      content: text,  language: language)
    ChatMessage.create!(user: current_user, sender_role: "assistant", content: reply, language: language)

    render json: { reply: reply, language: language }
  end
end
