<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

<!-- BEGIN:turbopack-rules -->
## turbopack.root — PROHIBITED

**NEVER set `turbopack.root` in `next.config.ts`.**

### Why it is forbidden

Setting `turbopack.root: path.resolve(__dirname)` causes Turbopack to resolve module imports starting from the monorepo root instead of `web/`. This breaks CSS `@import "tailwindcss"` because Tailwind CSS is installed in `web/node_modules/`, not the root `node_modules/`.

### Error you will see

```
Module not found: Can't resolve 'tailwindcss'
```

The CSS `@import` in `globals.css` fails at build time because Turbopack looks for `tailwindcss` under the root `node_modules/` where it does not exist.

### Correct approach

Do **not** set `turbopack.root`. Even in a monorepo layout, Turbopack works correctly without it — leave the option unset and let Next.js resolve modules from `web/node_modules/` as normal.
<!-- END:turbopack-rules -->
