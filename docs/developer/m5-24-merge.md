# m5-24 병합 메모 (그룹 A~D → `m5-24-merge`)

## 2026-10-13 — 네 그룹 병합 완료, 검증 5단계 통과
- **브랜치**: `m5-24-merge` = `origin/main`(481eea0) + `--no-ff` 병합 A → B → C → D. main에는 push 안 함.
- **스펙**: `docs/specs/m5-24-map-art-pass-v2.md` `status: in-qa`. 다음 차례는 QA(m5-24 전체 12맵).

### 충돌 해결
- `tests/m5-23-qa.spec.luau`, `tests/m5-23-visual-kit.spec.luau`, `tests/map-art-race.spec.luau`(B 병합 때): **그룹 A 방식으로 통일**.
  - `artModule(id)`로 각 맵 Art 모듈을 읽어 `Art.LIGHTING`이 있으면 `lighting == Art.LIGHTING`(정확히 그 표), 없으면 `== PRESETS[id]`.
  - 렌더러 조명·파티클 수: `Art.BUDGET == "Extended"`면 `countLights/countParticles(Art.decor()) + 코드 수`, 아니면 코드 수 고정. → B의 soy-swamp 고정값 `{8, 9}` 줄은 버림(A의 `expected`가 같은 값을 계산하고 테스트 통과).
  - B의 "lighting이 nil 아님 + validate 통과"·C의 "Extended면 validate만 / preset 또는 validate" 완화 단언은 A 규칙보다 약해서 버림(단언은 더 엄격한 쪽 유지).
  - `map-art-race` AC1: A 버전(`budget(tier).parts` 상한 + `checkBudget(specs, tier) == nil`) 채택. B 버전은 같은 검사의 부분집합.
- `docs/specs/m5-24-map-art-pass-v2.md`(C·D 병합 때): 그룹 B·C·D 개발 메모 절을 모두 유지, **그룹 A 절 새로 씀**(`docs/developer/m5-24-group-a.md` 요약 + 링크). 결정 기록 D5(그룹 B 안개 패널 위치)는 B 병합에서 자동으로 들어옴.
- 그룹별 새 테스트 `m5-24-group-a/b/d.spec.luau`, `m5-24-c.spec.luau`는 충돌 없이 공존.
- 소스 코드(`src/`) 충돌 없음 — 그룹마다 맵 파일이 겹치지 않음. 통합 때문에 고친 코드 없음.

### 검증 (병합 결과 기준)
1. `rojo build -o build.rbxl` OK
2. `stylua --check src tests tools` 끝 코드 0
3. `selene src` 0 errors, 0 warnings, 0 parse errors (그룹 D가 못 돌린 selene도 여기서 통과)
4. `lune run tests` **1815 passed, 0 failed**
5. `luau-lsp analyze ...` 끝 코드 0
- `lune run tools/render-map all --view overview --quality fast` (build/는 커밋 안 함) — 12맵 모두 Extended 안:

| 맵 | decor/1500 | lights/24 (그림자/2) | particles/16 | anim/80 | void |
|---|---|---|---|---|---|
| rotating-belt | 1386 | 13 (1) | 7 | 45 | 0% |
| soy-swamp | 966 | 8 (1) | 9 | 34 | 0% |
| ramen-rapids | 966 | 7 (1) | 13 | 29 | 0% |
| hot-plate | 808 | 8 (1) | 11 | 16 | 0% |
| chef-board | 778 | 5 (1) | 6 | 11 | 0% |
| skewer-showdown | 1294 | 13 (1) | 6 | 30 | 0% |
| bouncy-castle-maze | 1468 | 7 (1) | 3 | 47 | 4% |
| lantern-bridge | 1412 | 23 (1) | 9 | 73 | 0% |
| giant-jenga | 1101 | 7 (1) | 4 | 5 | 0% |
| cat-cafe-shelves | 842 | 6 (1) | 4 | 17 | 2% |
| tug-of-war-platform | 411 | 3 (1) | 4 | 11 | 6% |
| claw-machine-prize | 554 | 11 (1) | 4 | 8 | 0% |

### 특이사항
- 여유가 작은 맵: lantern-bridge 조명 23/24·anim 73/80, bouncy-castle-maze decor 1468/1500, rotating-belt 1386/1500. 나중에 장식을 더하면 넘을 수 있음.
- m5-24 대상이 아닌 dessert-fridge는 overview void 21%(기존 상태, 이번 병합과 무관).
- 그룹 B D5(안개 패널을 방 벽 바깥으로 옮김)는 "planner 확인 필요"로 남아 있음.
- Studio 확인(AC12~15)은 사용자 차례 — 그룹별 인계 메모(`m5-24-group-<a~d>.md`)의 순서를 따름.
