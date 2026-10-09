# m5-22 skin pack 1 — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **브랜치/worktree**: `worktree-agent-a599d836333638de2` (`.claude/worktrees/agent-a599d836333638de2`). push는 메인 세션이 함 (worktree 브랜치라 origin 없음).
- **끝난 것**: 스펙 범위 전체 — 신규 스킨 10종(일반 3·레어 3·에픽 2·전설 2), `tests/skins.spec.luau` 갱신, 기존 테스트 하네스 버그 3건 수정(아래 참고).
  - `src/shared/SushiBody.luau`: 색 상수 39개, `LAYOUTS`에 10개 항목(`takoyaki`, `egg-toast`, `slider-burger`, `tonkatsu`, `cat-sushi`, `robo-roll`, `galaxy-roll`, `softserve-roll`, `crown-tuna`, `unicorn-roll`) 추가. 스펙의 size/offset/rotation/effect 표를 그대로 옮김.
  - `src/shared/Skins.luau`: 카탈로그 10종 추가(order 22~31), `productId`는 전부 `nil`.
  - `tests/skins.spec.luau`: `EXPECTED` 31종, `byTier` 개수(1/8/9/7/6), 효과 테스트를 다중 효과 지원으로 일반화, Wedge 14파츠(고양이 초밥 4 + 크라운 참치 7 + 유니콘 롤 3) 전용 검증 추가.
  - `tests/m4-13-qa.spec.luau`: **m5-21이 Wedge를 도입했을 때 같이 안 고쳐졌던 테스트 하네스 버그 3건**을 이번에 10종 중 Wedge·2효과 스킨이 실제로 생기면서 발견·수정했다 (자세한 내용은 스펙 "개발 메모" 참고, 요약: 가짜 `IsA("BasePart")`가 WedgePart를 인정 안 함 → `build()`의 Weld 루프에서 Wedge 파츠가 빠짐, 파츠 개수 집계가 WedgePart를 안 셈, 효과·비율 테스트가 m5-21 이전 숫자(1개/±15%)를 하드코딩해 둠).
  - `tests/m5-03-foundation.spec.luau`: 카탈로그 총 개수 21→31.
  - `tests/shop-logic.spec.luau`: "일반 N종 구매" 테스트를 `Skins.byTier("Common")` 개수 기반으로 일반화.
- **m5-21 의존 가정 검증**: 스펙이 머지 전에 쓴 4가지 가정(Wedge=WedgePart, bounds()가 shape를 안 봄, EFFECT_BUDGET, BOUNDS_TOLERANCE)을 실제 `src/shared/SushiBody.luau` 코드와 대조 — **전부 일치**, 불일치 없음. 결정 기록에 추가할 질문 없음.
- **검증**: `rojo build` OK, `stylua --check` OK, `selene` 0 errors/0 warnings, `lune run tests` **1153 passed / 0 failed**(새 테스트 24개 포함, 기존 1129개 전부 그대로 통과), `luau-lsp analyze` exit 0.
- **"여유 빠듯" 3종 결과**: 고양이 초밥(레어 ±15%, 계산 margin 0.0106 studs), 소프트아이스크림 롤·유니콘 롤(에픽/전설 ±25%, ratio 1.234 vs 허용 1.25) 전부 **offset 조정 없이** 테스트 통과 — 스펙의 사전 계산이 정확했다.
- **남은 것**: Studio 확인(AC5, 아래 "다음에 할 첫 단계" 참고) — 이 worktree에는 Studio가 없어 QA 또는 사용자가 확인해야 한다.
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"의 Studio 확인 방법 5가지(탈의실 카드·가격, 10종 실루엣, 효과 2개 동시 표시, "여유 빠듯" 3종 체감, 비초밥 7종 탈락 대사)를 확인.
- **막힌 점**: 없음.
- **메모**:
  - 로보 롤·갤럭시 롤의 `Topping`/`ToppingBack`은 `slab()` 헬퍼를 못 썼다(로보 롤은 Topping/ToppingBack 색이 다름, 갤럭시 롤은 그냥 둘 다 같은 색이라 `slab(GALAXY_NAVY)` 사용 가능해서 그건 재사용함). 소프트아이스크림 롤은 스펙 지시대로 `Topping`/`ToppingBack` 자체가 없고 `ConeBand` 하나만 앵커.
  - 돈가스는 `stripes(TONKATSU_RIDGE, 20)`을 그대로 재사용해서 파츠 이름이 스펙 표의 "Ridge0/1/2"가 아니라 기존 헬퍼의 "Stripe0/1/2"로 나온다 — 스펙 본문이 "stripes() 그대로 재사용"이라고 명시했으므로 의도대로.
  - 공용 파일(`shared/Config.luau` 등)은 건드리지 않았다. `docs/GDD.md`도 수정하지 않았다.
