export class CostTracker {
  private totalCostUsd: number = 0;
  private totalDurationMs: number = 0;
  private numTurns: number = 0;

  constructor() {}

  // onMessage から呼び出し。コスト情報を累積
  track(msg: any): void {
    if (msg.total_cost_usd !== undefined) {
      this.totalCostUsd += msg.total_cost_usd;
    }
    if (msg.duration_ms !== undefined) {
      this.totalDurationMs += msg.duration_ms;
    }
    this.numTurns++;
  }

  // 現在の累計コスト情報を返す
  getSummary(): {
    totalCostUsd: number;
    totalDurationMs: number;
    numTurns: number;
    avgCostPerTurn: number;
  } {
    return {
      totalCostUsd: this.totalCostUsd,
      totalDurationMs: this.totalDurationMs,
      numTurns: this.numTurns,
      avgCostPerTurn: this.numTurns > 0 ? this.totalCostUsd / this.numTurns : 0,
    };
  }

  // ログファイルに出力
  async writeTo(path: string): Promise<void> {
    const fs = await import('fs/promises');
    const summary = this.getSummary();
    await fs.writeFile(path, JSON.stringify(summary, null, 2), 'utf-8');
  }
}
