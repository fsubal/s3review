# s3review

S3 互換ストレージ（Amazon S3 / MinIO / Ceph RGW / Google Cloud Storage）に **すでにあるオブジェクト** を人間がレビューするための、セルフホスト可能な単独アプリケーションです。ファイルを自分のところにアップロードさせるのではなく、既存のバケットをそのまま覗き、コメントと承認ステータスをバケット側に書き戻します。いわば「Box のヘッドレス版」です。

- **S3 が真実の源。** コメントは W3C Web Annotation の JSON としてバケット内のサイドカー（`.review/`）に、承認ステータスはオブジェクトタグ（タグのない GCS ではサイドカー）に保存します。アプリ側の SQLite は一覧・検索用の索引で、消えても S3 から作り直せます。
- **認証は前段のプロキシに委譲。** Google IAP / AWS ALB 認証 / Cloudflare Access / oauth2-proxy が付ける身元をそのまま使います。ユーザーテーブルもログイン画面もありません。
- **1 コンテナ。** Web と ジョブワーカーが同じプロセスで動きます。既存の docker-compose にサービスをひとつ足すだけで導入できます。

## 試す

```sh
docker compose up --build
```

- http://localhost:3000 — アプリ。デモ用の `developer` 認証なので任意のメールでログインできます（`admin@example.com` が admin）
- http://localhost:9001 — S3 互換ストレージ（RustFS）のコンソール（rustfsadmin / rustfsadmin）

`script/sample/` の中身が `s3://manuscripts/submissions/` に投入され、起動時の再索引ジョブで一覧に出ます。詳細画面でコメントを書き、承認ボタンを押すと、ストレージ側のオブジェクトタグに `review-status=approved` が付きます:

```sh
docker compose exec app bin/rails runner 'p ObjectStore.client.get_tags("submissions/2026-10-issue/cover.png")'
```

デモ用ストレージには MinIO ではなく RustFS を使っています（MinIO の公式イメージが公開レジストリから取れなくなったため。MinIO 互換で Web コンソール付き）。versity/versitygw でも動作確認済みです。

## 自分の compose に足す

```yaml
services:
  s3review:
    image: <ビルドしたイメージ>
    ports: ["3000:80"]
    environment:
      SECRET_KEY_BASE: <bin/rails secret>
      SOLID_QUEUE_IN_PUMA: "true"
      S3_ENDPOINT: http://s3:9000           # AWS S3 なら不要
      S3_PUBLIC_ENDPOINT: https://files.example.com   # ブラウザから見えるホスト
      S3_REGION: us-east-1
      S3_BUCKET: my-bucket
      S3_ACCESS_KEY_ID: ...
      S3_SECRET_ACCESS_KEY: ...
      TARGET_PREFIX: uploads/
      AUTH_PROVIDER: forwarded_header       # 前段の認証プロキシに合わせる（下記）
      ADMIN_EMAILS: you@example.com
      API_TOKENS: <長いランダム文字列>
    volumes:
      - s3review-storage:/rails/storage     # SQLite。消えても再索引で復元される
```

すべての環境変数は `.env.example` にまとめてあります。

## 認証（AUTH_PROVIDER）

アプリ自身はログインを実装せず、前段のプロキシが付けるヘッダから身元を取ります。JWT を付けるプロキシでは **必ず署名を検証** し、メールアドレスのヘッダ単体は信用しません（ヘッダ偽装対策）。

| `AUTH_PROVIDER` | 前段 | 必要な設定 | 備考 |
|---|---|---|---|
| `gcp_iap` | Google Cloud Identity-Aware Proxy | `IAP_AUDIENCE`（`/projects/<番号>/global/backendServices/<ID>`。Cloud Console の IAP 画面 → 「JWT オーディエンス コードを取得」） | `X-Goog-IAP-JWT-Assertion` を ES256 で検証 |
| `aws_alb` | ALB の認証アクション（Cognito または OIDC IdP。Google も可） | `ALB_REGION`、任意で `ALB_ARN` | `x-amzn-oidc-data` を ALB のリージョン別公開鍵で検証。IAM ではなく ALB の機能です |
| `cloudflare_access` | Cloudflare Access | `CF_ACCESS_TEAM_DOMAIN`、`CF_ACCESS_AUD` | `Cf-Access-Jwt-Assertion` を RS256 で検証 |
| `forwarded_header` | oauth2-proxy / Pomerium / Authelia / Authentik | 任意で `AUTH_EMAIL_HEADER`（既定 `X-Forwarded-Email`） | **署名がない。** アプリにプロキシ以外から到達できないネットワーク構成が前提 |
| `developer` | なし | — | 開発・デモ専用。production では `AUTH_ALLOW_DEVELOPER_IN_PRODUCTION=true` を明示しないと起動しない |

設定が合っているかは `/whoami` で確認できます（届いている認証ヘッダと、誰として見えているかを表示）。oauth2-proxy を前段に置く構成例は `compose.oauth2-proxy.yml` にあります。

認証済みのユーザーは全員 reviewer（コメント・承認ができる）。`ADMIN_EMAILS` に含まれる人だけ admin（再索引の手動実行）。

## データの置き場所

```
s3://<S3_BUCKET>/
├── <TARGET_PREFIX>...                         レビュー対象（読み取り + タグ書き込みのみ）
│     tag: review-status = pending | approved | changes_requested | rejected
│     tag: review-updated-at = <ISO8601>,  review-reviewer = <email>
└── <REVIEW_PREFIX>                             既定 .review/（REVIEW_BUCKET で別バケットにもできる）
    └── objects/<sha256(key)>/
        ├── comments/<ULID>.json               コメント 1 件 = 1 オブジェクト（W3C Web Annotation）
        └── status.json                        STATUS_STRATEGY=sidecar のときだけ
```

- コメントは追記のみなので同時書き込みで競合しません。
- `STATUS_STRATEGY=tags` は PutObjectTagging を使うので、オブジェクト本体をコピーせずに更新できます。既存のタグは壊しません。
- GCS にはタグがないので `STATUS_STRATEGY=sidecar` を使ってください。

コメントの JSON 例:

```json
{
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "id": "urn:ulid:01M3EC16S3B3DKA96QA5EV0TX1",
  "type": "Annotation",
  "motivation": "commenting",
  "created": "2026-09-26T08:00:00Z",
  "creator": { "type": "Person", "email": "alice@example.com", "name": "Alice" },
  "body": { "type": "TextualBody", "value": "表紙の色味を確認してください", "format": "text/plain" },
  "target": { "source": "s3://manuscripts/submissions/2026-10-issue/cover.png" }
}
```

今はファイル全体へのコメントだけですが、`target.selector` に Media Fragments（画像 `xywh=`、動画 `t=`）や PDF の `page=` を足すことで位置指定コメントに拡張する予定です。

## JSON API

`Authorization: Bearer <API_TOKENS のいずれか>`、またはブラウザと同じ前段プロキシの身元で認証します。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/api/v1/objects?status=approved&prefix=2026/&updated_since=<ISO8601>&page=1&per=100` | オブジェクト一覧（索引から返す） |
| GET | `/api/v1/objects/<key>` | 1 件 + コメント |
| GET | `/api/v1/objects/<key>/comments` | コメント（W3C Annotation の配列） |

```sh
curl -H "Authorization: Bearer demo-api-token" "http://localhost:3000/api/v1/objects?status=approved"
```

## 索引（SQLite）について

一覧・フィルタを速くするため、`TARGET_PREFIX` 以下をクロールして SQLite に写しています。

- 起動時（`REINDEX_ON_BOOT`）と定期（`REINDEX_EVERY`、既定 10 分）に `ReindexJob` が走ります。手動なら `bin/rails review:reindex` か、admin で一覧画面の「再索引」。
- 詳細画面を開いたときはその 1 件を S3 から読み直すので、索引が古くても詳細は常に最新です。
- タグ戦略では 1 オブジェクトごとに GetObjectTagging が飛びます。数千件までは問題ありませんが、それ以上は S3 イベント通知や S3 Inventory による差分更新を検討してください（未実装）。

## 開発

```sh
mise install
bundle install && npm install
bin/rails db:prepare
docker compose up -d s3 seed         # ストレージとサンプルデータだけ立てる
S3_BUCKET=manuscripts TARGET_PREFIX=submissions/ S3_ENDPOINT=http://localhost:9000 \
  S3_ACCESS_KEY_ID=rustfsadmin S3_SECRET_ACCESS_KEY=rustfsadmin bin/dev
```

テスト:

```sh
bin/rails test                     # S3 はインメモリの FakeClient
S3_TEST_ENDPOINT=http://localhost:9000 S3_TEST_ACCESS_KEY_ID=rustfsadmin S3_TEST_SECRET_ACCESS_KEY=rustfsadmin \
  bin/rails test test/lib/object_store/s3_compat_test.rb   # 実ストレージ（compose の RustFS 等）に対する統合テスト
npm run check                      # TypeScript
```

## 今後

1. Webhook（`object.approved` などのイベントを HMAC 署名付きで POST、指数バックオフで再送）
2. 位置指定コメント: 画像領域（Annotorious）→ 動画時間 → PDF ページ + 領域 → テキスト行
3. OIDC 直結（前段プロキシなしで動かしたい人向け）、GCS メタデータへの書き戻し、S3 イベント通知による差分索引
