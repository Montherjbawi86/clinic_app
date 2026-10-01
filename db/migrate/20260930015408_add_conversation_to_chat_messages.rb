class AddConversationToChatMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :chat_messages, :conversation_id, :string  unless column_exists?(:chat_messages, :conversation_id)
    add_column :chat_messages, :tokens,          :integer unless column_exists?(:chat_messages, :tokens)
    add_column :chat_messages, :metadata,        :jsonb, default: {} unless column_exists?(:chat_messages, :metadata)
    add_index  :chat_messages, :conversation_id unless index_exists?(:chat_messages, :conversation_id)
  end
end
