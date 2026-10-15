# QA — m5-37 새 Survival 맵: 수산시장 (`fish-market`)

- 스펙: `docs/specs/m5-37-map-fish-market.md`
- 검증 커밋: `087acf5`(구현·아트·개발 테스트), 브랜치 `m5-map-fish`(worktree, `b2769b8` 위)
- 결과: **통과** (P0/P1/P2 없음, P3 2건) → 스펙 `qa-passed`

## 자동 검증 (2026-10-15, Windows, QA 테스트 추가 뒤 다시 돌림)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공 (끝 코드 0) |
| `stylua --check src tests tools` | 통과 (끝 코드 0) |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests` | **2029 passed, 0 failed** (개발 2020 + QA 9), 끝 코드 0 |
| `luau-lsp analyze … src` | 끝 코드 0 |

공용 파일: `git diff b2769b8 --stat` — 바뀐 파일은 `FishMarket*.luau` 4개, `tests/map-fish-market.spec.luau`, `docs/renders/fish-market/`, 개발 기록, 스펙뿐. `Config`·`Remotes`·`Types`·`Attributes`·`maps/init`·`MapTypes`·`SfxCues`·`SfxLibrary`·`MapFxPresets`·`default.project.json`·init 스크립트 변경 없음.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-fish-market` AC1 3개(validate·Survival·이름/규칙·`lighting = Art.LIGHTING`·풀 진입, 상자 36개 10 × 6 × 10·물길 5·전체 85, 스폰 24개 가운데 4 × 4 위·서로 3 이상·상자당 1~2개). QA `crateAt` 전수 검사 |
| AC2 | 통과 | `map-fish-market` AC2(빌드 직후 Ice 태그 0, 충돌 파츠는 `MarketCrate`뿐) + QA "태그"(75초 돌린 **런타임**에도 Ice 태그 0, 태그 이름 `MarketCrate`·`MarketIceBlock`·`MarketFish`가 다른 맵 소스에 없음). `IceController`는 태그만 봄(`IceController.luau:88`) — 얼음 블록 안쪽 `Ice` 재질 파츠는 충돌 없어서 밟을 수 없음 |
| AC3 | 통과 | `map-fish-market` AC3 3개(`timeLimit` 75, `iceCount` 경계, `icePosition` 0/4/8/9.99/10/11/18초·60초부터 100/15초, 시드 40개 × 75초 시뮬레이션에서 같은 줄 2개 없음) + QA "시간 종료" |
| AC4 | 통과 | `map-fish-market` AC4 (블록 ±5 안·발 < 7, 높이 7 > 점프 6.4, 넉백·면제·쿨다운 상수) |
| AC5 | 통과 | `map-fish-market` AC5 3개 (`fishWave` 표, 이웃 쌍 60개, `pickFishTarget` 1,000번 — 이웃·누운 생선 회피·최다 쌍 53~67%) |
| AC6 | 통과 | `map-fish-market` AC6 2개 (철퍼덕 36 + 22 수직·멀어짐, 몸에서 6 안 18 + 12, 팔딱 4 안(위 포함) 16 + 16, 면제 1.5·1.2, 쿨다운) |
| AC7 | 통과 | `map-fish-market` AC7 (validate, Extended 예산, 장식 1298(목표 700~1300), 그림자 조명 1, 시야 상자 안 겹침, 얼음 조각 윗면 ≤ −2, 시장 바닥 −93 ≤ −50, 큰 반투명 판은 물 1장, `inPool` 없음) |
| AC8 | 통과 | 위 자동 검증 표(QA 직접 실행). `maps`·`movement-guard`·`ice-logic`·`m5-23-qa`·`m5-33-batch3`·`m5-33-qa` 모두 ok |
| AC9 | 통과 (문서 확인) | `docs/developer/m5-37-map-fish-market.md` — 반복 3회 × 18항목 표, 마지막 18개 "예", `after-stats.txt` void 최대 3%(intro-01), 시트 비교 표 7항목·분위기 한 줄, 휴대폰 성능 메모. before 6장·after 9장 + stats 커밋됨. QA가 after-overview·after-intro-01을 직접 봄(수조 격자·참치·차양 좌판·간판 판 보임). 간판 글씨는 SurfaceGui라 렌더에 없음 → Studio |
| AC10~AC15 | 사용자 확인 필요 | 아래 체크리스트 |

## 요청 확인 항목

### 결정 기록 D6~D14
- **D6 안전망 −40**: 맞음. 낙하는 `rel.Y < −6`이 먼저 걸리고 −40은 보조 + 배경 바닥 기준(−93·−60). 스펙 "낙하 < −6, 안전망 −40, 배경 ≤ −50"과 어긋남 없음.
- **D7 누운 생선 최대 2마리**: 스펙(누움 5초, 45초부터 4.5초마다 2마리, 최대 2마리)이 그대로는 함께 성립하지 않아서 "오래된 것부터 바로 가라앉힘"을 고른 것은 타당. 결과적으로 45초 뒤 생선은 약 4~4.5초 누워 있다가 가라앉음(팔딱 2.5초는 그 전에 일어남). 과녁은 누운 + 떨어지는 중인 상자를 모두 피함(`FishMarket.luau:540~553`).
- **D8 참치 꼬리·지느러미만 Sway**: `anim`이 파츠마다 제자리 회전이라 타당. 범위 밖 컨트롤러를 만들지 않은 것도 맞음.
- **D9 맞음은 Move 동안만, 대기 블록은 가장자리 물(x ±60)**: Pause·Wait 블록은 x ±50(맞음 범위 45~55)에 있어서 격자(가장자리 42.5) 위 사람과 닿을 일이 없음 → 게임 차이 없음. 경고 동안 격자를 가로지르지 않음은 개발 연기 시험이 고정.
- **D10 옆 줄 옮기기**: 격자 밖 x ±50에서 0.5초 뒤 1초 동안. 같은 줄 금지는 `claimedRows`(현재 줄 + 정해진 다음 줄)로 지켜지고 시뮬레이션 40시드가 확인.
- **D11 생선 낙하 모습·CanCollide 0.2초 지연**: 스펙 범위 안. 지연은 끼임을 줄이는 쪽(아래 P3-2 참고).
- **D12 넉백 범위 해석**: 철퍼덕 수평만, 팔딱 3D — 스펙 "(위 포함)"과 맞음. 얼음·생선 쿨다운을 따로 둔 것은 스펙(0.8 / 0.6)대로.
- **D13 간판 SurfaceGui**: 글씨판(108 × 0.2 × 24)을 X축 90° 돌려 Top 면이 +Z(출발 쪽)를 보게 하고 `Face = Top`. 계산상 글씨가 똑바로 서지만 렌더러에 안 나와서 **Studio 확인**(체크리스트 1).
- **D14 소개 카메라 ①**: **규칙 지킴**. QA 테스트가 `MapLightingController.measure`와 같은 방식으로(단 IntroCamera 점은 **빼고**) 판정 파츠 상자를 재서 5점 모두 `MapLightingLogic.pickArena`로 상자 + 40 안임을 확인. 판정 상자 윗면은 대기 얼음 블록 서리판(약 y 6.95)이라 한계 약 46.95, ①·④의 y 46은 그 안(여유 약 0.95). 경로(경유점 사이 `IntroCameraLogic.sample` 2,001점)는 판정 파츠(상자·대기 얼음·스폰)와 불투명 장식 상자를 하나도 지나지 않음. 스펙 원안(항구 쪽 높은 자리)에서 "출발 쪽 위에서 참치·항구 방향"으로 바꾼 것은 규칙을 지키려는 타당한 변경(디자인 위임 범위).

### 넉백 (LinearVelocity 0.12초 + PlatformStand 0.8초 + MoveExempt)
- **LinearVelocity가 남지 않음**: `task.delay(0.12)`로 지우고 `ctx.cleanup`에도 넣음. QA가 실제 소스를 0.02초 간격 70초 돌려 모든 `FishMarketLaunch`가 0.12초(+한 틱) 안에 사라짐을 확인, 끝난 뒤 0개.
- **연속으로 맞아도 타이머가 안 꼬임**: `standUntil[humanoid] == untilAt`일 때만 풂(`FishMarket.luau:476`). QA 테스트가 얼음·생선 넉백이 겹치는 상황(자석 레이서)을 만들어 매 틱 "PlatformStand = 마지막 넉백 + 0.8초 안"을 확인. 이 조건을 지우는 돌연변이를 잡음.
- **탈락**: `EliminationService`가 Anchored + PlatformStand로 고정 → 맵 타이머(`not root.Anchored`)와 라운드 종료 함수 둘 다 손대지 않음, 나중에 `toLobby`가 풂. QA 테스트로 확인(두 조건 각각 지우는 돌연변이를 잡음).
- **라운드 종료**: `ctx.cleanup`의 함수가 남은 넘어진 사람을 일으킴(`FishMarket.luau:486~495`) + 통과자는 `RoundService`가 `toLobby → resetMovement`로 다시 풂. QA 테스트로 확인.
- **퇴장·리스폰**: 타이머는 옛 Humanoid만 건드려서 새 캐릭터는 그대로, 에러 없음(QA 테스트).
- **MoveExempt**: 얼음 1.2·생선 1.5, `MoveExempt.mark`가 더 늦은 값을 유지해서 겹쳐도 줄지 않음.

### 서버 판정 · 여러 방
- 생선 철퍼덕·팔딱 넉백, 얼음 맞음, 물 탈락(`rel.Y < −6`, `origin:PointToObjectSpace`)은 모두 `start`의 서버 Heartbeat에서 `ctx.getRacers()`만 보고 `ctx.eliminate`만 부름. 클라이언트 입력·리모트 없음. QA 테스트: 37° 돌린 아레나 origin에서 −5.9 무사 / −6.1 탈락, 물길 위 공중은 무사, 끝난 라운드는 판정 없음.
- 모듈 수준 가변 상태 없음(맨 위 `local`은 require·상수·모듈 표뿐 — QA 테스트로 고정). 상태는 모두 `start` 지역 변수.
- 상자·얼음 블록 모두 `ctx.model:IsAncestorOf`로 거름. QA 테스트가 **같은 맵 두 방**(하나는 90° 회전)을 한 가짜 CollectionService로 동시에 60초 돌려, 얼음·위험물·소리가 모두 자기 방 안이고 상자가 그대로이며 한 방이 끝나도 다른 방이 계속 도는 것을 확인. 상자 필터를 지우는 돌연변이(소리가 남의 방 상자에서 남)·얼음 필터 돌연변이를 모두 잡음.
- `Ice` 태그 충돌 없음(위 AC2).

### `Layout.crateAt` 다시 확인
- 칸 계산 `axisIndex`(반올림 index + 중심에서 5 안)가 맞음. QA 테스트가 x −60~60 · z −112~12를 0.25 간격(약 24만 점)으로 훑어 "어떤 상자 윗면 정사각형(±5, 경계 포함) 안"과 **한 점도 다르지 않음**을 확인. 경계 ±5는 상자, ±5.01·물길 가운데는 nil, Row 0 = +Z. `>`를 `>=`로 바꾸거나 row 축을 뒤집는 돌연변이를 잡음.

### Survival 시간 종료
- `Maps.timeLimit` = 75 → `RoundLogic.schedule("Survival")` = `{ hardCapAt = 75 }`(연장전 없음), 74.9초 Wait / 75초 Expire → `RoundLogic.timeout`이 남은 사람 전원 `Passed`(8명 중 2명 탈락 → 6명 통과). 목표 인원만 남으면 그 자리에서 끝(5명 목표 3, 2명 탈락 → 3명 통과). 서버 경로: `RoundService.luau:546~585`(시간 루프 → `RoundLogic.timeout` → 통과자 `toLobby`).

### 장식·판정 파츠·렌더
- 장식 1298/1500, 조명 8/24(그림자 1), 파티클 14/16, anim 45/80 — Extended 안. 판정 파츠(상자·얼음·스폰)의 크기·위치·충돌은 Layout/Logic 값 그대로(개발 AC1·AC2 테스트 + QA 다중 방 테스트에서 상자 CFrame 불변). 장식은 `MapKit.buildDecor`(충돌 없음)만.

## 버그
P0/P1/P2 없음.

### [P3-1] 한 틱에 생선 넉백과 얼음 넉백이 같이 걸리면 LinearVelocity 2개가 0.12초 동안 겹침
- 재현: 얼음 블록이 지나가는 줄에 생선이 철퍼덕(또는 팔딱)하는 순간, 그 자리에 선 레이서. 생선 쿨다운(`fishReady`)과 얼음 쿨다운(`iceReady`)이 따로라 같은 Heartbeat에서 `knock`이 두 번 불림.
- 기대: 한 번에 하나의 밀기(나중 것이 앞 것을 바꾸거나, 두 속도를 합친 하나).
- 실제: `MaxForce = inf`인 `LinearVelocity` 2개가 같은 Attachment에 동시에 걸려 방향이 물리 엔진에 맡겨짐(0.12초 뒤 둘 다 지워져서 남지는 않음, PlatformStand·면제는 정상).
- 영향: 아주 드물고 짧음. 어차피 크게 날아가는 상황이라 플레이 차이는 거의 없음.
- 제안(개발, 반려 아님): `knock`에서 루트에 이미 `FishMarketLaunch`가 있으면 지우고 새로 걸기.
- 위치: `src/shared/maps/FishMarket.luau:457~469`, `:616~627`, `:819~835`

### [P3-2] 같은 웨이브의 다른 생선(또는 팔딱)에 막 맞은 사람은 쿨다운으로 두 번째 생선 철퍼덕을 건너뛰어, 0.2초 뒤 충돌이 켜지는 생선 몸과 겹칠 수 있음
- 재현: 45초 이후(2마리 동시) 두 과녁 쌍이 이웃해 있고, 레이서가 A 생선 약한 넉백 범위이면서 B 과녁 상자 위. A 넉백이 먼저 걸리고 B 넉백은 `FISH_COOLDOWN 0.6`으로 건너뜀 → 0.2초 뒤 B `Hitbox.CanCollide = true`.
- 기대: 생선 몸이 단단해질 때 그 안에 사람이 없다.
- 실제: A 넉백(18/s 정도)으로 0.2초에 약 3.6만 움직여 B 몸(폭 6) 안에 남을 수 있음 → Roblox 물리가 밀어냄(보통 위로). 판정 문제는 아니고 모양이 어색할 수 있음.
- 제안(개발, 반려 아님): 철퍼덕만은 쿨다운을 무시하거나, `CanCollide`를 켤 때 몸 안에 있는 레이서를 한 번 더 밀기. Studio 재미 확인(AC15) 때 같이 봐도 됨.
- 위치: `src/shared/maps/FishMarket.luau:616~618`, `:786~789`

### 참고 (버그 아님)
- 생선 일정은 "다음 낙하 시각"의 웨이브 값을 쓰므로 실제 낙하는 8·16·24·32(이후 6초)·38·44·50(2마리)…로, 6초 간격이 30초가 아니라 32초부터 시작. 스펙 AC5는 `fishWave(t)` 값만 정하고 표도 "구간마다 간격"이라 어긋남으로 보지 않음.
- D14 ①·④는 판정 상자 + 40 한계(약 46.95)보다 0.95 아래. 대기 얼음 블록 높이(`ICE_PARK_Y`)를 낮추면 밖으로 나갈 수 있음 — QA 테스트가 그때 잡음. 조명 컨트롤러는 IntroCamera 점도 상자에 넣어서 조명 자체는 문제없음.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가·변경하지 않음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 맵 `start`의 서버 Heartbeat에서 `ctx.eliminate`만, 시간 종료 통과는 `RoundLogic`
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `start` 지역 변수, `ctx.model` 하위 태그만(QA 두 방 테스트)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 1개, `Hazards` 폴더, LinearVelocity·delay·만든 Attachment, PlatformStand 되돌리기 함수 모두 `ctx.cleanup`

## 사용자 Studio 확인 체크리스트 (AC10~AC15)
준비: `src/shared/Config.luau`에서 `DEBUG.forceMapPlan = { "rotating-belt", "fish-market", "skewer-showdown" }`. 4명 이상이면 Studio "Test → Clients and Servers"(4명), 혼자면 `minPlayersToStart = 1` 그대로 Play.
1. **소개·조명(AC14)**: 2라운드 소개에서 출발 쪽 위 넓은 샷(수조 격자·뒤 참치 크레인) → 가장자리 물에 반쯤 잠긴 얼음 블록 → 참치 올려다보기 → 격자 위 → 출발 자리. 첫 컷부터 아침 조명(차가운 하늘·물안개 + 따뜻한 백열등)인지, 라운드 뒤 로비 조명으로 돌아오는지. 뒤 간판에 빨간 **"수산시장"** 글씨가 똑바로(뒤집히거나 거울 글씨가 아니게) 보이는지(D13).
2. **물길(AC10)**: 상자 사이를 점프로 건널 수 있는지. 걸어서 물길로 들어가면 바로 물에 빠져 탈락 연출(손님 입)이 나오는지. 상자 위·얼음 블록 옆에서 **미끄러지지 않는지**(디저트 냉장고 얼음처럼 미끄러지면 버그).
3. **얼음 블록(AC11)**: 5초쯤 줄 끝 상자에 파란 화살표가 깜빡이고 블록이 그 줄 끝으로 떠오른 뒤 출발하는지. 그 줄에 서 있으면 진행 방향으로 밀려나고(넘어져 0.8초 누움), 점프로는 넘을 수 없는지. 끝에서 2초 멈춘 뒤 가끔 옆 줄(파란 화살표 줄)로 옮기는지. 옆 줄로 건너면 피할 수 있는지. 25초에 3개, 45초에 4개.
4. **생선(AC12)**: 8초부터 높이 30에 노란 ⚠ 표지 + 상자 두 개에 걸친 그림자가 커지고 2초 뒤 생선이 철퍼덕. 그 두 상자 위에 있으면 옆으로 크게, 옆 상자에 있으면 작게 밀리는지. 생선이 누워 있는 동안 위에 올라설 수 있는지, 2.5초에 팔딱(가까우면 밀림), 그 뒤 물로 기울며 가라앉는지. **상자는 하나도 없어지지 않는지**. 생선 몸에 끼어 이상하게 튀는 일이 있는지(P3-2) 봐 두기.
5. **후반·끝(AC13)**: 45초부터 생선 2마리씩, 60초부터 더 잦고 얼음이 빨라지는지. 75초에 버틴 사람 전원 통과(혼자면 75초 뒤 통과 → 결승). 여럿이면 목표 인원만 남는 순간 바로 끝나는지.
6. **이동 감시·휴대폰(AC14)**: Output에 넉백 때문에 `[MovementGuard]` 경고가 안 찍히는지. 휴대폰 에뮬레이터(Device: 작은 폰)에서 ⚠·그림자·물길·얼음 블록이 보이는지. Output에 빨간 에러가 없는지.
7. **재미(AC15, 4~8명)**: "옆 줄로 뛰어 피하기"가 재밌는지, 물길 5가 너무 어렵거나 쉬운지(4~6 사이 조정), 생선 간격이 적당한지 — 의견은 `docs/USER-TODO.md` 답변 기록에.
8. **끝나면 `forceMapPlan = nil`로 되돌린다**(커밋 값 고정 테스트가 있음).

## 추가한 테스트
- `tests/m5-37-qa.spec.luau` (9개) — 실제 `FishMarket.luau` 소스를 가짜 Heartbeat·시계·task로 돌림(여러 방 지원 가짜 CollectionService).
  1. `crateAt` 0.25 간격 전수 비교 + 경계값
  2. 물 탈락선(37° 돌린 origin): −5.9 무사 / −6.1 탈락, 물길 위 공중 무사, 끝난 라운드 판정 없음
  3. 넉백 수명 70초(0.02초 틱): LinearVelocity 0.12초 안 소멸, PlatformStand = 마지막 넉백 + 0.8초, 겹친 넉백 발생 확인
  4. 탈락 고정(Anchored)·퇴장·리스폰 중 타이머 안전, 라운드 종료 cleanup이 넘어진 사람을 일으킴
  5. 같은 맵 두 방 동시 실행: 얼음·위험물·소리가 자기 방 안, 상자 불변, 한 방이 끝나도 다른 방 계속
  6. 모듈 수준 가변 상태 없음, 맵 표가 런타임에 안 바뀜
  7. 런타임 Ice 태그 없음, 태그 이름 다른 맵과 안 겹침
  8. Survival 75초 일정·시간 종료 전원 통과·목표 인원 즉시 종료
  9. D14: 소개 경유점이 판정 상자 + 40 안(IntroCamera 점 제외), 경로가 판정 파츠·장식을 안 뚫음
- 돌연변이 확인(저장소 복사본, 원본 `src/` 안 고침): 타이머 조건 제거·LinearVelocity 안 지움·얼음/상자 `ctx.model` 필터 제거·물 판정을 월드 좌표로·cleanup 되돌리기 제거·Anchored 조건 제거(2곳)·`crateAt` 경계/축 뒤집기 — **10개 모두 QA 테스트가 잡음**.

## 인계 메모 (2026-10-15, qa)
- **브랜치**: `m5-map-fish` (worktree `.claude/worktrees/agent-acb85e11c6fb396b8`). QA 커밋 1개, `origin/m5-map-fish`에 push.
- **끝난 것**: AC1~AC9 확인(검증 5단계 직접 실행), D6~D14 확인, 넉백·여러 방·crateAt·시간 종료·소개 카메라 테스트 9개 추가, 리포트, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio AC10~AC15(위 체크리스트), 소리 id 3개(`MarketFishWarn`·`MarketFishSlam`·`IceBlockSlide`). P3-1·P3-2는 개발이 원하면 다음 손볼 때(반려 아님).
- **다음 첫 단계**: 메인 세션이 `m5-map-fish`를 `main`에 병합 → 병합 뒤 검증 5단계 다시(다른 배치 3 맵과 처음 만남, `Batch3` 풀 개수 테스트). 6개가 모두 들어가면 m5-33 QA P3-1(`#Maps.infos() == 21` 고정) 처리.
- **막힌 점**: 없음.
