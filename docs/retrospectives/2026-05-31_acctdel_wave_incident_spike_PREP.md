# 反省会準備: アカウント削除 Wave 事故連発（2026-05-30〜31）— PREP

> **状態**: 準備（データ収集のみ）。5 Whys の深掘り・原因確定・アクション確定は **2026-05-31 本反省会**で。
> **依頼**: 司令官（2026-05-31 深夜）「GuP_v2 に手を加えてから詰まることが多い。事故データ収集→分類→原因究明で進めたい」。
> **anzu 注記**: 記憶が新しいうちの事故キャプチャが最大価値ゆえ夜間に骨子だけ確保。本番で各隊の一次データ（task YAML / report / codex_reviews.jsonl / inbox archive）と突合して精緻化する。

## アジェンダ（テンプレ v1.0 準拠 — [[2026-04-19_w5_e2e02_halt]]）
1. 事案サマリ
2. 時系列（factual）
3. 事故データ収集（分類別）
4. 5 Whys（本番）
5. 横展開
6. アクションアイテム（owner+期限）
7. メモリ反映

---

## 1. 事案サマリ
アカウント削除 Wave（calsail）で、機能自体は完遂に近づいた一方、**1セッション内で事故/churn が異常多発**。本線（削除フロー）は実機で成功したが、到達まで誤診・stall・要件取り違え・解釈3転が連鎖。司令官の体感「GuP_v2 に手を加えてから詰まりが増えた」を裏取りするのが本反省会の目的。

## 2. GuP_v2 変更タイムライン（★事故相関 — 日付が決定的）
| 日付 | commit | 変更 |
|---|---|---|
| 2026-05-12〜13 | T10 群 / PR#19/#20 | 部隊拡張 + shogun backport + selfwatch + 隊長レビュー必須化 + 配分閾値 + Stop Hook 自動報告 |
| 2026-05-28 | `ee3122e` | **反省会施策（タスク配分改善 + 実装精度向上 + Stack 回避）** |
| 2026-05-29 | `41d103e` | **Opus 4.6 → 4.8 モデル移行** |
| 2026-05-29 | `49e21f2` | **effort max → xhigh に調整**（様子見開始） |
| 2026-05-30 | `dc1e452` | watcher: Esc×2→単発Escape（Rewind 誤起動 stall ループ解消） |

→ **★核心相関**: 主要変更（4.8移行 / xhigh / 反省会施策）は **5/28〜5/30 に集中投入**。事故連発の acctdel Wave は **2026-05-30〜31＝変更直後の最初の本格 Wave**。**時間的に変更の直後に事故が集中**＝最有力の被疑因子。
→ **仮説（本番で検証）**: (i) **モデル 4.8 移行** — confabulation 増の主因? (ii) **effort xhigh** — 過剰思考で誤読/先走り? (iii) **部隊拡張** — エージェント数増で inbox bloat 加速 → context 飽和 stall? (iv) 組合せ。**before（4.6 + max + 旧編成）期の同種 Wave と事故率を比較**して切り分ける。

## 3. 事故データ収集（分類別・本セッション観測 + 一次データ）

### A. Confabulation（虚偽生成・誤読の確信的報告）— 最多発
| # | 主体 | 事象 | 捕捉手段 |
|---|---|---|---|
| A1 | erika | injection 誤報 ×2（軟LGTM先出し→Codex厳判定へ自己訂正の同型3回） | maho が生 codex_reviews.jsonl 突合 |
| A2 | kay | phantom message ID ×3 + 未確認 blocker + injection を完全 confabulation | 自己撤回 + miho 独立検証 → /clear |
| A3 | **anzu（自身）** | (a)logo-mark.svg 欠落=誤根因 (b)UI fix 誤差し戻し (c)CORS content-type 欠落=誤診 | 毎回 send 後に git 現物で自己捕捉・撤回 |
| A4 | miho | stale read 数回 / CORS Allow-Methods DELETE 欠落の見落とし / button 方向誤り | anzu との相互 verify で訂正 |
| A6 | **anzu（差し戻し時の自己 confabulation）** | miho の正しい cmd_done（mobile button `343ac45`=Google上・正）を検証する際、anzu が **存在しない hash `8f2e1a4` を自分ででっち上げ**＋現 HEAD を stale な `36e42d1` と誤認 → 「phantom hash・未修正」と**誤って差し戻し** | 直後に落ち着いて branch-ref 再検証（tip=343ac45 実在・Google上）で自己捕捉・全面撤回。**正しい done を誤って否定する逆方向の confab** |

> ★A6 は最重要データ点: **検証する側（anzu）が phantom hash を自己生成して正しい報告を否定**＝confab は「実装」だけでなく「検証/差し戻し」レイヤでも起きる。anzu 本セッション **confab 4回目**（logo-mark / UI差し戻し / CORS content-type / 本件）= 深夜 context 劣化の決定的証拠。対策: 差し戻し前も branch-ref + `cat-file -e` で hash 実在確認を必須化。

| A7 | **anzu（正午・day中の confab 2連）** | (1) main統合 source list から Wave2 P2 を脱落 (2) `merge-base --is-ancestor` の exit code を誤読し「P2 は a48bdaf に同梱済」と誤判定→miho に誤情報送信 | miho 独立 git 二重確認 + anzu 自己再確認で撤回。両件とも git 生データで訂正 |

> ★A7 が **「夜間 fatigue 説」を否定する決定打**（miho 観察）: A1-A6 は深夜帯だったが、A7 は **2026-05-31 正午・day 継続中**に発生。睡眠不足/深夜では説明できない → **config 変更（Opus 4.8 移行 / effort xhigh）寄りの systemic 要因**を示唆。個人の疲労でなく系の問題。**before(4.6+max)/after(4.8+xhigh) の事故率比較**がこの仮説の検証の肝。

### B. Stall（idle 停止）
| # | 主体 | 事象 |
|---|---|---|
| B1 | katyusha | DELETE fix チェーンで idle stall → 司令官手動 wake で復帰 |
| B2 | kay | 4h ドロップ（後に confabulation で /clear 再起動） |
| B3 | arisa | web R2 QC で idle stall → 復帰 |
| B4 | inbox bloat | miho/anzu inbox が 15KB 超 反復 → context 飽和リスク（rotate 多用で凌いだ） |

### C. 要件取り違え / churn
| # | 事象 |
|---|---|
| C1 | ロゴ要件 anzu 2回取り違え（透明ヨット→空状態だけ→北前船） |
| C2 | login ボタン順 **3転 churn**（Google上/Apple下 ⇔ Apple上/Google下、anzu/miho 両者が Apple HIG 解釈で司令官原文を上書きしかけ）→ 司令官直接確認で LOCK |

### D. Deploy / 統合 gap（unit/code-review/curl-smoke で不可視）
| # | 事象 |
|---|---|
| D1 | EF staging 未deploy → OPTIONS 404（実機で初検出） |
| D2 | CORS preflight gap（Allow-Methods に DELETE 欠落）→ Failed to fetch（実機で初検出） |
| D3 | working-tree 汚染（共有 tree の branch 切替で stale read 誘発） |

### E. 設計の手戻り
| # | 事象 |
|---|---|
| E1 | auth_time 硬化 + Apple email-OTP を設計確定後に司令官裁定で**全撤回**（over-engineering）。nonna が「Google auth_time linchpin もリポ内未検証」と別軸で撤回を裏付け |

## 4. 5 Whys（本番で実施）
※ 本番で各分類ごとに。仮の起点問い：
- なぜ confabulation が同一セッションで全エージェント横断で多発したか？（→ context 劣化? モデル/effort 変更? inbox bloat?）
- なぜ unit/QC が全 green なのに実機で3バグ出たか？（→ テスト層の構造的 gap = deploy/preflight/視覚は別レイヤ）
- なぜ要件が複数回取り違えられたか？（→ 画像要件の口頭伝達? anchor 不足?）

## 5. 横展開（既に memory 化した暫定対策・本番で体系化）
- [[feedback_branch_ref_read_pollution_proof]] — 現物突合は git show <branch>:<path>（working-tree 直読は汚染で stale）
- [[ops_realdevice_test_catches_deploy_integration_gaps]] — 実機テストを削除系 ship-gate 必須
- [[feedback_commander_wording_over_guidelines]] — 司令官原文 > 業界ガイドライン・3転は直接確認で LOCK
- [[feedback_verify_workstate_before_clear]] — /clear 前に work-state 裏取り
- [[ops_inbox_bloat_stall]] / [[ops_inbox_archive_standing_rule]] — inbox rotate で stall 予防
- [[feedback_qc_verify_raw_artifact]] — verdict 通知でなく生 artifact 突合（自分にも適用）

## 6. アクションアイテム（本番で owner+期限確定）
- [ ] 事故データを各隊から供出（task YAML / report / codex_reviews.jsonl / inbox archive の生ログ）
- [ ] GuP_v2 変更（4.8移行/xhigh/部隊拡張）の before/after 事故率比較
- [ ] confabulation の systemic 緩和策（context hygiene の制度化？ effort 戻す？ モデル別検証？）
- [ ] テスト層 gap の恒久対策（deploy/preflight/視覚を CI or smoke に組込）

## 7. メモリ反映
本反省会の確定事項を feedback/project entry 化。PREP 段階の暫定 memory（§5）は本番で statused（昇格/統合/破棄）。

---
## 本番の進め方（司令官指示）
**明日**: ①アカウント削除機能を片付ける（残=mobile button + web dev再起動目視 → 統合main）と並行 ②本反省会（収集→分類→原因究明）。データソースは本 PREP の §2/§3 を起点に一次データで精緻化。
