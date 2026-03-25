# Webアニメーション パターンカタログ — カテゴリ3-4 ドラフト

## カテゴリ3: ボタンホバーエフェクト

---

### パターン3-1: 背景色スライド（左→右）

**カテゴリ**: ボタンホバーエフェクト
**難易度**: 低
**使用頻度**: ★★★★★

#### 概要

ホバー時に背景色が左端から右端へスライドして塗りつぶされるエフェクト。CTAボタンやナビゲーションリンクで頻出。疑似要素 `::before` の `scaleX` トランジションで実現する。

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
- **variant**: `"left-right"`（デフォルト）または `"bottom-top"` で方向を切り替え
- **カスタマイズポイント**:
  - `border-current` / `before:bg-slate-800` を変更して色をカスタム
  - `duration-300` を `duration-500` に変えるとゆっくりになる
  - `before:origin-left` を `before:origin-right` にすると右→左スライド

#### 注意点

- `overflow-hidden` が必須。これがないと疑似要素がはみ出す
- `z-10` をテキストの `span` に付けないと背景色の下に隠れる
- `motion-reduce` で `transition-none` にフォールバック（アクセシビリティ対応）
- `will-change` は不要。`transform` の `scaleX` は GPU 合成されるため十分高速

---

### パターン3-2: ボーダーアニメーション（アンダーライン展開）

**カテゴリ**: ボタンホバーエフェクト
**難易度**: 低
**使用頻度**: ★★★★★

#### 概要

ホバー時に下線が中央から左右に展開するエフェクト。テキストリンクやナビゲーション項目に最適。`scaleX(0)` → `scaleX(1)` のトランジションで実現。

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
- **variant**:
  - `"center"` — 中央から左右に展開（デフォルト、最も汎用的）
  - `"left"` — 左端から右へ展開
  - `"full-border"` — 上下ボーダーが同時に展開（インパクト強め）
- **カスタマイズポイント**:
  - `after:h-0.5` を `after:h-1` にすると太い下線に
  - `after:bg-current` を `after:bg-orange-500` 等にして色を固定
  - `after:-bottom-1` にすると下線をテキストから離せる

#### 注意点

- `inline-block` が必要。`inline` だと `after` 疑似要素の幅が正しく計算されない
- `full-border` variant は `before` / `after` 両方使うので、他で疑似要素を使うコンポーネントとの競合に注意
- `motion-reduce` でトランジション無効化済み

---

### パターン3-3: リップルエフェクト（クリック時の波紋）

**カテゴリ**: ボタンホバーエフェクト
**難易度**: 中
**使用頻度**: ★★★★☆

#### 概要

クリック地点から波紋が広がるマテリアルデザイン風エフェクト。クリック座標を取得して `span` 要素をアニメーションさせる。ユーザーに明確なフィードバックを与える。

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
      // prefers-reduced-motion チェック
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

        // アニメーション完了後にDOMから削除
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
/* globals.css に追加 */
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

/* または tailwind.config で */
/* animation: { ripple: "ripple 0.6s ease-out forwards" } */
```

#### 使い方

- **用途**: フォーム送信ボタン、カード内のアクションボタン、マテリアルデザインテイストのUI
- **カスタマイズポイント**:
  - `rippleColor`: `"bg-white/30"`（暗いボタン用）や `"bg-slate-800/20"`（明るいボタン用）
  - アニメーション時間: CSS の `0.6s` を調整
  - `active:scale-[0.98]` でクリック時の押し込み感を演出

#### 注意点

- `"use client"` が必須（`useState` / イベントハンドラ使用）
- `overflow-hidden` がないとリップルがボタン外にはみ出す
- `setTimeout` でリップル要素を削除しないとDOMが増え続ける
- `prefers-reduced-motion: reduce` の場合はリップル生成をスキップ（アクセシビリティ対応）
- SSR環境では `window.matchMedia` がないため、`useCallback` 内で安全に呼び出している

---

## カテゴリ4: スクロールトリガー

---

### パターン4-1: フェードイン（Intersection Observer）

**カテゴリ**: スクロールトリガー
**難易度**: 低
**使用頻度**: ★★★★★

#### 概要

要素がビューポートに入った時にフェードインするエフェクト。Intersection Observer API を使用してパフォーマンスを確保。方向（上下左右）を指定可能。HP案件のほぼ全セクションで使う定番パターン。

#### 実装コード

```tsx
// hooks/useFadeIn.ts
"use client";

import { useEffect, useRef, useState } from "react";

type FadeDirection = "up" | "down" | "left" | "right" | "none";

type UseFadeInOptions = {
  direction?: FadeDirection;
  delay?: number;       // ms
  duration?: number;    // ms
  threshold?: number;   // 0-1
  once?: boolean;       // 一度だけ発火（デフォルト true）
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
    // prefers-reduced-motion チェック
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
  as?: keyof HTMLElementTagNameMap;
};

export function FadeIn({
  children,
  direction = "up",
  delay = 0,
  duration = 600,
  threshold = 0.1,
  className = "",
  as: Tag = "div",
}: FadeInProps) {
  const { ref, style } = useFadeIn({ direction, delay, duration, threshold });

  return (
    // @ts-expect-error -- dynamic tag
    <Tag ref={ref} style={style} className={className}>
      {children}
    </Tag>
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

// 左から、200msディレイ
<FadeIn direction="left" delay={200}>
  <p>テキスト内容</p>
</FadeIn>

// カードを連番ディレイで順番に表示
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

- **用途**: セクション見出し、カード一覧、テキストブロック、画像 — ほぼ全場面で使用
- **カスタマイズポイント**:
  - `delay` を `i * 100` でスタガーアニメーション（順番に表示）
  - `threshold` を `0.3` にすると、要素の30%が見えてから発火
  - `once={false}` でスクロールアウト時に再度非表示→再フェードイン

#### 注意点

- `"use client"` が必須（`useEffect` / `useRef` / `useState` 使用）
- `once={true}`（デフォルト）で一度表示した要素は再監視しない → パフォーマンス良好
- `prefers-reduced-motion: reduce` の場合は即座に `isVisible=true` → アニメーション無しで表示
- `threshold` が高すぎる（例: `0.9`）と、大きな要素がなかなか発火しないので注意
- 大量要素（50+）に使う場合は `IntersectionObserver` を1つに共有する設計に切り替えを推奨（別パターンとして検討）

---

### パターン4-2: パララックス（背景の視差効果）

**カテゴリ**: スクロールトリガー
**難易度**: 中
**使用頻度**: ★★★☆☆

#### 概要

スクロールに連動して背景がコンテンツより遅く/速く動く視差効果。ヒーローセクションや区切りセクションでの使用が定番。CSS `background-attachment: fixed` の簡易版と、`scroll` イベントでの精密制御版の2つを提供。

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
      {/* オーバーレイ */}
      <div
        className="absolute inset-0 bg-black"
        style={{ opacity: overlayOpacity }}
      />
      {/* コンテンツ */}
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
  speed?: number; // -1 ~ 1。負=遅い、正=速い。0=通常
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
    handleScroll(); // 初期位置設定

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

CSS版は Tailwind のみで完結。JS版も追加CSS不要。

#### 使い方

```tsx
// CSS版: ヒーローセクション
<ParallaxSection backgroundImage="/images/hero-bg.jpg">
  <h1 className="text-4xl text-white font-bold">キャッチコピー</h1>
</ParallaxSection>

// JS版: 特定要素に視差効果
<div className="relative overflow-hidden">
  <ParallaxElement speed={-0.2}>
    <img src="/images/decoration.png" alt="" className="w-full" />
  </ParallaxElement>
  <div className="relative z-10">
    <p>コンテンツ</p>
  </div>
</div>
```

- **用途**: ヒーローセクション、セクション区切り、装飾画像
- **カスタマイズポイント**:
  - CSS版: `overlayOpacity` で暗さ調整、`height` で高さ変更
  - JS版: `speed` を `-0.5`（大きな視差）〜 `-0.1`（微細な視差）で調整

#### 注意点

- **iOS Safari**: `background-attachment: fixed` が **動作しない**。iOS対応が必要な場合はJS版を使用
- JS版は `scroll` イベントをリスンするが、`{ passive: true }` + `requestAnimationFrame` でスロットリング済み
- `translate3d` を使うことでGPU合成レイヤーに昇格 → パフォーマンス確保
- `prefers-reduced-motion: reduce` の場合はJS版のパララックスを無効化（静止表示）
- パララックスの `speed` が大きすぎるとコンテンツとの乖離が激しくなり、レイアウトが崩れる可能性がある

---

### パターン4-3: スクロール連動プログレスバー

**カテゴリ**: スクロールトリガー
**難易度**: 低
**使用頻度**: ★★★★☆

#### 概要

ページのスクロール進捗をページ上部に横バーで表示。ブログ記事やLPで「読了率」を視覚フィードバックする定番パターン。

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
    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    // reduced-motionでもプログレスバーは表示（アニメーションではなく情報表示のため）
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

```tsx
// layout.tsx や page.tsx に配置
<ScrollProgress />

// カスタム: オレンジ色、高さ4px、下部表示
<ScrollProgress color="bg-orange-600" height={4} position="bottom" />
```

- **用途**: ブログ記事、LP、長いフォームページ
- **カスタマイズポイント**:
  - `color`: Tailwind のカラークラスで自由に変更
  - `height`: バーの太さ（px）
  - `position`: `"top"` / `"bottom"` でページ上部/下部

#### 注意点

- `transition-none` を指定。`transition` をつけるとスクロール追従が遅延してカクつく
- `{ passive: true }` でスクロールパフォーマンスを確保
- `prefers-reduced-motion` でも非表示にしない（プログレスバーは情報表示であり、アニメーションではないため）
- `zIndex` を高めに設定しないとヘッダー等に隠れる

---

### パターン4-4: カウントアップ（数字アニメーション）

**カテゴリ**: スクロールトリガー
**難易度**: 中
**使用頻度**: ★★★★☆

#### 概要

要素がビューポートに入った時に、数字が0から目標値まで増加するアニメーション。実績紹介（「施工実績 500+ 件」等）で定番。`requestAnimationFrame` によるスムーズなカウントアップ。

#### 実装コード

```tsx
// components/CountUp.tsx
"use client";

import { useEffect, useRef, useState, useCallback } from "react";

type CountUpProps = {
  end: number;
  start?: number;
  duration?: number;   // ms
  suffix?: string;     // "+", "件", "%" など
  prefix?: string;     // "¥", "$" など
  separator?: boolean; // 3桁カンマ区切り
  decimals?: number;   // 小数点以下桁数
  threshold?: number;
  className?: string;
};

// easeOutExpo: 最初は速く、終盤はゆっくり（数字の勢い感を演出）
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
// 基本: 0 → 500
<CountUp end={500} suffix="+" />

// 実績セクションでの典型的な使い方
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

// 金額表示
<CountUp end={12500000} prefix="¥" separator />
```

- **用途**: 実績数、統計データ、KPI表示
- **カスタマイズポイント**:
  - `duration`: 数値が大きいほど長めに（`500` → `1500ms`、`10000` → `3000ms`）
  - `suffix`/`prefix`: 単位や通貨記号
  - `separator`: 3桁区切りカンマ
  - `decimals`: 小数点（`98.5%` 等）
  - イージング関数 `easeOutExpo` を変更すると動きの印象が変わる

#### 注意点

- `"use client"` が必須（`useEffect` / `useState` / `useRef` 使用）
- `easeOutExpo` により終盤がゆっくりになる → 最終値が「ドン」と止まる印象を避け、自然な減速
- `hasAnimated` フラグで一度だけ発火。スクロールで行ったり来たりしても再アニメーションしない
- `prefers-reduced-motion: reduce` の場合は即座に最終値を表示
- `formatNumber` を `useCallback` でメモ化（60fps更新時のGC負荷を軽減）
- 非常に大きな数値（1,000,000+）の場合は `duration` を長めにしないと一瞬で終わって見えない

---

## パターン一覧サマリー

| # | パターン名 | カテゴリ | 難易度 | 使用頻度 | 依存 |
|---|-----------|---------|--------|---------|------|
| 3-1 | 背景色スライド | ボタンホバー | 低 | ★★★★★ | Tailwind のみ |
| 3-2 | アンダーライン展開 | ボタンホバー | 低 | ★★★★★ | Tailwind のみ |
| 3-3 | リップルエフェクト | ボタンホバー | 中 | ★★★★☆ | React state + CSS keyframes |
| 4-1 | フェードイン | スクロールトリガー | 低 | ★★★★★ | Intersection Observer |
| 4-2 | パララックス | スクロールトリガー | 中 | ★★★☆☆ | CSS fixed / scroll event |
| 4-3 | プログレスバー | スクロールトリガー | 低 | ★★★★☆ | scroll event |
| 4-4 | カウントアップ | スクロールトリガー | 中 | ★★★★☆ | Intersection Observer + rAF |

**全パターン共通**:
- framer-motion 不使用（CSS + React state で完結）
- `prefers-reduced-motion` 対応済み
- Tailwind CSS v4 互換クラス使用
- TypeScript strict mode 対応
