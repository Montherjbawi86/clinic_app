class CreateChatMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.text :content
      t.string :language

      t.timestamps
    end
  end
end
