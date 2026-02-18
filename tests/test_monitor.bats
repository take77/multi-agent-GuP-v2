#!/usr/bin/env bats

@test "start.ts が存在する" {
  [ -f scripts/monitor/start.ts ]
}

@test "TypeScript コンパイルが通る" {
  cd scripts/monitor/
  npx tsc --noEmit
}
