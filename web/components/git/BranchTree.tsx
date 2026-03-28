"use client";

import type { Branch } from "@/types/git";

const ROW_HEIGHT = 58;
const COL_WIDTH = 26;
const LEFT_PAD = 14;

function getDepth(branch: Branch, branches: Branch[]): number {
  let d = 0;
  let cur: Branch | undefined = branch;
  while (cur?.parent) {
    d++;
    cur = branches.find((b) => b.id === cur!.parent);
  }
  return d;
}

function getNodeColor(b: Branch): string {
  if (b.conflict?.length) return "#ef4444";
  if (b.stale) return "#f59e0b";
  if (b.type === "protected") return "#94a3b8";
  if (b.type === "integration") return "#22d3ee";
  return b.squadColor ?? "#4ade80";
}

interface BranchTreeProps {
  branches: Branch[];
  flat: Branch[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}

export default function BranchTree({ branches, flat, selectedId, onSelect }: BranchTreeProps) {
  const height = flat.length * ROW_HEIGHT;

  return (
    <div className="shrink-0" style={{ width: 90 }}>
      <svg width={90} height={height} className="block">
        {flat.map((b, idx) => {
          const d = getDepth(b, branches);
          const x = LEFT_PAD + d * COL_WIDTH;
          const y = idx * ROW_HEIGHT + ROW_HEIGHT / 2;
          const col = getNodeColor(b);

          // Parent connection lines
          const parentIdx = flat.findIndex((pb) => pb.id === b.parent);
          const parentDepth = b.parent
            ? getDepth(branches.find((pb) => pb.id === b.parent)!, branches)
            : 0;
          const px = LEFT_PAD + parentDepth * COL_WIDTH;
          const py = parentIdx >= 0 ? parentIdx * ROW_HEIGHT + ROW_HEIGHT / 2 : 0;

          const r = b.type !== "feature" ? 5 : 4;
          const isSelected = selectedId === b.id;

          return (
            <g key={b.id} className="cursor-pointer" onClick={() => onSelect(b.id)}>
              {b.parent && parentIdx >= 0 && (
                <>
                  <line x1={px} y1={py} x2={px} y2={y} stroke={col} strokeWidth={1.5} opacity={0.3} />
                  <line x1={px} y1={y} x2={x} y2={y} stroke={col} strokeWidth={1.5} opacity={0.3} />
                </>
              )}
              {isSelected && (
                <circle cx={x} cy={y} r={r + 3} fill="none" stroke={col} strokeWidth={1} opacity={0.5} />
              )}
              <circle
                cx={x}
                cy={y}
                r={r}
                fill={col}
                opacity={b.stale ? 0.5 : 1}
              />
            </g>
          );
        })}
      </svg>
    </div>
  );
}
