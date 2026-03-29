"use client";

import { useState } from "react";
import type { AvatarDef } from "@/types/agent";

const AVATARS: Record<string, AvatarDef> = {
  // 指揮系統
  anzu: { bg: "bg-amber-500", ini: "杏", ring: "ring-amber-400", objectPosition: "50% 20%" },
  miho: { bg: "bg-rose-400", ini: "み", ring: "ring-rose-300", objectPosition: "50% 15%" },
  // ダージリン隊
  darjeeling: { bg: "bg-blue-500", ini: "D", ring: "ring-blue-400", objectPosition: "50% 20%" },
  orange_pekoe: { bg: "bg-sky-400", ini: "P", ring: "ring-sky-300" },
  assam: { bg: "bg-indigo-400", ini: "As", ring: "ring-indigo-300" },
  rukuriri: { bg: "bg-blue-300", ini: "ル", ring: "ring-blue-200" },
  nilgiri: { bg: "bg-teal-400", ini: "N", ring: "ring-teal-300" },
  rosehip: { bg: "bg-pink-500", ini: "R", ring: "ring-pink-400", objectPosition: "50% 15%" },
  pekoe: { bg: "bg-sky-300", ini: "ペ", ring: "ring-sky-200", objectPosition: "50% 20%" },
  hana: { bg: "bg-pink-300", ini: "華", ring: "ring-pink-200", objectPosition: "50% 20%" },
  marie: { bg: "bg-blue-200", ini: "マ", ring: "ring-blue-100", objectPosition: "50% 15%" },
  andou: { bg: "bg-indigo-300", ini: "安", ring: "ring-indigo-200", objectPosition: "50% 15%" },
  oshida: { bg: "bg-violet-300", ini: "押", ring: "ring-violet-200", objectPosition: "50% 15%" },
  // カチューシャ隊
  katyusha: { bg: "bg-red-500", ini: "К", ring: "ring-red-400", objectPosition: "50% 15%" },
  nonna: { bg: "bg-slate-400", ini: "Н", ring: "ring-slate-300", objectPosition: "50% 20%" },
  klara: { bg: "bg-red-300", ini: "Кл", ring: "ring-red-200", objectPosition: "50% 15%" },
  mako: { bg: "bg-slate-500", ini: "麻", ring: "ring-slate-400", objectPosition: "50% 20%" },
  erwin: { bg: "bg-amber-400", ini: "Er", ring: "ring-amber-300", objectPosition: "50% 20%" },
  caesar: { bg: "bg-orange-400", ini: "Ca", ring: "ring-orange-300", objectPosition: "50% 15%" },
  saori: { bg: "bg-pink-400", ini: "沙", ring: "ring-pink-300", objectPosition: "50% 20%" },
  // ケイ隊
  kay: { bg: "bg-green-500", ini: "K", ring: "ring-green-400", objectPosition: "50% 15%" },
  naomi: { bg: "bg-emerald-400", ini: "Na", ring: "ring-emerald-300", objectPosition: "50% 15%" },
  arisa: { bg: "bg-lime-400", ini: "Al", ring: "ring-lime-300", objectPosition: "50% 15%" },
  yukari: { bg: "bg-yellow-400", ini: "優", ring: "ring-yellow-300", objectPosition: "50% 20%" },
  anchovy: { bg: "bg-green-400", ini: "An", ring: "ring-green-300", objectPosition: "50% 20%" },
  pepperoni: { bg: "bg-orange-300", ini: "ペ", ring: "ring-orange-200", objectPosition: "50% 15%" },
  carpaccio: { bg: "bg-emerald-300", ini: "カ", ring: "ring-emerald-200", objectPosition: "50% 20%" },
  // まほ隊
  maho: { bg: "bg-purple-500", ini: "ま", ring: "ring-purple-400", objectPosition: "50% 15%" },
  erika: { bg: "bg-violet-400", ini: "エ", ring: "ring-violet-300", objectPosition: "50% 15%" },
  mika: { bg: "bg-cyan-400", ini: "ミ", ring: "ring-cyan-300", objectPosition: "50% 20%" },
  aki: { bg: "bg-teal-300", ini: "ア", ring: "ring-teal-200", objectPosition: "50% 20%" },
  mikko: { bg: "bg-cyan-300", ini: "ミッ", ring: "ring-cyan-200", objectPosition: "50% 15%" },
  kinuyo: { bg: "bg-purple-300", ini: "絹", ring: "ring-purple-200", objectPosition: "50% 20%" },
  fukuda: { bg: "bg-purple-200", ini: "福", ring: "ring-purple-100", objectPosition: "50% 20%" },
};

const DEFAULT_AVATAR: AvatarDef = {
  bg: "bg-slate-500",
  ini: "?",
  ring: "ring-slate-400",
};

export function getAvatar(id: string): AvatarDef {
  return AVATARS[id] ?? DEFAULT_AVATAR;
}

export function Avatar({
  id,
  size = "w-8 h-8 text-xs",
  online,
}: {
  id: string;
  size?: string;
  online?: boolean;
}) {
  const a = getAvatar(id);
  const [imgError, setImgError] = useState(false);
  const imgSrc = `/avatars/${id}.png`;

  return (
    <div className={`relative ${size} rounded-full shrink-0`}>
      {!imgError ? (
        <img
          src={imgSrc}
          alt={a.ini}
          className="w-full h-full rounded-full object-cover"
          style={{ objectPosition: a.objectPosition ?? "50% 50%" }}
          onError={() => setImgError(true)}
        />
      ) : (
        <div
          className={`w-full h-full rounded-full ${a.bg} flex items-center justify-center font-bold text-white select-none`}
        >
          {a.ini}
        </div>
      )}
      {online !== undefined && (
        <span
          className={`absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-slate-900 ${
            online ? "bg-emerald-400" : "bg-slate-500"
          }`}
        />
      )}
    </div>
  );
}
