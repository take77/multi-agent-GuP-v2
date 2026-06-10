# spike-1: アカウント削除 進行中ジョブ orphan リスク調査 (redo v2)

**調査日**: 2026-05-30  
**担当**: caesar (katyusha隊)  
**対象リポ**: calsail-supabase (`supabase/functions/` + `supabase/migrations/`) + calsail-mobile  
**判定ルール**: データ喪失/orphan は invariant 案件。確率論で軽視禁止。  
**改訂理由**: nonna Codex adversarial-review FAIL(Critical) — ocr_corrections 欠落 + Claim2 事実誤認 + file:line 不一致

---

## 調査サマリ

| 観点 | ジョブ完了待ち要否 | 結論 |
|------|------------------|------|
| 1. webhook 再生成リスク | **不要** | UPDATE-only + CASCADE 削除済み = 0-row update。.deleted 500 パスは Minor ノイズ |
| 2. OCR / batch-ocr 同期性 | **不要** | ocr-process は user_profiles UPDATE あり（Claim2 訂正）。orphan-safety は CASCADE+verifyAuth で保証 |
| 3. ストレージ削除の原子性 | **削除順序 7 step 必須** | ocr_corrections(00004) が 2 本の RESTRICT FK で既存 6 step を破る Critical 欠落を修正 |

---

## 観点1: webhook 再生成リスク

### 調査コード

**Stripe webhook — `user_profiles` への書き込みは全て `.update()` のみ:**

```
webhook-stripe/index.ts:263  .update({subscription_status:..., ...})  // checkout.session.completed
webhook-stripe/index.ts:303  .update({subscription_status:..., ...})  // invoice.paid
webhook-stripe/index.ts:377  .update(updatePayload)                   // customer.subscription.updated
webhook-stripe/index.ts:433  .update({subscription_status:..., ...})  // customer.subscription.deleted
```

INSERT/UPSERT は grep 0 件。INSERT をしているのはコード内にない。

**RevenueCat webhook — 同様に `.update()` のみ:**

```
webhook-revenuecat/index.ts:240  .from("user_profiles")
webhook-revenuecat/index.ts:241  .update(updateData)
webhook-revenuecat/index.ts:242  .eq("id", userId)
```

**user_profiles FK (00001_init_schema.sql:14):**
```sql
id uuid primary key references auth.users(id) on delete cascade,
```
auth.users 削除 → user_profiles が CASCADE 削除 → 後着 webhook の `.update().eq("id", userId)` は 0-row で終了。

**【Minor: customer.subscription.deleted 500 パス (webhook-stripe/index.ts:405-417)】**

```typescript
// webhook-stripe/index.ts:405
const { data: currentProfile, error: fetchError } = await serviceClient
  .from("user_profiles").select("subscription_status").eq("id", userId).single();
// :411-417
if (fetchError || !currentProfile) {
  return new Response(JSON.stringify({ success: false, ... }), { status: 500 ... });
}
```

user_profiles が CASCADE 削除済みの場合、`.single()` は null を返し 500 を返す。
これは **Stripe に無限リトライを誘発する運用ノイズ**（orphan 生成はしない）。
→ 推奨ガード: `!currentProfile` 時に 200 skip（nonna / caesar hardening 案 #3 と一致）。

### 結論

**ジョブ完了待ち: 不要**  
核心 invariant（削除データ非再生成）は UPDATE-only + CASCADE で成立。  
customer.subscription.deleted の 500 パスは Minor（運用ノイズ）、orphan 生成なし。

---

## 観点2: OCR / batch-ocr 同期性

### 【Claim2 訂正】ocr-process は user_profiles を UPDATE する

前回レポートの「DB/storage への書き込みは一切ない」は**事実誤認**。以下を訂正する。

**checkOcrLimit の月次リセット fallback (_shared/subscription.ts:131-137):**

```typescript
// _shared/subscription.ts:131
.from("user_profiles")
.update({
  monthly_ocr_count: 0,
  monthly_ocr_reset_at: nextMonthStart.toISOString(),
})
.lt("monthly_ocr_reset_at", now.toISOString());
```

**incrementOcrCount RPC (ocr-process/index.ts:445):**

```typescript
await incrementOcrCount(supabase, user.id);
// → _shared/subscription.ts:263 → rpc("increment_monthly_ocr_count", ...)
// → 00003_subscription.sql:86-94 の user_profiles.monthly_ocr_count += 1
```

これらはいずれも `user_profiles` の UPDATE。auth.users 削除後は user_profiles が CASCADE 削除済みのため
`.update().eq("id", userId)` は 0-row update → orphan 生成なし（orphan-safety は成立するが根拠が変わる）。

**batch-ocr は DB 書き込みなし（grep 確認、主張通り）。**

### OCR 修正パス: ocr_provider.dart:190 による直 INSERT

receipt-save を経由しない別の書き込みパスが存在する。

```dart
// calsail-mobile/lib/providers/ocr_provider.dart:190
await client.from('ocr_corrections').insert({
  'user_id': userId,
  'receipt_id': receiptServerId,
  'original_json': original.toJson(),
  'corrected_json': corrected.toJson(),
  'corrected_fields': correctedFields,
  'image_path': imagePath,
});
```

このパスは **receipt-save を経由せず client が ocr_corrections テーブルに直接 INSERT** する。
JWT ガードは有効（Supabase client は JWT を用いる）のため、auth.users 削除後は 401 でブロックされる。
ただし **ocr_corrections 自体はアカウント削除時に明示的削除が必要**（→ 観点3 参照）。

### receipt-save の二重保護（line 訂正）

```
receipt-save/index.ts:147  const { user } = await verifyAuth(req);
  // 第1ガード: auth.users 削除後は JWT 即時無効化 → 401

receipt-save/index.ts:253  .from("receipts").insert({ user_id: userId, ... })
  // 第2ガード: 00001:28 receipts.user_id FK → auth.users(id) RESTRICT
  //   auth.users なき user_id への INSERT は FK violation で失敗
```

### 結論

**ジョブ完了待ち: 不要**  
ocr-process の user_profiles UPDATE は CASCADE 削除後に 0-row で終了（orphan なし）。  
receipt-save は JWT guard + FK の二重保護で orphan 生成は invariant で防止。  
ocr_corrections は JWT ガードで削除後の新規 INSERT は不可。既存データは削除順序で対処（観点3）。

---

## 観点3: ストレージ削除の原子性

### FK 完全マトリクス（migration 現物 grep 結果）

| テーブル | FK 列 | 参照先 | ON DELETE | 手動削除 |
|---------|-------|-------|-----------|---------|
| `user_profiles` (00001:14) | `id` | `auth.users(id)` | **CASCADE** | 自動 |
| `receipts` (00001:28) | `user_id` | `auth.users(id)` NOT NULL | **RESTRICT** | **要** |
| `receipt_items` (00001:61) | `receipt_id` | `receipts(id)` | **CASCADE** | receipts 削除で連鎖 |
| `receipt_audit_log` (00001:75) | `receipt_id` | `receipts(id)` | **SET NULL** | 不要（自動 NULL 化） |
| `receipt_audit_log` (00001:76) | `user_id` | `auth.users(id)` nullable | **RESTRICT** | **要** |
| `custom_categories→categories` (00001:90) | `user_id` | `auth.users(id)` NOT NULL | **RESTRICT** | **要** (source='custom' 行) |
| `receipt_images` (00001:101) | `receipt_id` | `receipts(id)` | **CASCADE** | receipts 削除で連鎖 |
| `user_store_rules` (00001:115) | `user_id` | `auth.users(id)` NOT NULL | **RESTRICT** | **要** |
| `user_category_settings` (00021:25) | `user_id` | `auth.users(id)` NOT NULL | **CASCADE** | 自動 |
| ★ **`ocr_corrections` (00004:3)** | `user_id` | `auth.users(id)` NOT NULL | **RESTRICT** | **要（v1 で欠落）** |
| ★ **`ocr_corrections` (00004:4)** | `receipt_id` | `receipts(id)` NOT NULL | **RESTRICT** | **要（v1 で欠落）** |

`contact_submissions`(00016): auth.users FK なし（匿名 LP フォーム）→ 削除対象外で正しい。  
`subscription`/`stripe_customer_id`(00003/00007): user_profiles のカラム追加のみ → 別テーブル不在。

### ocr_corrections の致命的欠落（Critical — 修正済み）

```sql
-- 00004_create_ocr_corrections.sql:3
user_id UUID REFERENCES auth.users(id) NOT NULL,       -- RESTRICT
-- 00004_create_ocr_corrections.sql:4
receipt_id UUID REFERENCES receipts(id) NOT NULL,       -- RESTRICT
```

ocr_corrections は **2 本の RESTRICT FK** を持つ。旧 6 step では：
- step3: `DELETE receipts WHERE user_id=$1` → ocr_corrections.receipt_id RESTRICT → **FK 違反で失敗**
- step6: `auth.admin.deleteUser` → ocr_corrections.user_id RESTRICT → **FK 違反で失敗**

本番書き込み実績あり（ocr_provider.dart:190）。OCR 修正を 1 回でも行ったユーザーで構造的に必ず削除が失敗する。**invariant 破れ。**

### 推奨削除フロー（7 step に修正）

```
① storage.remove receipts/{user_id}/**
  （best-effort: 失敗は storage_cleanup_failed: true でログ → DB 削除は継続）

② DELETE FROM ocr_corrections WHERE user_id = $1
  （receipt_id → receipts RESTRICT のため step③ より前に必須）
  （user_id → auth.users RESTRICT のため step⑦ より前にも必須）

③ DELETE FROM receipts WHERE user_id = $1
  （CASCADE → receipt_items 自動削除: 00001:61）
  （CASCADE → receipt_images 自動削除: 00001:101）
  （SET NULL → receipt_audit_log.receipt_id が NULL に: 00001:75）

④ DELETE FROM receipt_audit_log WHERE user_id = $1
  （user_id → auth.users RESTRICT: 00001:76）

⑤ DELETE FROM categories WHERE user_id = $1
  （source='custom' 行のみ対象。RESTRICT: 00001:90 / 00010:12 RENAME）

⑥ DELETE FROM user_store_rules WHERE user_id = $1
  （RESTRICT: 00001:115）

⑦ auth.admin.deleteUser(userId)
  （CASCADE → user_profiles 自動削除: 00001:14）
  （CASCADE → user_category_settings 自動削除: 00021:25）
```

### 孤児（orphan）発生ケース

| ケース | 何が起きるか | 対処 |
|--------|-------------|------|
| ① storage 削除失敗 | ファイルが storage に残存（auth 消失→ RLS ブロック、アクセス不可だがプライバシー問題） | `storage_cleanup_failed: true` を EF レスポンスに含める。呼び出し元でログ記録、後日 cleanup |
| ⑦ deleteUser で FK 違反 | ②〜⑥ に漏れがある場合のみ。本順序を厳守すれば発生しない | 本 7 step で invariant 保証 |

### webhook 再生成ブロック手段（案）

| 手段 | コスト | 推奨度 |
|------|--------|--------|
| A. FK 制約のみ（現状） | なし | v1 では十分 |
| B. webhook handler 先頭で profile 存在確認 → 不在は 200 skip | 小 | hardening 推奨（.deleted の 500 ループ解消） |
| C. 削除済みフラグ `user_profiles.deleted_at` | 中 | 将来 |

---

## 結論まとめ

| 観点 | ジョブ完了待ち | 削除前の必須対処 |
|------|--------------|----------------|
| webhook 再生成 | **不要** | なし（Minor: .deleted 500 パスは 200 skip guard 推奨） |
| OCR / batch-ocr | **不要** | ocr_corrections の明示削除（7 step 順序で対処済み） |
| storage 原子性 | N/A | **削除 7 step 厳守**（ocr_corrections を step② に追加） |

---

*Codex adversarial-review (nonna): FAIL(Critical) → 本 v2 で全 redo_item 対応済み。*
