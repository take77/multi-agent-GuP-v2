# Web アニメーション パターンカタログ — カテゴリ 1-2 ドラフト

> **担当**: hana (五十鈴華)
> **カテゴリ**: ページ遷移アニメーション + ナビゲーション
> **技術スタック**: React 19 + Next.js App Router + Tailwind CSS v4
> **制約**: framer-motion 不使用（CSS + React state のみ）

---

## カテゴリ 1: ページ遷移アニメーション

---

### 1-1. フェードイン / フェードアウト（ページ全体）

**カテゴリ**: ページ遷移アニメーション
**難易度**: 低
**使用頻度**: ★★★★★

#### 概要

ページ遷移時にコンテンツ全体をフェードイン/アウトさせる、もっとも基本的な遷移アニメーション。
視覚的な「切り替わり感」を和らげ、ユーザーにスムーズな印象を与える。
Next.js App Router の `layout.tsx` に配置し、ルート変更を検知して自動的にアニメーションを実行する。

#### 実装コード

```tsx
// src/components/common/PageTransition.tsx
"use client";

import { usePathname } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";

interface PageTransitionProps {
  children: ReactNode;
  /** フェード時間（ms） */
  duration?: number;
}

export function PageTransition({
  children,
  duration = 300,
}: PageTransitionProps) {
  const pathname = usePathname();
  const [isVisible, setIsVisible] = useState(true);
  const [displayChildren, setDisplayChildren] = useState(children);

  useEffect(() => {
    // パスが変わったらフェードアウト → children 差し替え → フェードイン
    setIsVisible(false);
    const timeout = setTimeout(() => {
      setDisplayChildren(children);
      setIsVisible(true);
    }, duration);
    return () => clearTimeout(timeout);
  }, [pathname]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div
      className="page-transition"
      style={{
        opacity: isVisible ? 1 : 0,
        transition: `opacity ${duration}ms ease-in-out`,
      }}
    >
      {displayChildren}
    </div>
  );
}
```

```tsx
// src/app/layout.tsx での使用例
import { PageTransition } from "@/components/common/PageTransition";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ja">
      <body>
        <Header />
        <PageTransition>{children}</PageTransition>
        <Footer />
      </body>
    </html>
  );
}
```

#### CSS（必要な場合）

```css
/* prefers-reduced-motion 対応 */
@media (prefers-reduced-motion: reduce) {
  .page-transition {
    transition: none !important;
    opacity: 1 !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` の `{children}` を `<PageTransition>` で wrap する
- **カスタマイズポイント**:
  - `duration`: フェード時間を調整（デフォルト 300ms。200〜500ms が自然）
  - `ease-in-out` を `ease` や `cubic-bezier()` に変更して緩急を調整

#### 注意点

- **パフォーマンス**: `opacity` のみの変更なのでレイヤー合成のみで完結し、リフロー・リペイントは発生しない。非常に軽量
- **アクセシビリティ**: `prefers-reduced-motion: reduce` 時はアニメーションを無効化すること（上記 CSS 参照）
- **初回レンダリング**: 初回ロード時はフェードインのみ（フェードアウト対象がないため自然に見える）
- **SEO**: コンテンツは DOM 上に存在するため、検索エンジンへの影響なし

---

### 1-2. スライドイン（方向付き遷移）

**カテゴリ**: ページ遷移アニメーション
**難易度**: 中
**使用頻度**: ★★★★☆

#### 概要

ページ遷移時にコンテンツが指定方向（左右・上下）からスライドして現れるアニメーション。
「進む」→ 左からスライドイン、「戻る」→ 右からスライドインのように方向性を持たせることで、
ユーザーにナビゲーションの階層感覚を伝えることができる。

#### 実装コード

```tsx
// src/components/common/SlideTransition.tsx
"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";

type Direction = "left" | "right" | "up" | "down";

interface SlideTransitionProps {
  children: ReactNode;
  /** スライド方向 */
  direction?: Direction;
  /** アニメーション時間（ms） */
  duration?: number;
  /** スライド距離（px） */
  distance?: number;
}

const getTranslate = (direction: Direction, distance: number) => {
  const map: Record<Direction, string> = {
    left: `translateX(-${distance}px)`,
    right: `translateX(${distance}px)`,
    up: `translateY(-${distance}px)`,
    down: `translateY(${distance}px)`,
  };
  return map[direction];
};

export function SlideTransition({
  children,
  direction = "right",
  duration = 400,
  distance = 30,
}: SlideTransitionProps) {
  const pathname = usePathname();
  const [phase, setPhase] = useState<"visible" | "hidden">("visible");
  const [displayChildren, setDisplayChildren] = useState(children);
  const isFirstRender = useRef(true);

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }

    setPhase("hidden");
    const timeout = setTimeout(() => {
      setDisplayChildren(children);
      // 次フレームでvisibleに切り替え（CSSトランジションを発火させる）
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setPhase("visible");
        });
      });
    }, duration);

    return () => clearTimeout(timeout);
  }, [pathname]); // eslint-disable-line react-hooks/exhaustive-deps

  const isHidden = phase === "hidden";

  return (
    <div
      className="slide-transition"
      style={{
        transform: isHidden ? getTranslate(direction, distance) : "translateX(0)",
        opacity: isHidden ? 0 : 1,
        transition: `transform ${duration}ms ease-out, opacity ${duration}ms ease-out`,
      }}
    >
      {displayChildren}
    </div>
  );
}
```

#### CSS（必要な場合）

```css
/* prefers-reduced-motion 対応: スライドを無効化しフェードのみに */
@media (prefers-reduced-motion: reduce) {
  .slide-transition {
    transform: none !important;
    transition: opacity 200ms ease-in-out !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` で `<PageTransition>` の代わりに使用
- **カスタマイズポイント**:
  - `direction`: スライド方向。ナビゲーション階層に合わせて動的に変更可能
  - `distance`: スライド距離。小さい値（20-30px）で上品に、大きい値（80-100px）でダイナミックに
  - `duration`: 300〜500ms が自然。速すぎると目が追いつかず、遅すぎると待たされる感覚になる

#### 注意点

- **パフォーマンス**: `transform` と `opacity` のみ使用。GPU 合成レイヤーで処理されるため、60fps を維持可能
- **アクセシビリティ**: `prefers-reduced-motion` 時は `transform` を無効化し、`opacity` のみのフェードにフォールバック
- **オーバーフロー**: スライド中にコンテンツが画面外にはみ出す場合、親要素に `overflow: hidden` を検討
- **ヒストリ連携**: ブラウザの戻る/進むと direction を連動させると直感的（`popstate` イベント監視が必要）

---

### 1-3. クロスフェード（View Transitions API）

**カテゴリ**: ページ遷移アニメーション
**難易度**: 中
**使用頻度**: ★★★★☆

#### 概要

旧コンテンツと新コンテンツが同時に表示され、旧がフェードアウトしながら新がフェードインする「クロスフェード」。
View Transitions API を利用することで、ブラウザネイティブのスムーズな遷移を実現する。
Next.js では `next-view-transitions` パッケージが簡便に使える。

#### 実装コード

```tsx
// src/app/layout.tsx
// next-view-transitions を使用する場合
import { ViewTransitions } from "next-view-transitions";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ViewTransitions>
      <html lang="ja">
        <body>
          <Header />
          <main>{children}</main>
          <Footer />
        </body>
      </html>
    </ViewTransitions>
  );
}
```

```tsx
// リンクは next-view-transitions の Link を使用
import { Link } from "next-view-transitions";

export function Navigation() {
  return (
    <nav>
      <Link href="/">ホーム</Link>
      <Link href="/about">会社概要</Link>
      <Link href="/works">施工事例</Link>
    </nav>
  );
}
```

#### CSS（必要な場合）

```css
/* View Transitions API のクロスフェードカスタマイズ */

/* デフォルトのクロスフェード時間を調整 */
::view-transition-old(root) {
  animation: fade-out 300ms ease-in-out;
}

::view-transition-new(root) {
  animation: fade-in 300ms ease-in-out;
}

@keyframes fade-out {
  from { opacity: 1; }
  to   { opacity: 0; }
}

@keyframes fade-in {
  from { opacity: 0; }
  to   { opacity: 1; }
}

/* 特定要素のみ独立した遷移を持たせる（共有要素遷移） */
.hero-image {
  view-transition-name: hero-image;
}

::view-transition-old(hero-image) {
  animation: slide-out-left 400ms ease-in-out;
}

::view-transition-new(hero-image) {
  animation: slide-in-right 400ms ease-in-out;
}

@keyframes slide-out-left {
  to { transform: translateX(-100%); opacity: 0; }
}

@keyframes slide-in-right {
  from { transform: translateX(100%); opacity: 0; }
}

/* prefers-reduced-motion 対応 */
@media (prefers-reduced-motion: reduce) {
  ::view-transition-old(root),
  ::view-transition-new(root),
  ::view-transition-old(hero-image),
  ::view-transition-new(hero-image) {
    animation-duration: 0s !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` のルートを `<ViewTransitions>` で wrap
- **リンク**: `next/link` の代わりに `next-view-transitions` の `Link` を使用（遷移のフックに必要）
- **カスタマイズポイント**:
  - `::view-transition-old` / `::view-transition-new` 擬似要素でアニメーションを細かく制御
  - `view-transition-name` を要素に付与して「共有要素遷移」（Shared Element Transition）を実現
  - 遷移時間は 300〜500ms が最適

#### 注意点

- **ブラウザ対応**: View Transitions API は Chrome 111+ / Edge 111+ で対応。Safari は 18.0+。Firefox は未対応（2026年3月時点）
- **フォールバック**: 非対応ブラウザでは遷移アニメーションなしの通常ナビゲーションになる（機能的には問題なし）
- **パッケージ依存**: `next-view-transitions` は軽量（~2KB gzip）で、framer-motion（~30KB）と比べ負荷は極めて小さい
- **アクセシビリティ**: `prefers-reduced-motion` 時はアニメーション時間を 0s に設定
- **SSR 互換**: View Transitions API はクライアントサイドのみ。SSR に影響なし
- **view-transition-name の一意性**: 同一ページ内で `view-transition-name` が重複するとエラー。動的に生成する場合は ID を含めること

---

## カテゴリ 2: ナビゲーション

---

### 2-1. Sticky/Fixed ヘッダー（スクロール時の背景変化）

**カテゴリ**: ナビゲーション
**難易度**: 低
**使用頻度**: ★★★★★

#### 概要

ページ上部に固定されたヘッダーが、スクロール位置に応じて背景色・影・高さを変化させるパターン。
ファーストビューでは透明な背景、スクロール開始後は白背景＋シャドウで視認性を確保する。
コーポレートサイトやHP案件でもっとも多用されるナビゲーションパターン。

#### 実装コード

```tsx
// src/components/common/StickyHeader.tsx
"use client";

import { useEffect, useState } from "react";

interface StickyHeaderProps {
  children: React.ReactNode;
  /** スクロール何pxで背景を切り替えるか */
  threshold?: number;
}

export function StickyHeader({
  children,
  threshold = 50,
}: StickyHeaderProps) {
  const [isScrolled, setIsScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > threshold);
    };

    // パッシブリスナーでパフォーマンス最適化
    window.addEventListener("scroll", handleScroll, { passive: true });
    // 初期状態の反映（リロード時にスクロール位置が復元される場合）
    handleScroll();

    return () => window.removeEventListener("scroll", handleScroll);
  }, [threshold]);

  return (
    <header
      className={`
        fixed top-0 left-0 right-0 z-50
        transition-all duration-300 ease-in-out
        ${
          isScrolled
            ? "bg-white/95 shadow-md backdrop-blur-sm py-3"
            : "bg-transparent py-5"
        }
      `}
    >
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {children}
      </div>
    </header>
  );
}
```

```tsx
// 使用例
import { StickyHeader } from "@/components/common/StickyHeader";

export function Header() {
  return (
    <StickyHeader threshold={80}>
      <nav className="flex items-center justify-between">
        <a href="/" className="text-xl font-bold">
          ロゴ
        </a>
        <ul className="hidden md:flex gap-8">
          <li><a href="/about">会社概要</a></li>
          <li><a href="/works">施工事例</a></li>
          <li><a href="/contact">お問い合わせ</a></li>
        </ul>
      </nav>
    </StickyHeader>
  );
}
```

#### CSS（必要な場合）

```css
/* Tailwind v4 で backdrop-blur が効かない環境向けフォールバック */
@supports not (backdrop-filter: blur(8px)) {
  .sticky-header-scrolled {
    background-color: rgba(255, 255, 255, 0.98);
  }
}

/* prefers-reduced-motion 対応 */
@media (prefers-reduced-motion: reduce) {
  header {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` の `<body>` 直下、`<main>` の前
- **カスタマイズポイント**:
  - `threshold`: 背景切り替えのスクロール位置。ファーストビューの高さに合わせて調整
  - 透明→白の代わりに、`bg-primary/90` → `bg-primary` のように色味を変えても良い
  - `py-5` → `py-3` の変化で「高さが縮む」効果を演出
  - テキスト色の切り替え: `isScrolled` で `text-white` → `text-gray-900` に連動させる

#### 注意点

- **パフォーマンス**: `passive: true` のスクロールリスナーを使用。`requestAnimationFrame` でのスロットリングは `useState` の batching で不要（React 18+）
- **アクセシビリティ**: `prefers-reduced-motion` 時は `transition: none` に。固定ヘッダー自体はアクセシビリティ上問題なし
- **z-index**: `z-50` を使用。モーダルやドロワーの z-index と競合しないよう注意（モーダルは `z-[60]` 以上を推奨）
- **main の padding-top**: `fixed` ヘッダーの場合、`<main>` に `pt-20`（ヘッダーの高さ分）を追加して重なりを防ぐ
- **ファーストビュー透過**: 背景画像のあるヒーローセクション上では透明ヘッダーが美しいが、テキストの視認性を確保するため `text-shadow` やグラデーションオーバーレイを検討

---

### 2-2. ハンバーガーメニュー（開閉アニメーション）

**カテゴリ**: ナビゲーション
**難易度**: 中
**使用頻度**: ★★★★★

#### 概要

モバイルビューで使用するハンバーガーアイコン（三本線）をタップすると、
メニューパネルがスライドインで表示されるパターン。
アイコン自体も三本線 → ✕ へのモーフィングアニメーションを行い、開閉状態を視覚的に伝える。

#### 実装コード

```tsx
// src/components/common/HamburgerButton.tsx
"use client";

interface HamburgerButtonProps {
  isOpen: boolean;
  onClick: () => void;
}

export function HamburgerButton({ isOpen, onClick }: HamburgerButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="relative z-50 flex h-10 w-10 flex-col items-center justify-center gap-1.5 md:hidden"
      aria-expanded={isOpen}
      aria-label={isOpen ? "メニューを閉じる" : "メニューを開く"}
    >
      {/* 上の線 */}
      <span
        className={`
          block h-0.5 w-6 bg-current
          transition-all duration-300 ease-in-out origin-center
          ${isOpen ? "translate-y-2 rotate-45" : ""}
        `}
      />
      {/* 中の線 */}
      <span
        className={`
          block h-0.5 w-6 bg-current
          transition-all duration-300 ease-in-out
          ${isOpen ? "scale-x-0 opacity-0" : ""}
        `}
      />
      {/* 下の線 */}
      <span
        className={`
          block h-0.5 w-6 bg-current
          transition-all duration-300 ease-in-out origin-center
          ${isOpen ? "-translate-y-2 -rotate-45" : ""}
        `}
      />
    </button>
  );
}
```

```tsx
// src/components/common/MobileMenu.tsx
"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { HamburgerButton } from "./HamburgerButton";

interface MenuItem {
  label: string;
  href: string;
}

interface MobileMenuProps {
  items: MenuItem[];
}

export function MobileMenu({ items }: MobileMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const pathname = usePathname();

  // ルート変更時に自動で閉じる
  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  // メニューが開いているときはスクロールを抑止
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [isOpen]);

  return (
    <>
      <HamburgerButton isOpen={isOpen} onClick={() => setIsOpen(!isOpen)} />

      {/* オーバーレイ */}
      <div
        className={`
          fixed inset-0 z-40 bg-black/50
          transition-opacity duration-300
          ${isOpen ? "opacity-100" : "pointer-events-none opacity-0"}
        `}
        onClick={() => setIsOpen(false)}
        aria-hidden="true"
      />

      {/* メニューパネル */}
      <nav
        className={`
          fixed top-0 right-0 z-40 h-full w-72
          bg-white shadow-xl
          transition-transform duration-300 ease-in-out
          ${isOpen ? "translate-x-0" : "translate-x-full"}
        `}
        aria-label="モバイルメニュー"
      >
        <div className="flex flex-col gap-1 pt-20 px-6">
          {items.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className={`
                block rounded-lg px-4 py-3 text-lg
                transition-colors duration-200
                hover:bg-gray-100
                ${pathname === item.href ? "font-bold text-primary" : "text-gray-700"}
              `}
            >
              {item.label}
            </a>
          ))}
        </div>
      </nav>
    </>
  );
}
```

#### CSS（必要な場合）

```css
/* prefers-reduced-motion 対応 */
@media (prefers-reduced-motion: reduce) {
  /* ハンバーガーアイコンのモーフィング無効化 */
  .hamburger-line {
    transition: none !important;
  }

  /* メニューパネルのスライド無効化（即時表示/非表示） */
  nav[aria-label="モバイルメニュー"] {
    transition: none !important;
  }

  /* オーバーレイも即時切り替え */
  .menu-overlay {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: ヘッダーコンポーネント内。デスクトップメニューと並置し `md:hidden` で出し分け
- **カスタマイズポイント**:
  - スライド方向: `right-0` + `translate-x-full` → `left-0` + `-translate-x-full` で左から開く
  - メニュー幅: `w-72`（288px）を `w-80`（320px）や `w-full`（全画面）に変更
  - 背景色: `bg-white` をブランドカラーに変更可能
  - アイコンの線の太さ: `h-0.5`（2px）を `h-[3px]` に変更で太めに

#### 注意点

- **アクセシビリティ**:
  - `aria-expanded` でメニューの開閉状態を伝達
  - `aria-label` で「メニューを開く/閉じる」を明示
  - キーボード操作: `Escape` キーでメニューを閉じる処理を追加すること（下記参照）
  - フォーカストラップ: メニュー開放時、Tab キーのフォーカスがメニュー内に留まるようにする
- **スクロール抑止**: `document.body.style.overflow = "hidden"` でメニュー背面のスクロールを防止。iOS Safari では `-webkit-overflow-scrolling: touch` の問題があるため、`touch-action: none` も併用すると確実
- **パフォーマンス**: `transform` と `opacity` のみのアニメーションで 60fps を維持
- **Escape キー対応の追加例**:

```tsx
// MobileMenu 内に追加
useEffect(() => {
  const handleEscape = (e: KeyboardEvent) => {
    if (e.key === "Escape" && isOpen) {
      setIsOpen(false);
    }
  };
  document.addEventListener("keydown", handleEscape);
  return () => document.removeEventListener("keydown", handleEscape);
}, [isOpen]);
```

---

### 2-3. メガメニュー（ドロップダウン）

**カテゴリ**: ナビゲーション
**難易度**: 高
**使用頻度**: ★★★☆☆

#### 概要

デスクトップビューで、ナビゲーション項目にホバーまたはクリックすると、
画面幅いっぱい（またはコンテンツ幅いっぱい）のパネルがドロップダウンで展開されるパターン。
多くのサブページを持つコーポレートサイトやサービスサイトで、情報構造を一覧性高く提示するのに適する。

#### 実装コード

```tsx
// src/components/common/MegaMenu.tsx
"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

interface MegaMenuSection {
  title: string;
  items: { label: string; href: string; description?: string }[];
}

interface MegaMenuProps {
  /** トリガーとなるナビゲーションラベル */
  label: string;
  /** メガメニュー内のセクション */
  sections: MegaMenuSection[];
}

export function MegaMenu({ label, sections }: MegaMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>(null);

  // ホバー時の遅延開閉（意図しない開閉を防止）
  const handleMouseEnter = () => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    setIsOpen(true);
  };

  const handleMouseLeave = () => {
    timeoutRef.current = setTimeout(() => {
      setIsOpen(false);
    }, 150); // 150ms の猶予でメニューへの移動を許容
  };

  // クリック外で閉じる
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // Escape キーで閉じる
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") setIsOpen(false);
    };
    document.addEventListener("keydown", handleEscape);
    return () => document.removeEventListener("keydown", handleEscape);
  }, []);

  return (
    <div
      ref={menuRef}
      className="relative"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* トリガーボタン */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1 px-3 py-2 text-sm font-medium transition-colors hover:text-primary"
        aria-expanded={isOpen}
        aria-haspopup="true"
      >
        {label}
        <svg
          className={`h-4 w-4 transition-transform duration-200 ${isOpen ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {/* ドロップダウンパネル */}
      <div
        className={`
          absolute left-1/2 top-full z-50 w-screen max-w-4xl -translate-x-1/2
          rounded-b-xl bg-white shadow-xl ring-1 ring-black/5
          transition-all duration-200 ease-out origin-top
          ${
            isOpen
              ? "scale-y-100 opacity-100"
              : "pointer-events-none scale-y-95 opacity-0"
          }
        `}
        role="menu"
      >
        <div className="grid grid-cols-3 gap-8 p-8">
          {sections.map((section) => (
            <div key={section.title}>
              <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-gray-500">
                {section.title}
              </h3>
              <ul className="space-y-2">
                {section.items.map((item) => (
                  <li key={item.href}>
                    <a
                      href={item.href}
                      className="group block rounded-lg p-2 transition-colors hover:bg-gray-50"
                      role="menuitem"
                    >
                      <div className="text-sm font-medium text-gray-900 group-hover:text-primary">
                        {item.label}
                      </div>
                      {item.description && (
                        <div className="mt-0.5 text-xs text-gray-500">
                          {item.description}
                        </div>
                      )}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

```tsx
// 使用例
<MegaMenu
  label="サービス"
  sections={[
    {
      title: "施工",
      items: [
        { label: "新築工事", href: "/services/new-build", description: "注文住宅・建売住宅" },
        { label: "リフォーム", href: "/services/reform", description: "水回り・内装・外壁" },
        { label: "外構工事", href: "/services/exterior", description: "駐車場・フェンス・庭" },
      ],
    },
    {
      title: "設計",
      items: [
        { label: "建築設計", href: "/services/architecture" },
        { label: "耐震診断", href: "/services/seismic" },
      ],
    },
    {
      title: "サポート",
      items: [
        { label: "アフターサービス", href: "/support/after" },
        { label: "お見積もり", href: "/contact" },
      ],
    },
  ]}
/>
```

#### CSS（必要な場合）

```css
/* prefers-reduced-motion 対応 */
@media (prefers-reduced-motion: reduce) {
  /* パネルのスケール＋フェードを即時切り替えに */
  [role="menu"] {
    transition: none !important;
  }

  /* 矢印アイコンの回転も無効化 */
  svg {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: デスクトップ用ヘッダーナビゲーション内。各メニュー項目に対して使用
- **カスタマイズポイント**:
  - `grid-cols-3` をサブメニューの数に応じて `grid-cols-2` や `grid-cols-4` に変更
  - `max-w-4xl` でパネル幅を制御。`w-full` + `left-0`（`translate` なし）で完全な全幅パネルも可
  - ホバー遅延（150ms）を調整して開閉の感度を変更
  - 開閉アニメーション: `scale-y` → `translateY` に変更でスライドダウンに

#### 注意点

- **アクセシビリティ**:
  - `aria-expanded`, `aria-haspopup`, `role="menu"`, `role="menuitem"` を正しく設定
  - キーボードナビゲーション: `Enter`/`Space` で開閉、`Arrow Down`/`Arrow Up` で項目移動、`Escape` で閉じる、`Tab` でフォーカス移動
  - 完全な WAI-ARIA Menu パターン実装には `roving tabindex` が必要（上記コードは簡略版）
- **パフォーマンス**: `scale` + `opacity` のアニメーションで GPU 合成レイヤーを使用。重い DOM の場合でも滑らか
- **モバイル非表示**: メガメニューはデスクトップ専用。モバイルでは `md:hidden` で非表示にし、ハンバーガーメニュー（パターン 2-2）に切り替える
- **ホバー vs クリック**: ホバーで開くのがデスクトップの標準的な UX だが、タッチデバイスではクリック/タップが必要。`onMouseEnter` と `onClick` の両方をサポートすること
- **z-index 管理**: Sticky ヘッダー（z-50）の上に出す場合は z-50 以上が必要。ヘッダー内なので自然に含まれる

---

## まとめ

| # | パターン名 | カテゴリ | 難易度 | 使用頻度 | 依存 |
|---|-----------|---------|--------|---------|------|
| 1-1 | フェードイン/フェードアウト | ページ遷移 | 低 | ★★★★★ | なし |
| 1-2 | スライドイン（方向付き） | ページ遷移 | 中 | ★★★★☆ | なし |
| 1-3 | クロスフェード（View Transitions） | ページ遷移 | 中 | ★★★★☆ | next-view-transitions (~2KB) |
| 2-1 | Sticky/Fixed ヘッダー | ナビゲーション | 低 | ★★★★★ | なし |
| 2-2 | ハンバーガーメニュー | ナビゲーション | 中 | ★★★★★ | なし |
| 2-3 | メガメニュー | ナビゲーション | 高 | ★★★☆☆ | なし |

### 共通技術方針

- **CSS のみでアニメーション**: `transform`（translate, scale, rotate）と `opacity` を中心に使用。`will-change` は常時指定せず、必要時のみ
- **prefers-reduced-motion**: 全パターンで `@media (prefers-reduced-motion: reduce)` に対応。アニメーションを無効化またはフェードのみにフォールバック
- **framer-motion 不使用**: 外部依存を増やさず、CSS トランジション + React state で実現
- **Tailwind CSS v4 対応**: `transition-all`, `duration-300`, `ease-in-out` 等の v4 ユーティリティクラスを使用
