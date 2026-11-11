# f1-02 스시 파이트 특수 스킬 (로직) — 개발 작업 기록

## 2026-11-11 (클라우드 세션)
- **지금 브랜치**: `sushi-fight`
- **끝난 것**: 스킬 6종 수치·스킬 게이지·에픽·전설 14종 시그니처 표(연출만)·방패 guard → 스펙 `in-qa`. GDD v0.3(§5.1·5.1.1): Q1 확정 = 같은 유니버스 플레이스, 스킬 고르기 없앰 → 목숨마다 회전초밥 룰렛(`roll`·`rouletteSteps`), 연출 시안 아티팩트 "회전초밥 스킬 룰렛".
- **검증**: rojo build 통과, stylua 통과, lune 2500 passed 0 failed, luau-lsp 끝 코드 0. selene `src` 전체는 클라우드에서 못 돌림(Roblox API 덤프 TLS 실패) — `src/shared/fight/*` 3개만 luau 표준으로 0 warnings.
- **남은 것**: qa 에이전트로 f1-01·f1-02 검증. 사용자 결정 GDD 11절 Q2(순서)·Q3(4번째 버튼).
- **다음에 할 첫 단계**: planner로 `docs/specs/f1-03-fight-foundation.md`(Fight 플레이스 역할·Config.Fight·리모트·FightService) 작성.

## 2026-11-11 갱신 (GDD v0.4)
- 사용자 결정: 기본 모드는 스킬 없이 순수 격투, 스킬은 스킬 모드(F2-01, 2차)에서만 판 시작 때 랜덤 1개.
- 목숨마다 룰렛(`rouletteSteps`·`FightConfig.Skills.Roulette`)은 지움. `roll(nextInt)`만 남김. 룰렛 연출 시안 아티팩트는 기록용으로만 남음(구현 대상 아님).
- 다음 첫 단계는 그대로: planner로 `docs/specs/f1-03-fight-foundation.md`.
