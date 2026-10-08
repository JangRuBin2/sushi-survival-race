status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-01 — 결승 연장전: 마지막 1명이 남을 때까지

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §4(매치 흐름 3 "모든 라운드는 짧은 시간 제한"), §5.1(결승 = 마지막 1명 생존형), §5.2 Final 맵(최대 90초, 시간 종료면 가장 높이 있는 사람), ⑥ 회전 꼬치 쇼다운, §10(HUD), §11.4(맵 인터페이스). **GDD는 사용자 확정 전이라 아직 안 바꿨어요** (바뀔 절은 `docs/planner/m5-plan.md`).
- 레퍼런스: [`docs/REFERENCE-final-overtime.md`](../REFERENCE-final-overtime.md) (2026-10-08 조사)
- 담당 개발 worktree: `m5-overtime` (Rojo 포트 34872). m5-02와 **병렬 가능** (고치는 파일이 겹치지 않음)
- 공용 파일 수정 담당: **이 스펙** — `shared/Config.luau`, `shared/Types.luau`, `shared/maps/MapTypes.luau`. (m5-02는 이 셋을 건드리지 않아요)
- **이 스펙이 고치는 파일**: `src/shared/RoundLogic.luau`, `src/server/RoundService.luau`, `src/shared/maps/MapTypes.luau`, `src/shared/maps/SkewerShowdown.luau`, `src/shared/maps/SkewerShowdownLogic.luau`, `src/shared/Config.luau`, `src/shared/Types.luau`, `src/client/ui/HudScreen.luau`, `src/client/ui/HudController.luau`, `src/shared/SfxCues.luau`, `src/shared/SfxLibrary.luau`, (필요하면) `src/client/Sfx.luau`, 테스트 `tests/round-logic.spec.luau`(추가), `tests/map-skewer-showdown.spec.luau`(추가), `tests/maps.spec.luau`(validate 추가)

## 목표
결승이 90초에 "그 순간 가장 높이 있는 사람"으로 어정쩡하게 끝나지 않고, **마지막 1명이 남을 때까지** 이어진다. 90초가 되면 "⚡ 연장전!"과 함께 꼬치가 더 빨라지고 남은 접시가 바깥부터 무너져서, 20초 안에 설 곳이 사라진다 → 가장 늦게 떨어진 초밥이 우승한다. 결승 맵을 새로 만들 때도 같은 약속(연장전 훅)을 지키게 한다.

## 규칙 (기본값, 사용자 수정 가능 — 근거는 REFERENCE 2·3절)
| 시점 (라운드 출발 기준) | 일어나는 일 |
|---|---|
| 0 ~ `overtimeAt` (= 결승 맵의 시간 제한, 지금 90초) | 지금과 같음 |
| `overtimeAt` | **연장전 시작**: 서버가 맵의 `overtime(ctx, info)`를 부르고, 방 전원에게 연장전을 알림(HUD 배너·경적) |
| `collapseAt` = `overtimeAt + Config.Final.CollapseDuration`(20) | 이때까지 맵이 **설 곳을 전부 없애야** 해요. 남은 사람은 떨어지고, 가장 늦게 떨어진 사람이 우승 |
| `hardCapAt` = `collapseAt + Config.Final.HardCapMargin`(40) → 150초 | **안전 상한**. 그래도 안 끝났으면(버그·물리 이상·훅 없는 맵) 남은 사람 중 **점수(높이)가 가장 큰 1명 우승**, 나머지 탈락(사유 Timeout) — 지금의 90초 규칙을 그대로 옮긴 것. 같은 점수면 무작위 |

- **같은 판정 틱에 전원 낙하**: 지금 규칙 그대로 (그 묶음 낙하자 중 더 높이 있던 사람 우승, 리셋·퇴장은 더 나쁜 등수, 전부 리셋·퇴장이면 우승자 없음). 연장전 붕괴로 이 경우가 늘어날 수 있지만 규칙은 바꾸지 않아요.
- 연장전은 **결승 모드(`RoundLogic` Mode "Final" = 마지막 라운드)에서만**. Race·Survival의 시간 종료는 바뀌지 않아요(결정 기록 D2).
- 우승자는 지금처럼 항상 1명(Won을 받은 사람). 코인·순위표·단상·우승 연출은 바뀌지 않아요.

## 범위
- 포함:
  1. **순수 로직 — 일정** (`RoundLogic`):
     ```lua
     export type Schedule = { overtimeAt: number?, collapseAt: number?, hardCapAt: number }
     export type ClockPhase = "Normal" | "Overtime" | "Collapsed" | "Expired"
     RoundLogic.schedule(mode: Mode, timeLimit: number, final: { CollapseDuration: number, HardCapMargin: number }, overtimeAtOverride: number?): Schedule
     RoundLogic.clockPhase(schedule: Schedule, elapsed: number): ClockPhase
     ```
     - Race·Survival: `{ hardCapAt = timeLimit }` (overtimeAt·collapseAt nil), Final: 위 표. `overtimeAtOverride`(디버그)가 있으면 overtimeAt만 그 값.
     - `clockPhase`: elapsed < overtimeAt → Normal, < collapseAt → Overtime, < hardCapAt → Collapsed, 그 이상 → Expired. Race·Survival은 Normal / Expired만.
     - `RoundLogic.timeout`은 그대로(Expired에서 부름). 머리 주석의 Final 설명을 "시간 종료(안전 상한)면 점수가 가장 큰 사람이 우승"으로 고쳐요.
  2. **RoundService**: 라운드 대기 루프를 `Schedule`로 바꿔요.
     - 지금 `deadline = os.clock() + Maps.timeLimit(map)` → `RoundLogic.schedule(mode, Maps.timeLimit(map), Config.Final, overtimeOverride)`. 대기 루프에서 `clockPhase`가 Overtime이 되는 순간 **한 번만**: 라운드가 안 끝났고 mode가 Final이면 `map.overtime`을 `pcall(map.overtime, ctx, { collapseDuration = Config.Final.CollapseDuration })`로 부르고(에러면 warn, 판정은 안전 상한이 마무리), RoundProgress를 다시 보내요(아래 3). Expired가 되면 지금처럼 `flush()` 후 `RoundLogic.timeout`.
     - `overtimeOverride` = Studio(`RunService:IsStudio()`)에서만 `Config.DEBUG.overtimeAt`, 실서버는 nil.
     - 결승 마지막 탈락 뒤 3초 대기·우승 발표 순서(m3-09)는 그대로.
     - `MatchService`는 바꾸지 않아요: RoundActive의 `endsAt`은 지금처럼 `Maps.timeLimit(map)`(결승이면 = 연장전 시작 시각).
  3. **리모트 데이터** (`Types.RoundProgress`에 필드 추가, 둘 다 선택):
     ```lua
     overtime: boolean?,   -- 결승 연장전 중이면 true
     collapseAt: number?,  -- 연장전에서 바닥이 다 사라지는 시각 (workspace:GetServerTimeNow() 기준)
     ```
     RoundService `broadcastProgress`가 연장전 이후 보낼 때마다 채워요. 결승이 아니거나 연장전 전이면 nil.
  4. **맵 공통 계약** (`MapTypes`):
     ```lua
     export type OvertimeInfo = { collapseDuration: number }
     -- MapModule에 추가
     overtime: ((ctx: RoundContext, info: OvertimeInfo) -> ())?,
     ```
     - 약속(머리 주석에 적기): **`kind == "Final"` 맵은 `overtime`이 필수**. 불리면 `info.collapseDuration`초 안에 **어떤 레이서도 안전하게 서 있을 수 없게** 만든다(바닥 제거·치명 구역 등). 매달리기·높은 곳 버티기 같은 "안전한 자리"가 남으면 안 된다(REFERENCE 2절 C' Jump Showdown infinite hang). 낙하 판정은 `start`에서 이어 하던 대로 `ctx.eliminate`. 상태는 `ctx`/지역 변수(여러 방 동시 진행).
     - `MapTypes.validate`: `kind == "Final"`인데 `overtime`이 함수가 아니면 `"{id}: Final maps must have an overtime function"`, 다른 종류에 `overtime`이 있는데 함수가 아니면 에러 문자열.
     - 결승이 아닌 라운드(디버그 강제 플랜 중간의 Final 맵)에서는 부르지 않아요.
  5. **회전 꼬치 쇼다운 연장전** (`SkewerShowdown.overtime`, 수치는 `SkewerShowdownLogic`):
     - 셰프 손: 연장전이 시작되면 **새 조각을 고르지 않아요**(이미 경고·집는 중인 조각은 끝까지).
     - 꼬치 가속: 연장전 시작부터 `collapseDuration` 동안 낮은 꼬치 150 → **190**°/s, 높은 꼬치 120 → **150**°/s로 선형 증가, 그 뒤 유지. `Logic.speeds(elapsed, overtimeAt?)` 같은 순수 함수로(연장전 전에는 지금 값과 같아야 함).
     - **접시 붕괴**: 남아 있는 모든 조각의 띠(조각당 8줄, `STRIPS_PER_SLICE`)를 **바깥 줄부터 안쪽으로** 한 줄씩 없애요. 줄 간격 = **약 2.7초**(사라지는 시각 사이 `(collapseDuration - 경고) / (STRIPS_PER_SLICE - 1)` = 19/7초, `Logic.collapseTimes`). 줄마다 **1초 빨간 깜빡임 경고**(지금 셰프 손 경고 색) → `CanCollide = false` + 사라짐(투명도 1, 그 줄 위 장식도 함께). 첫 경고는 연장전 시작 순간, 마지막 줄(가장 안쪽)은 `collapseAt`에 사라져요 → 그 뒤 무대에 설 곳 없음. 집히는 중인 조각은 손이 가져가니 건너뛰어요.
     - 줄 순서·시각은 순수 함수 `Logic.collapseTimes(stripsPerSlice, collapseDuration, warnTime): { { strip: number, warnAt: number, dropAt: number } }`(연장전 시작 기준 초).
     - 소리: 줄이 사라질 때 기존 `TileVanish`(맵 효과음, 줄당 1번이면 너무 많으니 **줄 단위 1번**), 경고 시작 때 기존 `ChefHandWarn`은 쓰지 않아요(손이 안 와서 헷갈림).
     - 기둥은 그대로(위로 16 솟아 올라갈 수 없음). 꼬치·손·장식은 충돌 없음 그대로 — 붕괴 뒤 매달릴 곳이 없는지 확인(Studio AC).
  6. **HUD** (`HudScreen`/`HudController`):
     - 결승 RoundActive 동안 타이머는 지금처럼 `endsAt`(= 연장전 시작)까지 "⏱ N초".
     - `RoundProgress.overtime == true`를 처음 받으면: 가운데 배너 **"⚡ 연장전!"** / 부제 **"접시가 무너져요! 끝까지 버텨요"** 2초, 효과음 `Overtime` 1번. 타이머는 빨간 글씨 **"⚡ N초"**(`collapseAt`까지 남은 초). 0이 되면 **"⚡ 버텨요!"**(숫자 없음).
     - 관전 중인 사람(탈락자·대기석)도 같은 RoundProgress를 받으니 똑같이 보여요. 휴대폰 배치(m4-09 compact)에서도 타이머 칸 안에 들어가야 해요(글자 수가 "⏱ 90초"와 비슷하게).
     - 연장전 표시는 다음 MatchPhase(RoundResults·Victory)나 HUD 숨김에서 지워요.
  7. **소리**: `SfxCues.Effects`에 `"Overtime"`(경적·징 같은 짧은 소리) 추가, `SfxLibrary`에 `sfx(nil, …)`(id는 사용자가 고를 때까지 무음, `docs/USER-TODO.md` A2에 추가 제안). 연장전 동안 결승 배경음 `PlaybackSpeed` **1.1배**(Sfx에 함수가 없으면 `Sfx.setMusicSpeed(multiplier)`를 추가하고, 연장전 표시를 지울 때 1로).
  8. **설정** (`Config.luau`):
     ```lua
     -- 결승 연장전 (m5-01, GDD 5.2). 연장전 시작 = 결승 맵의 시간 제한(Config.TimeLimit.Final 또는 map.timeLimit)
     Config.Final = {
         CollapseDuration = 20, -- 연장전 시작부터 맵이 설 곳을 다 없앨 때까지(초)
         HardCapMargin = 40, -- 바닥이 다 사라진 뒤에도 안 끝나면 이만큼 더 기다렸다가 높이 순 판정(안전 상한)
     }
     -- Config.DEBUG에 추가:
     -- 결승 연장전 시작을 이 초로 당겨요 (Studio 전용, 혼자·2명 테스트용). 커밋할 때는 nil로.
     overtimeAt = nil :: number?,
     ```
     `Config.TimeLimit.Final = 90`은 그대로 두고 주석만 "결승은 연장전 시작 시각"으로.
- 제외:
  - 공동 우승(Fall Guys식)·무승부 — 사용자 선택지로만 (결정 기록 D3).
  - 결승 맵 추가(새 Final 맵은 M5 백로그 — 만들 때 이 계약을 따름).
  - 연장전 전용 배경음 곡(지금 Final 곡 1.1배로 대신).
  - Survival 탈락 0명 허용 여부(GDD 4.1 Q7, 별도 사용자 결정).

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `RoundLogic.schedule("Final", 90, { CollapseDuration = 20, HardCapMargin = 40 })`는 `{ overtimeAt = 90, collapseAt = 110, hardCapAt = 150 }`, `"Race"`·`"Survival"`(60)은 `{ hardCapAt = timeLimit }`(나머지 nil)이다. `overtimeAtOverride = 15`면 Final은 `{ 15, 35, 75 }`.
- [ ] AC2: `clockPhase`(Final 위 일정)는 elapsed 0·89.9 → Normal, 90·109.9 → Overtime, 110·149.9 → Collapsed, 150 이상 → Expired. Race 일정은 89.9 → Normal, 90 → Expired.
- [ ] AC3: 결승 레이서 3명이 안전 상한 전에 **서로 다른 묶음**으로 1명씩 떨어지면, 두 번째 낙하 묶음에서 남은 1명이 Won을 받고 라운드가 끝난다(지금 규칙 회귀). `RoundLogic.timeout`은 그 뒤 빈 목록.
- [ ] AC4: 결승 레이서 2명이 한 묶음으로 떨어지면(높이 5, 8) 높이 8인 사람이 Won, 5인 사람이 Eliminated. 한 명이 cause "Reset"이면 낙하자가 Won(높이와 상관없이). 둘 다 Reset이면 Won 없음 (기존 m4-01 테스트가 그대로 통과).
- [ ] AC5: 결승에서 `RoundLogic.timeout`(안전 상한)을 부르면 남은 사람 중 점수가 가장 큰 1명만 Won, 나머지는 Eliminated(점수 낮은 사람이 더 나쁜 등수). 점수가 같으면 `rng`로 정해지고 Won은 정확히 1명이다.
- [ ] AC6: 결승 레이서 1명(디버그 혼자)으로 시작하면 `activate`만으로는 끝나지 않고, 그 사람의 낙하 묶음(cause Fall)이 오면 Won을 받는다. Reset이면 Won 없이 끝난다.
- [ ] AC7: `MapTypes.validate`가 `kind = "Final"`이고 `overtime`이 없는 맵에 에러 문자열을, 있는 맵에 nil을 돌려준다. 맵 풀 6개(`Maps` ALL)는 모두 validate를 통과한다(꼬치 쇼다운에 overtime이 있음).
- [ ] AC8: `SkewerShowdownLogic.speeds`는 연장전 전(overtimeAt nil 또는 elapsed < overtimeAt)에는 지금 값과 같고, 연장전 시작 + 10초에 낮은 170·높은 135, + 20초 이상에서 190·150이다.
- [ ] AC9: `SkewerShowdownLogic.collapseTimes(8, 20, 1)`은 8개, strip 8부터 1 순서, 마지막 항목 `dropAt == 20`, 각 `dropAt - warnAt == 1`, `warnAt`은 0 이상이고 증가한다. 첫 항목 `warnAt == 0`.
- [ ] AC10: 검증 5단계 통과 (rojo build, stylua, selene, lune run tests, luau-lsp 타입 검사). 못 돌린 단계는 보고에 적는다.

### Studio 확인 (사용자 확인 필요)
설정: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, 빠른 확인은 `Config.DEBUG.overtimeAt = 15`. **확인 뒤 둘 다 nil**.
- [ ] AC11: Test → Clients and Servers 2명, 결승에서 둘 다 오래 버티면 연장전 시작 순간(기본 90초, 디버그 15초) 두 화면 모두 "⚡ 연장전!" 배너가 2초 뜨고 경적(id가 있으면)이 한 번 나며, 타이머가 빨간 "⚡ 20초"부터 줄어든다.
- [ ] AC12: 연장전 동안 접시 바깥 줄이 빨갛게 1초 깜빡인 뒤 사라지고 약 2.7초마다(19/7초) 한 줄씩 안쪽으로 이어진다. 디버그 15초(조각이 여러 개 남은 상태)여도 **남은 조각 전부**가 같이 무너진다. 셰프 손은 연장전 뒤 새 조각을 집지 않는다.
- [ ] AC13: 연장전 시작부터 20초가 지나면 무대에 설 곳이 없어 두 사람 다 떨어지고, **더 늦게 떨어진 사람**에게 "🏆 우승했어요!" → 3초 뒤 Victory. 기둥·꼬치·손 어디에도 서거나 매달려 버틸 수 없다.
- [ ] AC14: 혼자(Play Solo) 결승은 연장전 → 붕괴로 떨어져 우승 처리되고 매치가 끝난다(멈추지 않는다).
- [ ] AC15: 연장전 중 한 명이 리셋하거나 나가면 남은 1명이 그 즉시 우승한다(지금 규칙). 탈락자 화면(관전)에도 연장전 타이머가 보인다.
- [ ] AC16: 결승이 아닌 라운드(예: 강제 플랜 `{ "skewer-showdown", "hot-plate", "rotating-belt" }`처럼 꼬치 쇼다운이 중간)에서는 연장전이 일어나지 않고 90초에 버틴 사람 전원 통과한다.
- [ ] AC17: 휴대폰 에뮬레이터(Test → Device, 가로)에서 "⚡ 20초"·"⚡ 버텨요!"가 타이머 칸 안에 들어가고 배너가 다른 HUD와 겹치지 않는다.

## 공용 파일 변경
- `shared/Config.luau`: `Config.Final { CollapseDuration = 20, HardCapMargin = 40 }` 추가, `Config.DEBUG.overtimeAt = nil` 추가, `Config.TimeLimit.Final` 주석.
- `shared/Types.luau`: `RoundProgress.overtime: boolean?`, `RoundProgress.collapseAt: number?`.
- `shared/maps/MapTypes.luau`: `OvertimeInfo` 타입, `MapModule.overtime?`, validate 규칙, 머리 주석에 연장전 약속.
- `shared/Remotes.luau`·`Attributes.luau`·init 스크립트·`default.project.json`: 바꾸지 않음 (m5-02 담당).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 연장전 방식 · **90초에 연장전 → 20초 동안 접시가 바깥부터 무너져 설 곳 0 → 늦게 떨어진 사람 우승.** 시간 제한을 "끝내는 시각"이 아니라 "판을 끝내는 장치가 켜지는 시각"으로 바꿈. 근거: Super Bomberman(Hurry Up → 경기장 축소)·Fall Guys Jump Showdown(발판이 떨어짐, 막대 가속)·Stumble Guys Laser Tracer Endless(마지막 1명까지, 점점 어려워짐) — REFERENCE 2·3절. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 결승 외 라운드에도 적용? · **아니요.** Race 시간 종료(진행도 순으로 채우고 나머지 탈락)·Survival 시간 종료(버틴 사람 전원 통과)는 이미 결정적으로 끝나고, Survival은 Fall Guys 서바이벌·로블록스 생존 게임(NDS·MM2)과 같은 방식(REFERENCE 2절 J·K). 결승 전 2명 이하면 바로 결승(GDD 4.1)·결승 전 혼자 남으면 부전승도 그대로 — 둘 다 "끝나지 않는" 문제가 없음. 강제 플랜 혼자 결승은 이제 90초가 아니라 연장전 붕괴(약 110초)로 끝남(AC14). · planner
- 2026-10-08 · D3 안전 상한(150초)의 판정 · **가장 높이 있는 1명 우승(지금 90초 규칙을 옮김).** 붕괴가 있으면 정상 플레이에선 오지 않는 값이라, 우승자 1명 불변식(Standings.winnerUserId·코인 +100·단상·우승 연출)을 지키는 쪽. 대안: 공동 우승(Fall Guys 결승, 로블록스 생존 게임 문화 — 큰 변경), 무승부(Bomberman — 억울함). 근거: REFERENCE 3절 "사용자 선택지". **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D4 수치 · 연장전 시작 90초(지금 시간 제한 유지 — 한 판 4~5분 안), 붕괴 20초(Bomberman Hurry Up 1:30 → 끝 2:00의 30초보다 짧게, 우리 결승이 더 짧아서), 줄 간격 약 2.7초(19/7초, 아래 QA 후 수정 참고)·경고 1초(셰프 손 경고 2초보다 짧게 — 한 번에 한 줄이라), 상한 +40초(Fall Guys 숨은 5분보다 훨씬 짧게, 한 판 길이 유지), 꼬치 +약 27%(190/150). **기본값, 플레이테스트 후 조정** · planner
- 2026-10-08 · D5 같은 순간 전원 낙하 · 바꾸지 않음(GDD 5.2, m4-01). 붕괴로 같은 틱 낙하가 늘 수 있지만 "더 높이 = 더 늦게 떨어질 사람"이라 같은 원칙. · planner
- 2026-10-08 · D6 공통 계약 · 연장전은 맵마다 다르게 생겼지만(바닥 붕괴·용암 상승 등) "collapseDuration 안에 안전한 자리 0"만 약속하면 RoundService·RoundLogic은 맵을 몰라도 됨. 새 Final 맵(M5 백로그)은 이 훅이 없으면 validate에서 막힘. · planner
- 2026-10-08 · QA 후 수정 (상태 qa-passed 유지) · developer
  - N1 줄 간격 문구: "2.5초마다" → "약 2.7초마다(19/7초)". 첫 경고 0초·마지막 줄 20초·경고 1초·8줄(AC9)을 함께 지키면 사라지는 간격은 (20 − 1) / 7초라 2.5초가 될 수 없어요. 동작은 그대로, 문구만 맞춤.
  - B1: 연장전 훅을 대기 루프에서 직접 pcall하지 않고 `task.spawn`(cleanup에 등록)으로 불러요. 루프는 `RoundLogic.loopAction`으로 돌아서 훅이 멈춰도 안전 상한에 끝나요. MapTypes 주석에 "훅 안에서 오래 기다리지 말 것".
  - B2: 결승 맵에 overtime 훅이 없으면(디버그 강제 플랜으로 Race·Survival 맵이 결승) `RoundLogic.schedule(..., hasOvertimeHook = false)` → 연장전·배너 없이 시간 제한에 높이 순(timeout)으로 끝. `Rules.resolveForcedPlan`은 그대로 받고, `Rules.forcedPlanWarning`으로 MatchService가 경고만 찍어요.

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
2026-10-08 · developer · 브랜치 `m5-01-overtime`

**바뀐 파일**
- `src/shared/RoundLogic.luau`: `Schedule`·`ClockPhase`·`FinalTiming` 타입, `schedule(mode, timeLimit, final, override?)`, `clockPhase(schedule, elapsed)`. 머리 주석 Final 설명 갱신. 판정 함수(eliminate/timeout/pass)는 그대로.
- `src/server/RoundService.luau`: 대기 루프를 `schedule`/`clockPhase`로. 처음 Normal이 아닌 순간 한 번 `pcall(map.overtime, ctx, { collapseDuration = Config.Final.CollapseDuration })`(훅이 없으면 경고만 → 안전 상한), RoundProgress 다시 보냄. Expired면 예전처럼 flush → timeout. `overtimeOverride` = Studio에서만 `Config.DEBUG.overtimeAt`. 출발 기준 시각은 map.start 직전(예전엔 직후 — 차이 무시할 만함).
- `src/shared/maps/MapTypes.luau`: `OvertimeInfo`, `MapModule.overtime?`, validate 규칙 2개, 머리 주석에 연장전 약속.
- `src/shared/maps/SkewerShowdownLogic.luau`: `speeds(elapsed, overtimeAt?, rampDuration?)`(연장전 시작 순간 속도 → 190/150 선형, 기본 램프 20초), `collapseTimes`, 상수 `LOW/HIGH_SPEED_OVERTIME`, `OVERTIME_RAMP`, `COLLAPSE_WARN_TIME`.
- `src/shared/maps/SkewerShowdown.luau`: 조각 띠·장식에 `Strip` 속성(장식은 바깥 끝이 걸친 줄). ctx별 `roundStates`(start ↔ overtime 공유, ctx.cleanup이 지움). `overtime`: 손은 새 조각을 안 고름, 꼬치 가속, 남은 조각 전부를 줄 단위로 1초 빨간 깜빡임 → CanCollide/CanTouch/CanQuery false + 투명, 줄당 `TileVanish` 1번.
- `src/shared/Config.luau`(`Config.Final`, `DEBUG.overtimeAt = nil`, TimeLimit.Final 주석), `src/shared/Types.luau`(`RoundProgress.overtime?`, `collapseAt?`).
- `src/client/ui/HudScreen.luau`(`showOvertime`/`clearOvertime`, 빨간 "⚡ N초"/"⚡ 버텨요!", 타이머는 TextScaled + UITextSizeConstraint로 칸 안에), `src/client/ui/HudController.luau`(처음 overtime 받을 때 배너·`Overtime`·음악 1.1배, RoundActive 밖 단계·HUD 숨김에서 지움), `src/client/Sfx.luau`(`setMusicSpeed`), `src/shared/SfxCues.luau`·`SfxLibrary.luau`(`Overtime`, 무음).
- 테스트: `tests/round-logic.spec.luau`(AC1~6), `tests/map-skewer-showdown.spec.luau`(AC7~9), `tests/maps.spec.luau`(AC7), `tests/camera-priority.spec.luau`(고정 cue 목록에 `Overtime` 추가).

**스펙과 다른 점 / 해석**
- 줄 간격: AC9(첫 경고 0, 마지막 dropAt 20, 경고 1초, 8줄)를 지키면 사라지는 간격은 2.5초가 아니라 19/7 ≈ 2.71초예요(사라지는 시각 1, 3.71, … 20). "2.5초마다"는 대략값으로 봤어요.
- 꼬치 가속은 "연장전 시작 순간 속도"에서 190/150으로 올라가요. 90초 시작이면 150/120에서 시작(AC8 그대로), 디버그 15초면 그때 속도에서 이어져 끊기지 않아요.
- 이동 감시(m4-10): 아래로 떨어지는 건 보지 않고, 꼬치 넉백은 이미 MoveExempt라 충돌 없음.

**검증**: rojo build, stylua --check, selene(0/0/0), lune run tests **1032 passed, 0 failed**, luau-lsp analyze 오류 없음.

**Studio 확인 방법 (AC11~17)**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, 빠르게는 `Config.DEBUG.overtimeAt = 15`. Test → Clients and Servers 2명으로 결승까지 가서 둘 다 버티기 → 배너·빨간 타이머·바깥 줄부터 붕괴·늦게 떨어진 사람 우승. 혼자(Play Solo)·리셋/퇴장·관전 화면·중간 꼬치 쇼다운(`{ "skewer-showdown", "hot-plate", "rotating-belt" }`)·휴대폰 에뮬레이터는 스펙 AC 그대로. **확인 뒤 둘 다 nil**.

**남은 이슈**: `Overtime` 효과음 id 없음(무음, USER-TODO A2 제안). GDD 반영은 사용자 확정 뒤 planner.
