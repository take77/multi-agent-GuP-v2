"use client";

import type {
  StructuredEvent,
  TaskStartEvent,
  TaskProgressEvent,
  TaskDoneEvent,
  ErrorEvent,
  EscalationEvent,
  QualityGateEvent,
} from "@/types/structured-event";

// ── individual card components ──────────────────────────────────────────────

function TaskStartCard({ event }: { event: TaskStartEvent }) {
  return (
    <div className="rounded-lg border border-sky-700/40 bg-sky-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-sky-300">
        <span>🎯</span>
        <span>タスク開始</span>
        <span className="ml-auto font-mono text-sky-400/70 text-[11px]">
          {event.task_id}
        </span>
      </div>
      {event.summary && (
        <p className="mt-1 text-slate-300">{event.summary}</p>
      )}
      {event.target_files && event.target_files.length > 0 && (
        <ul className="mt-1 space-y-0.5">
          {event.target_files.map((f, i) => (
            <li key={i} className="font-mono text-[11px] text-sky-400/60">
              {f}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function TaskProgressCard({ event }: { event: TaskProgressEvent }) {
  const pct = Math.round((event.step / event.total_steps) * 100);
  return (
    <div className="rounded-lg border border-indigo-700/40 bg-indigo-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-indigo-300">
        <span>⏳</span>
        <span>{event.label ?? "進捗"}</span>
        <span className="ml-auto text-indigo-400/70 text-[11px]">
          Step {event.step}/{event.total_steps}
        </span>
      </div>
      <div className="mt-1.5 h-1.5 w-full rounded-full bg-indigo-900/60">
        <div
          className="h-1.5 rounded-full bg-indigo-400 transition-all"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

function TaskDoneCard({ event }: { event: TaskDoneEvent }) {
  const v = event.verification;
  return (
    <div className="rounded-lg border border-emerald-700/40 bg-emerald-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-emerald-300">
        <span>✅</span>
        <span>タスク完了</span>
        <span className="ml-auto font-mono text-emerald-400/70 text-[11px]">
          {event.task_id}
        </span>
      </div>
      {event.duration_sec != null && (
        <p className="mt-0.5 text-slate-400">
          所要時間: {event.duration_sec}s
        </p>
      )}
      {event.changed_files && event.changed_files.length > 0 && (
        <ul className="mt-1 space-y-0.5">
          {event.changed_files.map((f, i) => (
            <li key={i} className="font-mono text-[11px] text-emerald-400/60">
              {f}
            </li>
          ))}
        </ul>
      )}
      {v && (
        <div className="mt-1 flex gap-2 flex-wrap">
          {v.build_result && (
            <span
              className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
                v.build_result === "pass"
                  ? "bg-emerald-800/60 text-emerald-300"
                  : "bg-red-800/60 text-red-300"
              }`}
            >
              build:{v.build_result}
            </span>
          )}
          {v.dev_server_check && v.dev_server_check !== "skipped" && (
            <span
              className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
                v.dev_server_check === "pass"
                  ? "bg-emerald-800/60 text-emerald-300"
                  : "bg-red-800/60 text-red-300"
              }`}
            >
              dev:{v.dev_server_check}
            </span>
          )}
        </div>
      )}
    </div>
  );
}

function ErrorCard({ event }: { event: ErrorEvent }) {
  return (
    <div className="rounded-lg border border-red-700/40 bg-red-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-red-300">
        <span>❌</span>
        <span>エラー</span>
        <span className="ml-auto font-mono text-red-400/70 text-[11px]">
          {event.error_type}
        </span>
      </div>
      <p className="mt-1 text-slate-300 break-all">{event.message}</p>
      {event.file && (
        <p className="mt-0.5 font-mono text-[11px] text-red-400/60">
          {event.file}
          {event.line != null ? `:${event.line}` : ""}
        </p>
      )}
    </div>
  );
}

function EscalationCard({ event }: { event: EscalationEvent }) {
  return (
    <div className="rounded-lg border border-orange-700/40 bg-orange-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-orange-300">
        <span>🔺</span>
        <span>エスカレーション</span>
        <span className="ml-auto font-mono text-orange-400/70 text-[11px]">
          → {event.to}
        </span>
      </div>
      <p className="mt-1 text-slate-300">{event.reason}</p>
    </div>
  );
}

function QualityGateCard({ event }: { event: QualityGateEvent }) {
  const v = event.vitest;
  const allPass =
    event.typecheck === "pass" &&
    event.lint === "pass" &&
    (v == null || v.fail === 0);
  return (
    <div className="rounded-lg border border-violet-700/40 bg-violet-950/30 px-3 py-2 text-[12px]">
      <div className="flex items-center gap-1.5 font-semibold text-violet-300">
        <span>🏁</span>
        <span>Quality Gate</span>
        {allPass && (
          <span className="ml-auto text-emerald-400 text-[11px] font-bold">
            ALL PASS
          </span>
        )}
      </div>
      <div className="mt-1 flex gap-2 flex-wrap">
        {v != null && (
          <span
            className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
              v.fail === 0
                ? "bg-emerald-800/60 text-emerald-300"
                : "bg-red-800/60 text-red-300"
            }`}
          >
            vitest {v.pass}/{v.pass + v.fail}
          </span>
        )}
        {event.typecheck && (
          <span
            className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
              event.typecheck === "pass"
                ? "bg-emerald-800/60 text-emerald-300"
                : "bg-red-800/60 text-red-300"
            }`}
          >
            typecheck {event.typecheck === "pass" ? "✓" : "✗"}
          </span>
        )}
        {event.lint && (
          <span
            className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
              event.lint === "pass"
                ? "bg-emerald-800/60 text-emerald-300"
                : "bg-red-800/60 text-red-300"
            }`}
          >
            lint {event.lint === "pass" ? "✓" : "✗"}
          </span>
        )}
      </div>
    </div>
  );
}

// ── main dispatcher ──────────────────────────────────────────────────────────

export function StructuredEventCard({ event }: { event: StructuredEvent }) {
  switch (event.event) {
    case "task_start":
      return <TaskStartCard event={event} />;
    case "task_progress":
      return <TaskProgressCard event={event} />;
    case "task_done":
      return <TaskDoneCard event={event} />;
    case "error":
      return <ErrorCard event={event} />;
    case "escalation":
      return <EscalationCard event={event} />;
    case "quality_gate":
      return <QualityGateCard event={event} />;
    default:
      return null;
  }
}
