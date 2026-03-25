---
name: web-animation-patterns
description: HP案件で頻出するWebアニメーションパターン集。ページ遷移、ナビゲーション、ボタンホバー、スクロールトリガー、モーダル/アコーディオン等をTailwind CSS + Reactで実装。アニメーション実装時に参照。
---

# Web Animation Patterns

HP案件で再利用可能なWebアニメーションパターンカタログ。
React 19 + Next.js App Router + Tailwind CSS v4 で実装。外部ライブラリ依存なし（framer-motion 不使用）。

## Overview

全18パターンを5カテゴリに分類。各パターンはコピー&ペーストで即使用可能な完全な実装を提供する。

| # | パターン名 | カテゴリ | 難易度 | 使用頻度 | 依存 |
|---|-----------|---------|--------|---------|------|
| 1-1 | フェードイン/フェードアウト | ページ遷移 | 低 | ★★★★★ | なし |
| 1-2 | スライドイン（方向付き） | ページ遷移 | 中 | ★★★★☆ | なし |
| 1-3 | クロスフェード（View Transitions） | ページ遷移 | 中 | ★★★★☆ | next-view-transitions (~2KB) |
| 2-1 | Sticky/Fixed ヘッダー | ナビゲーション | 低 | ★★★★★ | なし |
| 2-2 | ハンバーガーメニュー | ナビゲーション | 中 | ★★★★★ | なし |
| 2-3 | メガメニュー | ナビゲーション | 高 | ★★★☆☆ | なし |
| 3-1 | 背景色スライド | ボタンホバー | 低 | ★★★★★ | Tailwind のみ |
| 3-2 | アンダーライン展開 | ボタンホバー | 低 | ★★★★★ | Tailwind のみ |
| 3-3 | リップルエフェクト | ボタンホバー | 中 | ★★★★☆ | React state + CSS keyframes |
| 4-1 | フェードイン（IO） | スクロールトリガー | 低 | ★★★★★ | Intersection Observer |
| 4-2 | パララックス | スクロールトリガー | 中 | ★★★☆☆ | CSS fixed / scroll event |
| 4-3 | プログレスバー | スクロールトリガー | 低 | ★★★★☆ | scroll event |
| 4-4 | カウントアップ | スクロールトリガー | 中 | ★★★★☆ | IO + rAF |
| 5-1 | アコーディオン | アコーディオン・モーダル | 中 | ★★★★★ | なし |
| 5-2 | モーダル / ダイアログ | アコーディオン・モーダル | 高 | ★★★★☆ | `<dialog>` |
| 5-3 | ドロワー | アコーディオン・モーダル | 中 | ★★★★☆ | `<dialog>` |
| 5-4 | ローディング / スケルトン | ユーティリティ | 低 | ★★★★★ | なし |
| 5-5 | トースト通知 | ユーティリティ | 中 | ★★★★☆ | なし |

## When to Use

- HP案件でアニメーション実装が必要なとき
- コーポレートサイト・LP のインタラクション設計時
- Tailwind CSS + React でアニメーションを実装する場面全般

---

## カテゴリ1: ページ遷移アニメーション

---

### 1-1. フェードイン / フェードアウト（ページ全体）

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

ページ遷移時にコンテンツ全体をフェードイン/アウトさせる、もっとも基本的な遷移アニメーション。
Next.js App Router の `layout.tsx` に配置し、ルート変更を検知して自動実行する。

#### 実装コード

```tsx
// src/components/common/PageTransition.tsx
"use client";

import { usePathname } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";

interface PageTransitionProps {
  children: ReactNode;
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

export default function RootLayout({ children }: { children: React.ReactNode }) {
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
@media (prefers-reduced-motion: reduce) {
  .page-transition {
    transition: none !important;
    opacity: 1 !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` の `{children}` を `<PageTransition>` で wrap
- **カスタマイズ**: `duration` で時間調整（200〜500ms が自然）

#### 注意点

- `opacity` のみの変更でリフロー不要。非常に軽量
- `prefers-reduced-motion: reduce` 時はアニメーション無効化
- 初回ロード時はフェードインのみ（フェードアウト対象がないため自然）

---

### 1-2. スライドイン（方向付き遷移）

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

ページ遷移時にコンテンツが指定方向からスライドして現れるアニメーション。
「進む」→ 左からスライドイン、「戻る」→ 右からスライドインで階層感を伝える。

#### 実装コード

```tsx
// src/components/common/SlideTransition.tsx
"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";

type Direction = "left" | "right" | "up" | "down";

interface SlideTransitionProps {
  children: ReactNode;
  direction?: Direction;
  duration?: number;
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
@media (prefers-reduced-motion: reduce) {
  .slide-transition {
    transform: none !important;
    transition: opacity 200ms ease-in-out !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` で `<PageTransition>` の代わりに使用
- **カスタマイズ**: `direction` でスライド方向、`distance`（20-100px）で動きの大きさ、`duration`（300〜500ms）で速度

#### 注意点

- `transform` + `opacity` のみで GPU 合成レイヤー処理。60fps を維持
- `prefers-reduced-motion` 時は `opacity` のみのフェードにフォールバック
- スライド中のオーバーフローは親要素に `overflow: hidden` で対応

---

### 1-3. クロスフェード（View Transitions API）

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

View Transitions API を利用したブラウザネイティブのクロスフェード遷移。
`next-view-transitions` パッケージで簡便に導入可能。共有要素遷移にも対応。

#### 実装コード

```tsx
// src/app/layout.tsx
import { ViewTransitions } from "next-view-transitions";

export default function RootLayout({ children }: { children: React.ReactNode }) {
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

/* 共有要素遷移の例 */
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
- **リンク**: `next/link` の代わりに `next-view-transitions` の `Link` を使用
- **共有要素**: `view-transition-name` を要素に付与して Shared Element Transition を実現

#### 注意点

- **ブラウザ対応**: Chrome 111+ / Edge 111+ / Safari 18.0+。Firefox は未対応（2026年3月時点）
- 非対応ブラウザでは遷移アニメーションなしの通常ナビゲーション（機能的に問題なし）
- `next-view-transitions` は ~2KB gzip（framer-motion ~30KB と比べ極めて軽量）
- `view-transition-name` は同一ページ内で一意にすること

---

## カテゴリ2: ナビゲーション

---

### 2-1. Sticky/Fixed ヘッダー（スクロール時の背景変化）

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

ページ上部に固定されたヘッダーが、スクロール位置に応じて背景色・影・高さを変化させるパターン。
ファーストビューでは透明、スクロール後は白背景＋シャドウで視認性を確保。HP案件で最多用。

#### 実装コード

```tsx
// src/components/common/StickyHeader.tsx
"use client";

import { useEffect, useState } from "react";

interface StickyHeaderProps {
  children: React.ReactNode;
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

    window.addEventListener("scroll", handleScroll, { passive: true });
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

#### CSS（必要な場合）

```css
@supports not (backdrop-filter: blur(8px)) {
  .sticky-header-scrolled {
    background-color: rgba(255, 255, 255, 0.98);
  }
}

@media (prefers-reduced-motion: reduce) {
  header {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: `layout.tsx` の `<body>` 直下
- **カスタマイズ**: `threshold` で切り替え位置調整。テキスト色切り替えは `isScrolled` で連動

#### 注意点

- `passive: true` でスクロールパフォーマンス最適化。React 18+ の batching で `requestAnimationFrame` 不要
- `z-50` 使用。モーダルは `z-[60]` 以上に
- `fixed` ヘッダーの場合、`<main>` に `pt-20`（ヘッダー高さ分）を追加

---

### 2-2. ハンバーガーメニュー（開閉アニメーション）

**難易度**: 中 | **使用頻度**: ★★★★★

#### 概要

モバイルビューのハンバーガーアイコン（三本線 → ✕ モーフィング）＋スライドインメニューパネル。

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
      <span
        className={`
          block h-0.5 w-6 bg-current
          transition-all duration-300 ease-in-out origin-center
          ${isOpen ? "translate-y-2 rotate-45" : ""}
        `}
      />
      <span
        className={`
          block h-0.5 w-6 bg-current
          transition-all duration-300 ease-in-out
          ${isOpen ? "scale-x-0 opacity-0" : ""}
        `}
      />
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

  // スクロール抑止
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

  // Escape キーで閉じる
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape" && isOpen) {
        setIsOpen(false);
      }
    };
    document.addEventListener("keydown", handleEscape);
    return () => document.removeEventListener("keydown", handleEscape);
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
@media (prefers-reduced-motion: reduce) {
  nav[aria-label="モバイルメニュー"] {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: ヘッダー内。デスクトップメニューと `md:hidden` で出し分け
- **カスタマイズ**: スライド方向（`left-0` + `-translate-x-full` で左から）、幅（`w-72` / `w-80` / `w-full`）

#### 注意点

- `aria-expanded`, `aria-label` でアクセシビリティ対応
- フォーカストラップの追加を推奨（メニュー開放時に Tab がメニュー内に留まるように）
- iOS Safari の `-webkit-overflow-scrolling` 問題には `touch-action: none` も併用

---

### 2-3. メガメニュー（ドロップダウン）

**難易度**: 高 | **使用頻度**: ★★★☆☆

#### 概要

ナビゲーション項目にホバーまたはクリックで展開される全幅パネル。
多くのサブページを持つサイトで情報構造を一覧性高く提示する。

#### 実装コード

```tsx
// src/components/common/MegaMenu.tsx
"use client";

import { useEffect, useRef, useState } from "react";

interface MegaMenuSection {
  title: string;
  items: { label: string; href: string; description?: string }[];
}

interface MegaMenuProps {
  label: string;
  sections: MegaMenuSection[];
}

export function MegaMenu({ label, sections }: MegaMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>(null);

  const handleMouseEnter = () => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    setIsOpen(true);
  };

  const handleMouseLeave = () => {
    timeoutRef.current = setTimeout(() => {
      setIsOpen(false);
    }, 150);
  };

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

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

#### CSS（必要な場合）

```css
@media (prefers-reduced-motion: reduce) {
  [role="menu"] {
    transition: none !important;
  }
}
```

#### 使い方

- **配置場所**: デスクトップ用ヘッダーナビゲーション内
- **カスタマイズ**: `grid-cols-3` をサブメニュー数に応じて変更。ホバー遅延（150ms）で開閉感度を調整

#### 注意点

- `aria-expanded`, `aria-haspopup`, `role="menu"`, `role="menuitem"` を正しく設定
- モバイルでは非表示にし、ハンバーガーメニュー（2-2）に切り替え
- ホバーとクリック両対応でタッチデバイスにも対応

---

## カテゴリ3: ボタンホバーエフェクト

---

### 3-1. 背景色スライド（左→右）

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

ホバー時に背景色が左端から右端へスライドして塗りつぶされるエフェクト。
疑似要素 `::before` の `scaleX` トランジションで実現。

#### 実装コード

```tsx
// components/SlideButton.tsx
import { type ComponentProps } from "react";

type SlideButtonProps = ComponentProps<"button"> & {
  variant?: "left-right" | "bottom-top";
};

export function SlideButton({
  children,
  variant = "left-right",
  className = "",
  ...props
}: SlideButtonProps) {
  const directionClass =
    variant === "bottom-top"
      ? "before:origin-bottom before:scale-y-0 hover:before:scale-y-100"
      : "before:origin-left before:scale-x-0 hover:before:scale-x-100";

  return (
    <button
      className={`
        group relative overflow-hidden
        px-8 py-3 border-2 border-current
        text-slate-800 font-semibold
        transition-colors duration-300
        hover:text-white
        before:absolute before:inset-0
        before:bg-slate-800 before:transition-transform before:duration-300
        before:ease-out before:z-0
        ${directionClass}
        motion-reduce:before:transition-none
        motion-reduce:hover:bg-slate-800
        ${className}
      `}
      {...props}
    >
      <span className="relative z-10">{children}</span>
    </button>
  );
}
```

#### CSS（必要な場合）

Tailwind CSS のみで完結。追加CSSは不要。

#### 使い方

- **用途**: CTAボタン、ナビゲーションのプライマリアクション
- **variant**: `"left-right"`（デフォルト）または `"bottom-top"` で方向切り替え
- **カスタマイズ**: `border-current` / `before:bg-slate-800` で色変更、`duration-300` で速度調整

#### 注意点

- `overflow-hidden` が必須（疑似要素がはみ出す）
- `z-10` をテキストの `span` に付与しないと背景色の下に隠れる
- `motion-reduce` で `transition-none` にフォールバック

---

### 3-2. アンダーライン展開（ボーダーアニメーション）

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

ホバー時に下線が中央から左右に展開するエフェクト。
`scaleX(0)` → `scaleX(1)` のトランジションで実現。

#### 実装コード

```tsx
// components/UnderlineLink.tsx
import { type ComponentProps } from "react";

type UnderlineVariant = "center" | "left" | "full-border";

type UnderlineLinkProps = ComponentProps<"a"> & {
  variant?: UnderlineVariant;
};

export function UnderlineLink({
  children,
  variant = "center",
  className = "",
  ...props
}: UnderlineLinkProps) {
  const variantStyles: Record<UnderlineVariant, string> = {
    center:
      "after:origin-center after:scale-x-0 hover:after:scale-x-100 after:bottom-0 after:h-0.5",
    left:
      "after:origin-left after:scale-x-0 hover:after:scale-x-100 after:bottom-0 after:h-0.5",
    "full-border":
      "after:origin-left after:scale-x-0 hover:after:scale-x-100 after:bottom-0 after:h-0.5 " +
      "before:absolute before:left-0 before:top-0 before:h-0.5 before:w-full " +
      "before:origin-right before:scale-x-0 hover:before:scale-x-100 " +
      "before:bg-current before:transition-transform before:duration-300",
  };

  return (
    <a
      className={`
        group relative inline-block
        py-1 text-slate-700 font-medium
        transition-colors duration-200
        after:absolute after:left-0 after:w-full
        after:bg-current after:transition-transform after:duration-300
        motion-reduce:after:transition-none
        ${variantStyles[variant]}
        ${className}
      `}
      {...props}
    >
      {children}
    </a>
  );
}
```

#### CSS（必要な場合）

Tailwind CSS のみで完結。追加CSSは不要。

#### 使い方

- **用途**: ナビゲーションリンク、テキストリンク、フッターリンク
- **variant**: `"center"`（中央から展開）、`"left"`（左から展開）、`"full-border"`（上下同時展開）

#### 注意点

- `inline-block` が必要。`inline` だと `after` の幅が正しく計算されない
- `full-border` は `before` / `after` 両方使うため、他の疑似要素との競合に注意

---

### 3-3. リップルエフェクト（クリック時の波紋）

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

クリック地点から波紋が広がるマテリアルデザイン風エフェクト。
クリック座標を取得して `span` 要素をアニメーションさせる。

#### 実装コード

```tsx
// components/RippleButton.tsx
"use client";

import { useState, useCallback, type MouseEvent, type ComponentProps } from "react";

type Ripple = {
  id: number;
  x: number;
  y: number;
  size: number;
};

type RippleButtonProps = ComponentProps<"button"> & {
  rippleColor?: string;
};

export function RippleButton({
  children,
  rippleColor = "bg-white/30",
  className = "",
  onClick,
  ...props
}: RippleButtonProps) {
  const [ripples, setRipples] = useState<Ripple[]>([]);

  const handleClick = useCallback(
    (e: MouseEvent<HTMLButtonElement>) => {
      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (!prefersReduced) {
        const rect = e.currentTarget.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height) * 2;
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;
        const id = Date.now();

        setRipples((prev) => [...prev, { id, x, y, size }]);

        setTimeout(() => {
          setRipples((prev) => prev.filter((r) => r.id !== id));
        }, 600);
      }

      onClick?.(e);
    },
    [onClick]
  );

  return (
    <button
      className={`
        relative overflow-hidden
        px-8 py-3 bg-slate-800 text-white font-semibold
        rounded-lg transition-shadow duration-200
        hover:shadow-lg active:scale-[0.98]
        ${className}
      `}
      onClick={handleClick}
      {...props}
    >
      {ripples.map((ripple) => (
        <span
          key={ripple.id}
          className={`absolute rounded-full ${rippleColor} animate-ripple pointer-events-none`}
          style={{
            left: ripple.x,
            top: ripple.y,
            width: ripple.size,
            height: ripple.size,
          }}
        />
      ))}
      <span className="relative z-10">{children}</span>
    </button>
  );
}
```

#### CSS（必要な場合）

```css
@keyframes ripple {
  from {
    transform: scale(0);
    opacity: 1;
  }
  to {
    transform: scale(1);
    opacity: 0;
  }
}

/* Tailwind v4: @theme で登録 */
@theme {
  --animate-ripple: ripple 0.6s ease-out forwards;
}
```

#### 使い方

- **用途**: フォーム送信ボタン、カード内アクションボタン
- **カスタマイズ**: `rippleColor` で波紋の色、CSS の `0.6s` で速度調整

#### 注意点

- `"use client"` が必須（`useState` / イベントハンドラ使用）
- `overflow-hidden` がないとリップルがはみ出す
- `setTimeout` でリップル要素を削除しないとDOMが増え続ける
- `prefers-reduced-motion: reduce` 時はリップル生成をスキップ

---

## カテゴリ4: スクロールトリガー

---

### 4-1. フェードイン（Intersection Observer）

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

要素がビューポートに入った時にフェードインするエフェクト。
方向（上下左右）を指定可能。HP案件のほぼ全セクションで使う定番パターン。

#### 実装コード

```tsx
// hooks/useFadeIn.ts
"use client";

import { useEffect, useRef, useState } from "react";

type FadeDirection = "up" | "down" | "left" | "right" | "none";

type UseFadeInOptions = {
  direction?: FadeDirection;
  delay?: number;
  duration?: number;
  threshold?: number;
  once?: boolean;
};

export function useFadeIn({
  direction = "up",
  delay = 0,
  duration = 600,
  threshold = 0.1,
  once = true,
}: UseFadeInOptions = {}) {
  const ref = useRef<HTMLDivElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    if (prefersReduced) {
      setIsVisible(true);
      return;
    }

    const element = ref.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          if (once) observer.unobserve(element);
        } else if (!once) {
          setIsVisible(false);
        }
      },
      { threshold }
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, [threshold, once]);

  const directionTransform: Record<FadeDirection, string> = {
    up: "translateY(30px)",
    down: "translateY(-30px)",
    left: "translateX(30px)",
    right: "translateX(-30px)",
    none: "none",
  };

  const style: React.CSSProperties = {
    opacity: isVisible ? 1 : 0,
    transform: isVisible ? "none" : directionTransform[direction],
    transition: `opacity ${duration}ms ease-out ${delay}ms, transform ${duration}ms ease-out ${delay}ms`,
  };

  return { ref, style, isVisible };
}
```

```tsx
// components/FadeIn.tsx
"use client";

import { useFadeIn } from "@/hooks/useFadeIn";

type FadeInProps = {
  children: React.ReactNode;
  direction?: "up" | "down" | "left" | "right" | "none";
  delay?: number;
  duration?: number;
  threshold?: number;
  className?: string;
};

export function FadeIn({
  children,
  direction = "up",
  delay = 0,
  duration = 600,
  threshold = 0.1,
  className = "",
}: FadeInProps) {
  const { ref, style } = useFadeIn({ direction, delay, duration, threshold });

  return (
    <div ref={ref} style={style} className={className}>
      {children}
    </div>
  );
}
```

#### CSS（必要な場合）

インラインスタイルで完結。追加CSSは不要。

#### 使い方

```tsx
// 基本: 下からフェードイン
<FadeIn>
  <h2>サービス紹介</h2>
</FadeIn>

// カードを連番ディレイで順番に表示（スタガーアニメーション）
{cards.map((card, i) => (
  <FadeIn key={card.id} delay={i * 100} direction="up">
    <Card {...card} />
  </FadeIn>
))}

// hookを直接使う場合
function MyComponent() {
  const { ref, style } = useFadeIn({ direction: "up", delay: 300 });
  return <div ref={ref} style={style}>コンテンツ</div>;
}
```

#### 注意点

- `once={true}`（デフォルト）で一度表示した要素は再監視しない → パフォーマンス良好
- `prefers-reduced-motion: reduce` 時は即座に `isVisible=true`
- `threshold` が高すぎると大きな要素が発火しない
- 大量要素（50+）に使う場合は IO を1つに共有する設計への切り替えを推奨

---

### 4-2. パララックス（背景の視差効果）

**難易度**: 中 | **使用頻度**: ★★★☆☆

#### 概要

スクロールに連動して背景がコンテンツより遅く/速く動く視差効果。
CSS `background-attachment: fixed` の簡易版と、`scroll` イベントでの精密制御版の2つを提供。

#### 実装コード

```tsx
// components/ParallaxSection.tsx — CSS版（軽量・シンプル）
type ParallaxSectionProps = {
  children: React.ReactNode;
  backgroundImage: string;
  height?: string;
  overlayOpacity?: number;
  className?: string;
};

export function ParallaxSection({
  children,
  backgroundImage,
  height = "60vh",
  overlayOpacity = 0.4,
  className = "",
}: ParallaxSectionProps) {
  return (
    <section
      className={`relative bg-cover bg-center bg-fixed ${className}`}
      style={{
        backgroundImage: `url(${backgroundImage})`,
        minHeight: height,
      }}
    >
      <div
        className="absolute inset-0 bg-black"
        style={{ opacity: overlayOpacity }}
      />
      <div className="relative z-10 flex items-center justify-center h-full min-h-[inherit]">
        {children}
      </div>
    </section>
  );
}
```

```tsx
// components/ParallaxElement.tsx — JS版（精密制御）
"use client";

import { useEffect, useRef, type ReactNode } from "react";

type ParallaxElementProps = {
  children: ReactNode;
  speed?: number; // -1 ~ 1
  className?: string;
};

export function ParallaxElement({
  children,
  speed = -0.3,
  className = "",
}: ParallaxElementProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    if (prefersReduced) return;

    const element = ref.current;
    if (!element) return;

    let rafId: number;

    const handleScroll = () => {
      rafId = requestAnimationFrame(() => {
        const rect = element.getBoundingClientRect();
        const scrolled = rect.top - window.innerHeight;
        const yOffset = scrolled * speed;
        element.style.transform = `translate3d(0, ${yOffset}px, 0)`;
      });
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();

    return () => {
      window.removeEventListener("scroll", handleScroll);
      cancelAnimationFrame(rafId);
    };
  }, [speed]);

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
```

#### CSS（必要な場合）

追加CSSは不要。

#### 使い方

- **CSS版**: ヒーローセクション、セクション区切りに
- **JS版**: `speed`（`-0.5`〜`-0.1`）で視差の強さを調整

#### 注意点

- **iOS Safari**: `background-attachment: fixed` が動作しない。iOS 対応が必要な場合はJS版を使用
- JS版は `{ passive: true }` + `requestAnimationFrame` でスロットリング済み
- `translate3d` で GPU 合成レイヤーに昇格
- `prefers-reduced-motion: reduce` 時はパララックスを無効化

---

### 4-3. スクロール連動プログレスバー

**難易度**: 低 | **使用頻度**: ★★★★☆

#### 概要

ページのスクロール進捗を上部に横バーで表示。ブログ記事やLPで「読了率」を視覚フィードバック。

#### 実装コード

```tsx
// components/ScrollProgress.tsx
"use client";

import { useEffect, useState } from "react";

type ScrollProgressProps = {
  color?: string;
  height?: number;
  zIndex?: number;
  position?: "top" | "bottom";
};

export function ScrollProgress({
  color = "bg-orange-500",
  height = 3,
  zIndex = 50,
  position = "top",
}: ScrollProgressProps) {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = document.documentElement.scrollTop;
      const scrollHeight =
        document.documentElement.scrollHeight -
        document.documentElement.clientHeight;
      const scrolled = scrollHeight > 0 ? (scrollTop / scrollHeight) * 100 : 0;
      setProgress(scrolled);
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();

    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <div
      className={`fixed ${position === "top" ? "top-0" : "bottom-0"} left-0 w-full`}
      style={{ height, zIndex }}
    >
      <div
        className={`h-full ${color} transition-none`}
        style={{ width: `${progress}%` }}
      />
    </div>
  );
}
```

#### CSS（必要な場合）

Tailwind CSS のみで完結。追加CSSは不要。

#### 使い方

- **用途**: ブログ記事、LP、長いフォームページ
- **カスタマイズ**: `color`（Tailwind カラークラス）、`height`（px）、`position`（top/bottom）

#### 注意点

- `transition-none` を指定。`transition` をつけるとスクロール追従が遅延してカクつく
- `prefers-reduced-motion` でも非表示にしない（情報表示であり、アニメーションではないため）
- `zIndex` を高めに設定しないとヘッダーに隠れる

---

### 4-4. カウントアップ（数字アニメーション）

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

要素がビューポートに入った時に、数字が0から目標値まで増加するアニメーション。
実績紹介（「施工実績 500+ 件」等）で定番。`easeOutExpo` でスムーズな減速。

#### 実装コード

```tsx
// components/CountUp.tsx
"use client";

import { useEffect, useRef, useState, useCallback } from "react";

type CountUpProps = {
  end: number;
  start?: number;
  duration?: number;
  suffix?: string;
  prefix?: string;
  separator?: boolean;
  decimals?: number;
  threshold?: number;
  className?: string;
};

function easeOutExpo(t: number): number {
  return t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
}

export function CountUp({
  end,
  start = 0,
  duration = 2000,
  suffix = "",
  prefix = "",
  separator = true,
  decimals = 0,
  threshold = 0.3,
  className = "",
}: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const [count, setCount] = useState(start);
  const [hasAnimated, setHasAnimated] = useState(false);

  const formatNumber = useCallback(
    (num: number) => {
      const fixed = num.toFixed(decimals);
      if (!separator) return `${prefix}${fixed}${suffix}`;
      const [intPart, decPart] = fixed.split(".");
      const formatted = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
      return `${prefix}${decPart ? `${formatted}.${decPart}` : formatted}${suffix}`;
    },
    [decimals, separator, prefix, suffix]
  );

  useEffect(() => {
    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    if (prefersReduced) {
      setCount(end);
      setHasAnimated(true);
      return;
    }

    const element = ref.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !hasAnimated) {
          setHasAnimated(true);
          const startTime = performance.now();

          const animate = (now: number) => {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const easedProgress = easeOutExpo(progress);
            const current = start + (end - start) * easedProgress;

            setCount(current);

            if (progress < 1) {
              requestAnimationFrame(animate);
            }
          };

          requestAnimationFrame(animate);
          observer.unobserve(element);
        }
      },
      { threshold }
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, [end, start, duration, threshold, hasAnimated]);

  return (
    <span ref={ref} className={className}>
      {formatNumber(count)}
    </span>
  );
}
```

#### CSS（必要な場合）

追加CSSは不要。

#### 使い方

```tsx
// 実績セクション
<div className="grid grid-cols-3 gap-8 text-center">
  <div>
    <CountUp end={500} suffix="件" className="text-4xl font-bold text-orange-600" />
    <p className="mt-2 text-sm text-slate-600">施工実績</p>
  </div>
  <div>
    <CountUp end={98} suffix="%" className="text-4xl font-bold text-orange-600" />
    <p className="mt-2 text-sm text-slate-600">顧客満足度</p>
  </div>
  <div>
    <CountUp end={30} suffix="年" className="text-4xl font-bold text-orange-600" />
    <p className="mt-2 text-sm text-slate-600">創業年数</p>
  </div>
</div>
```

#### 注意点

- `easeOutExpo` で終盤がゆっくり減速 → 自然な動き
- `hasAnimated` で一度だけ発火
- `prefers-reduced-motion: reduce` 時は即座に最終値を表示
- 大きな数値（1,000,000+）は `duration` を長めに

---

## カテゴリ5: アコーディオン・モーダル + ユーティリティ

---

### 5-1. アコーディオン（FAQ）

**難易度**: 中 | **使用頻度**: ★★★★★

#### 概要

FAQ やサービス詳細で使う開閉パネル。`grid-template-rows` による滑らかな高さアニメーションで、
`height: auto` への遷移を CSS のみで実現。JavaScript で高さ計測不要。

#### 実装コード

```tsx
"use client";

import { useState, useId } from "react";

interface AccordionItem {
  question: string;
  answer: string;
}

interface AccordionProps {
  items: AccordionItem[];
  exclusive?: boolean;
  className?: string;
}

export function Accordion({ items, exclusive = false, className = "" }: AccordionProps) {
  const [openIndices, setOpenIndices] = useState<Set<number>>(new Set());
  const baseId = useId();

  const toggle = (index: number) => {
    setOpenIndices((prev) => {
      const next = new Set(exclusive ? [] : prev);
      if (prev.has(index)) {
        next.delete(index);
      } else {
        next.add(index);
      }
      return next;
    });
  };

  return (
    <div className={`divide-y divide-gray-200 ${className}`}>
      {items.map((item, index) => {
        const isOpen = openIndices.has(index);
        const triggerId = `${baseId}-trigger-${index}`;
        const panelId = `${baseId}-panel-${index}`;

        return (
          <div key={index}>
            <button
              id={triggerId}
              type="button"
              aria-expanded={isOpen}
              aria-controls={panelId}
              onClick={() => toggle(index)}
              className="flex w-full items-center justify-between py-4 text-left text-base font-medium text-gray-900 hover:text-gray-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500"
            >
              <span>{item.question}</span>
              <svg
                className={`size-5 shrink-0 text-gray-500 transition-transform duration-300 motion-reduce:transition-none ${
                  isOpen ? "rotate-180" : ""
                }`}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fillRule="evenodd"
                  d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                  clipRule="evenodd"
                />
              </svg>
            </button>
            <div
              id={panelId}
              role="region"
              aria-labelledby={triggerId}
              className={`grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none ${
                isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
              }`}
            >
              <div className="overflow-hidden">
                <div className="pb-4 text-sm leading-relaxed text-gray-600">
                  {item.answer}
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
```

#### CSS（必要な場合）

Tailwind の `grid-rows-[0fr]` / `grid-rows-[1fr]` と `transition-[grid-template-rows]` で完結。

#### 使い方

- **FAQ ページ**: `exclusive={true}` で1つずつ開閉
- **サービス詳細**: `exclusive={false}` で複数同時展開

#### 注意点

- `grid-template-rows` アニメーション: Safari 16.4+, Chrome 107+, Firefox 113+
- WAI-ARIA: `aria-expanded`, `aria-controls`, `role="region"` 使用
- DOM の追加/削除ではなく CSS グリッドの遷移のみで再レンダリングコストが低い

---

### 5-2. モーダル / ダイアログ

**難易度**: 高 | **使用頻度**: ★★★★☆

#### 概要

`<dialog>` 要素ベースのモーダル。背景のフェードインとコンテンツのスケールインを組み合わせた上品な表示。
フォーカストラップ・ESC キー閉じ・背景スクロールロックをブラウザネイティブで実現。

#### 実装コード

```tsx
"use client";

import { useRef, useEffect, useCallback, type ReactNode } from "react";

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  title: string;
  className?: string;
}

export function Modal({ isOpen, onClose, children, title, className = "" }: ModalProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (isOpen) {
      dialog.showModal();
    } else {
      dialog.close();
    }
  }, [isOpen]);

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent<HTMLDialogElement>) => {
      if (e.target === dialogRef.current) {
        onClose();
      }
    },
    [onClose]
  );

  const handleCancel = useCallback(
    (e: React.SyntheticEvent<HTMLDialogElement>) => {
      e.preventDefault();
      onClose();
    },
    [onClose]
  );

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="modal-title"
      onClick={handleBackdropClick}
      onCancel={handleCancel}
      className={`
        backdrop:bg-black/50
        backdrop:opacity-0
        backdrop:transition-opacity
        backdrop:duration-300
        open:backdrop:opacity-100
        motion-reduce:backdrop:transition-none

        m-auto max-h-[85vh] w-[90vw] max-w-lg
        scale-95 rounded-xl bg-white p-0 opacity-0 shadow-2xl
        transition-[opacity,transform] duration-300 ease-out
        open:scale-100 open:opacity-100
        motion-reduce:transition-none
        ${className}
      `}
    >
      <div className="p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 id="modal-title" className="text-lg font-semibold text-gray-900">
            {title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="閉じる"
            className="rounded-full p-1.5 text-gray-400 hover:bg-gray-100 hover:text-gray-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500"
          >
            <svg className="size-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
        {children}
      </div>
    </dialog>
  );
}
```

#### CSS（必要な場合）

Tailwind の `open:` variant で `<dialog>` の open 状態を検知。追加 CSS は不要。

閉じアニメーションが必要な場合は `@starting-style`（Chrome 117+）、または `data-closing` 属性 + `transitionend` で `close()` を遅延実行する方式に拡張。

#### 使い方

- **確認ダイアログ**: フォーム送信前の確認
- **画像拡大表示**: ギャラリーの詳細ビュー
- **利用規約表示**: 長文コンテンツのポップアップ

#### 注意点

- `<dialog>` のフォーカストラップ・ESC 閉じ・`inert` による背景無効化はブラウザネイティブ
- `showModal()` 使用時はブラウザが自動で背景スクロールロック
- Safari 15.4+ で `<dialog>` 対応
- `aria-labelledby` でタイトルと紐付け済み

---

### 5-3. ドロワー

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

画面端からスライドインするパネル。`<dialog>` ベースでアクセシビリティを確保しつつ、
`translate-x` によるスライドアニメーションを実現。

#### 実装コード

```tsx
"use client";

import { useRef, useEffect, useCallback, type ReactNode } from "react";

type DrawerSide = "left" | "right";

interface DrawerProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  title: string;
  side?: DrawerSide;
  className?: string;
}

const slideConfig: Record<DrawerSide, { closed: string; position: string }> = {
  left: {
    closed: "-translate-x-full",
    position: "mr-auto ml-0 rounded-r-xl",
  },
  right: {
    closed: "translate-x-full",
    position: "ml-auto mr-0 rounded-l-xl",
  },
};

export function Drawer({
  isOpen,
  onClose,
  children,
  title,
  side = "right",
  className = "",
}: DrawerProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const config = slideConfig[side];

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (isOpen) {
      dialog.showModal();
    } else {
      dialog.close();
    }
  }, [isOpen]);

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent<HTMLDialogElement>) => {
      if (e.target === dialogRef.current) {
        onClose();
      }
    },
    [onClose]
  );

  const handleCancel = useCallback(
    (e: React.SyntheticEvent<HTMLDialogElement>) => {
      e.preventDefault();
      onClose();
    },
    [onClose]
  );

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="drawer-title"
      onClick={handleBackdropClick}
      onCancel={handleCancel}
      className={`
        backdrop:bg-black/50
        backdrop:opacity-0
        backdrop:transition-opacity
        backdrop:duration-300
        open:backdrop:opacity-100
        motion-reduce:backdrop:transition-none

        fixed inset-0 m-0 h-dvh w-80 max-w-[85vw]
        bg-white p-0 shadow-2xl
        transition-transform duration-300 ease-out
        motion-reduce:transition-none
        ${config.position}
        ${isOpen ? "translate-x-0" : config.closed}
        ${className}
      `}
    >
      <div className="flex h-full flex-col">
        <div className="flex items-center justify-between border-b border-gray-200 px-4 py-3">
          <h2 id="drawer-title" className="text-base font-semibold text-gray-900">
            {title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="閉じる"
            className="rounded-full p-1.5 text-gray-400 hover:bg-gray-100 hover:text-gray-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500"
          >
            <svg className="size-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-4">
          {children}
        </div>
      </div>
    </dialog>
  );
}
```

#### CSS（必要な場合）

追加 CSS は不要。`m-0` で UA スタイルシートの `margin: auto` を上書き。

#### 使い方

- **モバイルナビ**: `side="left"`
- **フィルターパネル**: `side="right"`
- **詳細パネル**: 一覧画面から横にスライド表示

#### 注意点

- `h-dvh`（`100dvh`）でモバイルブラウザのアドレスバーに追従
- `max-w-[85vw]` で背景が見え、「閉じられる」ことが直感的に伝わる
- 閉じアニメーションは `transitionend` で `close()` を遅延実行する方式に拡張可能

---

### 5-4. ローディングスピナー / スケルトンスクリーン

**難易度**: 低 | **使用頻度**: ★★★★★

#### 概要

データ取得中の待機状態を表現する2つのパターン。
CLS を防ぎ、体感速度を向上させる。

#### 実装コード

```tsx
/* ========== スピナー ========== */

interface SpinnerProps {
  size?: "sm" | "md" | "lg";
  className?: string;
}

const spinnerSizes = {
  sm: "size-4 border-2",
  md: "size-6 border-2",
  lg: "size-10 border-3",
} as const;

export function Spinner({ size = "md", className = "" }: SpinnerProps) {
  return (
    <div
      role="status"
      aria-label="読み込み中"
      className={`
        ${spinnerSizes[size]}
        animate-spin rounded-full
        border-gray-200 border-t-blue-600
        motion-reduce:animate-[spin_3s_linear_infinite]
        ${className}
      `}
    />
  );
}

/* ========== スケルトン ========== */

interface SkeletonProps {
  className?: string;
  circle?: boolean;
}

export function Skeleton({ className = "", circle = false }: SkeletonProps) {
  return (
    <div
      aria-hidden="true"
      className={`
        animate-pulse bg-gray-200
        motion-reduce:animate-none motion-reduce:bg-gray-300
        ${circle ? "rounded-full" : "rounded-md"}
        ${className}
      `}
    />
  );
}

/* ========== カードスケルトン（組み合わせ例） ========== */

export function CardSkeleton() {
  return (
    <div className="rounded-xl border border-gray-200 p-4">
      <Skeleton className="mb-4 h-48 w-full" />
      <Skeleton className="mb-2 h-5 w-3/4" />
      <Skeleton className="mb-1.5 h-3.5 w-full" />
      <Skeleton className="mb-1.5 h-3.5 w-full" />
      <Skeleton className="h-3.5 w-2/3" />
    </div>
  );
}
```

#### CSS（必要な場合）

Tailwind 組み込みの `animate-spin` と `animate-pulse` で完結。

`motion-reduce` 時: スピナーは3秒に減速（完全停止するとローディング中が伝わらない）。スケルトンはパルス停止、やや濃いグレーの静的プレースホルダーに。

#### 使い方

- **ページ初期表示**: SSR/SSG の fallback として `CardSkeleton` を表示
- **データ取得中**: API レスポンス待ちに `Spinner` を配置
- **無限スクロール**: リスト末尾に `CardSkeleton` を表示

#### 注意点

- `role="status"` + `aria-label` でスクリーンリーダー対応（スピナー）
- `aria-hidden="true"` でスケルトンを支援技術から隠す
- スケルトンの高さ・幅を実際のコンテンツと揃えないと CLS スコアが悪化

---

### 5-5. トースト通知

**難易度**: 中 | **使用頻度**: ★★★★☆

#### 概要

操作結果を一時的に表示するフローティング通知。画面右下からスライドインし、一定時間後に自動消去。
フォーム送信成功・エラー通知・コピー完了など、ユーザーの作業フローを中断しない非モーダルフィードバック。

#### 実装コード

```tsx
"use client";

import { useState, useEffect, useCallback, useId, type ReactNode } from "react";

/* ========== 型定義 ========== */

type ToastVariant = "success" | "error" | "info" | "warning";

interface Toast {
  id: string;
  message: string;
  variant: ToastVariant;
  duration: number;
}

/* ========== アイコン設定 ========== */

const variantConfig: Record<ToastVariant, { icon: ReactNode; containerClass: string }> = {
  success: {
    icon: (
      <svg className="size-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clipRule="evenodd" />
      </svg>
    ),
    containerClass: "border-green-200 bg-green-50",
  },
  error: {
    icon: (
      <svg className="size-5 text-red-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clipRule="evenodd" />
      </svg>
    ),
    containerClass: "border-red-200 bg-red-50",
  },
  warning: {
    icon: (
      <svg className="size-5 text-amber-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.168 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
      </svg>
    ),
    containerClass: "border-amber-200 bg-amber-50",
  },
  info: {
    icon: (
      <svg className="size-5 text-blue-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clipRule="evenodd" />
      </svg>
    ),
    containerClass: "border-blue-200 bg-blue-50",
  },
};

/* ========== 個別トースト ========== */

interface ToastItemProps {
  toast: Toast;
  onDismiss: (id: string) => void;
}

function ToastItem({ toast, onDismiss }: ToastItemProps) {
  const [isVisible, setIsVisible] = useState(false);
  const [isLeaving, setIsLeaving] = useState(false);
  const config = variantConfig[toast.variant];

  useEffect(() => {
    const showTimer = requestAnimationFrame(() => setIsVisible(true));
    const dismissTimer = setTimeout(() => {
      setIsLeaving(true);
    }, toast.duration);

    return () => {
      cancelAnimationFrame(showTimer);
      clearTimeout(dismissTimer);
    };
  }, [toast.duration]);

  const handleTransitionEnd = () => {
    if (isLeaving) {
      onDismiss(toast.id);
    }
  };

  return (
    <div
      role="status"
      aria-live="polite"
      onTransitionEnd={handleTransitionEnd}
      className={`
        flex items-start gap-3 rounded-lg border px-4 py-3 shadow-lg
        transition-all duration-300 ease-out
        motion-reduce:transition-none
        ${config.containerClass}
        ${isVisible && !isLeaving
          ? "translate-x-0 opacity-100"
          : "translate-x-full opacity-0"
        }
      `}
    >
      <div className="shrink-0 pt-0.5">{config.icon}</div>
      <p className="flex-1 text-sm text-gray-800">{toast.message}</p>
      <button
        type="button"
        onClick={() => setIsLeaving(true)}
        aria-label="通知を閉じる"
        className="shrink-0 rounded p-0.5 text-gray-400 hover:text-gray-600"
      >
        <svg className="size-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
        </svg>
      </button>
    </div>
  );
}

/* ========== コンテナ ========== */

interface ToastContainerProps {
  toasts: Toast[];
  onDismiss: (id: string) => void;
}

export function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  return (
    <div
      aria-label="通知"
      className="fixed right-4 bottom-4 z-50 flex w-80 max-w-[calc(100vw-2rem)] flex-col-reverse gap-2"
    >
      {toasts.map((toast) => (
        <ToastItem key={toast.id} toast={toast} onDismiss={onDismiss} />
      ))}
    </div>
  );
}

/* ========== カスタムフック ========== */

export function useToast() {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const baseId = useId();
  let counter = 0;

  const addToast = useCallback(
    (message: string, variant: ToastVariant = "info", duration = 5000) => {
      const id = `${baseId}-${Date.now()}-${counter++}`;
      setToasts((prev) => [...prev, { id, message, variant, duration }]);
    },
    [baseId]
  );

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return { toasts, addToast, dismissToast };
}
```

#### CSS（必要な場合）

追加 CSS は不要。`translate-x` + `opacity` のトランジションで入退場を実現。

#### 使い方

```tsx
function ContactPage() {
  const { toasts, addToast, dismissToast } = useToast();

  const handleSubmit = async () => {
    try {
      await submitForm(formData);
      addToast("お問い合わせを送信しました", "success");
    } catch {
      addToast("送信に失敗しました。時間をおいて再度お試しください", "error", 8000);
    }
  };

  return (
    <>
      <form onSubmit={handleSubmit}>{/* ... */}</form>
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </>
  );
}
```

#### 注意点

- `aria-live="polite"` でスクリーンリーダーが読み上げ
- 自動消去時間: 短いメッセージ5秒、エラー8秒が目安
- 手動閉じボタンも必ず提供（WCAG 2.2.1）
- `flex-col-reverse` で新しいトーストが下に追加
- `transitionend` で DOM から削除。タイマーは `useEffect` cleanup で解除

---

## Guidelines

### 共通技術方針

1. **framer-motion 不使用**: CSS transitions + React state で全パターンを実現。外部依存ゼロ
2. **Tailwind CSS v4**: `open:`, `backdrop:`, `motion-reduce:` variant を活用
3. **TypeScript strict mode**: 全パターンで型安全な実装
4. **コピペで動く**: 各パターンは単体でコピー&ペーストして即使用可能な完全な実装

### パフォーマンス

- アニメーションは `transform` と `opacity` のみ使用（GPU 合成レイヤーで処理、60fps 維持）
- `will-change` は常時指定せず、必要時のみ
- スクロールイベントは `{ passive: true }` を付与
- Intersection Observer は `once: true` で不要な監視を停止

### アクセシビリティ

- **`prefers-reduced-motion`**: 全パターンで `motion-reduce:` によるアニメーション低減/無効化を実装
- **WAI-ARIA**: `<dialog>` のネイティブアクセシビリティ、`role="status"`, `aria-expanded`, `aria-label` 等を適切に使用
- **キーボード操作**: `Escape` キーで閉じる、Tab でフォーカス移動

### ブラウザ対応

| 機能 | Chrome | Firefox | Safari | Edge |
|------|--------|---------|--------|------|
| View Transitions API | 111+ | 未対応 | 18.0+ | 111+ |
| `<dialog>` | 37+ | 98+ | 15.4+ | 79+ |
| `grid-template-rows` アニメーション | 107+ | 113+ | 16.4+ | 107+ |
| `backdrop-filter` | 76+ | 103+ | 9+ | 79+ |
| CSS `open:` pseudo | 全対応 | 全対応 | 全対応 | 全対応 |
