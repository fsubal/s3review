class CreateReviewedObjects < ActiveRecord::Migration[8.1]
  def change
    # S3 の一覧結果とタグ（承認ステータス）の写し。ReindexJob でいつでも作り直せる
    create_table :reviewed_objects do |t|
      t.string :bucket, null: false
      t.string :key, null: false
      t.string :etag
      t.integer :size, limit: 8
      t.string :content_type
      t.datetime :last_modified
      t.string :status, null: false, default: "pending"
      t.datetime :status_updated_at
      t.string :reviewer
      t.datetime :indexed_at, null: false

      t.timestamps
    end
    add_index :reviewed_objects, [ :bucket, :key ], unique: true
    add_index :reviewed_objects, [ :bucket, :status ]
  end
end
