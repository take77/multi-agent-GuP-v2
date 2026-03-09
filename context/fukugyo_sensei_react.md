# 複業先生 React フロント コンテキスト

> 調査日: 2026-03-09 / 作成者: marie (subtask_102d)
> 調査担当: hana (技術スタック・構成), rosehip (ページ構成・ドメイン), andou (テスト・デプロイ・開発環境)

---

## 概要

- **プロダクト**: 複業先生 — 教師と学校をつなぐ副業マッチングプラットフォーム
- **リポジトリ名**: `fukugyo-sensei-react`
- **リポジトリパス**: `/home/take77/Developments/AI-Novel-Generator/` 等ではなく、LX共通リポジトリ参照（SSH key: `lxdesign-inc/fukugyo-sensei-react`）
- **サービス構成**:
  - `api` — Rails バックエンド (`lxdesign-inc/fukugyo-sensei-api`)
  - `office` — Rails 管理画面
  - `react` — このフロントエンド（本ドキュメント対象）
  - `lambda` — PDF処理
- **開発サーバー**: `yarn start` → `http://localhost:8000`

---

## 技術スタック

### コアフレームワーク

| ライブラリ | バージョン | 用途 |
|-----------|----------|------|
| React | ^18.2.0 | UIフレームワーク |
| TypeScript | ^5.4.5 | 型安全 |
| react-scripts (CRA) | 5.0.1 | ビルドツール |
| Node.js | 24.11.1 | ランタイム（Volta管理） |
| Yarn | 1.22.22 | パッケージマネージャー（Volta管理） |

> ⚠️ **注意**: CLAUDE.md には Node.js v20.10.0 推奨と記載があるが、Volta設定は v24.11.1 と乖離。実際は v24 系で動作。

### 状態管理

| ライブラリ | バージョン | 用途 |
|-----------|----------|------|
| Jotai | ^2.6.4 | グローバル状態（`atomWithStorage`でセッション永続化） |
| SWR | ^2.2.5 | サーバー状態・データフェッチ |
| @aspida/swr | ^1.14.0 | SWR + aspida 統合 |

### UIフレームワーク

| ライブラリ | バージョン |
|-----------|----------|
| @mui/material | ^5.15.9 |
| @mui/icons-material | ^5.15.9 |
| @mui/lab | ^5.0.0-alpha.165 |
| @mui/x-date-pickers | 5 |
| @emotion/react | ^11.11.3 |
| @emotion/styled | ^11.11.0 |

### API連携

| ライブラリ | バージョン | 用途 |
|-----------|----------|------|
| aspida | ^1.14.0 | 型安全APIクライアント生成 |
| @aspida/axios | ^1.14.0 | axios アダプター |
| axios | ^1.6.7 | HTTP クライアント |
| openapi2aspida | ^0.23.2 | OpenAPI → aspida 型変換 |

### フォーム・バリデーション

| ライブラリ | バージョン |
|-----------|----------|
| react-hook-form | ^7.62.0 |
| @hookform/resolvers | ^3.3.4 |
| yup | ^1.3.3 |

### ルーティング

- **react-router-dom** v5系（`BrowserRouter`, `Switch`, `Route`, `Redirect`）

### その他主要ライブラリ

| ライブラリ | バージョン | 用途 |
|-----------|----------|------|
| d3 / d3-cloud | ^7.9.0 / ^1.2.7 | データ可視化 |
| date-fns / dayjs | ^2.0.1 / ^1.11.10 | 日付処理 |
| react-datepicker | ^6.1.0 | 日付選択UI |
| swiper | ^11.1.14 | スライダー |
| video.js | 7.21.5 | 動画プレイヤー |
| react-pdf | 9.2.1 | PDF表示 |
| jspdf | ^3.0.1 | PDF生成 |
| html2canvas | ^1.4.1 | スクリーンショット |
| @dnd-kit/core + @dnd-kit/sortable | — | ドラッグ&ドロップ |
| react-media-recorder | ^1.7.1 | 録音・録画 |
| @sentry/react | ^10.35.0 | エラーモニタリング |
| react-helmet-async | ^2.0.4 | SEO（head管理） |

### 開発ツール

| ツール | バージョン | 用途 |
|-------|----------|------|
| Storybook | ^10.1.2 | コンポーネントカタログ |
| Playwright | ^1.56.0 | E2Eテスト |
| ESLint | ^8.56.0 | Lint（airbnb設定） |
| Prettier | ^3.2.5 | コードフォーマット |
| Husky | ^9.0.10 | git hooks |
| lint-staged | — | コミット前自動lint |
| Knip | ^5.14.0 | 未使用コード検出 |

---

## ディレクトリ構成

```
src/
├── api/               # aspida で自動生成された API クライアント型定義（yarn api:build で再生成）
├── assets/            # 静的アセット（画像等）
├── components/        # リソース横断で再利用可能なコンポーネント
│   ├── atoms/         # 原子コンポーネント
│   ├── layouts/       # レイアウトコンポーネント
│   ├── molecules/     # 分子コンポーネント
│   ├── organisms/     # オーガニズムコンポーネント
│   ├── providers/     # Context プロバイダー
│   └── routes/        # ルーティング設定（PrivateRoute 等）
├── constants/         # グローバル定数
├── features/          # ページ・機能単位モジュール（Atomic Design + Feature-based）
│   ├── accountDeletion/        # アカウント削除
│   ├── lessonSlides/           # 授業スライド
│   ├── lessons/                # 授業（アンケート等）
│   ├── pastLessonExamples/     # 過去授業事例
│   ├── recruitments/           # 募集（一覧・詳細）
│   ├── root/                   # ルートページ（LP・ログイン・サインアップ・お問合せ等）
│   ├── schoolAdmin/            # 学校管理者機能
│   ├── schools/                # 学校（認証・マイページ・プロフィール）
│   ├── teachers/               # 先生（認証・マイページ・プロフィール・AI検索）
│   └── ticketGroupDashboard/   # チケットグループダッシュボード（教育委員会）
├── hooks/             # グローバルカスタムフック
├── libs/              # ライブラリ設定（aspida 等）
├── services/          # アプリ全体のロジック・ユーティリティ
├── store/             # グローバルストア（Jotai atoms）
├── test/              # テストファイル（e2e/ unit/）
├── themes/            # MUI・CSS テーマ設定
├── types/             # グローバル型定義
└── utils/             # ユーティリティ関数
```

### 設計パターン

- **Atomic Design** 採用（atoms / molecules / organisms）
- **Feature-based** 構成（`src/features/{リソース名}/`）
- features 内でページ別サブディレクトリ（index / id / auth / mypage 等）に分割
- 各 feature に `atoms/`, `molecules/`, `organisms/`, `hooks/`, `useApi.ts`, `store.ts`, `pages.tsx`

---

## 主要ドメインオブジェクト

### ① 複業先生（Teacher）

ソース: `src/api/api/v1/teachers/`, `src/store/AuthStore.ts`

| フィールド | 型 | 概要 |
|-----------|---|------|
| `teacher_id` / `id` | number | 先生ID |
| `name` | string | 氏名 |
| `kana_name` | string | カナ氏名 |
| `teacher_rank` | string | 先生ランク |
| `organization_name` | string | 所属組織名 |
| `introduction` | string | 自己紹介 |
| `enthusiasm` | string | 授業への熱意 |
| `lesson_contents` | string | 授業内容 |
| `tags` | `{id, name}[]` | スキルタグ |
| `image.url` | string | プロフィール画像 |
| `total_rating` | number | 総合評価スコア |
| `rating_count` | number | 評価数 |
| `origin_prefecture_name` | string | 出身都道府県 |
| `residence_prefecture_name` | string | 居住都道府県 |
| `is_public` | boolean | 公開フラグ |
| `is_limited_public` | boolean | 限定公開フラグ |
| `can_interview` | boolean | 面談可否 |
| `is_imprisonment` | boolean | 法人格確認フラグ |
| `is_reward` | boolean | 謝礼受取フラグ |
| `is_invoice_operator` | boolean | インボイス事業者フラグ |
| `invoice_registration_number` | string | インボイス登録番号 |
| `websites` | `{title, url}[]` | Webサイト一覧 |
| `teaching_licenses` | `{name, special_subject}[]` | 教員免許 |
| `videos` | `{key, file.url}[]` | 紹介動画 |

### ② 学校教員（SchoolTeacher）

ソース: `src/api/api/v1/school_teacher_profiles/`, `src/store/SchoolAuthStore.ts`

| フィールド | 型 | 概要 |
|-----------|---|------|
| `school_teacher_id` / `id` | number | 学校教員ID |
| `name` | string | 氏名 |
| `kana_name` | string | カナ氏名 |
| `school_name` | string | 学校名 |
| `school_code` | string | 学校コード |
| `school_prefecture_name` | string | 都道府県名 |
| `school_division_name` | string | 学校区分名（公立/私立等） |
| `school_type_name` | string | 学校種別（中学/高校等） |
| `school_address` | string | 学校住所 |
| `manage_grade` | string | 担当学年 |
| `manage_subject` | string | 担当教科 |
| `school_job` | string | 役職 |
| `phone_number` | string | 電話番号 |
| `image.url` | string | プロフィール画像 |
| `is_public` | boolean | 公開フラグ |
| `is_match_accepted` | boolean | マッチング受諾フラグ |
| `is_school_admin` | boolean | 管理者フラグ |
| `is_temporary_password` | boolean | 仮パスワードフラグ |
| `is_mail_magazine` | boolean | メールマガジン受信フラグ |

### ③ 授業（Lesson）

ソース: `src/api/api/v1/lessons/`, `src/types/lessonTypes.ts`

| フィールド | 型 | 概要 |
|-----------|---|------|
| `lesson_id` | number | 授業ID |
| `title` | string | 授業タイトル |
| `exact_start_at` | string | 開始日時 |
| `is_online` | boolean | オンライン授業フラグ |
| `lesson_count` | number | 授業コマ数 |
| `lesson_per_minutes` | number | 1コマの時間（分） |
| `school_grades` | `{id, name}[]` | 対象学年 |
| `timelines` | `{timeline_id, title, minutes}[]` | 授業タイムライン |
| `teacher` | `{teacher_id, name, image}` | 担当先生 |
| `lesson_slides` | スライドオブジェクト[] | 授業スライド |

### ④ 授業管理（LessonManager）

ソース: `src/api/api/v1/lesson_managers/`

| フィールド | 型 | 概要 |
|-----------|---|------|
| `id` | number | 授業管理ID |
| `title` | string | タイトル |
| `school_grades` | `{id, name}[]` | 対象学年 |
| `student_number` | number | 生徒数 |
| `student_condition` | string | 生徒の状況 |
| `issue` | string | 課題・テーマ |
| `lesson_requests` | 授業依頼オブジェクト[] | 直接依頼リスト |
| `lesson_recruitments` | 授業募集オブジェクト[] | 募集リスト |
| `lessons` | 授業オブジェクト[] | 確定授業リスト |

### ⑤ 授業募集（LessonRecruitment）

ソース: `src/api/api/v1/lesson_recruitments/`

| フィールド | 型 | 概要 |
|-----------|---|------|
| `id` | number | 募集ID |
| `title` | string | 募集タイトル |
| `lesson_contents` | string | 授業内容詳細 |
| `is_online` | boolean | オンライン可否 |
| `is_flexible` | boolean | 日程柔軟対応可否 |
| `travel_cost` | string | 交通費扱い |
| `lesson_count` | number | コマ数 |
| `lesson_per_minutes` | number | 時間（分） |
| `want_to` | string | 実現したいこと |
| `recruitment_dead_at` | string | 募集締切日時 |
| `school_grade_name` | string | 対象学年名 |
| `step` | string | 募集ステータス |
| `proposed_dates` | `{id, is_selected, start_at_datetime, end_at_datetime}[]` | 候補日程 |
| `tags` | `{id, name, sort, is_matched}[]` | タグ（マッチ済みフラグ付き） |

### ⑥ 授業依頼（LessonRequest）

| フィールド | 型 | 概要 |
|-----------|---|------|
| `id` | number | 依頼ID |
| `is_online` | boolean | オンライン可否 |
| `travel_cost` | string | 交通費 |
| `lesson_count` | number | コマ数 |
| `lesson_per_minutes` | number | 時間（分） |
| `accept_dead_at` | string | 受諾期限 |
| `possible_dates` | string[] | 可能日程 |
| `destinations` | 送信先（先生）情報[] | 依頼送信先リスト |

### ⑦ チケットグループ（TicketGroup / 教育委員会）

- ソース: `src/api/api/v1/ticket_groups/`
- **key 認証**（ログイン不要）でアクセス可能
- 教育委員会ダッシュボード専用

### 状態管理（Jotai atoms）

| ストアファイル | 管理対象 |
|-------------|---------|
| `store/AuthStore.ts` | `currentUserAtom`（先生ユーザー）, `isLoggedInAtom` |
| `store/SchoolAuthStore.ts` | `currentSchoolAtom`（学校教員）, `schoolIsLoggedInAtom` |
| `store/MasterData.ts` | マスタデータ（タグ、都道府県等） |
| `store/FavoriteTeachersStore.ts` | お気に入り先生リスト |
| `store/TicketStore.ts` | チケット情報 |

---

## ページ構成・ルーティング

### ルーティング制御コンポーネント（4種類）

| コンポーネント | 用途 |
|-------------|------|
| `PrivateRoute` | 複業先生（teacher）ログイン必須 |
| `GuestRoute` | 複業先生向けゲスト専用（ログイン済みはリダイレクト） |
| `SchoolPrivateRoute` | 学校教員ログイン必須 |
| `SchoolGuestRoute` | 学校教員向けゲスト専用 |
| `SchoolAdminRoute` | 学校管理者専用（`is_school_admin` フラグ + サーバーサイド確認） |

### 認証ガード制御フロー

**PrivateRoute（複業先生）**:
1. 学校ログイン済み → `/login?tab_name=school` へリダイレクト
2. 未ログイン → `/login?tab_name=teacher` へリダイレクト
3. プロフィール未作成 → `/teachers/profile/to-new` へリダイレクト
4. `is_imprisonment` 未確認 → `/teachers/imprisonment` へリダイレクト
5. インボイス未登録（terms 未同意） → `/teachers/invoice_operator` へリダイレクト

**SchoolPrivateRoute（学校教員）**:
1. 先生ログイン済み → `/login?tab_name=school` へリダイレクト
2. 未ログイン → `/login?tab_name=school` へリダイレクト
3. プロフィール未作成 → `/schools/profile/to-new` へリダイレクト
4. 仮パスワード → `/schools/update-temporary-password` へリダイレクト

**SchoolAdminRoute（学校管理者）**: `currentSchool.is_school_admin` + `master_schools` API 二重チェック

### 全ページ一覧

#### 共通（認証不要）

| パス | コンポーネント | 概要 |
|-----|-------------|------|
| `/` | `Home` | トップページ |
| `/login` | `Login` | 共通ログイン（`?tab_name=teacher/school`） |
| `/signup` | `Signup` | 共通サインアップ |
| `/privacy` | `Privacy` | プライバシーポリシー |
| `/contact` | `Contact` | お問い合わせフォーム |
| `/contact/complete` | `ContactComplete` | お問い合わせ完了 |
| `/lp/school` | `SchoolHome` | 学校向けLP |
| `/lp/classi` | `LPClassi` | Classi連携LP |
| `/not-found` | `NotFound` | 404ページ |

#### 授業関連（共通・認証不要）

| パス | コンポーネント | 概要 |
|-----|-------------|------|
| `/lessons/:id/student_before_questionnaires/new` | `StudentBeforeQuestionnaire` | 生徒向け事前アンケート |
| `/lessons/:id/student_before_questionnaires/complete` | `SendedBeforeQuestionnaires` | 事前アンケート完了 |
| `/lessons/:id/student_after_questionnaires/new` | `StudentAfterQuestionnaire` | 生徒向け事後アンケート |
| `/lessons/:id/student_after_questionnaires/complete` | `SendedAfterQuestionnaires` | 事後アンケート完了 |

#### 授業募集・教育委員会

| パス | ガード | 概要 |
|-----|--------|------|
| `/recruitments` | なし | 授業募集一覧 |
| `/recruitments/:id` | PrivateRoute | 授業募集詳細 |
| `/lesson-creation-tips` | PrivateRoute | 授業スライド一覧 |
| `/past-lesson-examples` | SchoolPrivateRoute | 過去授業事例一覧 |
| `/recruitment-examples/:id` | SchoolPrivateRoute | 過去授業事例詳細 |
| `/ticket-groups/:ticketGroupId/dashboard` | なし（key認証） | 教育委員会ダッシュボード |

#### 複業先生（/teachers/*）— 主要ページ

| パス | ガード | 概要 |
|-----|--------|------|
| `/teachers` | なし | 先生一覧 |
| `/teachers/ai-search` | なし | AI先生検索 |
| `/teachers/:id` | なし | 先生詳細プロフィール |
| `/teachers/:id/ratings` | なし | 先生評価一覧 |
| `/teachers/mypage` | PrivateRoute | 先生マイページトップ |
| `/teachers/mypage/lessons` | PrivateRoute | 授業一覧 |
| `/teachers/mypage/lessons/:id` | PrivateRoute | 授業詳細 |
| `/teachers/mypage/lessons/:id/agenda` | PrivateRoute | ミーティングシート |
| `/teachers/mypage/lessons/:id/after-lesson-survey` | PrivateRoute | 授業後アンケート |
| `/teachers/mypage/lessons/:id/lesson-report` | PrivateRoute | 授業報告書 |
| `/teachers/mypage/recruitments` | PrivateRoute | 応募中募集一覧 |
| `/teachers/profile/new` | PrivateRoute | プロフィール作成 |
| `/teachers/profile/edit` | PrivateRoute | プロフィール編集 |
| `/teachers/imprisonment` | PrivateRoute | 法人格確認 |
| `/teachers/invoice_operator` | PrivateRoute | インボイス事業者登録 |
| `/teachers/mypage/settings` | PrivateRoute | 設定 |

#### 学校教員（/schools/*）— 主要ページ

| パス | ガード | 概要 |
|-----|--------|------|
| `/schools/mypage` | SchoolPrivateRoute | マイページトップ |
| `/schools/mypage/lessons` | SchoolPrivateRoute | 授業一覧 |
| `/schools/mypage/lessons/:id` | SchoolPrivateRoute | 授業詳細 |
| `/schools/mypage/lessons/:id/ratings/new` | SchoolPrivateRoute | 授業評価入力 |
| `/schools/mypage/lesson-managers/new` | SchoolPrivateRoute | 授業管理新規作成 |
| `/schools/mypage/lesson-managers/:id` | SchoolPrivateRoute | 授業管理詳細 |
| `/schools/mypage/recruitments` | SchoolPrivateRoute | 授業募集一覧 |
| `/schools/mypage/recruitments/new` | SchoolPrivateRoute | 授業募集新規作成 |
| `/schools/mypage/ai-teaching-plan/new` | SchoolPrivateRoute | AI授業計画作成 |
| `/schools/mypage/favorite-teachers` | SchoolPrivateRoute | お気に入り先生一覧 |
| `/schools/profile/new` | SchoolPrivateRoute | プロフィール作成 |
| `/schools/profile/edit` | SchoolPrivateRoute | プロフィール編集 |

#### 学校管理者（/school_admin/*）

| パス | 概要 |
|-----|------|
| `/school_admin` | 管理者トップ |
| `/school_admin/school_teachers` | 教員一覧 |
| `/school_admin/school_teachers/new` | 教員追加 |
| `/school_admin/school_teachers/approvals` | 教員承認一覧 |
| `/school_admin/settings` | 管理者設定 |

---

## テスト

### テストフレームワーク

| 種別 | フレームワーク | 備考 |
|------|-------------|------|
| ユニットテスト | Jest（react-scripts 経由） | `@testing-library/react` v14.2.1 |
| E2Eテスト | Playwright v1.56.0 | GitHub Actions CI で実行 |

### テスト実行スクリプト

```bash
# ユニットテスト
yarn test
# → NODE_OPTIONS='--openssl-legacy-provider' react-scripts test

# E2Eテスト
yarn playwright test src/test/e2e/tests/
```

### テストディレクトリ構成

```
src/test/
├── unit/
│   └── text.test.ts        # ユニットテスト（1件のみ）
├── e2e/
│   ├── auth.setup.ts       # 認証セットアップ
│   ├── seed.spec.ts        # シードデータ投入
│   ├── .auth/
│   │   ├── teacher.json    # 先生認証状態保存
│   │   └── school.json     # 学校認証状態保存
│   ├── tests/
│   │   ├── teacher/        # 先生向け E2E（login, lessons, recruitments 等）
│   │   └── school/         # 学校向け E2E（login, lessons, lessonManagers 等）
│   ├── pages/              # Page Object Model
│   ├── functions/          # テストユーティリティ
│   └── utils/              # 共通ユーティリティ
└── README.md
```

### Playwright 設定

- `baseURL`: `http://localhost:8000`
- `fullyParallel`: true
- `retries`: CI=2, local=0
- `workers`: CI=1（逐次実行）, local=default
- `timeout`: CI=60000ms, local=30000ms
- `locale`: `ja-JP`, `timezoneId`: `Asia/Tokyo`
- **skip-ci ラベル**で CI スキップ可能

---

## 開発環境

### 主要 npm scripts

| コマンド | 説明 |
|---------|------|
| `yarn start` | 開発サーバー起動（`http://localhost:8000`） |
| `yarn build` | 本番ビルド（`build/` に出力） |
| `yarn test` | ユニットテスト実行（Jest、watch モード） |
| `yarn lint` | ESLint チェック |
| `yarn lint:fix` | ESLint 自動修正 |
| `yarn format` | Prettier フォーマット |
| `yarn api:build` | OpenAPI → aspida 型生成（APIリポジトリの `openapi.yml` 使用） |
| `yarn storybook` | Storybook 開発サーバー起動（port 6006） |
| `yarn build-storybook` | Storybook 静的ビルド |
| `yarn knip` | 未使用ファイル・エクスポート検出 |

### lint/format 設定

**ESLint** (`.eslintrc.cjs`):
- extends: `plugin:react/recommended`, `airbnb`, `airbnb-typescript`, `prettier`, `plugin:storybook/recommended`
- `noImplicitAny` 系ルールは無効化（`any` 許容）
- pre-commit: ESLint fix → Prettier write → `tsc --noEmit`

**Prettier** (`.prettierrc`):
```json
{ "semi": true, "trailingComma": "none" }
```

### TypeScript 設定

- `target`: es5
- `strict`: true（ただし `noImplicitAny`: false）
- `baseUrl`: `src`（絶対パス import 対応）
- `jsx`: `react-jsx`
- `moduleResolution`: `bundler`

---

## デプロイ

### ビルド・デプロイ手順

```bash
# ローカルビルド確認
yarn build
# → NODE_OPTIONS='--openssl-legacy-provider --max-old-space-size=4096' PORT=8000 react-scripts build
# 出力先: build/
```

### インフラ構成

- **デプロイ先**: AWS Elastic Beanstalk（ECS + ECR）
- **Docker**: マルチステージビルド（`node:24` → `nginx:alpine`）
- **CI/CD**: GitHub Actions（E2E） + AWS CodeBuild（本番デプロイ）

### ECR リポジトリ

| 環境 | リポジトリ名 |
|-----|-----------|
| 本番 | `production-fukugyo-sensei-front` |
| プール（ステージング） | `pool-fukugyo-sensei-front` |

リージョン: `ap-northeast-1`（東京）

### 環境変数一覧（キー名のみ）

#### ローカル開発用（`.env`）

| キー | 用途 |
|-----|------|
| `REACT_APP_BUILD_ENV` | ビルド環境識別 |
| `REACT_APP_API_URL` | API ベース URL |
| `REACT_APP_HOST` | フロントエンドホスト |
| `REACT_APP_OPEN_AI_API_KEY` | OpenAI API キー |
| `TZ` | タイムゾーン |

#### 本番・プール環境（buildspec で注入）

| キー | 用途 |
|-----|------|
| `REACT_APP_GA_TAG_ID` | Google Analytics |
| `REACT_APP_GTM_ID` | Google Tag Manager |
| `REACT_APP_TRUSTDOCK_URL` | TrustDock URL |
| `REACT_APP_TRUSTDOCK_PLAN_ID` | TrustDock プラン ID |

#### GitHub Actions Secrets（E2E CI）

- `REACT_APP_BUILD_ENV`, `REACT_APP_API_URL`, `REACT_APP_HOST`, `REACT_APP_OPEN_AI_API_KEY`
- `API_REPO_SSH_KEY`（API リポジトリ SSH 鍵）
- `MASTER_KEY`, `DEVELOPMENT_KEY`, `PRODUCTION_KEY`, `STAGING_KEY`, `TEST_KEY`（Rails credentials）

---

## 注意事項（既存 CLAUDE.md より抜粋）

1. **`useAspidaSWR` の正しい使用法**: `default import` を使うこと（named import は誤り）
2. **`CommonLayout` の使用法**: `isLoading` を props で渡すこと
3. **型不整合対応**: 型が合わない場合は `fukugyo-sensei-api` 側を修正してから `yarn api:build` で再生成
4. **Storybook は atoms/molecules 全件必須**: 新規コンポーネント追加時は必ず Storybook も作成
5. **既存コンポーネント最大活用**: 新規作成前に `src/components/` を必ず確認
6. **PR ラベル `skip-ci`**: CI スキップが必要な場合に使用
7. **Playwright MCP**: コード実行禁止。MCP ツールの直接呼び出しのみ許可
8. **Node.js バージョン乖離**: CLAUDE.md は v20.10.0 推奨だが Volta 設定は v24.11.1。実際は v24 系で動作
9. **API 型生成**: バックエンド変更後は必ず `yarn api:build` を実行
