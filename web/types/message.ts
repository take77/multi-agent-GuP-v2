export type MessageType =
  | "task_assigned"
  | "report_received"
  | "qc_request"
  | "qc_result"
  | "cmd_done"
  | "cmd_failed"
  | "cmd_new"
  | "clear_command"
  | "model_switch"
  | "system";

export interface InboxMessage {
  id: string;
  from: string;
  to: string;
  content: string;
  type: MessageType;
  timestamp: string;
  read: boolean;
}

export type MessageFilter = "all" | string; // "all" or cluster/agent id
