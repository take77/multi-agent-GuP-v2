/**
 * agent-names.ts
 *
 * エージェントID → キャラクター表示名のマッピング。
 * UI上で内部IDではなくキャラクター名を表示するために使用する。
 */

const AGENT_NAME_MAP: Record<string, string> = {
  // 指揮系統
  anzu: "杏（大隊長）",
  miho: "みほ（参謀長）",

  // ダージリン隊
  darjeeling: "ダージリン（隊長）",
  pekoe: "ペコ（副隊長）",
  hana: "華",
  rosehip: "ローズヒップ",
  marie: "マリー",
  oshida: "押田",
  andou: "安藤",

  // カチューシャ隊
  katyusha: "カチューシャ（隊長）",
  nonna: "ノンナ（副隊長）",
  klara: "クラーラ",
  mako: "麻子",
  erwin: "エルヴィン",
  caesar: "カエサル",
  saori: "沙織",

  // ケイ隊
  kay: "ケイ（隊長）",
  arisa: "アリサ（副隊長）",
  naomi: "ナオミ",
  yukari: "優花里",
  anchovy: "アンチョビ",
  carpaccio: "カルパッチョ",
  pepperoni: "ペパロニ",

  // まほ隊
  maho: "まほ（隊長）",
  erika: "エリカ（副隊長）",
  mika: "ミカ",
  aki: "アキ",
  mikko: "ミッコ",
  kinuyo: "絹代",
  fukuda: "福田",
};

/**
 * エージェントIDを表示名に変換する。
 * マッピングが存在しない場合は元のIDをそのまま返す。
 */
export function getAgentDisplayName(agentId: string): string {
  return AGENT_NAME_MAP[agentId] ?? agentId;
}
