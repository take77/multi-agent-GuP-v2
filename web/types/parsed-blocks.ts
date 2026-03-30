/**
 * parsed-blocks.ts
 *
 * capture-pane パーサーの出力型定義。
 * UI側（ParsedOutput コンポーネント）との契約。
 */

/** ツール呼び出し1件分 */
export type ToolCall = {
  icon: string;     // 💻📖📝⏱ 等
  label: string;    // "Bash", "Read", "Update", "Write", "Cogitated" 等
  detail: string;   // コマンド内容やファイルパス
  result?: string;  // ⎿ 行の結果テキスト（あれば）
};

/** パース済みブロック（4種 + スキップ用） */
export type ParsedBlock =
  | { type: "assistant-text"; content: string }
  | { type: "tool-execution"; tools: ToolCall[]; agentName: string }
  | { type: "user-input"; content: string }
  | { type: "session-duration"; duration: string }
  | { type: "raw"; content: string };
