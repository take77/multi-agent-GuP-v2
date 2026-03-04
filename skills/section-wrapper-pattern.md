# section-wrapper-pattern

## 概要

統一されたセクションレイアウトラッパーパターン。
複数のページセクションに対して一貫したmax-width・padding・縦余白を提供する2層構造のコンポーネント。

**スキル候補発見条件**: cmd_084（ポートフォリオサイト構築）で ServiceOverview / FeaturedWorks / AboutSection の3コンポーネントに同一パターンが適用されたことから抽出。

---

## 問題

複数セクションで `max-width` / `padding` / `margin` が個別に定義され、
コンテンツ幅がページ間でバラバラになる。

**典型的な症状:**
- セクションごとに `max-width: 1280px; margin: 0 auto;` が重複
- 水平paddingの値がコンポーネントごとに微妙に異なる（`px-8` / `px-10` / `px-12` のズレ）
- 全幅背景（背景色・背景画像）を使いたいとき、max-widthとの共存が難しい
- モバイル対応のpadding調整を各セクションで個別に行う必要がある

---

## 解決策

外側（`section`）で縦余白のみ、内側（`div`）でmax-width + 水平paddingのみを管理する
**2層構造のラッパーコンポーネント**を作成。

| レイヤー | 役割 | 管理するもの |
|---------|------|------------|
| 外側（`section`） | 縦リズム | `padding-top` / `padding-bottom` のみ |
| 内側（`div.section-inner`） | コンテンツ幅 | `max-width` + `margin: 0 auto` + 水平 `padding` |

この分離により、全幅背景が必要なセクションでも背景は外側に、コンテンツは内側に自然に収まる。

---

## 実装例

```astro
---
// src/components/common/SectionWrapper.astro
interface Props {
  class?: string;
  id?: string;
  as?: string;  // デフォルト 'section'。'div' や 'article' に変更可能
}
const { class: className, id, as: Tag = 'section' } = Astro.props;
---

<Tag id={id} class:list={["section-wrapper", className]}>
  <div class="section-inner">
    <slot />
  </div>
</Tag>

<style>
  /* ── 外側: 縦余白のみ ── */
  .section-wrapper {
    width: 100%;
    padding-top: 80px;
    padding-bottom: 80px;
  }

  /* ── 内側: max-width + 水平padding ── */
  .section-inner {
    max-width: 1280px;
    margin: 0 auto;
    padding-left: clamp(1.5rem, 6vw, 5rem);
    padding-right: clamp(1.5rem, 6vw, 5rem);
  }

  @media (max-width: 640px) {
    .section-wrapper {
      padding-top: 60px;
      padding-bottom: 60px;
    }
  }
</style>
```

**ポイント: `clamp()` による水平padding**

```css
padding-left: clamp(1.5rem, 6vw, 5rem);
```
- 最小値 `1.5rem`（モバイル）〜 最大値 `5rem`（ワイドデスクトップ）の間でビューポートに応じて自動調整
- メディアクエリなしで滑らかなレスポンシブ対応

---

## Props

| Prop | 型 | デフォルト | 説明 |
|------|-----|----------|------|
| `id` | `string` | `undefined` | セクションのID（アンカーリンク用）。例: `id="services"` |
| `class` | `string` | `undefined` | 追加CSSクラス（外側の `section` に適用） |
| `as` | `string` | `"section"` | レンダリングするHTML要素。`div` / `article` / `main` 等に変更可能 |

---

## 使い方

### 基本的な使い方（Astro）

```astro
---
import SectionWrapper from '../common/SectionWrapper.astro';
---

<SectionWrapper id="services">
  <h2>提供サービス</h2>
  <div class="services-grid">
    <!-- コンテンツ -->
  </div>
</SectionWrapper>
```

### 全幅背景が必要なセクション

外側（`.section-wrapper`）に背景を追加するだけでよい。コンテンツは自動的に内側に収まる。

```astro
<SectionWrapper id="hero" class="hero-bg">
  <h1>キャッチコピー</h1>
</SectionWrapper>

<style>
  /* 全幅背景はWrapperの外側クラスに適用 */
  .hero-bg {
    background: linear-gradient(135deg, #362742, #1a0f24);
  }
</style>
```

### React/Vue コンポーネントとの共存

Reactアイランド内に配置する場合は、JSX側では通常の `<section>` を使い、
SectionWrapperはAstroレイヤーで wrapping する。

```astro
---
import SectionWrapper from '../common/SectionWrapper.astro';
import ContactForm from './ContactForm.tsx';
---

<SectionWrapper id="contact">
  <!-- ReactアイランドはSectionWrapper内に配置するだけでよい -->
  <ContactForm client:visible />
</SectionWrapper>
```

---

## 適用判断基準

**適用すべき場合:**
- 3つ以上のセクションで同一の `max-width` / `padding` パターンが重複している
- 縦余白（セクション間のspace）を一元管理したい
- 全幅背景とコンテンツ幅制限を同時に使うセクションがある

**適用しなくていい場合:**
- 1〜2セクションのみ（抽象化のコストが見合わない）
- 各セクションで余白やmax-widthが大きく異なる（個別管理が明快）
- ページ全体が単一のコンテンツ幅で統一されている（body / main に1回設定すれば足りる）

---

## 注意事項

### ネスト禁止

SectionWrapper を入れ子にしてはならない。
内側の `.section-inner` が二重に `max-width` を適用し、コンテンツが過度に狭くなる。

```astro
<!-- ❌ 禁止 -->
<SectionWrapper>
  <SectionWrapper>  <!-- ネスト禁止 -->
    ...
  </SectionWrapper>
</SectionWrapper>

<!-- ✅ 正しい -->
<SectionWrapper>
  <div class="inner-layout">
    ...
  </div>
</SectionWrapper>
```

### レスポンシブ対応の拡張

縦余白をセクションごとにカスタマイズしたい場合は、`class` prop で上書きする。

```astro
<SectionWrapper class="py-hero">
  ...
</SectionWrapper>

<style>
  /* Tailwindではなくスコープスタイルで上書き */
  .section-wrapper.py-hero {
    padding-top: 120px;
    padding-bottom: 120px;
  }
</style>
```

### `as` prop の使い分け

| 用途 | 推奨タグ |
|------|---------|
| 通常のコンテンツセクション | `section`（デフォルト） |
| メインコンテンツ領域 | `main` |
| ヘッダー下の最初のセクション | `section`（`main` より意味的に軽い） |
| ページ内で記事的な内容 | `article` |
| レイアウト上の便宜的な区切り | `div` |

---

## 参考実装

- 参照先: `take77_port_v2/src/components/common/SectionWrapper.astro`
- 適用コンポーネント: `ServiceOverview.astro`, `FeaturedWorks.astro`, `AboutSection.astro`
- フレームワーク: Astro 5（`.astro` コンポーネント）
- 同等パターン: Vue の `<slot>` ラッパーコンポーネント、React の `SectionContainer` HOC でも同様に実装可能
