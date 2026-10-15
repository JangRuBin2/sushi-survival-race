# QA — m5-36 새 Survival 맵: 초대형 밥솥 (`rice-cooker`)

- 스펙: `docs/specs/m5-36-map-rice-cooker.md`
- 검증 커밋: `76c9cb5`(구현) · `16f84b6`(렌더·문서), 브랜치 `m5-map-rice` (기준 `b2769b8` = m5-33 QA 통과)
- 결과: **통과** (P0/P1 없음, P2 1건, P3 2건) → 스펙 `qa-passed`. Studio AC11~AC17은 사용자 확인 필요.

## 자동 검증 (2026-10-15, Windows, QA 테스트 추가 뒤 다시 돌림)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공 (끝 코드 0) |
| `stylua --check src tests tools` | 통과 (끝 코드 0) |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **2028 passed, 0 failed** (개발 2022 + QA 6), 끝 코드 0. `maps` 13·`movement-guard` 33·`m5-23-qa` 22·`m5-33-batch3` 7·`m5-33-qa` 5·`map-rice-cooker` 18 모두 통과 |
| `luau-lsp analyze … --flag:LuauSolverV2=true src` | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-rice-cooker` AC1 2개 (validate Survival, 풀에 있음, 스폰 24개 반지름 12~28·서로 3 이상·판정 바닥 위, `lighting = Art.LIGHTING`) |
| AC2 | 통과 | `map-rice-cooker` AC2 3개 (단 표·높이 차 1, 조각 꼭짓점 ≤ 40, 반지름 40 밖 충돌 0 — 솥·림·주걱·밸브·타이머 `CanCollide = false`). 코드: `RiceCooker.luau:52-57` `ghost`, 밸브 `:101,117,131`, 타이머 `:155` |
| AC3 | 통과 | `map-rice-cooker` AC3 3개 + QA "timeLimit 75" (RoundLogic 일정이 74.9 Wait / 75 Expire, Survival이라 연장전 없음, 시간 종료 = 남은 사람 전원 Passed, `Config.TimeLimit.Survival` 60 그대로) |
| AC4 | 통과 | `map-rice-cooker` AC4 + QA "끓어오름" (실제 `start()`에서 원 중심 → 위 45 + 바깥 22, 수평 5는 바깥 방향, 6.5는 안 맞음) |
| AC5 | 통과 | `map-rice-cooker` AC5 3개 + QA "증기" (12초 띠 1개·한쪽 밸브, |dz| 4.9 맞음 / 5.1 안 맞음, 다른 띠 안 맞음) |
| AC6 | 통과 | `map-rice-cooker` AC6 + QA "증기"(발 윗면 + 7.9 맞음 / 8.1 안 맞음, MoveExempt 1.2) · "끓어오름"(+4.9 맞음 / +5.1 안 맞음, MoveExempt 1.5, PlatformStand 0.8초 뒤 풀림) |
| AC7 | 통과 | `map-rice-cooker` AC7 + QA "타이머"(start가 실제로 01:15 → 01:12 → 01:05로 씀) |
| AC8 | 통과 | `map-rice-cooker` AC8 4개 (validate·Extended 예산, 밟는 면 시야 상자, 배경 ≤ −30, `inPool` 없음, IntroCamera 5점) |
| AC9 | 통과 | 위 자동 검증 표 (QA가 직접 실행) |
| AC10 | 통과 | `docs/developer/m5-36-map-rice-cooker.md` 반복 4회·체크리스트 18개, `docs/renders/rice-cooker/before-*`(6장)·`after-*`(9장)·stats 2개 커밋됨. after: decor 1393/1500, lights 8/24(그림자 1/2), particles 10/16, anim 35/80, void 0%(overview 3%). 시트 비교 표·휴대폰 메모(Rate 합 약 22/s)는 스펙 개발 메모에. 단 그림자 Spot이 언덕에 닿지 않음 → P3 B2 |
| AC11 | 사용자 확인 필요 | 체크리스트 1. 코드 분석으로는 위험 낮음(아래 "AC11 분석") |
| AC12~AC17 | 사용자 확인 필요 | 체크리스트 2~7 |

### AC11 분석 — 높이 1 단을 걸어서 오를 수 있나 (위험 낮음, 버그 아님)
- 단 높이: `RiceCookerLayout.luau:48-54` 윗면 4/3/2/1/0, 이웃 차 정확히 1(`map-rice-cooker` AC2). 조각은 Y축 회전만 한 Block이라 윗면이 평평하고 단 경계는 수직 1 studs 턱(`Layout.segments`, 윗단 조각이 아랫단 밑으로 1.5 묻혀 틈 없음).
- Humanoid에는 `StepHeight` 속성이 없고, `MaxSlopeAngle`(기본 89°)은 경사면에만 쓰여 수직 턱과는 관계없다. R15 Humanoid는 HumanoidRootPart를 바닥에서 `HipHeight`(기본 아바타 약 2) 위에 띄우고 다리는 충돌로 막지 않으므로, `HipHeight`보다 낮은 턱은 몸통 충돌에 걸리지 않고 바닥 감지로 올라선다. 높이 1 계단은 Roblox에서 흔히 걷는 계단 높이다.
- 이 게임은 `HipHeight`를 바꾸지 않는다(`src`에서 읽기만, `AppearanceService.luau:82`), 초밥 몸은 충돌 없는 장식(`SushiBody`). 그래서 AC11은 기본 R15 걸음 그대로이고, 위험은 낮다고 봐서 P2 이상으로 올리지 않았다. 다만 아바타 크기(키 작은 아바타는 `HipHeight` 약 1.3)에 따라 달라질 수 있어 Studio에서 확인해야 한다(체크리스트 1). 걸리면 스펙대로 단 사이 쐐기 띠를 넣는다(판정 모양만).

### 결정 기록 확인 (D6~D12)
- **D6 판정 바닥 = Block 조각 내접 다각형**: 맞음. 스펙이 "Cylinder 또는 조각 묶음"을 허용했고, 스폰 아래 바닥 검사(m5-33 AC5)·반지름 40 밖 충돌 0(AC2)을 테스트로 지킨다. 단 경계 오차 ≤ 0.15는 판정(`Layout.surfaceAtXZ`, 원 기준)과 실제 조각의 차이인데, 높이 판정 여유(−2 ~ +5/+8) 안이라 영향 없음.
- **D7 햇살 = Lighting 해 + 창 근처 햇살 줄기 장식, 그림자 SpotLight는 언덕 위 걸린 등**: **승인**(QA, 사용자 위임). 가이드 6절 "보이는 광원"은 국소 광원(Point·Spot·Surface)이 보이는 원인 파츠에 붙어야 한다는 규칙이고, 해는 Lighting이라 해당 없음. 창(언덕에서 190)에서 Spot을 쏘면 range 상한 60 때문에 언덕에 못 닿고, 창과 언덕 사이 허공에 등을 두면 "원인 없는 빛"이 된다. 걸린 등에 붙인 좁은 Spot(70°, 그림자 1개)은 가이드의 "히어로를 비추는 좁은 SpotLight + Shadows, 그림자 ≤ 2"와 맞고, 온도 대비(따뜻한 등·해 ↔ 차가운 창 하늘빛·은색 림)도 지킨다. 단, 지금 등 높이로는 빛이 언덕에 닿지 않는다 → P3 B2(고치면 의도대로).
- **D8 Sand 재질 + 물성 Plastic, 밥알 10~15% 크게**: 맞음. `RiceCooker.luau:74-77` 물성을 Plastic으로 고정해 마찰·탄성이 다른 맵 바닥과 같다. 밥알은 장식이고 단 옆면·윗면 + 1 아래에만(AC8 시야 상자 테스트).
- **D9 경고 원 높이**: 맞음. 테두리 18조각은 조각마다 그 자리 윗면 + 0.06이라 계단을 따라가 휴대폰에서도 끊기지 않는다. 안쪽 원판이 윗단에 묻히거나 아랫단 위로 최대 1 뜰 수 있는 건 표시뿐이고 판정과 무관(판정은 `Logic.burstKnockback` 수평 거리 + 단 윗면 기준).
- **D10 증기 시각 = 경고 시작 시각**: 맞음. 스펙 "경고 2초 → 분사 1.2초"와 일정 표(12, 24, 36 …)를 경고 시작으로 읽은 것이고, 마지막 72초 경고 → 74~75초 분사(75초에 cleanup)로 일정이 시간 안에 있다(QA "timeLimit 75"에서 `steamTimes` 마지막 72 확인). "분사마다 한 번"은 QA "증기"가 1.2초 동안 같은 자리에 있어도 MoveExempt가 한 번만 찍히는 것으로 확인.
- **D11 곳 고르기 세부**: 맞음. 스펙 "레이서 발밑 ± 2 / 반지름 36 안 / 12 이상"을 지키는 구현 선택이고 테스트(AC3 1,000번)로 확인.
- **D12 높이 기준(발 = 루트 − 3, 윗면 − 2 아래면 안 맞음)**: 맞음. 스펙 "발 < 윗면 + 5/8"에 떨어지는 사람 제외를 더한 것. 루트 − 3은 R15 기본(HipHeight 2 + 루트 반높이 1)과 같다.
- GDD: §5.3 표(223줄)·v0.7 길이(229줄, Survival `timeLimit` 75)와 일치.

## 버그
### [P2] B1 첫 끓어오름 대기에서 조금이라도 일찍 깨면 그 판 끓어오름이 하나도 안 나온다
- 위치: `src/shared/maps/RiceCooker.luau:521-527`
  ```lua
  waitUntil(Logic.BURST_SCHEDULE[1].from)   -- task.wait(5 - elapsed())
  while ctx.isActive() do
      local wave = Logic.burstWave(elapsed())  -- elapsed()는 os.clock() 기준
      if wave == nil then
          break                                -- 4.9999…면 nil → 루프 끝, 이 판 끓어오름 0
  ```
- 재현(QA 가짜 환경에서 실제로 봄): 가짜 시계를 1/30초씩 쌓아 `task.wait(5)`가 `os.clock()` 기준 4.99999…초에 깨게 하면 `burstWave`가 nil이라 루프가 끝나고 75초 동안 경고·넉백이 한 번도 없었다. (1/32초 틱으로 시각을 정확히 맞춘 지금 테스트에서는 재현되지 않음.)
- 기대: 첫 차례를 놓쳐도 끓어오름이 계속 나온다.
- 실제: `task.wait`는 엔진 스케줄러 시계로 기다리고 `elapsed()`는 `start()` 안에서 잰 `os.clock()`이다. 두 시계가 조금만 어긋나도(예: 스케줄러가 `start()`를 부른 프레임의 시작 시각으로 기한을 잡음) 깬 순간 `elapsed()`가 5보다 아주 조금 작을 수 있고, 그러면 그 판의 주요 장애물 하나가 통째로 사라진다. 일어날 확률은 낮지만 생기면 소리 없이 끓어오름이 없는 판이 된다.
- 제안: `Logic.burstWave(math.max(elapsed(), Logic.BURST_SCHEDULE[1].from))`처럼 시작 뒤에는 nil이 나오지 않게 하거나, nil이면 `break` 대신 짧게 기다렸다 다시 본다. (증기는 미리 계산한 `steamTimes` 목록을 돌아 이 문제 없음.) 고친 뒤 QA 하네스(`tests/m5-36-qa.spec.luau`)에서 `STEP`을 1/30으로 바꿔 끓어오름이 나오는지 보면 회귀를 잡을 수 있다.

### [P3] B2 그림자 SpotLight가 밥 언덕까지 닿지 않는다 (D7 의도가 화면에 안 나옴)
- 위치: `src/shared/maps/RiceCookerArt.luau:819`(등 `y = 66`), `:845-854`(Spot `range = 60`, `face = "Bottom"`)
- 내용: 전구 중심 y = 66 − 0.6 = 65.4, 언덕 꼭대기 윗면 y 4 → 거리 61.4로 range 60보다 멀다(가장자리 단 y 0이면 65 이상). SpotLight 밝기는 range에서 0이 되므로 이 등은 밥 언덕을 전혀 비추지 못하고, D7·스펙의 "단 그림자가 계단을 읽히게"가 이뤄지지 않는다. 판정과 무관, 예산(그림자 1/2)만 쓰고 효과 없음.
- 제안: 등을 낮춘다(전구 y ≈ 40~45 — 꼭대기에서 36~41, 빛이 절반 이상 남음). 소개 카메라 경로·밟는 면 시야 상자(윗면 + 16)와 안 겹치는지 테스트로 다시 확인.

### [P3] B3 ColorCorrection Contrast 0.18이 가이드 범위(0.05~0.15)보다 조금 높다
- 위치: `src/shared/maps/RiceCookerArt.luau:128`
- 내용: 렌더 반복 4에서 크림빛이 하얗게 뜨던 것을 잡으려고 올린 값(개발 기록). 가이드 6절 "색 보정은 살짝: Contrast 0.05~0.15". 근사 렌더러 기준으로 맞춘 값이라 Studio(Future 조명)에서 단 경계가 너무 어둡게 끊기는지 보고 0.15로 내릴지 정한다(체크리스트 6). 반려 사유 아님.

## 판정 · 동작 방식 확인
- **넉백에 MoveExempt**: 끓어오름·증기 모두 `knock`(`RiceCooker.luau:314-335`)이 `MoveExempt.mark(character, 1.5 / 1.2)`를 **launch 전에** 부른다. 연속 밀기는 없음. QA 테스트가 실제 `start()`에서 값 확인.
- **판정이 서버에만**: `start`는 RoundService(서버)가 부르는 공유 모듈. 클라이언트 리모트 없음, 새 RemoteEvent 없음. 맵은 `ctx.eliminate`만 부르고 통과는 RoundService(시간 종료·목표 인원).
- **ctx.model 하위 태그 파츠만**: 밸브는 `CollectionService:GetTagged("RiceSteamVent")` 중 `ctx.model:IsAncestorOf`만(`:255-264`), 타이머는 `ctx.model:FindFirstChild("CookerTimer")`, 경고·점선·김 파츠는 `start`가 `ctx.model` 아래에 만든다. `RiceFloor` 태그는 `start`가 쓰지 않음(장식·검사용). QA "증기"가 같은 시각 다른 방 모델의 밸브가 안 흔들리고 점선이 안 생기는 것을 확인.
- **타이머 SurfaceGui가 여러 방에서 섞이지 않음**: 글자는 `start` 지역 변수 `timerLabel`(그 방 모델 안 `Time`)에만 쓰고 시작 시각도 `start` 지역(`startedAt`). QA "타이머"가 3초 차이로 시작한 두 방이 각각 01:05 / 01:08을 보이는 것을 확인.
- **모듈 수준 상태 없음**: 최상위 local은 require·상수·`math.rad`·`Layout` 상수뿐(QA 소스 검사), 쿨다운 `lastBurstHit`·바로 전 띠 `last`·밸브 표는 `start` 지역. QA "두 방 동시"가 같은 시각 두 방의 끓어오름이 각자 레이서를 각자 origin 기준으로 한 번씩 치는 것을 확인.
- **끝난 라운드에서는 판정하지 않음**: 낙하 Heartbeat·끓어오름 루프·증기 루프·분사 루프·경고 깜빡임 모두 `ctx.isActive()`를 본다. QA "timeLimit 75"가 75초에 끝낸 뒤 10초 동안 떨어진 사람 탈락 0, 넉백 0, 새 소리 0, 새 경고 0을 확인. 끝날 때 남은 경고 파츠는 모두 `ctx.cleanup`에 들어 있어 RoundService가 지운다(QA 확인).
- **정리(Cleanup)**: Heartbeat 연결, `task.spawn`/`task.delay` 스레드, 경고·점선·김·퍼프 파츠, LinearVelocity, 새로 만든 Attachment 모두 `ctx.cleanup`. 넉백 중 라운드가 끝나 PlatformStand 복구 delay가 취소돼도 통과자는 `CharacterUtil.toLobby` → `resetMovement`가 풀고, 탈락자는 EliminationService가 맡는다(다른 맵과 같은 방식).
- **판정 파츠를 아트 때문에 바꾸지 않음**: 판정 조각 크기·위치는 `RiceCookerLayout`(단 표·조각 수·OVERLAP)에서만 나오고 `RiceCookerArt`는 색(`riceColor`)만 준다. 밥알 장식은 단 옆면·윗면 아래(`map-rice-cooker` AC8). 판정 파츠·경고 파츠에 `anim` 없음.
- **공용 파일**: `git diff b2769b8 --stat` → `src/shared/maps/RiceCooker*.luau` 4개, `tests/map-rice-cooker.spec.luau`, `docs/developer/…`, `docs/renders/rice-cooker/…`, 스펙뿐. 공용 파일·다른 맵·공용 테스트 변경 없음. QA는 `tests/m5-36-qa.spec.luau`(새 파일)·이 리포트·스펙만 추가/수정.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 맵은 리모트를 쓰지 않음(해당 없음)
- [x] 통과·탈락·순위 판정이 서버에만 있다
- [x] 맵 상태가 모듈이 아니라 `ctx`/`start` 지역에 있다 (QA 테스트)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`에서 `DEBUG.forceMapPlan = { "rotating-belt", "rice-cooker", "skewer-showdown" }` → Play(혼자 가능). **확인이 끝나면 `nil`로 되돌린다.** 2라운드가 밥솥이다.
1. (AC11) 밥 언덕 꼭대기 ↔ 가장자리를 **점프 없이** 걸어서 오르내린다(단 높이 1). 걸려서 멈추면 결정 기록에 적어 주세요(단 사이 쐐기 띠 수정). 가능하면 작은 아바타로도 한 번.
2. (AC12) 5초쯤 발밑에 주황 테두리 원 + 김이 1.5초 깜빡인 뒤 펑(밥알 튐) 하고 위로 튕긴다. 원 밖으로 비키면 안 맞는다. 바깥 4·5단에서 맞으면 밖으로 떨어져 탈락(손님 입). **판 내내 원이 한 번도 안 뜨면 B1** — Output을 확인하고 알려 주세요.
3. (AC13) 12초에 +X 또는 −X 밸브가 덜컹 흔들리며 휘파람, 한 띠 양쪽에 주황·흰 점선이 2초 깜빡인 뒤 짙은 김이 뿜어져 그 띠에 선 사람만 옆으로 날아간다. 점프로는 못 피한다. 36초부터 두 띠가 양쪽 밸브에서 동시에, 한 띠는 늘 비어 있다.
4. (AC14) 솥 앞 흰 패널 빨간 숫자가 01:15부터 1초씩 줄고 00:00에 라운드가 끝나 버틴 사람 전원 통과. (여러 명이면) 목표 인원만 남으면 그 자리에서 끝난다.
5. (AC15) 은색 테두리·주걱·뚜껑·밸브 위에 올라서거나 매달릴 수 없다(통과해 떨어짐). Output에 이동 감시 경고(MovementGuard)가 터짐·증기 때문에 찍히지 않는다.
6. (AC16) 휴대폰 에뮬레이터(작은 화면)에서 주황 원·점선이 흰 밥 위에서 잘 보이고 김이 화면을 가리지 않는다. 조명이 아침 주방(크림빛 안개·햇살)으로 바뀌고 로비로 돌아오면 원래대로. 함께 볼 것: 해 그림자가 **창이 있는 오른쪽(+X)** 에서 들어오는지(D7), 언덕 위 초록 등 아래 단 그림자가 보이는지(지금은 B2 때문에 안 보일 것), 단 경계가 너무 어둡게 끊기지 않는지(B3).
7. (AC17, 4~8명) 75초 안에 목표 인원 근처까지 줄어드는지, 60~75초가 지루하지 않은지. 너무 안 줄면 `RiceCookerLogic` `BURST_OUT` 22 → 26, `STEAM_PUSH` 34 → 38.
8. 소리: `RiceBubble`·`SteamWhistle`·`SteamBlast`는 무음(USER-TODO A2에서 id 고르기).

## 추가한 테스트
`tests/m5-36-qa.spec.luau` 6개 — 실제 `RiceCooker.luau` 소스를 가짜 시계(`os.clock`)·가짜 `task`(spawn·wait·delay, 1/32초 틱, 적어도 다음 틱에 깨움)·가짜 Heartbeat·가짜 CollectionService로 돌리고, 캐릭터는 Lune 인스턴스(루트·Humanoid·RootAttachment), `MoveExempt`·`MapSfx`는 기록용 가짜. 아레나 origin은 높이 300·2000 떨어짐·90° 회전.
1. 낙하선 −19.9 무사 / −20.1 탈락(회전 origin 로컬 기준), 끝난 라운드는 판정 없음
2. 끓어오름: 4.9초 경고 없음 → 5초 `RiceBurst` 경고(이 방 모델 안) → 경고 중 넉백 없음 → 터짐 뒤 원 중심·원 안(+4.9)만 맞음, 공중(+5.1)·원 밖(6.5) 안 맞음, 속도 위 45 + 바깥 22(중심은 rng 방향), MoveExempt 1.5, PlatformStand 0.8초 뒤 풀림, cue `RiceBubble` 1번, 경고 원 사라짐
3. 증기: 11.9초 없음 → 12초 `SteamWhistle`·점선(이 방만)·+X 밸브만 흔들림(다른 방 밸브 그대로) → 2초 경고 중 넉백 없음 → 분사 뒤 띠 안·발 + 7.9까지 맞음, +8.1·|dz| 5.1·다른 띠 안 맞음, **1.2초 동안 한 번만**, 속도 −X 34 + 위 10, MoveExempt 1.2, 밸브 제자리, 점선 사라짐
4. 타이머: 두 방이 각자 모델 글자를 각자 시작 시각으로(01:12/01:15 → 01:05/01:08)
5. timeLimit 75: RoundLogic 일정 74.9 Wait·75 Expire, 시간 종료 = 남은 6명 모두 Passed, `steamTimes` 마지막 72, 75초에 끝낸 뒤 10초 동안 탈락·넉백·소리·새 경고 0, 남은 경고는 `ctx.cleanup`에
6. 모듈 수준 가변 상태 없음(소스 검사) + 두 방 동시 끓어오름이 각자 레이서를 각자 origin으로 한 번씩

## 인계 메모 (2026-10-15, QA 끝)
- **브랜치**: `m5-map-rice` (worktree `.claude/worktrees/agent-ae20aaa05ea79fc0e`), QA 커밋은 이 브랜치에 push.
- **끝난 것**: 자동 검증 5단계(2028 passed, 0 failed), AC1~AC10 통과, D6~D12 확인(D7 승인 기록), QA 테스트 6개, 스펙 `qa-passed`.
- **남은 것**: B1(P2)·B2·B3(P3)는 반려 사유 아님 — 병합 전 또는 다음 맵 다듬기 때 개발이 고치면 좋음(특히 B1은 한 줄). 사용자 Studio AC11~AC17(위 체크리스트).
- **다음 첫 단계**: 메인 세션이 `m5-map-rice`를 main에 병합하고 병합 뒤 검증 5단계를 다시 돌린다(다른 배치 3 맵과 처음 만남). B1을 고치면 `tests/m5-36-qa.spec.luau`의 `STEP`을 1/30으로 바꿔 끓어오름이 나오는지 한 번 확인.
- **막힌 점**: 없음.

## 개발 수정 (2026-10-15, developer — 메인 세션 요청)
- **B1**: `RiceCooker.luau` 끓어오름 루프가 `Logic.burstWave(math.max(elapsed(), 5))`를 써서, `task.wait`가 os.clock보다 조금 일찍 깨도 첫 차례가 나와요. 증기는 미리 계산한 `steamTimes`의 시각(`at`)으로 띠를 골라 같은 문제 없음(확인). 회귀 테스트: `tests/m5-36-qa.spec.luau` 하네스에 `clockLag`(start 뒤 os.clock이 스케줄러보다 늦음)를 넣고 "B1 회귀" 1개 추가 — 고치기 전 코드로 돌리면 실패, 고친 뒤 통과.
- **B2**: 걸린 등을 y 66 → 42로 내림(전구 ~41.4, 꼭대기 윗면까지 약 37 < range 60). 판정 파츠 그대로, 시야 검사(윗면 + 16 위) 통과. after PNG·stats 갱신.
- **B3**: Contrast 0.18 → 0.15.
- 검증 5단계 통과: lune 2029 passed, 0 failed, selene 0/0, luau-lsp 끝 코드 0.
