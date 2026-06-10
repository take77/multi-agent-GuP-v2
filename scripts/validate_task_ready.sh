#!/usr/bin/env bash
# validate_task_ready.sh — Definition of Ready (DoR) バリデーション
# タスク YAML が dispatch 可能な状態かチェックする
# Usage: bash scripts/validate_task_ready.sh <task_yaml_path>
# Exit: 0 = ready, 1 = not ready (warnings printed to stderr)

set -e

TASK_YAML="$1"

if [ -z "$TASK_YAML" ] || [ ! -f "$TASK_YAML" ]; then
    echo "[DoR] ERROR: タスク YAML が見つかりません: ${TASK_YAML}" >&2
    exit 1
fi

WARNINGS=0

check_field() {
    local field="$1"
    local label="$2"
    local value
    value=$(python3 -c "
import yaml, sys
try:
    data = yaml.safe_load(open('$TASK_YAML'))
    task = data.get('task', data)
    v = task.get('$field', '')
    print(v if v else '')
except:
    print('')
" 2>/dev/null)

    if [ -z "$value" ] || [ "$value" = "None" ]; then
        echo "[DoR] WARNING: ${label} (${field}) が未記入" >&2
        WARNINGS=$((WARNINGS + 1))
    fi
}

# 必須フィールドチェック
check_field "task_id" "タスクID"
check_field "description" "タスク説明"
check_field "bloom_level" "Bloom Level"
check_field "target_path" "対象パス"

# acceptance_criteria / description に目的が含まれているか
DESC=$(python3 -c "
import yaml
try:
    data = yaml.safe_load(open('$TASK_YAML'))
    task = data.get('task', data)
    desc = str(task.get('description', ''))
    print(len(desc))
except:
    print('0')
" 2>/dev/null)

if [ "${DESC:-0}" -lt 20 ]; then
    echo "[DoR] WARNING: description が短すぎます（20文字未満）。目的を明確に記述してください" >&2
    WARNINGS=$((WARNINGS + 1))
fi

# T-shirt sizing チェック
SIZE=$(python3 -c "
import yaml
try:
    data = yaml.safe_load(open('$TASK_YAML'))
    task = data.get('task', data)
    print(task.get('size', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$SIZE" ] || [ "$SIZE" = "None" ]; then
    echo "[DoR] INFO: size フィールド未記入。S/M/L で作業量を見積もることを推奨" >&2
elif [ "$SIZE" = "L" ]; then
    echo "[DoR] WARNING: size=L のタスクです。分割を検討してください" >&2
    WARNINGS=$((WARNINGS + 1))
fi

# 結果出力
if [ $WARNINGS -gt 0 ]; then
    echo "[DoR] ${WARNINGS} 件の WARNING があります。修正してから dispatch してください" >&2
    exit 1
else
    echo "[DoR] OK: タスクは着手可能条件を満たしています" >&2
    exit 0
fi
