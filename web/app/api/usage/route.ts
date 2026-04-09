import { fetchUsage } from "@/lib/usage-tracker";
import { fetchCodexStatus } from "@/lib/codex-tracker";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const [claude, codex] = await Promise.all([
      fetchUsage(),
      fetchCodexStatus(),
    ]);
    return Response.json({ ...claude, codex });
  } catch {
    return Response.json(
      {
        five_hour: { utilization: 0, resets_at: "N/A" },
        seven_day: { utilization: 0, resets_at: "N/A" },
        fetched_at: Math.floor(Date.now() / 1000),
      },
      { status: 500 }
    );
  }
}
