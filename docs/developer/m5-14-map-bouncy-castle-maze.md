# m5-14 map bouncy-castle-maze — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-a338176d7e112bd3c` (브랜치 `worktree-agent-a338176d7e112bd3c`). 메인 세션이 머지 — 이 worktree에서 별도 push는 안 함.
- **끝난 것**: 스펙 범위 전부(실제 코스 구현, `Logic.bounceProfile`·`Logic.blockedAt` 분리, 아트, IntroCamera, `inPool = false` 줄 삭제), AC1~AC8, 검증 5단계 전부 통과(`rojo build`, `stylua --check`, `selene`, `lune run tests` 1163 passed/0 failed, `luau-lsp analyze` 종료 코드 0).
- **바뀐 파일**
  - `src/shared/maps/BouncyCastleMaze.luau` — m5-13 껍데기(회색 바닥+스폰24+FinishLine)를 덮어씀. 바닥 4장(A 일반/B+C `BounceFloor` 한 장/D 일반/E 일반), 양옆·출발·끝 벽(높이 `Layout.WALL_HEIGHT` 14), 칸막이 3개(색이 서로 다름, 각자 막힌 구간만큼만), 입구 문(열린 쪽 — 1번 레인 — 은 아예 안 만듦), 스폰 24개(6×4 격자), 결승선, 바운스 스테퍼(매 Heartbeat `BounceFloor` 태그로 레이캐스트해 쿨다운마다 `LinearVelocity` 수직 튕김 + `MoveExempt.mark`), 소개 카메라·Studio 아트 연결.
  - `src/shared/maps/BouncyCastleMazeLayout.luau` (신규) — 코스 치수(구간 Span 5개: `START`·`ANTEROOM`·`MAZE`·`EXIT`·`FINISH`), 레인(`LANES` 4개)·칸막이(`PARTITIONS` 3개)·관문(`GATE`)·바깥 벽(`BOUNDS`) 데이터, 바운스 상수(`BOUNCE_UP_SPEED` 55·`BOUNCE_HOLD` 0.08·`BOUNCE_COOLDOWN` 0.45·`BOUNCE_EXEMPT` 0.8·`BOUNCE_RAYCAST_LENGTH` 3.5), 스폰 24개 격자(`spawnPositions`).
  - `src/shared/maps/BouncyCastleMazeLogic.luau` (신규) — 순수 계산 전용: `blockedAt(x, z, partitions, gate, bounds)`(미로 격자 판정, 1 stud 플러드필 테스트가 이걸로 길을 찾음), `bounceProfile(upSpeed, gravity)`(포물선 apex·flightTime), `fallLineAt(z)`(상수 -40, 서명만 z를 받고 전 구간 동일).
  - `src/shared/maps/BouncyCastleMazeArt.luau` (신규) — 판정 파츠 색(`COLORS`: 일반 바닥 베이지, BounceFloor 주황, 바깥 벽 분홍, 입구 문 빨강, 칸막이 3개 각각 파랑/초록/보라), 장식(체크무늬 바닥 144개, 입구 문 경고 줄무늬, 칸막이·벽 위 풍선, 바깥 벽 삼각 깃발, 테두리 공기 주입구, 유원지 조명 기둥 6개 — `CarnivalLamp`에 `build`가 `PointLight`를 붙임, 결승 체크무늬), 소개 카메라 4점(입구 → 1번 레인 위 내려다보기 → 꺾이는 지점 → 결승 문). 장식 합계 약 290개 파츠, 조명 6개(예산 12 안), 파티클 0개 — 전부 예산 안.
  - `tests/map-bouncy-castle-maze.spec.luau` (신규) — AC1~AC7 순수 테스트. 특히 AC3·AC4는 1 stud 격자 BFS 플러드필을 직접 구현해서 `Logic.blockedAt`으로 길 연결성(입구 1번 레인 → 출구 직전 레인4, 가장 좁은 통과 폭 ≥8 studs — 실측 약 9)과 입구 문이 지름길을 막는지(관문 폭 전체에서 1번 레인 밖은 전부 막힘, 안쪽은 전부 열림을 직접 확인)를 검증.
  - `src/shared/SfxCues.luau`, `src/shared/SfxLibrary.luau` — 새 cue `BounceBoing` 추가(`sfx(nil, 0.7)`, 기본 무음). 스펙에 "m5-13이 cue 이름을 확정"이라고 적혀 있었지만 실제로는 m5-13이 cue를 추가하지 않았음을 확인해서(grep으로 재확인), 기존 `WasabiBoing`·`JellyBoing` 같은 맵 장애물 효과음 패턴대로 이 스펙에서 새로 만듦.
  - 기존 테스트 수정(맵 1개가 랜덤 풀에 합류하면서 하드코딩된 개수·목록이 달라짐 — developer 소유 파일이라 직접 고침):
    - `tests/maps.spec.luau` — "맵 풀 6개가 모두 validate" 테스트를 7개로.
    - `tests/m5-03-foundation.spec.luau` — `SHELLS` 목록에서 `bouncy-castle-maze` 제거(9→8개), AC1의 `expected` 표에서도 제거(이제 "else: 풀에 남아 있다" 분기로 확인), AC2 "infos()는 6개" → 7개 + 합류 확인 단언 추가.
    - `tests/m4-foundation.spec.luau` — "맵 풀 Race 3" 테스트의 하드코딩 목록에 `bouncy-castle-maze` 추가(Race 3→4개).
    - `tests/m4-12-hardening.spec.luau` — 연속 5판 강제 플랜 중 하나(`{ "rotating-belt", "soy-swamp", "skewer-showdown" }`)의 `rotating-belt`를 `bouncy-castle-maze`로 바꿔서, "맵 풀 전부가 5판 안에 한 번 이상 나온다" 단언이 새 맵도 커버하게 함.
    - `tests/camera-priority.spec.luau` — "SfxCues 확정 목록" 테스트에 `BounceBoing` 추가.
  - `docs/specs/m5-14-map-bouncy-castle-maze.md` — status `ready` → `in-qa`(중간 `in-dev` 단계는 같은 세션 안에서 바로 통과), 개발 메모·Studio 확인 목록 작성.
- **결정 기록**: D1~D4 전부 "기본값으로 진행"이라 적혀 있어서 스펙 수치(위 속도 55, 쿨다운 0.45, 벽 높이 14, 칸막이·관문 좌표 등) 그대로 구현. 별도 질문을 추가하지 않음.
- **구현 메모 (스펙과 다르게 해석한 부분, 전부 스펙 의도 안에서의 구체화)**
  - `Logic`/`Layout` 분리: 스펙이 "`Logic.bounceProfile`·`Logic.blockedAt` 분리"라고 명시했는데 m5-13 껍데기 주석·참고 파일(`SoySwampLayout`)은 Layout 하나에 계산 함수까지 두는 패턴이라, 치수 데이터는 `Layout`에 남기고 판정·물리 계산 함수만 `Logic`으로 뽑았다(`HotPlateLogic`처럼 데이터+계산을 합치는 기존 맵도 있지만, 이 스펙은 두 파일을 명시적으로 나열해서 분리를 택함).
  - AC4 테스트: "대기실에서 2·3·4번 레인으로 직접 넘어가는 경로가 없다"를, 레인1을 거치는 정상 경로까지 막아버리는 과잉 제약이 되지 않도록 "관문 폭 전체에서 1번 레인 밖은 막혀 있고 안쪽은 열려 있다"는 직접 판정 + 좁은 영역(1번 레인 제외 x범위)에서의 보조 플러드필로 구현. (전체 대기실에서 플러드필을 돌리면 1번 레인을 거쳐 미로까지 가는 "정상 경로"가 걸려서 거짓 실패가 났을 것 — 이건 버그가 아니라 설계상 의도된 길이라 테스트 범위를 좁혔다.)
  - 바운스 효과음 `BounceBoing`: 위 참고.
- **검증 5단계**: 전부 통과. 처음에 `BouncyCastleMazeArt.addGateStripes`에서 1번 레인이 왼쪽 벽에 바로 붙어 있어 왼쪽 문 폭이 0이 되는 경우(크기 0 DecorSpec)를 안 거르고 만들어서 `MapKitLogic.validate` 실패 → 폭이 0 이하면 건너뛰도록 고쳐서 해결. `stylua`는 자동 재포맷(`stylua src tests`)으로 통과.
- **Studio 확인 필요 (AC9~AC16, 이 worktree에서는 Studio를 못 돌려 직접 확인 못 함)**: `docs/specs/m5-14-map-bouncy-castle-maze.md`의 "Studio 확인" 절 참고. 요약:
  1. `Config.DEBUG.forceMapPlan = { "rotating-belt", "bouncy-castle-maze", "hot-plate" }`로 Play Solo(또는 Clients and Servers 2명).
  2. B·C 구간에서 멈추지 않고 계속 튕기는지, A·D·E에서는 안 튕기는지(AC9), 튕기면서도 방향을 바꿔 틈으로 들어갈 수 있고 칸막이를 점프로 못 넘는지(AC10), 대기실에서 1번 레인 없이 다른 레인으로 바로 못 들어가는지(AC11), 미로 밖으로 떨어지면 1초 안에 탈락 연출(AC12), 2명이 동시에 튕겨도 이동 감시 로그가 안 생기는지(AC13), 휴대폰 에뮬레이터에서 점프·다이브가 되는지(AC14), 혼자 60~90초 완주 체감(AC15), 다음 맵에서 이동이 평소와 같은지(AC16).
  3. 확인 뒤 **`forceMapPlan`을 반드시 `nil`로 되돌리기**.
- **남은 이슈 / 막힌 점**: 없음. Studio 확인만 사용자 몫.
- **다음에 할 일**: QA가 `docs/specs/m5-14-map-bouncy-castle-maze.md` 수용 기준(AC1~AC8 lune, AC9~AC16 Studio)대로 확인 → main 머지.
