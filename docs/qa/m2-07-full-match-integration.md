# QA — m2-07 M2 통합: 3~4라운드 한 판이 끝까지 돈다

- 스펙: `docs/specs/m2-07-full-match-integration.md`
- 검증 커밋: `1b74b08` (main, M2 스펙 6개 병합 + m2-07 통합 수정)
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. Studio 확인(AC3~AC10)은 사용자 확인 필요 — 아래 "한 번에 따라 하는 Studio 체크리스트".

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 209 passed, 0 failed (개발 206 + QA 추가 3) |

참고: 검증 4종에는 Luau 타입 검사(`luau-lsp analyze` 등)가 없다. 그래서 m2-05에서 시그니처가 바뀐 `EliminationService.passed/won/left/eliminate(roomId, …)`의 호출부 6곳을 손으로 대조했고, 모두 맞았다 (`MatchService.luau:232, 288`, `RoundService.luau:194-206`). `StubMap` 삭제 뒤 남은 참조도 없다.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | 위 자동 검증. rules·maps·round-logic·spectate·m1-retro 포함 17개 spec 파일 |
| AC2 | 통과 | `m2-01-qa.spec.luau` `실제 맵 풀: 3·4라운드 구성 500판씩…`이 실제 `Maps.infos()`(rotating-belt·soy-swamp·hot-plate·skewer-showdown)로 돈다. `실제 맵 풀: 결승은 언제나 skewer-showdown`도 통과 |
| AC11 | 통과 | `m2-07 AC11: Race 목표 2, 4명이 차례로 떨어지면…`, `…같은 틱에 3명이 떨어지면 더 멀리 간 사람부터 구제해요`. 코드: `RoundLogic.eliminate`의 구제 분기 (`RoundLogic.luau:307-336`) |
| AC12 | 통과 | `m2-07 AC12: Survival 목표 3, …높이 10·7 구제, 2 탈락` |
| AC13 | 통과 | `m2-07 AC13: … 3번째 리셋 순간 종료, 남은 1명 부전승 Won`, `m2-07 혼자 남음` 4개. 코드: `checkEnd`의 혼자 남음 분기 (`:229-238`) + `MatchService.luau:212-214` break → `decideWinner` → `won` → Victory (`:230-249`) |
| AC3 | 사용자 확인 필요 | 체크리스트 2 |
| AC3-1 | 사용자 확인 필요 | 체크리스트 3 |
| AC3-2 | 사용자 확인 필요 | 체크리스트 2 |
| AC4 | 사용자 확인 필요 | 체크리스트 5 |
| AC5 | 사용자 확인 필요 | 체크리스트 2 |
| AC6 | 사용자 확인 필요 | 체크리스트 2·4 |
| AC7 | 사용자 확인 필요 | 체크리스트 6 |
| AC8 | 사용자 확인 필요 | 체크리스트 7 |
| AC9 | 사용자 확인 필요 | 체크리스트 2·3에서 시간 측정 |
| AC10 | 사용자 확인 필요 | 모든 단계에서 Output 확인 |

요약: 순수 로직 AC1·AC2·AC11~AC13 통과, Studio AC3~AC10 사용자 확인 필요. 실패한 기준은 없다.

## 중점 확인 (1) — F1 "결승 진출 2명 보장"·"혼자 남으면 즉시 부전승"과 Won/Victory 불변식
**Won이 나가는 경로는 두 곳뿐이다.**
1. 결승 라운드 안 (`RoundLogic`의 Final 모드): 1명 남음, 같은 틱 묶음에서 0명 → 묶음 최고 점수, 시간 종료 → 최고 점수, Race 맵 결승 fallback → 첫 통과자. `RoundService.apply`가 `applyOutcomes`(→ `placeWinner`가 `winnerUserId` 기록) 뒤 `EliminationService.won`을 보낸다.
2. 매치 끝 (`MatchService.luau:230-233`): `decideWinner`가 이미 `winnerUserId`가 있으면 그대로 돌려주고(`needsWon = false`, Won을 다시 보내지 않음), 없고 생존자가 정확히 1명일 때만 부전승(`needsWon = true`)으로 Won을 보낸다.

→ 결승은 한 판에 한 번뿐이고(`isFinal = roundIndex == roundCount`, 그 뒤 `nextRound`가 nil), 경로 2는 경로 1이 이미 있으면 Won을 보내지 않으므로 **Won은 많아야 1번**이다. Victory는 `decideWinner`의 결과 = `standings.winnerUserId`로 나가므로 **Victory 우승자 = Won 받은 사람**이다. 생존자 0명이면 Victory가 없다.

**QA 시뮬레이션** (`tests/m2-07-qa.spec.luau`): MatchService 루프(`roundToPlay` → 라운드 → 결승 전 혼자 남음 break → `nextRound` → `decideWinner`)를 실제 맵 풀과 `Rules`·`RoundLogic`으로 흉내 냈다. 시작 인원 2~24, 무작위 통과·낙하·리셋·같은 틱 묶음(1~3명)·시간 종료로 한 판씩 돌린 결과:
- 3000판 (리셋 포함): Won ≤ 1, Victory 우승자 = Won 받은 사람, Eliminated를 받은 사람이 우승한 경우 0
- 3000판: 순위표 줄 수 = 시작 인원, 등수 중복 없음, 우승자가 있으면 1등 = 우승자
- 3000판 (낙하만, 리셋 없음): 결승은 항상 2명 이상으로 시작, 항상 우승자가 나오고 부전승 없음 → "결승 진출 2명 보장"이 무작위 상황에서도 지켜진다

**코드로 확인한 연결부**
- 구제(Passed)는 `apply`의 통과 분기로 가서 `passed` 방송 + 로비 스폰(대기석) 이동을 한다 → 떨어지던 캐릭터가 허공에 남지 않는다.
- 혼자 남은 사람은 `Passed`(대기석으로) → 매치 끝에 `Won` 순서로 받는다. 클라이언트(m2-06)는 Race면 Passed에서 자동 관전을 켜지만, 곧바로 Victory가 와서 우승자(자기) 카메라가 된다.
- 리셋 사유: `Died`, 캐릭터 제거·교체, 방 퇴장(`activeRemovers`), 캐릭터 없음(`placeAt` 실패)은 모두 `"Reset"`. 맵의 `ctx.eliminate`만 `"Fall"`이다 (`RoundService.luau:236-266, 273-278, 325-329, 342-348`).

**남은 점 → I1 (P3)**: 결승의 같은 틱 묶음은 사유를 보지 않는다. 아래 버그 참고.

## 중점 확인 (2) — 맵 4개 × RoundLogic 계약
| 맵 | kind | 맵이 부르는 것 | 중간 라운드 모드 | 마지막 라운드 모드 | 점수(scoreOf) | 확인 |
|---|---|---|---|---|---|---|
| rotating-belt | Race | `pass`(결승선 위치), `eliminate`(낙하) | Race | Final(fallback: 첫 통과 = Won) | 진행도(로컬 −Z) | ✅ |
| soy-swamp | Race | `pass`, `eliminate` | Race | Final(fallback) | 진행도 | ✅ |
| hot-plate | Survival | `eliminate`만 | Survival | Final(강제 플랜에서만) | 높이 | ✅ |
| skewer-showdown | Final | `eliminate`만 | Survival(강제 플랜에서만) | Final | 높이 | ✅ |

- 모드는 `RoundLogic.modeFor(map.kind, isFinal)` 하나로 정해진다 (`RoundService.luau:134-135`). 결승 여부는 라운드 번호 기준(B8)이다.
- 점수 축이 맵과 맞는다: Race 맵 두 개는 코스가 로컬 −Z로 뻗고(MapTypes 약속), 생존형 두 개는 높이가 곧 "더 버틴" 정도다 (철판은 위층일수록 높고, 꼬치는 무대 위가 높다).
- 맵은 모두 `ctx.getRacers()`로만 판정·장애물을 돌린다. `getRacers`는 배치가 끝났고 아직 판정 대기(`pendingIds`)가 아닌 레이서만 돌려준다. 그래서 (a) 배치 전 로비 캐릭터를 맵이 판정하지 않고(N1 계열 수정), (b) 같은 사람이 매 프레임 `eliminate`를 불러도 한 번만 묶음에 들어간다.
- `ctx.isActive()`는 `round.active and not round.ended and not closed`다. 네 맵 모두 Heartbeat 첫 줄에서 확인하고, `pass`/`eliminate` 직후 라운드가 끝나면 루프를 멈춘다.
- `ctx.pass`는 먼저 `flush()`로 같은 프레임의 낙하를 처리한다 → 결승선 통과와 낙하가 같은 프레임이면 낙하가 먼저 반영된다.
- 장애물 상태 복구: 통과·구제·우승자는 `toLobby`, 탈락자는 3초 뒤 `toLobby`, 다음 라운드는 `placeAt`의 `lockMovement` → 출발 때 `resetMovement`로 WalkSpeed·JumpPower·PlatformStand를 되돌린다. 간장(JumpPower 0), 젓가락(WalkSpeed/JumpPower 0), 꼬치·날치알(PlatformStand)이 라운드 밖으로 새지 않는다.

## 중점 확인 (3) — 이전 QA 리포트의 P3 처리 현황
| 출처 | 항목 | 통합 뒤 상태 | 근거 |
|---|---|---|---|
| M1 재검증 N1 / m2-03 H1 / m2-04 B2 / m2-02 W1 | 리스폰 중 캐릭터가 로비에서 낙하 판정 | **고쳐짐** | `placed` 집합으로 배치된 레이서만 `getRacers`에 넣고, 배치 전 `ctx.eliminate`는 무시 (`RoundService.luau:148, 291, 312, 326`) |
| M1 재검증 N2 | `placeAt` 스레드가 정리되지 않음 | **고쳐짐** | `cleanup:add(task.spawn(placeAt, …))` (`:296`), `placeAt`은 `closed`도 확인 (`:270`) |
| m2-05 F1 (P2) | 레이서 전원 탈락 시 탈락 1등이 우승자로 | **고쳐짐** | 이 리포트 (1) |
| m2-05 F2 | 결승 소개 중 우승자가 사라지는 맵에서 낙하 | **고쳐짐** | `cancel()`이 `qualified`도 로비로 (`:417-424`) |
| m2-05 F3 | 캐릭터가 안 생긴 레이서가 감시 없이 남음 | **고쳐짐** | `placeAt` 실패 → `Reset` 탈락 (`:273-278`) |
| m2-01 F1 (P2) | `CharacterUseJumpPower` 미고정 | **고쳐짐** (m2-01 단계) | `default.project.json` |
| m2-04 B4 | 서든데스 시작 때 3조각 | 기획 확정, 스펙 수정 | m2-04 리포트 재검증 |
| M1 B10 | 회전 벨트 장애물이 태그가 아니라 폴더로 동작 | 남음 (M2 범위 밖으로 확정) | m2-02 스펙 결정 기록 "회전 벨트를 이 규칙으로 바꾸는 건 M2 범위 밖". 새 맵 3개는 태그 규칙을 따른다 |
| M1 B11 | 위치·결승선 판정이 클라이언트 물리를 믿음 | 남음 (M4) | — |
| m2-04 B3 | 꼬치 무대 조각 경계 톱니 틈 | 남음, Studio 확인 | 체크리스트 2 |
| m2-02 W2 | 입력 없이 와사비로 산에 못 오를 수 있음 | 남음, Studio 확인 | 체크리스트 4 |
| m2-06 S1 | ←/→ 키가 카메라도 돌림 | 남음 | Q/E로 대체 가능 |
| m2-06 S2 | Studio에서 관전 순서가 역순 | 남음 (Studio 전용, 영향 없음) | — |
| 문서 | DEV-SETUP에 M2 확인 목록 없음, 3-5절이 M1 기준 | 남음 → **docs-writer** | 스펙 범위대로 docs-writer가 이 리포트의 체크리스트로 "M2 확인 목록"을 만든다 |

## 버그
P0/P1/P2 없음.

### [P3] I1 결승의 같은 틱 묶음에서 리셋·퇴장한 사람이 우승할 수 있다
- 재현 (순수 로직, `RoundLogic` 그대로 실행):
  - 결승 2명. 같은 틱에 A는 무대에서 떨어지고(`Fall`, 점수 270), B는 리셋(`Reset`, 무대 위 높이 303) → `A=Eliminated, B=Won`
  - 결승 2명이 같은 틱에 둘 다 퇴장(`Reset`, 점수 −∞) → 한 명이 `Won` (나간 사람에게 Won, Victory에도 그 사람)
- 기대: 결정 기록의 취지("리셋으로 구제받는 꼼수를 막는다", "생존자가 0명이면 Victory 없이")대로라면 결승에서도 리셋·퇴장한 사람은 우승하지 않는다. 묶음에 `Fall`이 있으면 `Fall` 중에서 높이로 우승자를 고르고, 전원 `Reset`이면 우승자 없이 끝나야 한다.
- 실제: `RoundLogic.eliminate`의 Final 분기는 `left == 0`이면 사유와 상관없이 묶음에서 점수가 가장 큰 사람을 우승자로 고른다. 리셋은 `Died`가 날 때의 높이(무대 위)를 점수로 쓰므로, 떨어지는 상대보다 높아서 이긴다.
- 영향: 같은 프레임(`task.defer` 한 번)에 두 일이 겹쳐야 해서 드물다. 의도적으로 노리기도 어렵다. 불변식(Won ≤ 1, Victory = Won, 탈락자 우승 없음)은 깨지지 않는다 — 리셋한 사람이 Eliminated가 아니라 Won을 받기 때문이다.
- 위치: `src/shared/RoundLogic.luau:287-304`
- 다음 할 일: 결승에서 리셋한 사람의 취급은 결정 기록에 명시돼 있지 않다 → **planner가 규칙을 확정**하고 developer가 Final 분기에 사유를 반영한다 (M3 초반 또는 다음 정리 작업).

### [P3] I2 (절차) 검증 4종에 Luau 타입 검사가 없다
- 이번 통합처럼 서비스 함수 시그니처가 바뀌면 잘못된 호출이 런타임에야 드러난다. 이번에는 손으로 대조해서 문제가 없었다. `luau-lsp analyze`(rokit) 같은 타입 검사를 검증 명령에 넣을지 developer/사용자가 판단해 달라.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — M2에서 새 리모트·인자 없음 (Remotes 변경 없음). 관전·"로비로"는 클라이언트 카메라만 바꾼다
- [x] 통과·탈락·순위·우승 판정이 서버에만 있다 — 맵 판정 → `RoundService` → `RoundLogic`. 클라이언트는 `MatchPhase`/`RoundProgress`/`PlayerResult`를 표시만 한다
- [x] 맵 상태가 모듈이 아니라 `ctx`/지역 상태에 있다 — 네 맵 모두 `start` 지역 변수. 라운드 상태는 `prepareRound` 호출마다, 매치 상태는 방마다 `MatchContext`
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 라운드 `cleanup`에 모델, 맵 연결·스레드, 리셋 감시 연결, `placeAt` 스레드. 에러 경로(`prepareRound` 실패, `run` 실패, 매치 crash)에서도 `close()`/`cancel()`/`sendHome`

## 한 번에 따라 하는 Studio 체크리스트
준비: `rojo serve` → Studio 연결. **매 단계마다 서버·클라이언트 Output에 빨간 에러가 없는지 본다 (AC10).** 여러 명은 Test 탭 → 플레이어 수 → Start (Clients and Servers). 스톱워치를 하나 준비한다 (AC9).

**1. 혼자 기본 확인 (1분)**
- [ ] F5 → 방 만들기 → 시작 → 라운드 없이 "🏆 우승!"(내 이름), 6초 뒤 대기실

**2. 5명 3라운드 — AC3·AC3-2·AC5·AC6·AC9 (5명, 약 5분 × 2~3판)**
- [ ] 공개 방, 5명 참가, 방장 시작. 스톱워치 시작
- [ ] R1 소개 "라운드 1 / 3" + Race 맵(회전 벨트 또는 간장 늪). 소개 동안 이미 맵에 서 있고 움직일 수 없다. 배너가 사라지면 모두 동시에 출발
- [ ] R1 왼쪽 위 "통과 0/3". 결승선을 넘은 사람은 1초 안에 로비 스폰(대기석)으로 옮겨지고 관전 화면이 뜬다
- [ ] 3명이 통과하는 순간 나머지 2명 탈락 → 탈락자는 3초 뒤 자동 관전 + [로비로]. 한 명은 [로비로]를 눌러 로비를 돌아다닌다
- [ ] R2: Race면 "통과 0/2", 뜨거운 철판이면 "남은 인원 n"이 떨어질 때마다 줄어든다. 철판에서 60초를 버티면 버틴 사람 전원 통과 (AC3-2)
- [ ] R3 "회전 꼬치 쇼다운": 시작 직후 꼬치가 약 2초 뒤에 다가오고(m2-04 B1), 결승선 없이 마지막 1명이 남는 순간 "🏆 우승!". 무대 조각 경계에 틈·깜빡임이 보이면 기록 (m2-04 B3)
- [ ] 순위표 1~5등, 각자 받은 "n등" 안내와 같다. 모든 화면이 우승자를 비춘다
- [ ] 대기실로 전원 돌아온다 ([로비로]를 누른 사람 포함). 스톱워치 정지 → 한 판 길이 기록 (AC9 기준 약 3~5분)
- [ ] 같은 방으로 2~3번 반복해서 R2에 Race와 Survival이 둘 다 나오는지 본다

**3. 4명 — AC3-1·AC9 (4명, 약 3분)**
- [ ] R1(목표 2) 뒤 R2 소개 없이 바로 "라운드 3 / 3 · 회전 꼬치 쇼다운". 먼저 떨어진 사람 2등, 남은 1명 우승. 한 판 길이 기록

**4. 새 동작 (4명, 강제 플랜 없이)**
- [ ] **F1 구제**: R1 Race에서 아무도 결승선을 넘지 않고 한 명씩 코스 밖으로 떨어진다 → 처음 둘은 탈락, 마지막 둘은 "✅ 통과"를 받고 결승으로 간다
- [ ] **혼자 남음 부전승**: 새 판 R1에서 3명이 차례로 Esc → Reset → 3번째 리셋 순간 결과 화면 없이 남은 1명에게 "🏆 우승했어요!"와 우승 배너가 뜬다. 순위표에서 리셋한 3명은 2~4등
- [ ] **결과 화면 중 리셋**: 라운드 결과 화면 동안 리셋한 사람이 다음 라운드 시작 때 탈락하지 않고 정상 배치된다 (N1 계열)
- [ ] **결승 소개 중 이탈**: 결승 소개 중 상대가 Stop으로 나가면 남은 사람이 로비 스폰에서 우승 화면을 본다. 허공에서 떨어지지 않는다 (m2-05 F2)
- [ ] 간장 늪이 나왔다면: 와사비 패드 맨 앞에서 키를 떼고 튀어도 산 위에 오르는지 (m2-02 W2)

**5. 4라운드 — AC4 (4명)**
- [ ] `Config.luau`에서 **로컬로만** `forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" } :: { string }?` → "라운드 1 / 4"~"4 / 4"가 끝까지 돈다 → 끝나면 `nil`로 되돌린다 (안 되돌리면 `lune run tests`가 실패한다)

**6. 연달아 3판 — AC7**
- [ ] 2~3번에서 같은 방으로 3판을 돌린 뒤 Explorer의 Workspace에 `Round*` Model, 날치알 공(`Tobiko`), 꼬치, 셰프 손, 철판 타일이 남아 있지 않다
- [ ] 전원 정상 속도로 걷고 점프할 수 있다

**7. 두 방 동시 — AC8 (4명)**
- [ ] 2명씩 두 방을 만들어 거의 동시에 시작 (Studio라 1명부터 시작 가능). 두 아레나가 x 2000 간격으로 따로 지어지고, HUD 숫자·관전 대상·순위표가 각자 방 사람만이다

## 추가한 테스트
`tests/m2-07-qa.spec.luau` (3개, 각 3000판, 모두 통과)
- 무작위 한 판(리셋 포함): Won ≤ 1, Victory 우승자 = Won 받은 사람, 탈락자는 우승 못 함, 우승자가 없으면 Won도 없음
- 무작위 한 판: 순위표 = 시작 인원, 등수 중복 없음·범위 안, 우승자가 있으면 1등 = 우승자
- 무작위 한 판(낙하만): 결승은 항상 2명 이상으로 시작, 항상 우승자, 부전승 없음

I1 재현은 실패하는 테스트로 넣지 않았다 (규칙이 확정되지 않음). 위 버그 절의 두 입력을 `RoundLogic.eliminate`에 그대로 넣으면 재현된다. 규칙이 확정되면 그 결과를 `tests/round-logic.spec.luau`에 테스트로 고정하길 권한다.

## 인계 메모 (2026-10-08, qa)
- 브랜치: `main`. 리포트·테스트·스펙 상태(`qa-passed`)를 커밋했다. **push는 메인 세션이 한다.**
- 끝난 것: 검증 4종(209 passed), F1·혼자 남음·Won/Victory 불변식(코드 + 무작위 시뮬레이션 9000판), 맵 4개 × RoundLogic 계약, 이전 P3 처리 현황, 통합 Studio 체크리스트.
- 남은 것: Studio 체크리스트 1~7 (사용자 확인 필요). I1은 planner 결정 → developer. DEV-SETUP "M2 확인 목록"은 docs-writer.
- 다음 첫 단계: 사용자 Studio 결과를 받아 이 리포트에 반영. P0/P1이 나오면 스펙을 `in-dev`로.
- 막힌 점: 없음.
