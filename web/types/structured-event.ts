// Structured log event types for Web UI (P3-2)
// Emitted by agents to logs/structured/{agent_id}.jsonl

export type StructuredEventType =
  | "task_start"
  | "task_progress"
  | "task_done"
  | "error"
  | "escalation"
  | "quality_gate";

interface BaseEvent {
  event: StructuredEventType;
  agent_id: string;
  timestamp: string;
}

export interface TaskStartEvent extends BaseEvent {
  event: "task_start";
  task_id: string;
  parent_cmd: string;
  target_files?: string[];
  summary?: string;
}

export interface TaskProgressEvent extends BaseEvent {
  event: "task_progress";
  task_id: string;
  step: number;
  total_steps: number;
  label?: string;
}

export interface TaskDoneEvent extends BaseEvent {
  event: "task_done";
  task_id: string;
  duration_sec?: number;
  changed_files?: string[];
  verification?: {
    build_result?: "pass" | "fail";
    dev_server_check?: "pass" | "fail" | "skipped";
    error_console?: "no_errors" | "has_warnings" | "has_errors";
  };
}

export interface ErrorEvent extends BaseEvent {
  event: "error";
  task_id?: string;
  error_type: string;
  message: string;
  file?: string;
  line?: number;
}

export interface EscalationEvent extends BaseEvent {
  event: "escalation";
  task_id?: string;
  to: string;
  reason: string;
}

export interface QualityGateEvent extends BaseEvent {
  event: "quality_gate";
  task_id?: string;
  vitest?: { pass: number; fail: number };
  typecheck?: "pass" | "fail";
  lint?: "pass" | "fail";
}

export type StructuredEvent =
  | TaskStartEvent
  | TaskProgressEvent
  | TaskDoneEvent
  | ErrorEvent
  | EscalationEvent
  | QualityGateEvent;
