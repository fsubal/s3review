namespace :review do
  desc "S3 をクロールして SQLite の索引を作り直す（同期実行）"
  task reindex: :environment do
    result = ObjectStore::Indexer.new.run
    puts "objects=#{result.objects} comments=#{result.comments} removed=#{result.removed}"
  end
end

namespace :review do
  desc "デモ用: ディレクトリの中身を S3_BUCKET/TARGET_PREFIX に投入する（バケットが無ければ作る）。例: bin/rails 'review:seed[script/sample]'"
  task :seed, [ :dir ] => :environment do |_t, args|
    dir = Pathname.new(args[:dir] || "script/sample")
    abort "#{dir} is not a directory" unless dir.directory?

    client = ObjectStore.client
    config = ObjectStore.config
    begin
      client.s3.head_bucket(bucket: config.bucket)
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
      client.s3.create_bucket(bucket: config.bucket)
      puts "created bucket #{config.bucket}"
    end

    # 同じ内容がすでにあれば触らない。PutObject し直すとオブジェクトタグ（承認ステータス）が消えてしまうため
    count = 0
    skipped = 0
    dir.glob("**/*").select(&:file?).sort.each do |path|
      key = config.target_prefix + path.relative_path_from(dir).to_s
      if (head = client.head(key)) && head.etag == Digest::MD5.file(path).hexdigest
        skipped += 1
        next
      end
      content_type = Rack::Mime.mime_type(path.extname, "application/octet-stream")
      path.open("rb") { |io| client.s3.put_object(bucket: config.bucket, key: key, body: io, content_type: content_type) }
      puts "put s3://#{config.bucket}/#{key} (#{content_type})"
      count += 1
    end
    puts "seeded #{count} objects (#{skipped} unchanged, skipped)"
  end
end
