"use client";

import type { Branch, BranchType } from "@/types/git";

const TYPE_LABELS: Record<BranchType, string> = {
  protected: "保護",
  integration: "統合",
  feature: "機能",
};

interface BranchDetailProps {
  branch: Branch;
  allBranches: Branch[];
  onClose: () => void;
}

export default function BranchDetail({ branch, allBranches, onClose }: BranchDetailProps) {
  const parent = allBranches.find((b) => b.id === branch.parent);
  const children = allBranches.filter((b) => b.parent === branch.id);

  return (
    <div className="w-52 border-l border-slate-700/50 bg-slate-900/60 overflow-y-auto p-3 shrink-0 space-y-2.5">
      <div className="flex justify-between">
        <span className="text-[12px] font-semibold text-slate-200">詳細</span>
        <button onClick={onClose} className="text-slate-500 hover:text-white">
          ×
        </button>
      </div>

      <div className="bg-slate-800 rounded p-2.5">
        <span className="text-[10px] text-slate-500 block mb-1">ブランチ</span>
        <span className="text-[11px] font-mono text-slate-200 break-all">{branch.name}</span>
      </div>

      <div className="bg-slate-800 rounded p-2.5">
        <span className="text-[10px] text-slate-500 block mb-1">種別</span>
        <span className="text-[11px] text-slate-300">{TYPE_LABELS[branch.type]}ブランチ</span>
      </div>

      {parent && (
        <div className="bg-slate-800 rounded p-2.5">
          <span className="text-[10px] text-slate-500 block mb-1">分岐元</span>
          <span className="text-[11px] font-mono text-cyan-400">{parent.name}</span>
        </div>
      )}

      {children.length > 0 && (
        <div className="bg-slate-800 rounded p-2.5">
          <span className="text-[10px] text-slate-500 block mb-1">派生</span>
          {children.map((c) => (
            <div key={c.id} className="text-[11px] font-mono text-slate-400">
              {c.name}
            </div>
          ))}
        </div>
      )}

      {branch.squad && (
        <div className="bg-slate-800 rounded p-2.5">
          <span className="text-[10px] text-slate-500 block mb-1">担当</span>
          <span className="text-[11px] font-medium" style={{ color: branch.squadColor ?? undefined }}>
            {branch.squad}
          </span>
        </div>
      )}

      {branch.files && (
        <div className="bg-slate-800 rounded p-2.5">
          <span className="text-[10px] text-slate-500 block mb-1">変更</span>
          <div className="flex gap-2">
            <span className="text-[11px] text-amber-300">~{branch.files[0]}</span>
            <span className="text-[11px] text-emerald-300">+{branch.files[1]}</span>
            {branch.files[2] > 0 && (
              <span className="text-[11px] text-red-300">-{branch.files[2]}</span>
            )}
          </div>
        </div>
      )}

      {branch.behind > 0 && parent && (
        <div className="bg-amber-950/60 rounded p-2.5 border border-amber-800/40">
          <span className="text-[11px] text-amber-300">
            {parent.name}より {branch.behind}コミット遅れ
          </span>
        </div>
      )}

      {branch.conflict?.length && (
        <div className="bg-red-950/60 rounded p-2.5 border border-red-800/40">
          <span className="text-[11px] text-red-300 block mb-1">コンフリクト</span>
          {branch.conflict.map((f, i) => (
            <div key={i} className="text-[10px] font-mono text-red-400/70">
              {f}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
