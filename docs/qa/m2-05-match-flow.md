# QA — m2-05 한 판 흐름 마무리 (출발 공정성 · 라운드 종료 규칙 · 생존형 결승 · 순위 · 생존자 방송)

- 스펙: `docs/specs/m2-05-match-flow.md`
- 검증 커밋: `134dcdc` (브랜치 `worktree-m2-match-flow`)
- 결과: **통과** (P0/P1 없음, P2 1건 · P3 2건) → 스펙 상태 `qa-passed`. Studio 항목 AC11~AC19는 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | 124 passed, 0 failed (QA 테스트 11개 추가 후) |

### M2 브랜치 머지 시험 (읽기 전용 확인)
scratch worktree에서 `134dcdc` 위에 `worktree-m2-hot-plate`(eac13b4) → `worktree-m2-skewer-showdown`(91c453a) → `worktree-m2-soy-swamp`(97a9491) → `worktree-m2-spectate`(0123b17)를 차례로 머지했다.
- 충돌 없음. 머지 결과에서 검증 4종 전부 통과, `lune run tests` 175 passed / 0 failed.

## 인터페이스 변경 호환성 (머지 후 맞물림)
| 대상 | 확인 내용 | 결과 |
|---|---|---|
| 맵 `MapTypes.RoundContext` 계약 | `MapTypes.luau`는 바뀌지 않았다. hot-plate·skewer-showdown·soy-swamp는 `ctx.model/origin/rng/cleanup/isActive/getRacers/pass/eliminate`만 쓰고 `RoundService`·`EliminationService`를 직접 부르지 않는다 (grep 확인). | 맞물림 |
| `ctx.eliminate` 한 프레임 모으기 | 세 맵 모두 `for _, player in ctx.getRacers() do … ctx.eliminate(player); if not ctx.isActive() then break end`. 지연 판정이라 `isActive()`는 프레임 끝까지 true로 남지만 `getRacers()`가 대기 중(pending)인 사람을 빼므로(`RoundService.luau:300-309`) 중복 탈락·누락이 없다. soy-swamp의 `ctx.pass`는 먼저 `flush()`(`RoundService.luau:314`)해서 같은 프레임의 낙하가 먼저 판정된다. | 맞물림 |
| 이동 잠금 | `map.start`는 잠금 해제 뒤에 불린다(`RoundService.luau:345-360`). soy-swamp 간장(WalkSpeed/JumpPower 변경)과 skewer·soy의 넘어짐(PlatformStand)은 출발 뒤에만 동작하고, 통과자는 `CharacterUtil.toLobby`가 이동 값을 되돌린다. | 맞물림 |
| `EliminationService` 시그니처 (`roomId` 첫 인자, `left`) | 다른 브랜치에서 부르는 곳 없음 (grep). | 영향 없음 |
| m2-06 UI (`aliveUserIds`/`racerUserIds`/`standings`) | `Types.luau` 모양 그대로 채운다. `SpectateController`는 `MatchPhase.aliveUserIds`, `RoundProgress.racerUserIds`, `PlayerResult`의 `Passed && mapKind=="Race"`를 쓰고, 서버는 Race 통과자에게만 그 조합을 보낸다(Survival 통과는 `mapKind=="Survival"`). `HudScreen`의 순위 패널은 `standings`를 `place`로 정렬해서 쓰고 서버는 1등부터 `{userId,name,place}`로 보낸다. 나간 사람의 `left()` 발표는 `userId ~= me`라 관전 UI에 영향 없음. | 맞물림 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `round-logic.spec` "AC1: Race 목표 2…" |
| AC2 | 통과 | `round-logic.spec` "AC2: Race 시간 종료…" |
| AC3 | 통과 | `round-logic.spec` "AC3", QA "Survival 같은 틱에 여러 명 탈락…" |
| AC4 | 통과 | `round-logic.spec` "AC4" 2개, QA "Survival 소개 중 탈락…" |
| AC5 | 통과 | `round-logic.spec` "AC5" |
| AC6 | 통과 | `round-logic.spec` "AC6" 3개, QA "결승 3명 중 2명이 같은 틱에…", "이탈(-inf)과 낙하가 같은 틱…" |
| AC7 | 통과 | `round-logic.spec` "AC7", QA "결승 시간 종료 높이 동점…" |
| AC8 | 통과 | `round-logic.spec` "AC8" 2개 |
| AC9 | 통과 | `round-logic.spec` "AC9" 2개, QA "24명 4라운드 매치 순위표" |
| AC10 | 통과 | `lune run tests` 124/124 |
| AC11 | 사용자 확인 필요 | 코드상: `prepareRound`가 소개 방송 직후 짓기·배치·`lockMovement`(`RoundService.luau:90-95, 286-289`), `run`이 `RoundActive` 방송 바로 뒤 해제(`MatchService.luau:197-207`) |
| AC12 | 사용자 확인 필요 | 코드상: 배치 뒤 `Died`/제거/`CharacterAdded` 감시(`RoundService.luau:246-262`), 라운드 사이엔 감시 없음(close가 Cleanup으로 해제). `RespawnTime = 1`이라 결과 단계 리셋 뒤 소개 배치(대기 5초)에 늦지 않는다 |
| AC13 | 사용자 확인 필요 | 코드상: `Passed` 즉시 `CharacterUtil.toLobby`(`RoundService.luau:199-207`). 대기석 = 로비 스폰(아레나와 높이 300·슬롯 간격 떨어짐) |
| AC14 | 사용자 확인 필요 | 로직은 AC4 테스트로 확인 |
| AC15 | 사용자 확인 필요 | 로직은 AC5/AC6 테스트로 확인 |
| AC16 | 사용자 확인 필요 | 서버 Output `[MatchService] room … standings:` 줄(`MatchService.luau:230-235`) |
| AC17 | 사용자 확인 필요 | 맵 Model은 Cleanup에 Workspace 넣기 전 등록(`RoundService.luau:121`), 별도 대기석 Model 없음 |
| AC18 | 사용자 확인 필요 | `RoomService.luau` 미변경 (diff 확인) |
| AC19 | 사용자 확인 필요 | 코드상: `onMemberLeft`가 생존자에서 빼고 `handlePlayerLeft`→`queueFall(-inf)`(`MatchService.luau:271-289`, `RoundService.luau:332-338`) |

통과 10 / 실패 0 / 사용자 확인 필요 9.

## 버그
### [P2] F1 중간 라운드에서 레이서 전원이 탈락하면 마지막 탈락자가 "탈락 1등"을 받고 그 사람이 우승자로 Victory가 나간다
- 재현 (순수 로직으로 확인, lune 임시 스크립트):
  1. 4명 매치 R1 Race(목표 2). 아무도 결승선을 못 넘고 4명이 차례로 떨어지거나 리셋한다 (Survival에서 남은 사람이 한 프레임에 전부 떨어져도 같다).
  2. `RoundLogic.eliminate`가 등수 4,3,2,**1**을 `Eliminated`로 매긴다 (`placeEliminated`가 nextWorst를 1까지 내림).
  3. `MatchService`는 생존자 0명이라 루프를 끝내고 `RoundLogic.winnerOf(standings)`로 1등(=마지막 탈락자)을 찾아 Victory에 `winnerUserId`로 보낸다. 그 사람에게는 `Won`이 안 가고 "탈락 1등"만 간다.
- 기대: 스펙에 정의 없음. 결승이 아닌 라운드에서 우승이 정해지면 안 되고, 받은 결과(탈락)와 Victory(우승)가 어긋나면 안 된다.
- 실제: 위와 같음. 크래시는 없고 순위표 등수는 빈틈없다.
- 위치: `src/shared/RoundLogic.luau:208-220` (Race/Survival은 `left == 0`이어도 통과자 0명으로 끝냄), `src/shared/RoundLogic.luau:316-325`, `src/server/MatchService.luau:222-228`
- 제안 (기획 결정 필요 → planner): (A) 중간 라운드에서 남은 사람이 0명이 되는 탈락 묶음이면 그 묶음에서 점수가 가장 큰 1명을 통과시켜 결승 규칙처럼 "누군가는 남게" 한다, 또는 (B) 지금처럼 끝내되 MatchService가 그 경우 1등에게 `Won`을 보낸다. 리셋 = 탈락 규칙 때문에 일부러 재현할 수 있다.

### [P3] F2 결승 소개 중 2명 → 1명이 되어 우승이 나면, 우승자가 잠긴 채 사라지는 맵에서 떨어진다
- 재현: 결승 소개(3초) 중 2명 중 1명이 리셋/퇴장 → `RoundLogic.eliminate`가 남은 사람을 `Won` 처리 → `MatchService`가 `aliveCount < 2`로 `prepared.cancel()`.
- 기대: 우승자가 로비 스폰(대기석)으로 옮겨져 Victory를 본다.
- 실제: `cancel()`은 `RoundLogic.racers(round)`(아직 통과/탈락 안 한 사람)만 로비로 보낸다. 우승자는 이미 racers에서 빠져 있어 이동 잠금(WalkSpeed/JumpPower 0) 상태로 맵이 지워진 허공에 남아 떨어진다. Victory 끝의 `sendHome`이나 리스폰으로 결국 로비에 온다 (보기만 나쁨).
- 위치: `src/server/RoundService.luau:399-411` (`qualified`도 로비로 보내면 된다)

### [P3] F3 소개 중 캐릭터가 5초 안에 안 생긴 레이서는 감시도 배치도 안 된 채 레이서로 남는다
- 재현: 소개 시작 때 캐릭터가 없고 5초 안에 생기지 않는 플레이어(로딩 지연 등).
- 기대: 탈락하거나, 늦게라도 배치된다.
- 실제: `placeAt`이 경고만 남기고 끝난다. Race는 시간 종료에 -inf로 탈락하지만, Survival은 시간 종료에 "버틴 사람"으로 통과한다. `RespawnTime = 1`이라 리셋으로는 재현되지 않는다.
- 위치: `src/server/RoundService.luau:264-271`

### 관찰 (버그 아님)
- m2-06 `HudScreen.progressText`는 진행 문구를 `mapKind`로 고른다. 결승에 Race 맵이 쓰이는 개발 초기 fallback에서는 "통과 0/1"로 보인다. skewer-showdown 머지 뒤 일반 플랜에서는 나오지 않는다.
- 개발 메모의 세부 결정(결승 fallback 시간 종료는 진행도 기준, 같은 프레임 묶음은 점수 낮은 사람부터 나쁜 등수, 소개 중 탈락자는 그 라운드 탈락)은 스펙과 어긋나지 않는다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 클라이언트 → 서버 리모트를 추가하지 않았다 (서버 → 클라이언트 방송만)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — `RoundLogic`(shared지만 서버만 호출), `RoundService`, `MatchService`
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 라운드 상태는 `prepareRound` 호출마다 지역 상태, 모듈 전역은 방 id 키의 `activeRemovers`/`matches`뿐
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 맵 Model, 감시 연결, 배치 스레드, `map.cleanup` 모두 `cleanup`에 등록, `run`/`cancel`/`prepare 실패` 모두 `close()`

## 사용자 Studio 확인 체크리스트
`cd .claude/worktrees/m2-match-flow && rojo serve --port 34876`. 강제 플랜은 `Config.DEBUG.forceMapPlan`을 로컬에서만 바꾸고 커밋하지 않는다. 지금 이 브랜치에는 hot-plate·skewer-showdown이 stub이라 AC14·AC15는 **M2 브랜치 머지 뒤(m2-07)** 확인하는 게 정확하다.
1. AC11: 아무 판 시작 → 소개 배너가 떠 있는 동안 새 맵 스폰 위에 서 있고 WASD·Space가 안 먹힘 → 배너가 사라지고 타이머가 도는 순간 모두 움직임.
2. AC12: 라운드 중 Esc → Reset Character → "🥢 탈락했어요…", 다음 라운드에 배치 안 됨. 결과 화면(5초) 중 리셋 → 다음 라운드에 정상 배치.
3. AC13: `forceMapPlan = { "rotating-belt", "soy-swamp", "skewer-showdown" }` 2명 이상 → 결승선 통과 1초 안에 로비 스폰으로 이동, 라운드가 끝나도 떨어지지 않음.
4. AC14: `{ "hot-plate", "rotating-belt", "skewer-showdown" }` 4명 → 철판에서 60초 버티면 버틴 사람 전원 "통과".
5. AC15: 결승에 3명 이상 → 한 명씩 떨어지다 1명 남는 순간 "🏆 우승!", 라운드 즉시 종료.
6. AC16: 우승 때 서버 Output `[MatchService] room … standings: 1. … , 2. …` 줄 수 = 시작 인원, 각자 받은 "n등"과 같음.
7. AC17: 5명 랜덤 판 끝까지 → 우승자 1명, Workspace에 `Round…` Model이 남지 않음.
8. AC18: 정원 4명 방, 매치 끝나고 대기실에서 10초 자동 시작 카운트다운이 다시 뜸.
9. AC19: 매치 중 한 명 접속 종료 → Output 에러 없음, 남은 인원·생존자에서 빠짐. 결승 2명 중 1명이 나가면 남은 사람 우승.
10. (F2 확인용, 선택) 결승 소개 3초 안에 2명 중 1명이 리셋 → 남은 사람이 허공에서 떨어지는지.

## 추가한 테스트
- `tests/m2-05-qa.spec.luau` (11개): 결승 3명 중 2명 동시 탈락, 결승 이탈(-inf)+낙하 동시, 결승 시간 종료 동점(30 시드), 결승 종료 뒤 입력 무시, Survival 동시 다수 탈락, Survival 소개 중 탈락, Race 동시 탈락 묶음 등수, Race 목표 = 인원, 24명 4라운드 순위표, `standingsList` 빈 등수 채우기, `newRound` 중복 id.

## 인계 메모 (QA)
- 브랜치 `worktree-m2-match-flow`. QA 완료 → `qa-passed`. 남은 것: 사용자 Studio 확인(AC11~19), F1은 기획 결정(planner) 뒤 개발.
