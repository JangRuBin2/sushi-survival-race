# m5-13 map expansion foundation — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-adc34d787c5bacd97` (브랜치 `worktree-agent-adc34d787c5bacd97`). 메인 세션이 머지 — 이 worktree에서 별도 push는 안 함.
- **끝난 것**: 스펙 범위 전부(신규 맵 6개 껍데기 + `shared/maps/init.luau` 등록 + 테스트 갱신), AC1~AC6, 검증 5단계 전부 통과(`rojo build`, `stylua --check`, `selene`, `lune run tests` 1135 passed/0 failed, `luau-lsp analyze` 종료 코드 0).
- **바뀐 파일**
  - 새 맵 6개(기존 `IkuraBombs`·`DessertFridge`·`TempuraPot` 껍데기와 똑같은 패턴, 머리 주석에 "m5-13 껍데기 → m5-1X"와 원안 번호 표시):
    - `src/shared/maps/BouncyCastleMaze.luau` — Race, `DessertFridge` 패턴(바닥+스폰24+FinishLine) → m5-14
    - `src/shared/maps/LanternBridge.luau` — Race, 같은 패턴 → m5-15
    - `src/shared/maps/GiantJenga.luau` — Survival, `TempuraPot` 패턴(바닥+스폰24, 낙하만) → m5-16
    - `src/shared/maps/CatCafeShelves.luau` — Survival, 같은 패턴 → m5-17
    - `src/shared/maps/TugOfWarPlatform.luau` — Final, `IkuraBombs` 패턴(접시+스폰24+낙하+overtime) → m5-18
    - `src/shared/maps/ClawMachinePrize.luau` — Final, 같은 패턴 → m5-19
  - 공용(이 스펙의 담당 파일): `src/shared/maps/init.luau` — `ALL`에 6개 `require` 추가, `inPool = false`. `Maps.infos()`는 그대로 6개, `Maps.allInfos()`는 9 → 15개.
  - 테스트:
    - `tests/m5-03-foundation.spec.luau` — `SHELLS` 목록(9개)로 확장, AC1 테스트 제목/개수(15)와 `expected` 표에 6개 추가, `tug-of-war-platform`·`claw-machine-prize`의 `overtime` 함수 단언 추가, AC2 테스트 제목(allInfos 15개), `buildRoundPlan` 1,000회 테스트의 하드코딩 `shell` 표를 `SHELLS`에서 만들도록 변경. 숫자만 맞추고 m5-03 테스트의 원래 의도는 그대로 둠.
    - `tests/maps.spec.luau` — `Rules` require 추가, AC3("Maps.get으로 6개 조회")·AC4(`resolveForcedPlan`이 신규 맵도 순서대로) 테스트 신규 추가. "맵 풀 6개가 모두 validate를 통과해요"는 스펙 지시대로 숫자(6) 안 건드림.
  - `docs/specs/m5-13-map-expansion-foundation.md` — status `ready` → `in-dev` → `in-qa`, AC1~AC6 체크, 개발 메모 작성.
- **스펙 오타 발견** (수정은 안 함, planner 확인 필요): 스펙 17·44·54·65줄이 "`Maps.infos()`는 그대로 **9개**"라고 쓰는데, 같은 스펙 45줄("`Maps.infos()` 개수 **6** 그대로 — 안 바뀜, 혼동 방지로 수용 기준에 명시")과 실제 기존 코드·테스트(`m5-03-foundation.spec.luau`의 "AC2: infos()는 **6개**")는 둘 다 6이 맞다고 확인된다. 구현·테스트는 **6**으로 맞췄다(기존 랜덤 풀 맵 6종은 그대로, 안 바뀐 게 맞음). 스펙 문서 자체의 9↔6 오타만 planner가 정리해 주면 됨.
- **AC 구현 매핑**: AC1·AC2는 `tests/m5-03-foundation.spec.luau`, AC3·AC4는 `tests/maps.spec.luau`에 새로 추가, AC5는 기존 AC2 테스트(`shell` 표 확장)로 커버, AC6은 아래 검증 결과.
- **검증 5단계**: 전부 통과. `stylua --check`가 처음 `tests/maps.spec.luau`의 새 테스트 2곳 줄 길이로 걸려서 `stylua src tests`로 자동 재포맷 후 재확인 통과.
- **Studio 확인 필요 (AC7·AC8, 이 worktree에서는 Studio를 못 돌려 직접 확인 못 함)**: 사용자가 `docs/DEV-SETUP.md` 디버그 설정 안내대로
  1. `Config.DEBUG.forceMapPlan = { "bouncy-castle-maze", "giant-jenga", "tug-of-war-platform" }`로 바꾸고 Play Solo로 한 판을 끝까지 돌려서 — Race는 평평한 바닥을 달려 결승선 통과, Survival은 시간(기본 `Config.TimeLimit.Survival`) 동안 버티면 생존 통과, Final은 90초에 연장전이 걸리고 `Config.Final.CollapseDuration`초 뒤 접시가 사라져 마지막까지 버틴 사람이 우승하는지 확인. Output 창에 에러가 없는지도 확인.
  2. 확인이 끝나면 **`forceMapPlan`을 다시 `nil`로 되돌리기** (커밋 전 기본값).
  3. 그 뒤 Play Solo로 로비에 들어가 지금과 똑같이 보이는지(새 맵 버튼·표시 없음) 확인. 필수는 아니고, 여유 되면 랜덤 판 몇 번 돌려서 신규 6개가 안 나오는지 체감해도 됨.
- **남은 이슈 / 막힌 점**: 없음. 6개 전부 기존 3개 껍데기와 동일한 구조(회색 바닥/접시 + 스폰 24개 + 낙하 판정, Race는 FinishLine, Final은 overtime 훅)라 치수(`SIZE`/`LENGTH`/`FALL_DEPTH` 등)는 기존 값을 그대로 재사용함 — 스펙이 명시한 대로 실제 구현(m5-14~m5-19)이 전부 덮어쓸 예정이라 치수 자체는 중요하지 않음.
- **다음에 할 일**: QA가 `docs/specs/m5-13-map-expansion-foundation.md` 수용 기준(AC1~AC6 lune, AC7~AC8 Studio)대로 확인 → main 머지 → 맵마다 `m5-14`~`m5-19` worktree를 만들어 병렬 개발.
