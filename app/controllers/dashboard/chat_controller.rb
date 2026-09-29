class Dashboard::ChatController < ApplicationController
  before_action :require_login

  def index
    messages = current_user.chat_messages.order(created_at: :asc).limit(50)
    render json: { messages: messages }
  end

  def create
    message_text = params[:message]
    language = params[:language] == "en" ? "en" : "ar"
    
    # Basic rule-based medical assistant mock reply
    reply = language == "en" ? "Hello! I am your medical assistant. How can I help you with your clinic records or patient evaluation today?" : "مرحباً! أنا مساعدك الطبي. كيف يمكنني مساعدتك في سجلات عيادتك اليوم؟"

    ChatMessage.create(user: current_user, role: "user", content: message_text, language: language)
    ChatMessage.create(user: current_user, role: "assistant", content: reply, language: language)

    render json: { reply: reply, language: language }
  end
end
