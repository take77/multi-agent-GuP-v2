# spike-2: OAuth 再認証の実装方式（アカウント削除フロー④）

**調査日**: 2026-05-30  
**最終確定**: erika rev3 条件付きLGTM 4要件 反映済み（R1/R3/R4/R6）  
**担当**: fukuda (maho隊)  
**katyusha 連携**: 完了（inbox msg_20260530_003310_afcaf3e8 + msg_20260530_022708_08a0c827）  
**erika QC**: R3/R1/R4/R6 反映 → clean 再QC 待ち  
**対象リポ**: calsail-mobile (`lib/services/auth_service.dart` 中心)  
**参照**: directive_release_account_deletion.md §1/§2, spike-1 結論, erika_report.yaml R3_local_auth_spec, codex_reviews.jsonl:14  
**判定ルール**: セキュリティ critical は invariant 保証で判定。確率論で軽視禁止。

---

## 調査サマリ（確定版）

| 精査項目 | 結論 |
|---------|------|
| 1. identity 一致検証方式 | **fresh Supabase セッション + EF verifyFreshAuth**（GoTrue がサインイン時に検証済み）|
| 2. 方式選択 | **OAuth 再サインイン採用**（Supabase reauthenticate() は利用不可） |
| 3. user-presence 保証（R3 確定） | **local_auth 生体ゲート MANDATORY**（全 provider 一律・再認証前・fail-closed） |
| 4. Supabase reauth API 可否 | **利用不可**（OTP/email 前提）。EF は verifyFreshAuth（amr.method allowlist + timestamp ≤120s MANDATORY）で代替 |
| R4. fresh-token handoff | **AuthResponse.session / currentSession のみ（古いキャッシュ token 禁止 MANDATORY）** |
| R6. 残余リスク | **鮮度窓内 bearer replay リスクを明文化**（多層縮小するが ゼロではない） |

---

## 精査項目1: identity 一致検証の具体方式（確定）

### 現物確認（grep 結果）

**現在の signIn 実装（auth_service.dart:31-99）**

```dart
// Apple: identity token（JWT）を取得 → Supabase に渡す
final credential = await SignInWithApple.getAppleIDCredential(...);
final idToken = credential.identityToken;
await _client.auth.signInWithIdToken(
  provider: OAuthProvider.apple,
  idToken: idToken,
  nonce: rawNonce,
);

// Google: id_token（JWT）を取得 → Supabase に渡す
final googleAuth = await googleUser.authentication;
await _client.auth.signInWithIdToken(
  provider: OAuthProvider.google,
  idToken: googleAuth.idToken,
  accessToken: googleAuth.accessToken,
);
```

**signInWithIdToken の動作（gotrue-2.18.0, gotrue_client.dart:398-423）**

```dart
// GoTrue サーバーが Apple/Google ID token を JWKS 検証 → 正規ユーザーかを確認
// 検証通過後に Supabase 独自 JWT（access token）を発行
_saveSession(authResponse.session!);
notifyAllSubscribers(AuthChangeEvent.signedIn);
```

### 採用方式: fresh OAuth サインイン → fresh Supabase セッション → EF verifyAuth

**katyusha の回答（要約）**:  
> GoTrue は `signInWithIdToken()` 内で Apple/Google の ID token を JWKS で検証し、
> Supabase 独自 JWT を発行する。全 EF は `_shared/auth.ts` の `verifyAuth`
> （= `supabase.auth.getUser(Authorization ヘッダ)`）でサーバー検証するパターンで統一。
> delete-account EF も同パターンに従う。fresh セッション（mobile が削除直前に OAuth 再実行）
> が再認証の証拠になる。identity 一致は Supabase が保証（GoTrue が既に検証済み）。

**フロー（erika R3 反映・確定版）**:

```
Step 0 [mobile]: ★ local_auth でデバイス認証（R3: MANDATORY・fail-closed・全 provider 一律）
         → authenticate(biometricOnly:false, stickyAuth:true)
         → authenticated == true のみ Step 1 へ続行
         → cancel / error / 未登録端末 = 削除フロー中止（素通り禁止）
         ★ 配置 = signInWith~ の【前】（後置は fresh token 先取り窓が生じる）

Step 1 [mobile]: signInWithApple() または signInWithGoogle() を再実行
         → GoTrue が Apple/Google ID token を JWKS 検証
         → 検証通過 = 同一アカウントであることを GoTrue が保証
         → fresh Supabase access token が発行される（新規セッション）

Step 2 [mobile]: delete-account EF を fresh access token つきで呼び出す
         ★ R4 MANDATORY: token は再認証 await 完了後の AuthResponse.session
           または currentSession の token のみ。古いキャッシュ token の使用禁止。
         Authorization: Bearer {fresh_access_token}

Step 3 [EF: delete-account]: verifyFreshAuth(req, 120)
         = verifyAuth(getUser) + amr.method allowlist filter + timestamp ≤120s
         → user.id を権威として取得（詳細: §1 verifyFreshAuth 要件）

Step 4 [EF]: user.id をキーに spike-1 の削除順序で全データを削除
         （storage → receipt_audit_log → receipts → categories → user_store_rules → auth.users）
```

**identity 一致の保証**:
- GoTrue は `signInWithIdToken()` で Apple/Google ID token を JWKS 検証する
- 検証通過した token の `sub` が `auth.identities.identity_id` に一致しない限り、Supabase はセッションを発行しない
- したがって EF が受け取る `user.id` = 再認証を通過したアカウントの ID → identity 一致は Supabase の内部保証

**「別アカウント再認証」シナリオの安全性**:
- 攻撃者が被害者の端末で「自分の」Google/Apple アカウントで再認証した場合
  - `signInWithIdToken()` により自分のセッションに切り替わる
  - EF は「攻撃者のアカウント」の user.id を取得 → 攻撃者自身のデータを削除する
  - 被害者のデータには一切触れない → **被害者は保護される**
- この設計で「最後の砦」（第三者による被害者アカウント削除防止）は成立

**✅ MANDATORY セッション鮮度チェック — fail-closed 確定版（katyusha R1 nonna QC LGTM 02:40）**:

**権威実装**: `calsail-supabase/docs/spike/spike2_r1_reauth_marker.md` L205-247  
（commit 4b2d1f3 / `release/account-deletion` ブランチ）

```
verifyFreshAuth() の確定要件（fail-closed 必須）:
1. verifyAuth(req) → getUser(access_token) でサーバー側 JWT 署名検証 → user 取得
2. JWT payload を decode し amr を取得。無ければ throw（fail-closed）
3. ★ R1 MANDATORY: amr[*].method を allowlist でフィルタし、認証イベントのみ残す
   allowlist = ['oauth', 'password', 'otp', 'totp', 'magiclink', 'sso'] 等の認証メソッド
   'token_refresh' 等の非認証イベントを除外（silent refresh で窓を満たすことを防ぐ）
   【cross-squad: katyusha 隊 / caesar による calsail-supabase 側への追加実装が必要】
4. ★ 各 amr timestamp を filter(t => Number.isInteger(t) && t > 0) で検証
   validTimestamps.length === 0 なら throw
   （NaN/null 混入で Math.max → NaN → NaN > 120 = false になる fail-open を防ぐ）
5. lastAuthTime = Math.max(...validTimestamps)  ← amr[0] 固定でなく max
6. ageSeconds = floor(Date.now()/1000) - lastAuthTime
   (!Number.isFinite(ageSeconds) || ageSeconds < 0 || ageSeconds > 120) → throw
   （未来タイムスタンプ / NaN / 期限切れを全て fail-closed）
```

**`iat` は使用不可（確定）**:  
`iat` は silent token refresh で更新されるため、再認証イベント時刻を保持しない。  
一次ソース: GoTrue `internal/models/sessions.go` `CalculateAALAndAMR` が  
`AMREntry.Timestamp = claim.UpdatedAt.Unix()` を read-only 参照。  
silent refresh は `session.RefreshedAt` のみ更新 → `amr.timestamp` は認証イベント時刻として不変。

**nonna 指摘（任意）clock skew 考慮**:  
EF の時刻が GoTrue より遅延すると `ageSeconds < 0` で正当な要求も誤拒否し得る。  
`ageSeconds >= -5` の小さな負許容を入れると clock skew 誤拒否を避けられる。  
安全を優先する場合は厳格な fail-closed（`ageSeconds < 0` も throw）のままでよい。

**不採用（katyusha R1 で明示却下）**:
- `iat` クレーム = silent refresh で更新される → 鮮度チェックに使えない
- `user_metadata` = client 偽造可能
- `reauth_events` テーブル = 削除カスケードで自テーブルも消える循環依存

### 却下した代替案

| 案 | 却下理由 |
|----|---------|
| client-side sub 比較（pre-Supabase JWT decode） | client-trusted = client 側で改竄可能。katyusha 明示却下 |
| EF 側 JWKS 署名検証 + auth.identities 突合 | GoTrue が既にサインイン時に検証済み。冗長。既存 verifyAuth パターンと不整合 |
| signInWithIdToken 後に user.id 比較 | EF verifyAuth で代替できるため不要 |

---

## 精査項目2: Supabase reauth / OAuth 再サインインの方式選択（確定）

### Supabase reauthenticate() の調査結果

**根拠コード（gotrue-2.18.0, gotrue_client.dart:627-644）**

```dart
/// Sends a reauthentication OTP to the user's email or phone number.
///
/// Requires the user to be signed-in.
Future<void> reauthenticate() async {
  await _fetch.request('$_url/reauthenticate', RequestMethodType.get, ...);
}
```

GoTrue の `/reauthenticate` は **メールまたは電話番号に OTP を送信する**。  
calsail は OAuth-only（メール/パスワードなし、電話登録なし）なので OTP 送付先がない。

→ **`reauthenticate()` は利用不可。**（SDK コード現物確認 + katyusha 確認で二重確定）

### 採用方式: OAuth 再サインイン（Apple/Google native SDK 再呼び出し）

**採用理由**:
- OAuth-only 環境で利用できる唯一の再認証手段
- 既存の `signInWithApple()` / `signInWithGoogle()` コードをそのまま再利用できる
- fresh Supabase セッション = katyusha 隊の verifyAuth パターンと完全整合

---

## 精査項目3: user-presence 保証 — local_auth MANDATORY（erika R3 確定仕様）

### R3 の核心: amr.timestamp = signInWithIdToken 発行時刻 NOW（断定）

`signInWithIdToken()` で id_token grant が実行されると、GoTrue はその処理時刻（= NOW）を  
`AMREntry.Timestamp` として書き込む。つまり **`amr.timestamp` = 「GoTrue がサインイン処理した時刻」**。

これは「ユーザーが端末を操作した時刻」を保証しない。

### Google silent re-auth が user-presence なしに 120s 窓を通過し得る

Google Sign-In SDK の `shouldRecoverAuth: true`（デフォルト）により、キャッシュ済みアカウント・  
トークンが有効な場合、**ユーザー操作なし**で `signInWithIdToken` が完了することがある。  
このとき GoTrue は NOW で `amr.timestamp` を生成 → 120s 窓を通過する。

**現物確認**: calsail-mobile の `pubspec.yaml` に `local_auth` は **NOT PRESENT**（grep 確認済み）。  
→ 現状、user-presence を保証するゲートが存在しない。

### ⚠️ IdP 生体認証（Apple Face ID など）は user-presence の保証外

Apple `signInWithApple()` で Face ID が求められるのは、iOS が ASAuthorizationController で  
Apple ID credential を取得する際の OS 挙動であり、アプリが制御できない。  
**アプリ側から「必ず生体認証を要求した」ことを invariant として保証できない。**

→ **`local_auth`（Flutter app 制御の端末認証）のみが我々が握る唯一の user-presence 保証。**

### local_auth ゲート — MANDATORY 確定仕様（erika rev3 spec）

| 要件 | 仕様 |
|------|------|
| **対象** | 全 provider 一律（Apple Sign In・Google Sign In）例外なし |
| **配置** | `signInWith~` の**前**（後置すると fresh token が先に発行される窓が生じる） |
| **コール** | `authenticate(biometricOnly: false, stickyAuth: true)` |
| **fail-closed** | `authenticated == true` のみ削除フロー続行 |
| **中止条件** | cancel / error / 未登録端末（生体未登録）→ 削除フロー中止。素通り禁止 |
| **signOut 先行** | 不要（presence は local_auth が担う。signOut は削除フロー後に EF が実施） |

### impl note（後続 UI④ タスクで実装・本 spike では仕様記載のみ）

```
pubspec.yaml:
  local_auth: ^2.x.x  ← 現状 NOT PRESENT。UI④ で追加。

使用箇所（削除確認ボタン → 再認証の間）:
  final localAuth = LocalAuthentication();
  final authenticated = await localAuth.authenticate(
    localizedReason: 'アカウント削除を確認してください',
    authMessages: [...],
    options: const AuthenticationOptions(
      biometricOnly: false,  // PIN/パターン等も許可（未登録端末対応）
      stickyAuth: true,      // 画面遷移中も認証維持
    ),
  );
  if (!authenticated) {
    // 削除フロー中止（fail-closed）
    return;
  }
  // ここで signInWithApple() or signInWithGoogle() を実行

iOS: ios/Runner/Info.plist
  <key>NSFaceIDUsageDescription</key>
  <string>アカウント削除の本人確認に使用します</string>

Android: android/app/src/main/AndroidManifest.xml
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

### UX（参考）

| プロバイダ | local_auth UX | IdP フロー UX |
|-----------|--------------|-------------|
| Apple（iOS） | Face ID / Touch ID（端末設定による） | ASAuthorizationController（OS 管理） |
| Google（Android） | 指紋 / PIN（端末設定による） | アカウント picker 経由（1-2 tap） |
| Google（iOS） | Face ID / Touch ID（端末設定による） | WebView 経由の可能性あり |

---

## 精査項目4: Supabase 側 reauth API の可否（katyusha 連携完了）

### katyusha 回答 R0（inbox msg_20260530_003310_afcaf3e8）

**Q1: GoTrue v2 に OAuth-only ユーザーの ID token を session 切替なしで verify する公式 API があるか？**

> GoTrue v2 に「OAuth-only ユーザーの第三者 ID token を session 切替なしでサーバー側 verify する公式 API」は存在しない。`/reauthenticate` が OTP/email 前提なのは確認通り。Supabase の整合機構は「Supabase アクセストークン(JWT)そのものが検証済み資格情報」であり、全 EF が `_shared/auth.ts` の `verifyAuth = supabase.auth.getUser(Authorization ヘッダ)` でサーバー検証している。鮮度をサーバー側で強制したいなら JWT クレーム(session age/iat)を見る余地はあるが、第三者 ID token を再 verify する単独 API は GoTrue にない。

→ **GoTrue v2 に該当 API は存在しない（確定）。**

**Q2: EF 側での再認証検証の推奨方式（mobile 側 sub 比較 vs EF-side JWKS 検証）**

> ①mobile 側 ID token sub 比較 = client-trusted で弱い（却下）  
> ②EF 側 JWKS 署名検証+auth.identities 突合 = 冗長（GoTrue がサインイン時に既に検証済み）  
> ①②とも既存 `_shared/auth.ts` パターン（全 EF 共通）と不整合。  
> **delete-account EF は verifyAuth → user.id を権威として扱い、fresh セッション必須（mobile が直前に OAuth 再実行）で再認証を満たす。**  
> provider 確認に user.identities 参照は可だが、token 自体がユーザー証明なので identity 一致は暗黙成立。

→ **採用方式: EF verifyAuth + fresh セッション（katyusha 確定）。**

### katyusha 回答 R1 — Codex QC 確定（inbox msg_20260530_022708_08a0c827）

> nonna Codex QC で再認証の核 approach が確定。  
> **確定方針**: delete-account EF は `verifyFreshAuth()` = `getUser(verifyAuth)` + JWT の `amr` エントリの `timestamp`（認証イベント時刻）で鮮度 ≤ 120s を MANDATORY チェック。複数 amr エントリは `max(timestamp)` を採る（`amr[0]` 固定でなく）。**`iat` は silent refresh で更新されるため不可**。  
> **linchpin 実証済み（一次ソース）**: GoTrue `internal/models/sessions.go` `CalculateAALAndAMR` が `AMREntry.Timestamp = claim.UpdatedAt.Unix()` を read-only 参照。silent refresh は `session.RefreshedAt` のみ更新 → `amr.timestamp` は認証イベント時刻として保たれる。  
> **R3 不採用**: `user_metadata` = client 偽造可 / `reauth_events` table = 循環依存（削除カスケードで自テーブルも消える）。  
> **⚠️ fail-closed 実装必須**: 非有限 timestamp で `Math.max → NaN → 比較 false → ゲート通過`（fail-open バグ）。各 timestamp を有限正整数検証→異常は throw。  
> **fail-closed 版 code は caesar redo（`spike2_r1_reauth_marker_caesar`）完了後に共有。approach はこれで固定。**

→ **鮮度チェックは `amr.timestamp` MANDATORY（`iat` 不可）、fail-closed 実装必須（katyusha R1 QC 確定）。**

### katyusha 回答 R2 — fail-closed 確定版コード共有（inbox msg_20260530_024152_6764c181）

> nonna 差分 QC LGTM (02:40) で R1 確定。  
> 権威実装: `calsail-supabase/docs/spike/spike2_r1_reauth_marker.md` L205-247 (commit 4b2d1f3 / `release/account-deletion`)。  
> **key ポイント（fail-closed 必須）**:  
> (1) verifyAuth(getUser) で署名検証 → user 取得  
> (2) JWT payload decode → amr 取得、無ければ throw  
> (3) ★ `.filter(t => Number.isInteger(t) && t > 0)` で有限正整数チェック → length===0 なら throw  
> (4) `lastAuthTime = Math.max(...validTimestamps)` (amr[0] 固定でなく max)  
> (5) `ageSeconds = now - lastAuthTime`、`!isFinite || <0 || >120` で throw（全パターン fail-closed）  
> **linchpin（実証済み）**: `amr.timestamp` は GoTrue silent refresh で不変（認証イベント時刻）。`iat` は更新されるので不可。  
> **任意（nonna）**: `ageSeconds < 0` の clock skew 許容 `>= -5s` 検討可。安全側は厳格 fail-closed でよい。

→ **spike-2 完全確定。実装は spike2_r1_reauth_marker.md L205-247 をベースとすること。**

---

## R6: bearer replay 残余リスクの明文化（erika rev3 要件）

本方式で鮮度窓（≤120s）+ amr method allowlist + local_auth 生体 + TLS + secure storage の  
多層防御を組み合わせるが、以下の残余リスクはゼロにできない。

**残余リスク: 鮮度窓内の bearer token 窃取・リプレイ**

| 攻撃シナリオ | リスク評価 |
|-------------|----------|
| 120s 窓内に攻撃者が fresh access token を傍受・リプレイ | **残余リスク**（軽減されているが ゼロではない） |
| TLS 終端後の token 露出 | TLS + secure storage で縮小。ゼロではない |
| memory dump による token 窃取 | 短窓（120s）で時間的制限。ゼロではない |

**多層縮小策（本方式で実施）**:
- 鮮度窓 ≤ 120s → 有効時間を制限
- amr method allowlist → 非認証イベントを鮮度判定から除外
- local_auth 生体ゲート → user-presence を端末側で保証
- TLS → 通信路での傍受を防止
- flutter_secure_storage → token の安全な保管

**明記**: 上記の多層は「攻撃コストを引き上げる」ものであり、  
**「このフローは絶対安全」と断言することはできない。**  
数値窓（≤120s）のみで安全性を保証するような誤解を与えてはならない。

---

## 結論（最終確定版）

### 採用方式

```
削除フロー④ 再認証 = 「OAuth 再サインイン → fresh Supabase セッション → EF verifyAuth 検証」
```

### 実装概要

```
[mobile]
0. ★ R3 MANDATORY: local_auth でデバイス認証
   authenticate(biometricOnly:false, stickyAuth:true)
   authenticated != true → 削除フロー中止（fail-closed）

1. signInWithApple() or signInWithGoogle() を再実行（Step 0 通過後のみ）
   → GoTrue が Apple/Google ID token を JWKS 検証し fresh access token を発行

2. ★ R4 MANDATORY: AuthResponse.session / currentSession の fresh token のみ使用
   delete-account EF を fresh access token で呼び出す
   Authorization: Bearer {fresh_access_token}
   （古いキャッシュ token 禁止）

[EF: delete-account（新規作成・calsail-supabase）]
3. await verifyFreshAuth(req, 120)  // 権威実装: spike2_r1_reauth_marker.md L205-247
   ★ R1 追加要件: amr[*].method allowlist filter（token_refresh 除外）→ max(timestamp)
   → verifyAuth(getUser) + amr.method allowlist + timestamp MANDATORY チェック（fail-closed）
   → user.id を権威として取得

4. spike-1 の削除順序（storage → DB → auth.users）で全データを削除
```

**✅ verifyFreshAuth の fail-closed 確定コード: `calsail-supabase/docs/spike/spike2_r1_reauth_marker.md` L205-247（commit 4b2d1f3）**  
**⚠️ R1 amr method allowlist は上記確定コードへの追加要件（katyusha 隊 cross-squad 実装必要）**

### 方式選択（最終確定）

- **採用**: local_auth デバイス認証ゲート（全 provider 一律・再認証前・fail-closed）— R3 確定
- **採用**: OAuth 再サインイン（Apple / Google native SDK）
- **採用**: EF `verifyFreshAuth` = verifyAuth + amr.method allowlist + `amr.timestamp` ≤ 120s MANDATORY（fail-closed）— R1 反映
- **採用**: fresh-token-only handoff（AuthResponse.session のみ）— R4
- **不採用**: Supabase `reauthenticate()` → OTP/email 前提で OAuth-only 環境に利用不可
- **不採用**: client-side sub 比較 → client-trusted で弱い（katyusha 明示却下）
- **不採用**: EF-side JWKS 検証 → GoTrue 内部で既に検証済み、verifyAuth と不整合
- **不採用**: `iat` クレームによる鮮度チェック → silent refresh で更新されるため不可（katyusha R1 確定）

---

## 次アクション

| アクション | 担当 | 状態 |
|-----------|------|------|
| erika rev3 4要件を doc 反映 | fukuda | ✅ 完了（本タスク） |
| erika clean 再QC | erika | maho 報告後 |
| maho claim-integrity → miho 上程 | maho | erika clean 後 |
| fail-closed 確定コード（spike2_r1_reauth_marker.md） | caesar (katyusha 隊) | ✅ 完了（commit 4b2d1f3） |
| verifyFreshAuth R1 amr method allowlist 追加実装 | katyusha 隊（cross-squad） | maho→miho 経由で binding 予定 |
| delete-account EF 実装（verifyFreshAuth 組み込み） | katyusha 隊 | spike 確定後 着手可 |
| mobile 削除フローUI④: local_auth + OAuth re-auth + EF 呼び出し | maho 隊（fukuda） | 後続 UI④ タスク |
