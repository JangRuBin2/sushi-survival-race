# QA — m5-01 결승 연장전: 마지막 1명이 남을 때까지

- 스펙: `docs/specs/m5-01-final-overtime.md`
- 검증 커밋: `d60f6af` (브랜치 `m5-01-overtime`, `origin/main` 병합 결과 변경 없음) + QA 테스트 추가
- 결과: **통과 (qa-passed)**. P0/P1 없음, P3 2건 + 스펙 문구 정리 1건. Studio 항목 AC11~17은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 포함) |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — 개발 1032 + QA 10 = **1042 passed, 0 failed** |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (오류 없음) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `round-logic.spec` "m5-01 AC1", QA "clockPhase는 되돌아가지 않아요"(override 0/1/15/60/90/200에서 collapseAt = +20, hardCapAt = +60) |
| AC2 | 통과 | `round-logic.spec` "m5-01 AC2" (경계값 89.9/90/109.9/110/149.9/150) |
| AC3 | 통과 | `round-logic.spec` "m5-01 AC3", QA 무작위 시뮬레이션 400판 |
| AC4 | 통과 | `round-logic.spec` "m5-01 AC4" + 기존 m4-01 테스트 그대로 통과 |
| AC5 | 통과 | `round-logic.spec` "m5-01 AC5", QA "아무도 안 떨어지는 결승 — 정확히 150초에 높이 1명" |
| AC6 | 통과 | `round-logic.spec` "m5-01 AC6", QA "혼자 결승(강제 플랜)" (기본 약 111초, 디버그 15초면 약 36초에 Won) |
| AC7 | 통과 | `maps.spec` "m5-01 AC7" 2개 — 맵 풀 6개 모두 validate 통과, Final에 overtime 없으면 에러 |
| AC8 | 통과 | `map-skewer-showdown.spec` + QA "꼬치 속도"(연장전 시작 순간 연속, 줄지 않음, 190/150 상한) |
| AC9 | 통과 | `map-skewer-showdown.spec` + QA "붕괴 일정"(모든 줄 한 번, 바깥부터, 시간 안, 경고 안 겹침, 여러 수치) |
| AC10 | 통과 | 위 자동 검증 5단계 |
| AC11 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC12 | 사용자 확인 필요 | 체크리스트 2 (코드상 남은 조각 전부를 줄 단위로 붕괴, 손은 연장전 뒤 새 조각 안 고름: `SkewerShowdown.luau:548`) |
| AC13 | 사용자 확인 필요 | 체크리스트 3 (코드상 충돌 있는 파츠는 접시 띠·기둥뿐 — 아래 "끝나지 않을 경로" 참고) |
| AC14 | 사용자 확인 필요 | 체크리스트 4 (순수 로직 시뮬레이션은 통과) |
| AC15 | 사용자 확인 필요 | 체크리스트 5 (순수 로직: QA "연장전 중 리셋·퇴장" 통과) |
| AC16 | 사용자 확인 필요 | 체크리스트 6 — **B2 참고** (스펙의 강제 플랜은 마지막 라운드가 회전 벨트라 결승 연장전이 150초까지 감) |
| AC17 | 사용자 확인 필요 | 체크리스트 7 |

자동 확인 10/10 통과, Studio 7개 대기.

## 중점 확인 결과

### 판정 불변식 (QA 시뮬레이션)
`tests/m5-01-qa.spec.luau`가 RoundService 대기 루프를 그대로 흉내 내요: 0.2초마다 `clockPhase`, 처음 Normal이 아닐 때 훅 한 번, Expired면 `flush` → `timeout`, 한 프레임(1/60초)에 들어온 탈락 = 한 묶음(`task.defer(flush)`), 이미 대기 중·끝난 라운드·레이서 아님은 무시(`queueFall`).
무작위로 1~8명, 낙하·리셋·퇴장 시점을 섞고 일부는 같은 프레임에 묶어서:
- 붕괴 훅 정상 400판: Won ≤ 1, 리셋·퇴장한 사람은 우승 안 함, Won 없음은 마지막 묶음이 전부 리셋일 때뿐, 우승자보다 늦게 탈락한 사람 없음, Standings 우승자 = Won, 연장전은 90.0~90.2초에 한 번, **모두 collapseAt(110) + 낙하·점프 여유 안에 끝남(안전 상한까지 안 감)**.
- 훅 실패(`error`)·훅 없음(`none`) 각 150판: 같은 불변식 + 늦어도 150.2초에 끝나고, 상한 도달이면 정확히 1명 Won.
- Race(90)·Survival(60/90) 각 60판: 연장전 0번, Won 0, 시간 제한에 끝.

### 끝나지 않을 경로
- **붕괴가 설 곳을 다 없애는지 (코드 확인)**: 꼬치 쇼다운에서 `CanCollide = true`인 파츠는 조각의 접시 띠(`Plate`, 전부 `Strip` 속성 1~8)와 기둥뿐이에요. 꼬치(`CanCollide = false`), 손(전부 false), 스폰(false), 장식·Studio 아트(`MapKit.applyDecorRules` — 충돌·쿼리·터치 없음)는 처음부터 설 수 없어요. 기둥은 무대 위로 16 솟아 점프(약 6.4)·넉백(위로 22 studs/s, 약 1.2)으로 못 올라가요. 테두리(남색 띠)는 strip 8 = 가장 먼저 사라지는 줄이에요. 붕괴는 `state.alive`(손이 아직 안 고른 조각) 전부의 8줄을 지우고, 손이 집는 중인 조각은 `grabSlice`가 CanCollide false → Destroy 해요. → 연장전 20초 뒤 충돌 파츠는 기둥 옆면뿐. Studio 확인은 AC13.
- **훅 실패**: `pcall` + warn, 판정은 안전 상한이 마무리 (시뮬레이션 통과). `start`가 실패해 `roundStates[ctx]`가 없어도 `overtime`은 태그로 조각을 찾아 붕괴시켜요(`SkewerShowdown.luau:596~`).
- **훅이 멈추는(yield) 경우**: B1 (P3, 지금 맵은 해당 없음).
- 혼자 강제 플랜: 순수 로직상 연장전 붕괴로 Won (AC6/AC14).

### 결승 외 라운드 불변
- `RoundLogic.schedule`이 Race·Survival엔 `overtimeAt`을 안 주니 `clockPhase`가 Normal/Expired만 → 훅·RoundProgress.overtime 없음. 디버그 `overtimeAt`도 결승에만 적용(테스트).
- 꼬치 쇼다운이 중간 라운드면 `modeFor` → Survival → 연장전 없음, 시간 제한에 버틴 사람 통과(기존과 같음). 기존 Race/Survival 테스트 전부 통과.

### 기타
- 여러 방: 연장전 상태는 `roundStates[ctx]`(ctx 키), `ctx.cleanup`이 지우고, 붕괴 스레드(`task.delay`)도 `ctx.cleanup`에 등록. `collapseStrip`은 `ctx.isActive()`가 false면 바로 멈춰요. RoundService 쪽 상태(`overtimeCollapseAt`, `overtimeStarted`)도 `prepareRound` 지역 변수.
- 이동 감시(m4-10): `MovementGuardLogic`은 상승(`rise`)·수평 속도만 봐요 — 붕괴 낙하와 충돌 없음. 꼬치 넉백은 이미 `MoveExempt`.
- 결승 3초 대기·우승 발표(m3-09): 루프 뒤 `deferredWonUserId` 처리는 그대로. 안전 상한 timeout으로 끝날 때도 예전 90초 timeout과 같은 경로(방에 남은 탈락자가 있으면 3초 뒤 Won).
- 디버그 `Config.DEBUG.overtimeAt`: 기본 `nil`(테스트), RoundService가 `RunService:IsStudio()`일 때만 읽어요(`RoundService.luau:541`).
- `MatchService` 미변경 — RoundActive `endsAt`은 그대로 시간 제한(= 연장전 시작).

### 개발이 스펙과 다르게 한 것 (타당성)
- **줄 간격 19/7 ≈ 2.71초**: 스펙 문구가 서로 맞지 않아요 — "줄 간격 = 20/8 = 2.5초", "첫 경고 0", "마지막 줄은 collapseAt에 사라짐"(AC9)을 경고 1초와 함께 다 지킬 수 없어요(2.5초 간격이면 1, 3.5, …, 18.5초). AC9(시각 약속)를 지키고 간격을 늘린 쪽이 "collapseDuration 안에 설 곳 0"이라는 계약에도 맞아서 **타당**. planner가 스펙·GDD 문구를 "약 2.7초마다"로 고치면 돼요 (아래 N1).
- **가속 시작점**: 연장전 시작 순간 속도에서 190/150으로 선형. 90초 시작이면 150/120 → 스펙 AC8 그대로, 디버그로 일찍 시작해도 끊기지 않아요(QA 연속성 테스트). **타당**.
- **출발 기준 시각을 `map.start` 직전으로**: 꼬치 쇼다운 start는 양보하지 않아(손은 task.spawn) 차이 없음. 타당.
- **MapTypes validate(Final 필수)**: 기존 맵 6개 모두 통과, 다른 맵 테스트 영향 없음.
- **camera-priority 효과음 목록에 `Overtime` 추가**: 그 테스트는 `SfxCues.Effects` 전체를 고정 목록으로 비교해 새 cue를 넣으면 반드시 고쳐야 하는 테스트예요. 기대값을 구현에 맞춘 게 아니라 스펙 7번이 요구한 cue 추가를 반영한 것 — **타당**.

## 버그
### [P3] B1 연장전 훅을 대기 루프 안에서 동기로 불러서, 훅이 멈추면(yield) 안전 상한도 멈춰요
- 재현: (가상) 새 Final 맵의 `overtime`이 안에서 `task.wait`로 붕괴를 순서대로 기다리거나 무한 대기하면.
- 기대: 스펙 "훅이 실패해도 안전 상한이 마무리" — 훅이 무엇을 하든 150초에 끝.
- 실제: `pcall(overtimeHook, ctx, info)`는 Roblox에서 양보를 허용하니 훅이 돌아올 때까지 루프가 서요. 그동안 낙하 판정은 계속되지만 `Expired` 검사가 안 돌아요. 지금 꼬치 쇼다운은 `task.delay`만 써서 바로 돌아오니 해당 없음.
- 제안: `task.spawn`으로 부르고 스레드를 `cleanup`에 넣거나, MapTypes 머리 주석에 "overtime은 양보하지 말 것(일정은 task.delay)"을 적기.
- 위치: `src/server/RoundService.luau:557`

### [P3] B2 마지막 라운드가 Final 맵이 아니면(디버그 강제 플랜) "접시가 무너져요" 배너가 뜨고 150초까지 늘어나요
- 재현: `Config.DEBUG.forceMapPlan = { "skewer-showdown", "hot-plate", "rotating-belt" }`(스펙 AC16 그대로) → 3라운드 회전 벨트가 결승 모드로 돌고, 아무도 결승선을 못 넘으면 90초에 "⚡ 연장전! / 접시가 무너져요!" 배너·빨간 타이머, 실제로 아무것도 안 무너지고 150초에 높이(진행도) 순으로 1명 우승. 출력창에 `has no overtime()` 경고.
- 기대: 디버그 전용이라 치명적이진 않지만, 예전엔 90초에 끝났어요. 훅이 없으면 연장전 표시를 안 보내거나 바로 상한으로 가는 편이 덜 헷갈려요.
- 실제: 위와 같음 (코드로 확인, Studio 미실행). 실서버는 마지막 라운드가 항상 Final 맵이라 해당 없음(`Rules.roundKinds`). `Rules.resolveForcedPlan`은 마지막이 Final인지 검사하지 않아요.
- 위치: `src/server/RoundService.luau:552~566`, `src/client/ui/HudScreen.luau:475`
- 영향: AC16 확인할 때 3라운드는 무시(체크리스트 6에 적어 둠).

### N1 (스펙 문구, 버그 아님) 줄 간격 "2.5초"
- 스펙 범위 5·AC12·D4·m5-plan GDD 변경안의 "2.5초마다"를 "약 2.7초마다(첫 경고 0초, 마지막 줄 20초)"로 — planner 담당.

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 — 이 스펙은 새 클라이언트→서버 리모트가 없어요. `RoundProgress`는 서버→클라이언트, 클라이언트는 `collapseAt` 타입만 보고 표시.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 연장전 시각·붕괴·판정 모두 서버(RoundService, 맵 start/overtime). HUD는 표시만.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `roundStates[ctx]`(모듈 테이블이지만 ctx 키, cleanup이 지움), 나머지는 지역 변수.
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 붕괴 `task.delay` 스레드·roundStates 항목 모두 `ctx.cleanup`. HUD 배너 `task.delay`는 토큰으로 무효화.

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, 빠르게 보려면 `Config.DEBUG.overtimeAt = 15`. **확인이 끝나면 둘 다 `nil`로 되돌리기.**

1. (AC11) Test → Clients and Servers, 플레이어 2명. 방 만들고 시작 → 결승(꼬치 쇼다운)까지 둘 다 살아남기. 둘 다 버티다 15초(디버그)/90초가 되면:
   - [ ] 두 화면 모두 가운데 "⚡ 연장전!" / "접시가 무너져요! 끝까지 버텨요" 배너가 약 2초 뜨고 사라진다.
   - [ ] 오른쪽 위 타이머가 빨간 "⚡ 20초"로 바뀌어 1초씩 줄고, 0이 되면 "⚡ 버텨요!"로 바뀐다.
   - [ ] 배경음이 조금 빨라진다(곡 id가 있을 때). 경적은 id가 없으면 무음이 정상.
2. (AC12)
   - [ ] 남은 모든 조각의 가장 바깥 남색 줄이 1초 빨갛게 깜빡인 뒤 사라지고, 약 2.7초마다 한 줄씩 안쪽으로 이어진다(디버그 15초면 조각이 여러 개 남은 상태에서도 전부 같이).
   - [ ] 연장전 뒤 셰프 손이 새 조각을 집으러 오지 않는다(이미 빨갛게 깜빡이던 조각은 마저 가져감).
   - [ ] 꼬치가 눈에 띄게 빨라진다.
3. (AC13)
   - [ ] 연장전 시작 약 20초 뒤 가장 안쪽 줄까지 사라져 두 사람 다 떨어진다. 더 늦게 떨어진 쪽에 "🏆 우승했어요!" → 약 3초 뒤 Victory 연출.
   - [ ] 기둥 옆에 붙기, 기둥 위로 점프, 꼬치·손·장식 위에 올라타기 — 전부 실패하고 떨어진다.
4. (AC14) Play Solo(혼자) 같은 설정으로 결승까지 →
   - [ ] 연장전 → 붕괴로 떨어지면 우승 처리되고 Victory → 로비로 끝난다(멈추지 않는다).
5. (AC15) 2명, 연장전 중(빨간 타이머가 보일 때)
   - [ ] 한 명이 리셋(Esc → Reset)하면 남은 사람에게 즉시 "🏆 우승했어요!".
   - [ ] 다시 해서 한 명이 게임을 나가면(창 닫기) 남은 사람 즉시 우승.
   - [ ] 연장전 전에 떨어진 사람(관전 중) 화면에도 배너·빨간 타이머가 똑같이 보인다.
6. (AC16) `forceMapPlan = { "skewer-showdown", "hot-plate", "rotating-belt" }`, 2명
   - [ ] 1라운드(꼬치 쇼다운)는 90초가 되어도 연장전 배너가 없고, 버틴 사람이 전원 통과한다.
   - 3라운드(회전 벨트가 결승 역할)는 B2 때문에 90초에 연장전 배너가 뜨고 150초까지 갈 수 있어요 — 이번 확인에서는 무시.
7. (AC17) Test → Device(휴대폰 가로) 에뮬레이터로 1번 반복
   - [ ] "⚡ 20초", "⚡ 버텨요!"가 타이머 칸 안에 들어가고(잘리거나 넘치지 않음) 글씨가 읽힌다.
   - [ ] "⚡ 연장전!" 배너가 왼쪽 위 인원·내 결과·조작 버튼과 겹치지 않는다.
8. 끝나면 `Config.DEBUG.forceMapPlan`, `Config.DEBUG.overtimeAt`를 `nil`로.

## 추가한 테스트
- `tests/m5-01-qa.spec.luau` (10개)
  - Config 기본값(붕괴 20, 상한 +40, `DEBUG.overtimeAt`/`forceMapPlan` nil, 결승 시간 제한 90)
  - 무작위 결승 400판(붕괴 정상) — 우승자 불변식 + collapseAt 직후 종료
  - 훅 실패·훅 없음 각 150판 — 150초 안에 반드시 종료, 상한이면 Won 정확히 1명
  - 아무도 안 떨어짐 — 150초에 높이 1명
  - 혼자 결승(기본/디버그 15/리셋)
  - 연장전 중 리셋 → 남은 1명 즉시 우승
  - Race/Survival 무작위 — 연장전 없음, 시간 제한에 종료
  - clockPhase 단조성(override 여러 값)
  - 붕괴 일정(여러 수치: 모든 줄 한 번, 바깥부터, 시간 안, 경고 안 겹침, 기본 간격 19/7)
  - 꼬치 속도(연장전 시작 연속성, 단조, 상한, 램프 0)

## 인계 메모 (2026-10-08, 최신)
- **브랜치**: `m5-01-qa` (`origin/m5-01-overtime` d60f6af 위, `origin/main` 병합 — 이미 최신이라 변경 없음). push 완료.
- **끝난 것**: 검증 5단계 통과(1042/0), 수용 기준 AC1~AC10 통과, QA 테스트 10개 추가, 리포트 작성, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인(위 체크리스트 1~8). P3 B1·B2는 개발 선택(반려 아님). N1 스펙 문구는 planner.
- **다음에 할 첫 단계**: 메인 세션이 `m5-01-qa`(= m5-01-overtime + QA 커밋)를 main에 병합 → docs-writer 반영. Studio에서 문제가 나오면 이 리포트에 추가하고 P0/P1이면 `in-dev`로.
- **막힌 점**: 없음. Studio는 이 환경에서 못 돌림.
