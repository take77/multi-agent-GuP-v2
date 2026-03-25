## 移行タスク追加手順（デザイン調整タスク限定）

**適用条件**: dev server が起動可能 **かつ** 移行元が存在するデザイン調整タスク。
初回実装でビルド未完了の段階では適用しない。

### ルール1: コードベース比較表の作成

修正着手前に移行元コンポーネントのスタイル定義を数値レベルで抽出し、移行先との1対1突き合わせ表を作成する。

- 対象: padding, margin, gap, font-size, line-height, カラーコード（hex/rgb）等
- 色味は必ず数値突き合わせ。「同じに見える」は不可
- 突き合わせ表は報告 YAML の `result.notes` に含める

例:
```
| 項目         | v1（移行元）      | v2（移行先）      | 状態 |
|------------|----------------|----------------|------|
| padding    | 24px           | py-[2.4rem]    | ✓   |
| 文字色      | #ffffff        | text-white     | ✓   |
| font-size  | 1.1rem         | text-[1.1rem]  | ✓   |
```

### ルール2: CSS 適用の実確認

CSS クラスを追加・変更した場合、「クラスを書いた」だけで完了とみなしてはならない。

- **「クラスを書いた」≠「適用されている」**
- Playwright 等で dev サーバーにアクセスし、目視で確認すること
- 特に注意が必要なケース:
  - `@layer` 外の CSS 宣言（unlayered CSS は Tailwind utilities より優先度が高い）
  - CSS 詳細度の競合（複数クラスが同一プロパティを上書きし合う）
  - グローバルリセット CSS による上書き（例: `a { color: inherit }` が link の text-white を無効化）

**失敗例（実際に発生）**:
- `globals.css` の `a { color: inherit }` が unlayered にあり、`text-white` を上書き → ボタン黒文字のまま
- `globals.css` の unlayered CSS により padding 全滅（2回発生）

### ルール3: スクショ証跡の添付

修正後、Playwright 等でスクショを撮影し、報告 YAML に必ずファイルパスを記載する。

- 口頭の「確認しました」は証跡として認めない
- チェック粒度: 移行先フレームワークの breakpoint に基づくビューポート
  - Tailwind → sm:640px / md:768px / lg:1024px
- 撮影コマンド例:
  ```bash
  npx playwright screenshot http://localhost:{PORT} /path/to/screenshot.png --full-page
  ```
- 報告 YAML に記載:
  ```yaml
  result:
    screenshot: "/home/take77/Pictures/Screenshots/screenshot-name.png"
  ```
- main マージ完了後に削除 OK
