class RenameDeletedAtToDiscardedAt < ActiveRecord::Migration[7.2]
  def change
        rename_column :users,   :deleted_at, :discarded_at
    rename_column :clinics, :deleted_at, :discarded_at
  end
end
