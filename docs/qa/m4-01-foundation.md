# QA — m4-01 M4 기반 작업 (공용 파일 · 이벤트 훅 · 프로필 껍데기 · 맵 키트 · 새 맵 2개 stub · P3 2건)

- 스펙: `docs/specs/m4-01-foundation.md`
- 검증 커밋: `f33086b` (main, 구현 c880407 · 2f6cb83 · 0daea60)
- 결과: **통과 (P0/P1 없음, P2 1건, P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC9~AC14)은 사용자 확인 필요.
- P2 B1(라멘 stub 스폰이 바닥 밖)은 m4-04가 파일을 덮어쓰기 전까지 맵 풀에 들어 있으니, **m4-04 착수 전에 한 줄 고치거나 m4-04 수용 기준에 넣기**를 권한다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 538 passed, 0 failed (기존 519 + QA 추가 19) |

참고: 검증 4종에 Luau 타입 검사는 여전히 없다 (m2-07 I2, m4-12 예정).

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m4-foundation` `AC1: PlaceRole.resolve` |
| AC2 | 통과 | `m4-foundation` AC2. QA: DataService가 접속 때 `ProfileSchema.new()`로 로드(`m4-01-qa` `DataService: 접속하면 바로 로드…`) |
| AC3 | 통과 | `m4-foundation` AC3 2개. QA: `update` 뒤 보낸 view의 `title`이 `titleFor(wins)` |
| AC4 | 통과 | `m4-foundation` AC4 3개. 회전 순서(Rz→Ry→Rx = `CFrame.Angles`)와 부호를 코드로 확인 (`MapKitLogic.luau` `rotate`) |
| AC5 | 통과 | `m4-foundation` AC5 2개 + QA 무작위 2000판(아래), 기존 `round-logic` 30개 통과 |
| AC6 | 통과 | `m4-foundation` AC6 3개 |
| AC7 | 통과 | `m4-foundation` `Config` 테스트, `Config.luau` 확인 |
| AC8 | 통과 | 위 자동 검증 |
| AC9 | 사용자 확인 필요 | 체크리스트 1 |
| AC10 | 사용자 확인 필요 | 체크리스트 2 |
| AC11 | 사용자 확인 필요 | 체크리스트 3 (폴더 존재만. 장식 붙는 건 m4-02 QA) |
| AC12 | 사용자 확인 필요 | 체크리스트 4 |
| AC13 | 사용자 확인 필요 | 체크리스트 5 |
| AC14 | 사용자 확인 필요 | 체크리스트 6 |

요약: 순수 로직 AC1~AC8 통과(8/8), Studio AC9~AC14 사용자 확인 필요(6). 실패한 기준 없음.

## 코드 리뷰

### 다른 m4 스펙이 기대하는 인터페이스 대조
| 인터페이스 (m4-01 구현) | 쓰는 스펙 · 기대 | 결과 |
|---|---|---|
| `MatchEvents.onMatchStart/onRoundStart/onResult/onMatchEnd/onWinnerShowcase` → 해제 함수 | m4-06(`onWinnerShowcase` info `{userId,name,appearanceId}`), m4-08(`onRoundStart` 결승 = `roundIndex == roundCount`, `onResult` Passed/Won, `onMatchEnd` `participants`, Victory 직후) | 일치. `fireRoundStart`는 `prepared.run` 직전(`MatchService.luau:253`), 결승으로 건너뛰어도 `roundIndex == roundCount`(`Rules.roundToPlay`). `fireMatchEnd`는 Victory 방송 직후(`:297`), 우승자 없으면 sendHome 직전(`:301`), 크래시 경로(`:324`) — `endFired`로 한 번만. 부전승 `Won`(`decideWinner` → `EliminationService.won`)도 `fireResult`를 거친다 |
| `MatchEvents.fireWinnerShowcase` | m4-11(로비 서버가 쏨) | 일치. 한 플레이스 모드에서만 MatchService가 쏨(`PlaceService.role() ~= "Single"`이면 안 쏨) |
| 핸들러 격리 | 스펙 9 "에러 나도 매치가 멈추지 않는다" | 일치. QA가 실제 모듈을 가짜 환경으로 돌려 확인: 에러 → 경고만·다른 핸들러 계속, 기다리는 핸들러가 fire를 막지 않음, 인자 복사, 해제 |
| `DataService.get / waitForProfile / update / onLoaded / canPersist` | m4-06(`get`), m4-07(같은 API + `saveNow` 추가), m4-08(`update`, `waitForProfile` 10초), m4-13·14(`get`, `canPersist`) | 일치. `saveNow`는 m4-07이 붙이는 것(스펙대로 없음). QA 실행 테스트: 로드·프레임 끝 한 번 전송·퇴장 정리·onLoaded 즉시 호출/에러 격리/해제 |
| `ProfileSchema.new / titleFor / toView / sanitizeSettings / VERSION` | m4-06·08(`titleFor`), m4-07(`new`, 마이그레이션 VERSION) | 일치 |
| `ProfileStore.get / changed(fn) → {Disconnect}` / `start` 맨 앞 | m4-07(첫 프로필로 음소거 복원), m4-08(`changed`로 배지) | 일치. 단 `changed`는 지금 값을 바로 다시 불러 주지 않는다 → 구독자는 `get()`을 먼저 읽어야 한다 (m4-07·m4-08 개발 참고, 버그 아님) |
| `RoundService.setPassValidator(fn)` 하나만, false면 무시, 구제는 안 물음, 에러면 허용 | m4-10 | 일치 (`RoundService.luau:76-87, 438, 575-578`). 검사는 `isRacing` 확인 뒤·`flush` 앞 |
| `RoundService.activeRoomOf` | m4-10 | 기존(m3-07) 그대로 |
| `MoveExempt.mark(character, seconds?)` (shared) + `Attributes.MoveExemptUntil` | m4-02~05(장애물), m4-10 | 일치. `toLobby`(`CharacterUtil.luau:37`)와 스폰 배치(`RoundService.luau:385`)가 `PivotTo` 앞에서 부름 |
| `Config.MovementGuard` 7개 값 | m4-10 | 일치 |
| `MapKit.decorFolder / buildDecor / introCamera / attachStudioArt(model, ID, origin) / applyDecorRules`, `MapKitLogic.DecorSpec / validate / count / bounds / PALETTE / MATERIALS / *_BUDGET` | m4-02~06 | 일치. 장식 규칙(Anchored, CanCollide/CanQuery/CanTouch false, Massless) 확인 |
| `PlaceService.role()` / `PlaceRole.resolve` | m4-06(Match면 로비 안 지음), m4-11 | 일치 (지금 항상 `"Single"`) |
| `UiScaleController.attach(screenGui)` 껍데기, `Config.Ui` | m4-08·09·13 | 일치 |
| `Config.Rewards / Titles / Data / Teleport / Places`, `Types.ProfileView / RewardGrant / RewardReason / Settings`, `Attributes.Title` | m4-07·08·11 | 일치 |
| 껍데기 6개 + 등록 순서 (서버 Data → Place → 기존 → 새, 클라 ProfileStore → Sfx → 기존 → 새) | m4-06·08·09·10 | 일치 |

### 새 리모트 (방향 · 서버 검증)
| 리모트 | 방향 | 확인 |
|---|---|---|
| `ProfileUpdated` | S→C, 본인에게만 | `FireClient(player, …)`만 씀. 서버가 `OnServerEvent`를 듣지 않음 (QA 테스트) |
| `RewardGranted` | S→C | 정의만 (m4-08이 보냄). 서버가 듣지 않음 |
| `SaveSettings` | C→S | `DataService.luau:121-135`: 사람마다 `os.clock` 간격 0.5초 → `sanitizeSettings`(표, number, NaN·소수 거부, 1~3) → `update`로 `muteLevel`만 복사. QA 실행 테스트: 0·4·2.5·NaN·±inf·"2"·{2}·{}·숫자·문자열·bool·nil 거부, 0.5초 안 두 번째 무시·0.5초 뒤 허용, 사람마다 따로, 로드 전/모르는 사람도 에러 없음. (잘못된 요청도 간격 칸을 쓰는데 — `:128` — 무해) |

### RoundLogic 결승 규칙 변경 (m2-07 I1) · 우승자 불변식
- 결승 묶음은 `finalBatchOrder`: 리셋·퇴장 무리(점수 순) → 낙하 무리(점수 순). 남은 0명이면 맨 끝이 낙하일 때만 우승, 전부 리셋이면 우승자 없이 `ended`.
- QA 무작위 테스트 2000판(2~8명, 묶음마다 낙하/리셋 무작위, 끝까지 또는 시간 종료): `Won` ≤ 1, **리셋한 사람은 우승하지 않음**, `Won`의 place 1, `Standings.winnerUserId == Won 받은 사람`, `decideWinner`가 결승 뒤 추가 `Won`을 요구하지 않음, 등수 1..N 빠짐·중복 없음, 끝난 뒤 eliminate/timeout은 빈 결과. 남은 전원이 한 묶음이면 "낙하가 있으면 우승자, 전부 리셋이면 없음".
- 결승이 아닌 라운드는 바뀌지 않음 (`rank`가 Final 분기 뒤로 옮겨졌을 뿐). QA 테스트: Race 2명 보장 구제는 낙하만, 리셋은 점수가 높아도 탈락.
- `MatchService`: 전부 리셋으로 끝나면 생존자 0 → `decideWinner` nil → Victory 없이 `fireMatchEnd(nil)` → 로비. 맞다.

### 낙하 탈락 위치 (m3-03 B2)
- 0.1초마다 배치된 레이서 중 `FloorMaterial ~= Air`인 사람의 루트 위치 기록(`RoundService.luau:397-413`), 루프는 `closed`에서 끝나고 `cleanup`에도 등록. 배치 때 기록 지움. `cause == "Fall"`이고 맵이 위치를 안 줬을 때만 사용, 없으면 예전 값. Reset·Left·Timeout 경로는 그대로.

### 매치 크래시 시 onMatchEnd
- `pcall(runMatch)` 실패 → `ctx`가 있으면 `pcall(fireMatchEnd, ctx, nil, …)`. `endFired`로 한 번만 → 정상 경로에서 이미 보냈으면 다시 안 보냄. `ctx`가 생기기 전 크래시면 matchStart도 안 나갔으니 matchEnd도 없음 — 짝이 맞다. 단 B2 참고.

## 버그
### [P2] B1 라멘 국물 급류 stub: 스폰 19~24번이 바닥 밖(뒤쪽 허공), 13~18번은 바닥 끝 걸침
- 재현: 19명 이상 방에서 `ramen-rapids`가 뽑힘(Race라 1라운드에도 나옴). 또는 Studio에서 24명.
- 계산 (`origin` 기준 로컬 z, 코스는 -Z): 바닥 `Floor`는 길이 `LENGTH + 20 = 180`, 중심 z = `-(180)/2 + 10 = -80` → **z ∈ [-170, +10]**. 스폰은 `z = row × 5`, row 0~3 → z = 0, 5, 10, **15**. `Spawn19`~`Spawn24`(row 3)는 바닥 끝보다 5 studs 뒤, `Spawn13`~`Spawn18`(row 2)은 정확히 끝선.
- 기대: 스폰 24개 전부 바닥 위 (stub도 다른 맵처럼 24명 수용).
- 실제: 배치 잠금은 `WalkSpeed = 0`뿐(앵커 아님, `RoundService.luau:123-128`)이라 소개 중에 바로 떨어진다 → 아레나 높이 300에서 허공으로 떨어져 사망 = `Reset` 탈락(구제 없음). 출발도 못 하고 6명(가장자리 6명 포함하면 최대 12명) 탈락.
- 고치는 법(제안): 바닥을 뒤로 더 늘리거나(예: 중심 `-(LENGTH + 30)/2 + 20`, 길이 `LENGTH + 30` → z ∈ [-170, +20]) 스폰 행을 `row * SPAWN_SPACING + 2` 대신 앞쪽(-Z)으로. m4-04가 이 파일을 덮어쓰므로 m4-04 수용 기준에 "스폰 24개가 모두 판정 바닥 위"를 넣어도 된다.
- 위치: `src/shared/maps/RamenRapids.luau:31-36`(바닥), `:41-55`(스폰). `ChefBoard`는 스폰 x ±15, z -49~-31로 도마(±30, -70~-10) 안 — 문제 없음.

### [P3] B2 크래시 경로의 onMatchEnd가 이미 Won을 받은 우승자를 버림
- 재현(드묾): 우승 `Won`을 보낸 뒤 Victory 방송·`fireMatchEnd` 전 사이에 에러.
- 기대: `winnerUserId = ctx.standings.winnerUserId`(Won 받은 사람).
- 실제: 항상 `nil`. m4-08의 우승 코인은 `onResult(Won)`이라 영향 없지만, m4-11 `MatchResult`(로비 단상)·통계가 우승자 없음으로 기록될 수 있다.
- 위치: `src/server/MatchService.luau:324` → `RoundLogic.winnerOf(ctx.standings)` 사용 권장.

### [P3] B3 결승이 전부 리셋으로 끝나면 순위표 1등 칸에 우승자 아닌 사람
- 재현: 결승 2명이 같은 판정 틱에 둘 다 리셋. QA 테스트 `결승 전원 리셋으로 끝남…`.
- 실제: `winnerUserId = nil`인데 `standings`에는 place 1(마지막에 탈락 처리된 사람)이 있다. Victory를 안 보내므로 화면엔 안 나오지만 `onMatchEnd.info.standings`를 받는 m4-08·m4-11은 **`place == 1`이 아니라 `winnerUserId`로 우승을 판단해야** 한다. 버그라기보다 계약 주의 — 개발 메모나 `MatchEvents.luau` 주석에 한 줄 적어 두길 권함.
- 위치: `src/shared/RoundLogic.luau` `standingsList`, `src/server/MatchEvents.luau` 머리 주석.

### [P3] B4 (참고) `ProfileStore.changed`는 지금 값을 바로 불러 주지 않음
- `DataService.onLoaded`는 이미 로드된 사람에게 바로 부르는데 `ProfileStore.changed`는 다음 갱신부터다. 구독자(m4-07 음소거 복원, m4-08 배지)는 `get()`을 먼저 읽고 구독해야 한다. 스펙 문구와는 어긋나지 않음.
- 위치: `src/client/ProfileStore.luau:26-40`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — `SaveSettings` 타입·범위(정수 1~3)·간격 0.5초·사람마다, 잘못된 값 조용히 무시 (QA 실행 테스트). S→C 이벤트 둘은 서버가 듣지 않음.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 통과 검사(`setPassValidator`)·결승 묶음 규칙·코인/프로필 모두 서버. 클라이언트 `ProfileStore`는 보관만.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — stub 2개는 `start` 지역 연결만, `lastGroundOf`는 `prepareRound` 지역. `passValidator`는 서버 전역 하나(의도).
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 땅 기록 스레드와 stub Heartbeat 연결은 `ctx.cleanup`/`cleanup`. DataService는 PlayerRemoving에서 세 표를 지움. MatchEvents 리스너는 해제 함수 제공.

## 사용자 Studio 확인 체크리스트
준비: `rojo serve` → Studio 연결. 매 단계 서버·클라이언트 Output에 빨간 에러가 없는지 본다.
1. **AC9 새 stub 2개로 한 판** — `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 `{ "ramen-rapids", "chef-board", "soy-swamp", "skewer-showdown" }`로 바꾸고 F5 → 방 만들기 → 시작.
   - [ ] 1라운드: 회색 긴 길 끝에 노란 결승선. 결승선을 넘으면 통과(대기석으로 이동).
   - [ ] 2라운드: 회색 정사각 도마. 가장자리로 떨어지면 탈락 연출, 버티면 시간 종료 때 통과.
   - [ ] 4라운드까지 돌고 우승 화면 → 로비. 빨간 에러 없음.
   - [ ] 끝나면 `forceMapPlan = nil`로 되돌린다.
2. **AC10 프로필** — F5 후 클라이언트 쪽 Command Bar에서
   `local v = require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get() print(v and v.coins, v and v.persistent)`
   - [ ] `0 false`가 찍힌다. `nil nil`이면(Command Bar가 모듈 캐시를 따로 쓰는 경우) 그대로 알려 준다 — 개발이 다른 확인 방법을 정한다.
3. **AC11 MapArt 폴더** — 플레이 중 상단 "Current: Server"로 바꿔 Explorer를 본다.
   - [ ] `ServerStorage` 아래 `MapArt` 폴더가 있다(비어 있음). 장식이 맵에 붙는 확인은 m4-02 QA 때.
4. **AC12 낙하 연출 위치** — `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, Test 탭 → Clients and Servers 2명.
   - [ ] 결승(꼬치 쇼다운)에서 Player1이 무대 밖으로 떨어지면 Player2 화면의 탈락 연출이 **무대 가장자리 높이**에서 재생된다(예전엔 무대 20 studs 아래).
   - [ ] 리셋(Esc → R)으로 탈락하면 예전처럼 리셋한 자리에서 연출.
5. **AC13 가로 고정** — Test 탭 → Device 에뮬레이터에서 휴대폰(예: iPhone)을 고르고 F5.
   - [ ] 기기를 세로로 돌려도 화면이 가로로 유지된다.
6. **AC14 회귀** — `docs/DEV-SETUP.md` 3-7·3-8 핵심.
   - [ ] (forceMapPlan nil로) 혼자 한 판 완주, 탈락·우승 연출, 다이브(E)·잡기가 예전처럼 된다.
   - [ ] (선택) 2명으로 결승에서 둘이 거의 동시에 떨어지게 해 본다 — 우승 화면이 나오면 우승자는 PlayerResult `Won`을 받은 사람이어야 한다.

## 추가한 테스트
`tests/m4-01-qa.spec.luau` (19개)
- MatchEvents(실제 모듈 + 가짜 `game`·`task`): 핸들러 에러는 경고만·다른 핸들러 계속, 기다리는 핸들러가 fire를 막지 않음, 훅 5개 해제 함수(두 번 불러도 됨), `roundStart` 인자 순서와 userIds·result 복사, fire 중 새 구독은 이번 fire에 안 불림.
- DataService(실제 모듈 + 가짜 Players·Remotes·시계·task): 접속 즉시 로드·프레임 끝 ProfileUpdated 1번(persistent false), 한 프레임 여러 update → 1번·로드 전 false·mutate 안 부름, 퇴장 뒤 전송 없음·`waitForProfile` nil, onLoaded 즉시·에러 격리·해제, SaveSettings 값 검증 12가지 + nil, 간격 0.5초·사람마다, 로드 전 요청 무해, S→C 이벤트를 서버가 안 들음.
- ProfileStore(실제 모듈): get/changed/Disconnect, 잘못된 값 무시, start 한 번만 연결.
- RoundLogic: 결승 무작위 2000판 불변식, 리셋 혼자 → 남은 1명 우승(기존), 같은 점수면 낙하가 우승, 전원 리셋 시 순위표 모양(B3), 결승 아닌 라운드 구제 규칙 그대로.

## 인계 메모
- 지금 브랜치: `m4-01-qa` (origin/main `f33086b`에서 분기, QA 커밋 + push)
- 끝난 것: 자동 검증 4종 통과(538/0), AC1~AC8 통과, 인터페이스·리모트·결승 규칙·크래시 경로 리뷰, QA 테스트 19개, 리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC9~AC14(위 체크리스트). 메인 세션이 `m4-01-qa`를 main에 병합. B1(P2)은 m4-04 전에 developer가 한 줄 고치거나 m4-04 수용 기준에 추가. B2·B3 주석/한 줄 수정은 다음 MatchService를 만지는 스펙(m4-11)에서 같이.
- 다음에 할 첫 단계: `m4-01-qa` 병합 → m4-02~m4-10 worktree 생성. docs-writer가 DEV-SETUP에 m4-01 확인 항목(체크리스트 1~6) 반영.
- 막힌 점: 없음.
