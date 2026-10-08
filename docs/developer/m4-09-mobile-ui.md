# m4-09 mobile UI — 개발 작업 기록

## 2026-10-08 — QA 반려 수정, 다시 in-qa (최신)
- **브랜치**: 로컬 `m4-09-mobile` → `origin/m4-09-qa`에 push. origin/m4-09-qa(d913f64)와 origin/main을 병합함, 충돌 없음.
- **끝난 것**:
  - B1(P1): `UiScaleController.attach`가 TopbarSafeInsets gui의 안전 영역을 그대로 둠.
  - B4: 그 gui에는 UIScale도 붙이지 않음. `attach(gui, { scale })` 옵션 추가. CoinController(m4-08)는 수정할 필요가 없었음.
  - B2: 방 만들기 창 높이를 LobbyGui 실제 높이 기준으로 계산.
  - B3: JUMP_LARGE.right 170.
- **검증**: rojo build OK, stylua OK, selene 0/0/0, lune 672 passed / 0 failed.
- **남은 것**: 재QA, Studio 확인 AC4~AC8, AC9(사용자).
- **다음에 할 첫 단계**: QA가 m4-09-qa 브랜치를 재검증.
- **막힌 점**: 없음.

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-09-mobile` (origin/main f33086b 기반), push 완료.
- **끝난 것**: 스펙 범위 1~5 전부 (6 콘솔은 TextButton 기본 `Selectable = true`라 그대로). 자세한 건 스펙 "개발 메모".
  - 순수 `src/shared/UiLayout.luau` + `tests/ui-layout.spec.luau` 9개.
  - `UiScaleController` 구현 (attach / metrics / onChanged).
  - 로비·방·HUD·관전·출발 글씨·우승 글씨·다이브·잡기 버튼 배치.
  - 관전 ←/→ 바인딩 제거.
  - `tests/m3-06-qa.spec.luau` 글자 검사 2줄 갱신 (다이브 글씨·간격 상수 이동).
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 528 passed / 0 failed.
- **남은 것**: Studio AC4~AC8 (기기 에뮬레이터), AC9 실제 휴대폰 (사용자). QA.
- **다음에 할 첫 단계**: QA가 Device 에뮬레이터 iPhone SE에서 로비 → 매치 → 관전을 확인. UIScale을 ScreenGui에 둔 동작부터 확인.
- **막힌 점**: 없음.
- **메모**:
  - LobbyGui에 UIScale이 붙어서 Absolute*(실제 픽셀)를 Offset으로 쓰는 코드는 scale로 나눠야 함.
  - 코디네이터가 RamenRapids 스폰 수정(m4-01 QA B1)을 지시했지만, 이 스펙이 고치는 파일이 아니고 다른 worktree 담당이라 손대지 않음 → 코디네이터에게 보고.
