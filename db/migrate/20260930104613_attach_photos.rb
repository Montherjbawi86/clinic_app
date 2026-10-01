class AttachPhotos < ActiveRecord::Migration[7.2]
  def change
    # Medical images table — one patient can have many images
    unless table_exists?(:medical_images)
      create_table :medical_images do |t|
        t.references :clinic,        null: false, foreign_key: true
        t.references :patient,       null: false, foreign_key: true
        t.references :medical_report, foreign_key: true
        t.references :uploaded_by,   foreign_key: { to_table: :users }

        t.string   :title
        t.string   :title_ar
        t.string   :image_type          # xray, mri, ct, ultrasound, photo, other
        t.string   :body_part           # chest, head, abdomen, etc.
        t.date     :taken_on
        t.text     :notes
        t.text     :notes_ar
        t.datetime :deleted_at

        t.timestamps
      end

      add_index :medical_images, :image_type
      add_index :medical_images, :deleted_at
      add_index :medical_images, [:patient_id, :created_at]
    end
  end
end
