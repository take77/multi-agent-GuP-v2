# Web Animation Patterns — カテゴリ5: アコーディオン・モーダル + ユーティリティ

HP案件で再利用可能なアニメーションパターン集。
React + Tailwind CSS v4 で実装。外部ライブラリ依存なし（framer-motion 不使用）。

---

## 1. アコーディオン（FAQ）

**カテゴリ**: アコーディオン・モーダル
**難易度**: 中
**使用頻度**: ★★★★★

### 概要

FAQ やサービス詳細で使う開閉パネル。`grid-template-rows` による滑らかな高さアニメーションで、
`height: auto` への遷移を CSS のみで実現する。JavaScript で高さ計測は不要。

### 実装コード

```tsx
"use client";

import { useState, useId } from "react";

interface AccordionItem {
  question: string;
  answer: string;
}

interface AccordionProps {
  items: AccordionItem[];
  /** 同時に1つだけ開く場合 true */
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

### CSS（必要な場合）

CSS ファイル追加は不要。Tailwind の `grid-rows-[0fr]` / `grid-rows-[1fr]` と `transition-[grid-template-rows]` で完結する。

**仕組み**:
```
grid-rows-[0fr] → grid-template-rows: 0fr  → 高さ 0（閉）
grid-rows-[1fr] → grid-template-rows: 1fr  → 高さ auto（開）
overflow-hidden の子要素で内容がクリップされる
```

### 使い方

- **FAQ ページ**: `exclusive={true}` で1つずつ開閉
- **サービス詳細**: `exclusive={false}` で複数同時展開
- **カスタマイズ**: アイコンを `+/-` に変更、`duration-300` を調整

```tsx
<Accordion
  items={[
    { question: "相談は無料ですか？", answer: "はい、初回相談は無料..." },
    { question: "対応エリアは？", answer: "全国対応しております..." },
  ]}
  exclusive
/>
```

### 注意点

- **`grid-template-rows` アニメーション**: `height: auto` に遷移できない CSS の制約を回避するモダンな手法。Safari 16.4+、Chrome 107+、Firefox 113+ で対応
- **`motion-reduce:transition-none`**: `prefers-reduced-motion: reduce` 設定時にアニメーション無効化
- **WAI-ARIA**: `aria-expanded`, `aria-controls`, `role="region"` を使用。キーボード操作は `button` 要素で自動対応
- **パフォーマンス**: DOM の追加/削除ではなく CSS グリッドの遷移のみなので、再レンダリングコストが低い

---

## 2. モーダル / ダイアログ

**カテゴリ**: アコーディオン・モーダル
**難易度**: 高
**使用頻度**: ★★★★☆

### 概要

オーバーレイ付きのモーダルダイアログ。`<dialog>` 要素をベースに、
背景のフェードインとコンテンツのスケールインを組み合わせた上品な表示アニメーション。
フォーカストラップ・ESC キー閉じ・背景スクロールロックをブラウザネイティブで実現。

### 実装コード

```tsx
"use client";

import { useRef, useEffect, useCallback, type ReactNode } from "react";

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  /** モーダルのタイトル（アクセシビリティ用） */
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
      // dialog 要素自体がクリックされた場合 = 背景クリック
      if (e.target === dialogRef.current) {
        onClose();
      }
    },
    [onClose]
  );

  const handleCancel = useCallback(
    (e: React.SyntheticEvent<HTMLDialogElement>) => {
      e.preventDefault(); // デフォルトの即時閉じを防止
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

### CSS（必要な場合）

Tailwind の `open:` variant で `<dialog>` の open 状態を検知するため、追加 CSS は不要。

**`<dialog>` の閉じアニメーションについての注意**:
`<dialog>` 要素は `close()` 時に即座に `display: none` になるため、
閉じアニメーションをネイティブ CSS だけで実現するには `@starting-style`（Chrome 117+）が必要。
クロスブラウザ対応が必要な場合は、閉じ時に `data-closing` 属性を付与し `transitionend` で `close()` を呼ぶ方式に拡張する。

```css
/* 閉じアニメーションが必要な場合の拡張（オプション） */
dialog[data-closing] {
  opacity: 0;
  scale: 0.95;
}

dialog[data-closing]::backdrop {
  opacity: 0;
}
```

### 使い方

- **お問い合わせ確認**: フォーム送信前の確認ダイアログ
- **画像拡大表示**: ギャラリー画像の詳細ビュー
- **利用規約表示**: 長文コンテンツのポップアップ

```tsx
const [isOpen, setIsOpen] = useState(false);

<button onClick={() => setIsOpen(true)}>お問い合わせ内容を確認</button>

<Modal
  isOpen={isOpen}
  onClose={() => setIsOpen(false)}
  title="送信内容の確認"
>
  <p>以下の内容で送信します。よろしいですか？</p>
  <div className="mt-4 flex justify-end gap-3">
    <button onClick={() => setIsOpen(false)} className="rounded-lg px-4 py-2 text-sm text-gray-600 hover:bg-gray-100">
      キャンセル
    </button>
    <button onClick={handleSubmit} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
      送信する
    </button>
  </div>
</Modal>
```

### 注意点

- **`<dialog>` 要素**: フォーカストラップ・ESC キー閉じ・`inert` による背景無効化がブラウザネイティブ。自前実装不要
- **背景スクロールロック**: `showModal()` 使用時はブラウザが自動でロックする
- **`::backdrop` 擬似要素**: Tailwind v4 の `backdrop:` variant で直接スタイル可能
- **`aria-labelledby`**: タイトルの `id` と紐付け済み。スクリーンリーダーがモーダルの目的を読み上げる
- **閉じアニメーション**: 前述の通り、開きアニメーションのみネイティブ対応。閉じは拡張が必要
- **Safari**: Safari 15.4+ で `<dialog>` 対応。HP 案件のブラウザサポート範囲内

---

## 3. ドロワー

**カテゴリ**: アコーディオン・モーダル
**難易度**: 中
**使用頻度**: ★★★★☆

### 概要

画面端からスライドインするパネル。モバイルナビゲーション、フィルターパネル、
サイドバーメニューに使用。`<dialog>` ベースでアクセシビリティを確保しつつ、
`translate-x` によるスライドアニメーションを実現。

### 実装コード

```tsx
"use client";

import { useRef, useEffect, useCallback, type ReactNode } from "react";

type DrawerSide = "left" | "right";

interface DrawerProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  title: string;
  /** スライド方向 */
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

### CSS（必要な場合）

追加 CSS は不要。`translate-x` 遷移は Tailwind のユーティリティで完結。

`<dialog>` の配置を画面端に固定するため、`m-0` で UA スタイルシートの `margin: auto` を上書きしている点に注意。

### 使い方

- **モバイルナビゲーション**: ハンバーガーメニュー → `side="left"`
- **フィルターパネル**: EC サイト等の絞り込み → `side="right"`
- **詳細パネル**: 一覧画面から詳細を横にスライド表示

```tsx
const [isNavOpen, setIsNavOpen] = useState(false);

{/* ハンバーガーボタン */}
<button
  onClick={() => setIsNavOpen(true)}
  aria-label="メニューを開く"
  className="md:hidden"
>
  <svg className="size-6" /* ハンバーガーアイコン */ />
</button>

<Drawer
  isOpen={isNavOpen}
  onClose={() => setIsNavOpen(false)}
  title="メニュー"
  side="left"
>
  <nav>
    <ul className="space-y-2">
      <li><a href="/" className="block rounded-lg px-3 py-2 hover:bg-gray-100">ホーム</a></li>
      <li><a href="/services" className="block rounded-lg px-3 py-2 hover:bg-gray-100">サービス</a></li>
      <li><a href="/contact" className="block rounded-lg px-3 py-2 hover:bg-gray-100">お問い合わせ</a></li>
    </ul>
  </nav>
</Drawer>
```

### 注意点

- **`h-dvh`**: `100dvh`（Dynamic Viewport Height）を使用。モバイルブラウザのアドレスバー表示/非表示に追従
- **`max-w-[85vw]`**: 小画面でドロワーが画面全体を覆わないよう制限。背景が見えることで「閉じられる」ことが直感的に伝わる
- **スクロール**: コンテンツが長い場合、`overflow-y-auto` でドロワー内スクロール。背景はブラウザがロック
- **閉じアニメーション**: モーダルと同様、`<dialog>` の `close()` は即座に非表示になる。閉じアニメーションが必要な場合は `transitionend` ハンドラで `close()` を遅延実行する
- **`prefers-reduced-motion`**: `motion-reduce:transition-none` でスライドアニメーション無効化

---

## 4. ローディングスピナー / スケルトンスクリーン

**カテゴリ**: ユーティリティ
**難易度**: 低
**使用頻度**: ★★★★★

### 概要

データ取得中の待機状態を表現する2つのパターン。
スピナーは短時間のローディングに、スケルトンはページレイアウトが予測できる場合に使用。
CLS（Cumulative Layout Shift）を防ぎ、体感速度を向上させる。

### 実装コード

```tsx
/* ========== スピナー ========== */

interface SpinnerProps {
  /** サイズ: sm=16px, md=24px, lg=40px */
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
  /** 円形（アバター用） */
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
      {/* 画像 */}
      <Skeleton className="mb-4 h-48 w-full" />
      {/* タイトル */}
      <Skeleton className="mb-2 h-5 w-3/4" />
      {/* 本文行1 */}
      <Skeleton className="mb-1.5 h-3.5 w-full" />
      {/* 本文行2 */}
      <Skeleton className="mb-1.5 h-3.5 w-full" />
      {/* 本文行3（短め） */}
      <Skeleton className="h-3.5 w-2/3" />
    </div>
  );
}

/* ========== ページスケルトン（レイアウト全体） ========== */

export function PageSkeleton() {
  return (
    <div className="space-y-6">
      {/* ヒーローエリア */}
      <Skeleton className="h-64 w-full" />
      {/* セクションタイトル */}
      <div className="mx-auto max-w-3xl space-y-3 px-4">
        <Skeleton className="mx-auto h-8 w-1/3" />
        <Skeleton className="mx-auto h-4 w-2/3" />
      </div>
      {/* カードグリッド */}
      <div className="mx-auto grid max-w-6xl grid-cols-1 gap-6 px-4 sm:grid-cols-2 lg:grid-cols-3">
        <CardSkeleton />
        <CardSkeleton />
        <CardSkeleton />
      </div>
    </div>
  );
}
```

### CSS（必要な場合）

Tailwind 組み込みの `animate-spin` と `animate-pulse` で完結。追加 CSS は不要。

```
animate-spin   → @keyframes spin { to { transform: rotate(360deg) } }
animate-pulse  → @keyframes pulse { 50% { opacity: .5 } }
```

`motion-reduce` 時:
- スピナー: 回転速度を 3 秒に減速（完全停止するとローディング中であることが伝わらない）
- スケルトン: パルスを停止し、やや濃いグレーの静的プレースホルダーに

### 使い方

- **ページ初期表示**: SSR/SSG の fallback として `PageSkeleton` を表示
- **データ取得中**: API レスポンス待ちに `Spinner` をボタン内やセクション中央に配置
- **画像ロード待ち**: `Skeleton` を `<Image>` の placeholder として使用
- **無限スクロール**: 追加データ取得時にリスト末尾に `CardSkeleton` を表示

```tsx
{isLoading ? (
  <div className="flex justify-center py-12">
    <Spinner size="lg" />
  </div>
) : (
  <div className="grid grid-cols-3 gap-6">
    {works.map((work) => (
      <WorkCard key={work.id} {...work} />
    ))}
  </div>
)}
```

### 注意点

- **`role="status"`**: スピナーにスクリーンリーダー対応。`aria-label` で「読み込み中」を明示
- **`aria-hidden="true"`**: スケルトンは装飾要素のため、支援技術から隠す
- **CLS 対策**: スケルトンの高さ・幅を実際のコンテンツと揃えること。ズレが大きいと CLS スコアが悪化
- **スケルトンの幅バリエーション**: テキスト行は `w-full` と `w-2/3` を交互にすると自然に見える
- **over-skeleton 注意**: 全要素をスケルトン化すると逆に遅く感じる。主要な視覚要素のみに絞る

---

## 5. トースト通知

**カテゴリ**: ユーティリティ
**難易度**: 中
**使用頻度**: ★★★★☆

### 概要

操作結果を一時的に表示するフローティング通知。画面右下からスライドインし、
一定時間後に自動消去される。フォーム送信成功・エラー通知・コピー完了など、
ユーザーの作業フローを中断しない非モーダルなフィードバックに使用。

### 実装コード

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

/* ========== アイコン ========== */

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
    // マウント後に表示アニメーション開始
    const showTimer = requestAnimationFrame(() => setIsVisible(true));

    // 自動消去
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

  const handleManualDismiss = () => {
    setIsLeaving(true);
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
        onClick={handleManualDismiss}
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

### CSS（必要な場合）

追加 CSS は不要。`translate-x` + `opacity` のトランジションで入退場を実現。

### 使い方

- **フォーム送信結果**: 成功 → `success`、エラー → `error`
- **コピー完了**: クリップボードコピー → `info`
- **入力警告**: バリデーション警告 → `warning`

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

### 注意点

- **`aria-live="polite"`**: トーストの出現をスクリーンリーダーが読み上げる。`assertive` は緊急時のみ
- **自動消去の時間**: 短いメッセージは 5 秒、エラーは 8 秒が目安。ユーザーが読み切れる時間を確保
- **手動閉じボタン**: 自動消去だけでなく、閉じボタンも必ず提供。WCAG 2.2.1（タイミング調整可能）
- **スタック表示**: `flex-col-reverse` で新しいトーストが下に追加される。最新が常に最下部
- **`motion-reduce`**: トランジション無効化時はフェードのみ（translate なし）で即座に表示
- **メモリリーク防止**: `transitionend` で DOM から削除。タイマーは `useEffect` の cleanup で解除
- **z-index**: `z-50` で他の要素の上に表示。モーダルと共存する場合は z-index の管理に注意

---

## ブラウザ対応表

| パターン | Chrome | Firefox | Safari | Edge |
|---------|--------|---------|--------|------|
| アコーディオン（grid-rows） | 107+ | 113+ | 16.4+ | 107+ |
| モーダル（`<dialog>`） | 37+ | 98+ | 15.4+ | 79+ |
| ドロワー（`<dialog>`） | 37+ | 98+ | 15.4+ | 79+ |
| スピナー / スケルトン | 全対応 | 全対応 | 全対応 | 全対応 |
| トースト | 全対応 | 全対応 | 全対応 | 全対応 |

---

## 共通設計方針

1. **framer-motion 不使用**: CSS transitions + React state で全パターンを実現。依存ゼロ
2. **Tailwind CSS v4**: `open:`, `backdrop:`, `motion-reduce:` variant を活用
3. **WAI-ARIA 準拠**: `<dialog>` のネイティブアクセシビリティ、`role="status"`, `aria-expanded` 等を適切に使用
4. **`prefers-reduced-motion`**: 全パターンで `motion-reduce:` によるアニメーション低減/無効化を実装
5. **コピペで動く**: 各パターンは単体でコピー&ペーストして即使用可能な完全な実装
