# m5-21 skin foundation v2 — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-a77b6e6f24bd409ff`, 브랜치 `worktree-agent-a77b6e6f24bd409ff` (push 안 함 — 메인 세션이 머지).
- **끝난 것**: 스펙 범위 전부(Wedge·효과 예산·박스 허용치·`Skins.validate` 확장), AC1~AC8(lune 테스트) 전부. 검증 5단계 전부 통과:
  1. `rojo build -o build.rbxl` 통과
  2. `stylua --check src tests` 통과
  3. `selene src` 0 errors/0 warnings
  4. `lune run tests` **1139 passed, 0 failed** (기존 21종 스킨 테스트 `tests/skins.spec.luau`·`tests/sushi-body.spec.luau` 전부 그대로 통과 확인)
  5. `luau-lsp analyze` 종료 코드 0
- **바뀐 파일**: `src/shared/SushiBody.luau`(Wedge·Smoke·Glow·EFFECT_BUDGET·BOUNDS_TOLERANCE), `src/shared/Skins.luau`(SushiBody require, validate에 등급별 기하 검사 추가), `tests/sushi-body.spec.luau`·`tests/skins.spec.luau`(새 테스트), `tests/m4-14-qa.spec.luau`(가짜 의존성 하네스에 SushiBody 추가 — Skins가 SushiBody를 require하게 되면서 필요해진 보강, 다른 변경 없음). 자세한 내용·메시지 문구는 `docs/specs/m5-21-skin-foundation-v2.md` "개발 메모".
- **남은 것**: QA, 사용자 Studio 확인(AC9~AC12 — Wedge 경사면 방향, 2이펙트 겹침 체감, 다수 착용 성능, 서버 시작 로그). 신규 스킨 10종(`m5-22`)이 이 인프라를 실제로 쓰게 됨.
- **다음에 할 첫 단계**: QA가 `docs/specs/m5-21-skin-foundation-v2.md` 수용 기준대로 확인 → main 병합 → `m5-22`(신규 스킨 10종)가 이 인프라를 사용.
- **막힌 점**: 없음. 모호한 부분 없이 스펙 설계 메모(Wedge bounds 재사용, 분리된 effectCount/budget 책임, Skins.validate 시그니처 유지 등) 그대로 따름.
