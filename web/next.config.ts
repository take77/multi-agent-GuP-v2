import type { NextConfig } from "next";

// ⚠️ WARNING: turbopack.root を絶対に設定しないこと！
// turbopack: { root: path.resolve(__dirname) } を設定すると、
// CSS の @import "tailwindcss" がルートの node_modules から解決されてしまい、
// ビルドエラー「Module not found: Can't resolve 'tailwindcss'」が発生する。
// 「設定が必要そう」に見えても絶対に入れないこと。

const nextConfig: NextConfig = {};

export default nextConfig;
