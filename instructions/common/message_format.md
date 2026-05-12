# Message Format（2026-04-19 制定）

## 原則: inbox は pointer 役、詳細は report.yaml

inbox メッセージは **10 行以内**を原則。詳細レポートは `queue/reports/{agent}_report.yaml` に report-v2 フォーマットで書き、inbox には pointer を置く。

## 行数制約

| 行数 | 扱い |
|------|------|
| 1-10 行 | 正常（通常運用） |
| 11-20 行 | inbox_write.sh が warning 出力（送信は成功） |
| 21 行以上 | inbox_write.sh が block（送信失敗、短文化を要求） |

例外: 司令官 → anzu の企画書伝達、anzu → miho の初回発令（complexity-rich context が必要な場面）は `--force` オプションで block 解除可能。ただし本来は別途 markdown/yaml ファイルで伝達を推奨。

## Pointer 3 点セット

トリガー判断に必要な「最小情報」は以下 3 点を必ず含める:

```
【pointer 3 点セット】
1. severity: CRITICAL / HIGH / MEDIUM / LOW / INFO
2. 担当範囲: 対象 agent or squad
3. pointer: report.yaml 行番号 or commit hash or file path
```

### 例

**良い例（10 行以内、pointer 3 点セット含む）**:
```
W-5 E2E-02 原因確定
- severity: MEDIUM 濃厚（Step 2 で最終確定）
- 担当: kay 隊（connectivity_service.dart L85-95）
- pointer: queue/reports/katyusha_report.yaml#L42、codex_reviews.jsonl:7
- 次アクション: Step 2 撮影許可の司令官判断待ち
```

**悪い例（40 行の長文報告 inbox 直送）**:
```
[severity + 動線降下 / W-5 E2E 緊急 / miho → anzu]

anzu、katyusha の真犯人 grep 特定 (msg_20260419_211836) を踏まえ、参謀長裁可降下します。

■ severity 判定: **MEDIUM 維持 (暫定)**、HIGH 昇格は...
（以下 30+ 行続く）
```
→ 詳細は report.yaml に書いて、inbox は pointer 3 点のみにする。

## Report.yaml の summary フィールド必須化

詳細 report を書く際、冒頭に `summary:` フィールド（3 行以内）を必須とする:

```yaml
# queue/reports/katyusha_report.yaml
summary: |
  W-5 E2E-02 apikey 欠落 client bug 確定、MEDIUM 濃厚。
  connectivity_service.dart L85-95 で pingSupabase() に apikey header 未付与。
  修正 PR は kay 隊起草予定、Step 2 撮影許可待ち。

# 以下詳細（上限なし）
detailed_findings:
  ...
```

受け手は summary を読んで「深読みするか、pointer のみで判断するか」を選べる。

## Codex verdict の扱い（T7 連動）

Codex の詳細 verdict は `queue/hq/codex_reviews.jsonl` に全文記録。
inbox には以下の 3 行以内サマリのみ流す:

```
Codex QC 完了 PR #86
- verdict: LGTM / Major 1 件 / Critical 2 件 etc.
- pointer: codex_reviews.jsonl:15
```

副隊長が severity calibration を行った場合は判断根拠も 1 行追記:
```
Codex QC 完了 PR #86
- verdict: Major (副隊長 calibration で Minor に再分類)
- reason: flutter analyze 未実行環境の過大評価、実体は hygiene
- pointer: codex_reviews.jsonl:15
```

## 根拠

2026-04-19 の運用データで miho の inbox が 127 KB / 平均 33 行/msg まで肥大化し、起動時 context 消費が 25k tokens 超となっていた。短文化 + report 分離で起動負荷を 1/5 に削減見込み。
