# 施策完了報告格納ディレクトリ

各隊長が施策完了時に以下の形式でYAMLを配置します。

## ファイル名

```
{init_id}.yaml
```

例: `init_001.yaml`, `init_002.yaml`

## フォーマット

```yaml
id: init_001
cluster_id: darjeeling
completed_at: "2026-02-09T15:30:00"
result:
  summary: "ユーザー認証機能のJWT移行が完了"
  files_modified:
    - "src/auth/jwt.ts"
    - "src/api/login.ts"
    - "src/components/LoginForm.tsx"
  tests_passed: 42
  tests_failed: 0
  notes: |
    - 既存セッションの移行スクリプトも作成済み
    - 本番デプロイ前にセキュリティレビュー推奨
```

## フロー

1. 隊長が施策完了を確認
2. 隊長がこのディレクトリに完了報告YAMLを配置
3. 参謀長が完了報告を読み取り
4. 参謀長が `master_dashboard.md` を更新
5. 参謀長が `commander_to_staff.yaml` の該当施策を `status: done` に更新

## 注意事項

- ファイル名は施策IDと一致させること
- 完了報告は隊長のみが作成可能
- 参謀長は読み取り専用（更新・削除しない）
