# QA — m4-12 출시 점검 (타입 검사 · 남은 P3 · 연속 매치 안정성 · 출시 체크리스트)

- 스펙: `docs/specs/m4-12-release-hardening.md`
- 검증 커밋: `98eadcb`(타입) · `04e0fe6`(P3) · `ce9f470`(디버그·테스트) · `1026484`(forceMapPlans) · `473b21e`(문서). 브랜치 `m4-12-qa` (origin/main `473b21e`에서 분기)
- 결과: **통과 (qa-passed)** — P0/P1/P2 없음. P3 5건(전부 문서·체감·디버그 위생). Studio 항목(AC4~AC7)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors / 0 warnings / 0 parse errors |
| `lune run tests` | **918 passed, 0 failed** (개발 911 + QA 7) |
| `rojo sourcemap default.project.json -o sourcemap.json` | OK |
| `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src` | 끝 코드 0, 출력은 INFO/WARN(`didChangeWatchedFiles`) 줄뿐 |

### 타입 검사가 실제로 잡는지 (일부러 넣고 되돌림)
| 넣은 오류 | 결과 |
|---|---|
| `src/shared/Rules.luau`에 `local _qaBad: number = "x"` | `Rules.luau(4,24): TypeError: Expected this to be 'number', but got 'string'`, 끝 코드 1 |
| `src/server/MatchService.luau`에 `workspace:FooBar()` | `Key 'FooBar' not found in external type 'Workspace'` (Roblox 정의 파일이 실제로 쓰임) |
| `MatchService.luau:294` `Rules.qualifyCount("x", …)` (모듈 사이) | `(294,42): TypeError: Expected this to be 'number', but got 'string'` (sourcemap으로 require 해석됨) |
- 모두 되돌린 뒤 다시 끝 코드 0. `src/`의 `.luau` 파일은 전부 `--!strict`(빠진 파일 없음).
- 주의: 파일 끝 `return` 뒤에 줄을 붙이면 같은 SyntaxError가 수십 줄 반복돼 나온다(도구 출력 특성, 문제 아님).

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | 위 5개(+sourcemap) 명령 실행, 타입 에러 0, 일부러 넣은 에러는 잡힘 |
| AC2 | 통과 | `m4-12-hardening.spec` AC2 4개 + QA `무작위 입력 200개 시퀀스` (서버 빈도 제한 흉내와 맞물려 버리는 누름 0) |
| AC3 | 통과 | `m4-12-hardening.spec` AC3: 약한 키 메타테이블 + 정리 뒤 1개 이하. 값(`cues` 표)이 키(파트)를 참조하지 않아 약한 키가 실제로 풀릴 수 있는 구조. 실제 GC 회수는 Lune에서 `collectgarbage("collect")`를 못 써 직접 확인 못 함 |
| AC4 | 사용자 확인 필요 | 체크리스트 1 |
| AC5 | 사용자 확인 필요 | 체크리스트 2 (로직은 AC2로 확인) |
| AC6 | 사용자 확인 필요 | 체크리스트 3. 결정 기록에 "확인 대기"로 있음 — 결과가 들어와야 충족 |
| AC7 | 사용자 확인 필요 | 체크리스트 4 |

## 중점 검토

### 1. 타입 표기 수정(98eadcb)이 동작을 바꾸지 않았나 — 바꾸지 않음
- **차등 실행(전/후 비교)**: `5c1308c`(m4-12 직전)의 `src/shared`와 지금 `src/shared`를 Lune에서 같이 불러, 같은 시드로 결과를 JSON으로 비교했다(스크래치 스크립트, 커밋 안 함).
  - 매치 13,500판(시드 1500 × 인원 2·3·4·5·8·9·12·16·24, 5판 중 1판은 전 라운드를 Final 모드로): `buildRoundPlan` → 라운드마다 `newRound/activate/pass/eliminate(1~3명 묶음, 15% 리셋)/timeout` → `applyOutcomes` → `decideWinner/placeWinner` → `standingsList`. 점수는 0~19 정수라 동점이 많다.
  - `finalBatchOrder`(rng 있음/없음), `settleLeftover`, `roundKinds` 각 3000회, `RewardLogic.simulate` 500회, `matchTotal`, `ChefBoardArt.decor/allCellDecor`, `RamenRapidsLogic.platforms`.
  - 결과: **불일치 0**. 감도 확인으로 옛 사본의 `rank` 비교를 `a.score < b.score` → `>`로 바꾸면 불일치 16,606건이 나온다(비교가 실제로 작동함).
- **표본 코드 검토**: 바뀐 줄은 전부 지역 변수 타입 표기, `table.sort` 비교 함수 인자 표기, `table.create(n) :: { T }`, 메서드 결과 괄호 감싸기(`(base:ToObjectSpace(cf))` — 원래 값 1개라 같음), `table.unpack(RGB)` → `RGB[1], RGB[2], RGB[3]`(3개짜리 상수라 같음), `Config.TimeLimit :: {[string]: number}`(Race/Survival/Final 키 모두 있음).
- **ChefBoard `task.spawn(movePivot, …, false)`**: `easeIn`이 `nil`이던 자리를 `false`로 — `if easeIn then … else …`라 같은 분기. 진짜 결함이라기보다 인자 수 표기. (QA 테스트로 고정)
- **캐스트로 감춘 버그 없음**: 새 `:: any`는 2곳뿐(`ProfileLogic.deepCopy` 비표 값 반환, `MapSfxLogic` 약한 키 표). `RoundService` `RoomService.getPlayers(roomId :: string)`는 바로 위에서 `nil`을 걸러 낸 뒤라 안전.
- 기존 테스트 파일은 하나도 바뀌지 않았다(`git diff 5c1308c HEAD -- tests`는 새 파일만).

### 2. 각 P3 수정 — 원래 버그를 고쳤고 판정 수치는 그대로
| P3 | 원래 문제 | 확인 |
|---|---|---|
| m3-09 B3 | 소리 리미터가 지운 파트를 붙잡음 | 약한 키 표. 값이 키를 참조하지 않음 → 회수 가능 |
| m3-07 G1 | 0.1초 안 재누름이 서버에서 버려지고 클라는 누른 상태로 남음 | `GrabInputLogic`: 마지막 보낸 누름 + 0.13초 전이면 예약, 그때 누르고 있으면 한 번 보냄. 서버(`GrabService.luau:188-196`)는 `true`만 0.1초 제한, `false`는 항상 처리 → 클라도 `false`는 바로 보냄. 맞물림을 무작위 시퀀스로 확인(아래 QA 테스트) |
| m3-07 G4 | 입력원이 `holding` 하나 공유 | 마우스·게임패드·터치를 따로, 하나라도 누르면 잡기. `cancel`은 모두 뗌 |
| m4-02 Q1 | 간장 늪 소개 카메라가 종이 등 통과 | 등을 x 6으로. 개발 테스트가 경유점 사이 2000등분으로 회전 벨트·간장 늪 장식 전부 검사 |
| m4-02 Q2 | 노렌이 15 아래 | 문 기둥 19·보 18.6·노렌 16.6(바닥 15.2) |
| m4-03 B3 | 철판·꼬치 테두리가 윗면보다 0.3/0.2 높음 | 철판 Frame 윗면 = 층 윗면, 꼬치 RimLip 윗면 = 무대 윗면(0) |
| m4-05 C2·C3 | 칼이 줄 위·수평으로 올라감 / 내려칠 때 기울기 고정 | `movePivot`가 목표 함수를 받아 매 프레임 `currentTilt`를 다시 읽음. 내려치기·올라가기 시간 상수(`KNIFE_SLAM_TIME` 등)와 넉백 판정(`Logic.isOnLine`, 줄 좌표) 그대로 |
| m4-07 D5 | 로드 중 종료 시 잠금 못 풂 | `onClose`가 `loading`도 기다림. `load`는 `loading` 지우기 → `closing` 확인 → `save(session, true)` 사이에 yield 없음, `runSaves`가 `task.spawn`으로 바로 `saving`에 올림 → 루프가 틈에서 빠져나가지 않음. 대기는 `CLOSE_TIMEOUT = 25` 상한이라 Roblox 30초 안 |
- **충돌 파츠 여부**: 바뀐 노렌·문 기둥·보·종이 등·철판 Frame·꼬치 RimLip은 전부 `*Art.decor()/sliceDecor()` 목록 → `MapKit.buildDecor` → `applyDecorRules`(Anchored, CanCollide/CanQuery/CanTouch false). 통로·점프·판정에 영향 없음. 철판 Frame은 타일 영역 바깥(QA 테스트).
- 04e0fe6에서 바뀐 맵 파일은 `*Art.luau`·`ChefBoard.luau`(칼 연출)·`MapSfxLogic.luau`뿐이고 `*Logic.luau`(판정 수치) 변경 없음.

### 3. 잡기 입력 재전송 — 서버 제한과 맞고 스팸 없음
- 클라이언트 간격 0.13초(= `Config.Grab.InputMinInterval` 0.1 + `MARGIN` 0.03) ≥ 서버 0.1초. 같은 설정값을 씀.
- 스팸: `true`는 0.13초에 한 번 이하, `false`는 그 앞에 `true`를 보냈을 때만 → 초당 최대 약 7.7쌍. 빠른 연타 때 `task.delay`가 여러 개 생겨도 첫 `flush`가 `pendingAt`을 지워 나머지는 아무것도 안 보냄. 오래된 예약이 늦게 와도 새 `pendingAt`보다 이르면 `flush`가 무시.
- 남는 위험은 P3 N2(네트워크 흔들림 > 0.03초).

### 4. 새 DEBUG
- `forceMapPlans`(기본 `nil`): `forcedPlan`의 첫 줄이 `if not RunService:IsStudio() then return nil` → 실서버에서 무시. `forceMapPlan`이 우선.
- `logArenaStats`(기본 `false`): Studio 가드가 없다(스펙도 요구하지 않음) → P3 N3.
- 커밋 값 테스트가 두 값과 기존 디버그 값(`forceMapPlan`, `simulateMatchServer`, `persistDataInStudio`)을 고정한다.

### 5. 연속 매치·누수 테스트가 의미 있나 — 대체로 의미 있음, 한계 있음
- 10판 순수 시뮬레이션: 매치 진행 자체(순위표 1..N 한 번씩, 우승자 1등, 강제 플랜대로 진행)는 강한 검사다. 다만 "쌓이지 않음"은 `GrabLogic` 책·`MapSfxLogic` 리미터만 확인하고, 방은 판마다 새로 만들어서 "방 비었음"은 사실상 자명하다. `MatchService`·`RoundService`의 Instance·연결은 Roblox API라 여기서 못 보고 AC4(Studio `[ArenaStats]`)에 맡긴다 — 결정 기록에 그렇게 적혀 있어 타당.
- 누수 소스 점검: 변형 시험으로 `GrabService.luau`의 `lastPress[player] = nil`을 지우면 테스트가 실패한다(작동함). 한계: 정규식이 `local x: { [K]: V } = {}` 모양만 잡아 배열(`PlaceService.arrivals: { Player }`, `RoomDirectory.remoteCache`, `CameraDirector.entries`)과 타입 표기 없는 표는 안 본다. 수동으로 셋을 확인했고 모두 비우는 경로가 있다(`arrivals = {}` 교체 `PlaceService.luau:693-694` 등). `src/shared` 모듈 최상위 표는 상수뿐.

### 6. 출시 체크리스트 ↔ USER-TODO
- 모순은 없다(인원 Lobby 40/Match 24 = C2-3, API 접근 = C1, 상품 15개 = C3, 설문·기기·공개 = C4). 개인정보 삭제 절차의 스토어 이름 `PlayerData_v1`·키 `u_<UserId>`는 코드(`Config.Data.StoreName`, `DataService.luau:81-83`)와 같고, 다른 DataStore는 없다(MemoryStore만, 만료됨).
- 빠진 사용자 작업은 P3 N1(문서)로 적었다.

## 버그
P0/P1/P2 없음.

### [P3] N1 출시 체크리스트에 사용자 작업 몇 개가 빠짐 (문서)
- 재현: 스펙 "사용자 작업" 표와 `docs/USER-TODO.md`를 나란히 본다.
- 기대: 비공개 테스트 전에 사용자가 할 일이 체크리스트에 다 있다.
- 실제:
  1. **Match 플레이스 만들기·두 플레이스 퍼블리시·PlaceId 알려 주기(USER-TODO C2)** 가 표에 없다. #5는 인원만 말하고 "한 플레이스 모드로 내놓으면 40"이라 어느 모드로 내놓을지 결정 칸도 없다.
  2. 비공개 테스트(#7)의 USER-TODO D 줄과 `docs/playtest/m4.md`가 아직 없다(개발 메모 "새 줄 필요" — docs-writer 몫).
  3. 소리 에셋(A2, 배경음 4·효과음 8 무음)과 M3/M4 Studio 확인(B2·B3)이 "비공개 테스트 전" 선행 조건으로 안 걸려 있다. 무음으로 내놓을지 사용자 결정 필요.
  4. #7 "접근을 친구/지정 사용자로 제한" — Roblox 대시보드에서 실제로 어떤 설정(비공개 + 그룹/친구 공유 등)인지 단계가 없다. 사용자가 대시보드에서 확인할 것.
- 위치: `docs/specs/m4-12-release-hardening.md` "사용자 작업" 표, `docs/USER-TODO.md` C2·D·A2 → docs-writer가 DEV-SETUP 3-9로 옮길 때 반영.

### [P3] N2 네트워크 흔들림이 0.03초를 넘으면 재전송한 누름이 서버에서 여전히 버려질 수 있음
- 재현(이론): 첫 누름 패킷이 늦게, 0.13초 뒤 재전송 패킷이 빨리 도착해 서버 기준 간격이 0.1초 미만.
- 기대: 누르고 있는 동안 잡기.
- 실제: 서버가 `true`를 버리고 클라 `sent = true`라 뗄 때까지 다시 안 보냄 → G1과 같은 증상(훨씬 드묾). 놓기는 항상 처리돼 갇히지 않는다.
- 제안(필요하면): 서버가 버린 누름을 기억했다가 간격 뒤 적용하거나, 여유를 0.05로. 지금은 체감 보고가 있을 때만.
- 위치: `src/shared/GrabInputLogic.luau:17`, `src/server/GrabService.luau:188-196`

### [P3] N3 `logArenaStats`에 Studio 가드가 없음
- 실제: 실수로 `true`로 커밋하면 실서버에서도 매치마다 `workspace:GetDescendants()` 한 번 + 출력 한 줄. 커밋 값 테스트가 `false`를 고정하므로 실제 위험은 낮음. 다른 디버그 값과 맞추려면 `RunService:IsStudio()` 확인 추가.
- 위치: `src/server/MatchService.luau:128-151`

### [P3] N4 누수 소스 점검 테스트가 배열·타입 표기 없는 모듈 전역 표를 안 봄 (테스트 한계)
- 실제: 위 5번. 지금은 수동 확인으로 문제 없음. 새 전역 표가 생기면 놓칠 수 있다.
- 위치: `tests/m4-12-hardening.spec.luau` "서버 모듈 전역 표마다 지우는 곳이 있어요"

### [P3] N5 검증 5단계가 아직 WORKFLOW·CLAUDE.md·에이전트 정의에 없음 (docs-writer 대기)
- 실제: `docs/WORKFLOW.md:48`, `CLAUDE.md` "검증", `.claude/agents/*.md`는 4단계. 개발 메모가 docs-writer에게 넘겨 둠. "도구를 못 받으면 타입 검사 못 함을 보고" 규칙도 같이.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트 없음. `GrabInput`은 그대로 boolean 검사 + `true`만 0.1초 제한.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — `RoundLogic`·`Rules` 결과가 전/후 차등 비교에서 같음. 칼 연출 변경은 넉백 판정(줄 좌표)과 무관.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `ChefBoard`의 `currentTilt`·`knife`는 `start` 지역. `MapSfx` 리미터는 원래 모듈 전역(약한 키로 개선).
- [x] 연결·인스턴스·스레드가 정리된다 — 칼 조준 스레드는 `ctx.cleanup:add`. `logArenaStats`의 `task.delay` 2초는 읽기만. 클라 `GrabController` 예약 `task.delay`는 짧고 상태만 읽음.

## 사용자 Studio 확인 체크리스트
(개발 메모 "Studio 확인" 1~6과 같은 내용을 따라 하기 쉽게 정리)

1. **연속 5판 (AC4)**
   1. `src/shared/Config.luau`에서 `DEBUG.logArenaStats = true`, `DEBUG.forceMapPlans`에 스펙 개발 메모의 5개 플랜 목록을 넣는다(`forceMapPlan`은 `nil` 그대로).
   2. Studio **Play**(서버 하나). 방 만들기 → 시작 → 끝까지(혼자여도 진행) → 로비로 돌아오면 다시 방 만들기 → 시작. 5번.
   3. 매치가 끝날 때마다 Output에 `[ArenaStats] room … ended: workspace children N, arena models 0, open matches 0, round hooks 0, instances …, memory M MB`가 찍힌다.
   4. 기준: 5줄 모두 `arena models 0`, `round hooks 0`, `children` 같음. 5번째 `memory` − 1번째 `memory` ≤ 50. Output(서버·클라이언트)에 빨간 에러 없음.
   5. 첫 판 전 `Workspace` 자식 수(탐색기)와 5줄의 숫자를 스펙 개발 메모에 적어 준다.
   6. 끝나면 `logArenaStats = false`, `forceMapPlans = nil`로 되돌린다(커밋 금지).
2. **잡기 (AC5)**
   1. 상대가 필요하면 **Test → Clients and Servers 2명**, `forceMapPlan`에 Race 맵.
   2. 상대 바로 뒤에서 좌클릭을 아주 빨리 두 번 하고 두 번째를 누른 채 둔다 → 약 0.1초 뒤 잡힘(흰 팔·"잡혔다!").
   3. **Test → Device**(휴대폰)에서 화면의 잡기 버튼을 누른 채로 마우스 왼쪽을 눌렀다 뗀다 → 잡기 유지. 버튼을 떼면 놓음.
   4. 반대로 마우스를 누른 채 버튼을 눌렀다 떼도 유지되는지.
3. **다이브 지름길 (AC6)**: 6개 맵(회전 벨트·간장 늪·라멘 급류·철판·셰프의 도마·꼬치 쇼다운)을 돌며 벽 끝·절벽·국물 구간에서 점프 → 다이브로 코스를 건너뛸 수 있는지. 간장 늪은 와사비 위에서 다이브도. 찾으면 맵·대략 위치를 스펙 결정 기록에 적는다(고칠지는 사용자).
4. **8명 부하 (AC7)**: **Test → Clients and Servers 8명**, 24명 방 → 시작. F9 Developer Console → **Server Stats → Heartbeat** 55 이상인지. 꼬치 쇼다운 결승에서 특히(m4-03 B5). 4라운드를 보려면 `forceMapPlan`에 4개.
5. **P3 눈 확인**
   1. 간장 늪 소개 플라이스루 마지막 구간에 빨간 종이 등이 화면을 덮지 않음.
   2. 회전 벨트 결승 문 노렌이 머리 위로 충분히 높음(점프해도 시야를 가리지 않음).
   3. 철판 층 테두리·꼬치 무대 테두리가 턱처럼 보이지 않음. **추가 확인**: 철판 테두리가 이제 타일과 같은 높이라 "밟을 수 있는 바닥"처럼 보이는지(충돌이 없어 밟으면 떨어짐). 헷갈리면 알려 주기.
   4. 셰프의 도마: 기울기가 바뀌는 중에 내려칠 때 칼이 도마를 따라 내려오고, 친 뒤 도마 가운데 위로 올라감.
6. **m4-08 B4**: 작은 창(세로 720 이하)에서 우승할 때 "+100 🍚 우승!" 토스트가 우승 큰 글씨와 겹치는지.
7. **서버 종료(D5, 선택, C1 뒤)**: `persistDataInStudio = true`로 Play → 접속 직후(1초 안) Stop. Output에 저장 오류·멈춤 없이 종료되는지. 다음 Play에서 로드가 10초 기다리지 않는지. 끝나면 `false`.

## 추가한 테스트
`tests/m4-12-qa.spec.luau` (7개)
- QA G1/G4: 무작위 입력 200개 시퀀스(총 3000번, 입력원 3개·뗌/누름·cancel, 예약 flush 처리) — `GrabService` 빈도 제한을 흉내 낸 서버가 누름을 하나도 버리지 않음, 보낸 값은 번갈아, `true` 간격 ≥ 0.13초, 예약은 지금부터 0.13초 안, 끝나면 `sent == isHolding`, 서버 상태 = 클라 상태. 변형 시험: 예약 검사를 끄거나 `flush`가 아무것도 안 보내게 하면 실패.
- QA G1: 서버 제한과 클라 간격이 같은 설정값(`Config.Grab.InputMinInterval`)을 씀, 여유 0 < MARGIN ≤ 0.05.
- QA P3 장식: 바뀐 노렌·문·종이 등·Frame·RimLip이 장식 목록에 있고, 장식은 `MapKit.buildDecor` → `applyDecorRules`(충돌·쿼리·터치 없음)로 만들어짐.
- QA P3 철판: Frame 높이 1.4 유지, 층마다 4개, 타일 영역 바깥.
- QA D5: `CLOSE_TIMEOUT ≤ 25`, 마감 시각으로 루프 제한, `loading` 지우기와 `save` 사이 yield 없음, `runSaves`가 바로 `saving`에 올림.
- QA DEBUG: `forceMapPlans` 회전이 Studio 가드 뒤, 기본값 nil/false.
- QA 타입 수정: ChefBoard 조준 스레드 `false` 인자가 이전 `nil`과 같은 분기.

## 인계 메모 (최신)
- **지금 브랜치**: `m4-12-qa` (origin/main `473b21e`에서 분기). main에는 손대지 않음.
- **끝난 것**: 검증 5단계 실행(918/0, 타입 에러 0, 일부러 넣은 타입 에러 3종 잡힘 확인), 98eadcb 전/후 순수 모듈 차등 비교(불일치 0), P3 수정 8건 코드·테스트 확인, 잡기 재전송 무작위 시험, D5 종료 대기 상한 확인, 누수 테스트 변형 시험, 출시 체크리스트 ↔ USER-TODO 대조, QA 테스트 7개 추가, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 체크리스트 1~7(AC4~AC7). docs-writer: 검증 5단계·"타입 검사 못 함" 규칙을 WORKFLOW·CLAUDE.md·에이전트 정의에, DEV-SETUP 3-9에 체크리스트(N1 빠진 항목 포함), USER-TODO D에 비공개 테스트 줄, `docs/playtest/m4.md` 양식. P3 N2·N3·N4는 개발 판단(급하지 않음).
- **다음에 할 첫 단계**: 메인 세션이 `m4-12-qa`를 main에 병합 → docs-writer가 문서 반영 후 `done`. 사용자가 AC4 숫자·AC6 결과를 주면 스펙 개발 메모/결정 기록에 기록.
- **막힌 점**: 없음. Studio가 없어 AC4~AC7은 직접 못 봄. Lune에 `collectgarbage("collect")`가 없어 약한 키의 실제 회수는 못 봄(구조만 확인).
