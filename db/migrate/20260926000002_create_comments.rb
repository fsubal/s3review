class CreateComments < ActiveRecord::Migration[8.1]
  def change
    # S3 上のコメント（W3C Annotation の JSON）の写し
    create_table :comments do |t|
      t.references :reviewed_object, null: false, foreign_key: true
      t.string :ulid, null: false
      t.string :author_email, null: false
      t.string :author_name
      t.text :body, null: false
      t.json :selector
      t.datetime :commented_at, null: false

      t.timestamps
    end
    add_index :comments, :ulid, unique: true
  end
end
