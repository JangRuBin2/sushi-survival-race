status: in-dev
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-06 — 새 Race 맵: 디저트 냉장고 (`dessert-fridge`) + 얼음 이동

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.2 Race 맵(결승선에 목표 인원, 최대 90초), §5.3 "디저트 냉장고 (Race, 얼음 바닥 미끄러짐)", §6(조작 — 다이브·잡기와 함께 동작), §11.4, §11.6(이동 감시)
- 레퍼런스: [`docs/REFERENCE-m5-maps.md`](../REFERENCE-m5-maps.md) 1·2.3절
- 참고 코드: `SoySwampHazards.luau`(와사비 튕김 — 젤리 튕김에 같은 방식), `RamenRapids.luau`(서버 밀기 + `MoveExempt`), `input/DiveController.luau`·`GrabController.luau`(클라이언트 이동 입력), `MovementGuardLogic`(상한)
- 담당 개발 worktree: `m5-fridge` (Rojo 포트 34874)
- 공용 파일 수정 담당: 없음 (id·이름·규칙·등록·`IceController` 등록·`FanGust`/`JellyBoing` cue는 m5-03)
- 의존: **m5-03 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/maps/DessertFridge.luau`(껍데기 덮어쓰기, 끝나면 `inPool = false` 줄 삭제), 새 파일 `src/shared/maps/DessertFridgeLayout.luau`, `DessertFridgeLogic.luau`, `DessertFridgeArt.luau`, 새 파일 `src/shared/IceLogic.luau`, `src/client/input/IceController.luau`(껍데기 채우기), 테스트 `tests/map-dessert-fridge.spec.luau`, `tests/ice-logic.spec.luau`

## 목표
거대한 냉장고 안 디저트 칸을 달려 냉장고 문까지 탈출한다. **얼음 바닥에서는 쭉 미끄러져** 멈추기·꺾기가 어렵고, 젤리를 밟으면 위 칸으로 튕겨 오르고, 찬바람 송풍구가 얼음 위 초밥을 옆으로 밀어낸다. 회전 벨트(거슬러 달리기)·간장 늪(느려짐)·라멘 급류(앞으로 휩쓸림)와 다른 **관성** 손맛.

## 규칙 (수치는 전부 기본값, Layout·Logic·IceLogic 상수)
### 코스 (origin 앞 = 로컬 −Z, 약 260 studs)
| 구간 | z 범위 | 바닥 높이 | 내용 |
|---|---|---|---|
| A 출발 | 0 ~ −16 | 0 | 일반 바닥, 폭 24, `Spawns` 24개 |
| B 얼음 쟁반 | −16 ~ −96 | 0 | **얼음**(태그 `Ice`), 폭 22, 양옆 벽 없음. 얼음 큐브 장애물(4 × 4 × 4, 고정, 충돌 있음) 8개 지그재그. **구멍 2개**(6 × 6, z −40 x −5 / z −70 x +5) — 빠지면 낙하 |
| C 젤리 계단 | −96 ~ −136 | 0 → 12 | **젤리 발판 3개**(태그 `Jelly`, 8 × 8, 윗면 y 1) — 밟으면 위로 튕겨 위 칸(y 12)으로. 오른쪽에 느린 길 **쿠키 계단**(디딤 높이 3, 폭 6) — 젤리를 못 타도 올라갈 수 있음 |
| D 찬바람 선반 | −136 ~ −216 | 12 | **얼음**, 폭 18, 양옆 벽 없음. **송풍구 2개**(태그 `ColdFan`): z −150~−166은 +X로, z −186~−202는 −X로 밂 |
| E 결승 | −216 ~ −260 | 12 | 일반 바닥(얼음 아님), 냉장고 문틀, `FinishLine` z −250 |
- 낙하: 그 구간 바닥보다 **25** 아래 → `ctx.eliminate`(`Logic.fallLineAt(z)`, 위 칸 D·E는 −13, 구멍·B·C는 −25). 결승선 통과 → `ctx.pass`. 시간 제한 `Config.TimeLimit.Race`(90초).

### 얼음 이동 (클라이언트, `IceController` + 순수 `IceLogic`)
- 내 캐릭터가 **땅에 닿아 있고** 발밑(HumanoidRootPart에서 아래로 4.5 레이캐스트) 파츠가 `Ice` 태그면 얼음 모드. 그 밖(공중·일반 바닥)에서는 손대지 않아요(Roblox 기본 이동).
- 얼음 모드 매 프레임(`RunService.Stepped`):
  - `current` = 지금 실제 수평 속도(HumanoidRootPart `AssemblyLinearVelocity`의 x·z), `target` = `Humanoid.MoveDirection × Humanoid.WalkSpeed`(잡혀서 느려진 입력·간장 감속 등이 그대로 반영됨).
  - 입력이 있으면 `IceLogic.step(current, target, dt)` = `current + (target − current) × (1 − e^(−ACCEL·dt))`, **ACCEL = 2.5** (약 0.9초에 목표의 90%). 반대로 누르면 0.3초 안에 멈춤.
  - 입력이 없으면 `current × e^(−DRAG·dt)`, **DRAG = 1.0** (걷기 속도 16에서 약 16 studs 미끄러져 멈춤).
  - 수직 속도는 그대로. 결과 수평 속도 크기는 `max(|current|, WalkSpeed)`를 넘지 않게(얼음이 속도를 **늘리지는 않음**).
- **실제 속도에서 출발**하니까 서버 밀기(송풍구)·젤리 튕김·다이브·넉백 속도가 얼음 위에서 사라지지 않고 천천히 줄어요(다이브하면 더 멀리 미끄러짐 — Fall Guys 느낌).
- 이동 감시(m4-10): 얼음이 속도를 늘리지 않아서 상한(80)과 무관. 클라이언트 판단은 이동뿐이고 판정(결승선·낙하)은 서버 그대로(GDD 11.4).
- 로비·다른 맵에는 `Ice` 태그가 없어서 영향 없음. 다른 맵이 나중에 `Ice` 태그를 쓰면 같은 동작.

### 젤리 (서버, 와사비와 같은 방식)
- `Jelly` 파츠에 닿은 레이서(발이 윗면 근처)를 **위로 72**(약 13 studs 높이 — 위 칸 12에 닿음) + 진행 방향(−Z)으로 10 `LinearVelocity` 0.15초, `MoveExempt.mark` 1.5초, 같은 사람 0.6초 쿨다운. 효과음 `JellyBoing`, 젤리가 출렁이는 장식 애니메이션(크기만, 판정 파츠는 고정).

### 송풍구 (서버, 라멘 급류 밀기와 같은 방식)
- 주기 4초: **0.5초 서리 입자 경고 → 2초 불기 → 1.5초 쉼** (송풍구 2개는 2초 어긋나게). 불 때 그 구역 안 레이서의 수평 속도를 옆 방향으로 **14**까지 가속 40, `MoveExempt.mark`. 효과음 `FanGust`(불기 시작 때 한 번).
- `Logic.fanState(i, t) -> "Warn" | "Blow" | "Rest"`, `Logic.fanPush(i)`(방향 벡터).

### 아트 (**[`docs/REFERENCE-map-art-direction.md`](../REFERENCE-map-art-direction.md) 필수**, 도구 m5-23 비주얼 키트 + 렌더러, 예산 **Extended: 장식 파츠 1500·파티클 16·조명 24(그림자 2)·움직임 80**, `Art.BUDGET = "Extended"`)
- 아트 작업은 m5-23이 `main`에 머지된 뒤 `git merge main`으로 받아서 한다(판정·로직은 먼저 해도 됨).
- 기본 요소(유지): 냉장고 안: 흰 벽·투명 선반(유리 재질, 장식 쪽만), 차가운 파란 조명, 얼음 바닥(Ice 재질·밝은 하늘색), 디저트 장식(푸딩·케이크 조각·아이스크림 콘·마카롱 — 코스 밖, 충돌 없음), 젤리 발판은 반투명 빨강·초록, 송풍구는 냉장고 환풍구 모양 + 서리 입자, 결승은 열린 냉장고 문과 바깥 주방 불빛. `IntroCamera` 4점. (아래 디렉션이 우선)
- **아트 디렉션 — "차가운 업소용 냉장고 속 디저트 칸, 끝에 따뜻한 주방"**
  - 히어로 색: **민트-얼음 파랑**(`PALETTE.IceBlue`·`Mint`). 60 = 차가운 흰색·옅은 파랑 냉장고 벽과 선반, 30 = 얼음 하늘색 바닥·유리 선반, 10 = 채도 높은 디저트 강조(딸기 젤리 빨강·라임 젤리 초록·초콜릿·마카롱 파스텔). 판정 얼음은 밝은 하늘색, **구멍은 짙은 남색 안쪽 + 흰 림**으로 휴대폰에서도 읽히게, 얼음 코스 가장자리는 흰 립.
  - 조명(`lighting` 프리셋): ClockTime 13(실내 느낌이라 해 영향 적게 — Offset 낮게), 높은 차가운 Ambient(약 180,200,225), Atmosphere Density 0.3 흰-파랑 "냉기" Haze 1, ColorCorrection Tint 아주 옅은 파랑·채도 +0.1, Bloom 0.5(LED 띠). **온도 대비 보상**: 결승의 열린 문 너머 주방은 주황 빛(문틀에서 들어오는 따뜻한 SpotLight, 그림자 있음 1개) — 달리는 내내 "저 따뜻한 데로 탈출"이 보이게. 그림자 조명 두 번째: 냉장고 천장 LED 램프에서 젤리 계단을 비추는 좁은 SpotLight.
  - 히어로 세트피스: ① 냉장고 뒷벽 LED 램프 패널 + 송풍구(게임플레이 송풍구와 같은 모양 언어) ② C 구간 옆 거대한 딸기 쇼트케이크 조각과 푸딩(캐러멜이 흘러내림, 반사) ③ 문 선반의 아이스크림 콘·스쿱 탑 ④ 우유팩 + 계란판(계란초밥 캐릭터 오마주) ⑤ 결승의 열린 문 — 문 안쪽 선반에 병·소스, 문 바깥 주방 실루엣과 냉장고 자석.
  - 층: FG = 얼음 쟁반 림·젤리 받침 접시·코스 옆 마카롱·체리 무리, MG = 케이크·푸딩·아이스크림 탑·우유팩, BG = **아래 칸 채소 서랍(크리스퍼) 큰 판 — 낙하 탈락선보다 10 이상 아래**, 냉장고 옆벽(둥근 모서리 트림)·위 칸 유리 선반 밑면, 끝의 문 너머 주방.
  - 파티클: 송풍구에서 흘러내리는 냉기 `ColdMist`, 얼음 위 `Sparkle`, 문 쪽 `Frost`(서리 입자 경고는 게임플레이 기존), 결승 문가 따뜻한 `Dust` 빛 먼지.
  - 움직임(`anim`): 젤리 장식 Pulse(판정 젤리 파츠는 고정 — 장식 젤리만), 케이크 위 체리 Bob, 진열대 마카롱 Spin, 문 선반 병 Sway 약하게.
  - 큰 반투명 유리 선반은 얇게·작게(성능 — 가이드 2·5절), 투명도 0.5 이하로 테두리 트림을 진하게 해 모양이 읽히게.
  - `IntroCamera` 4~5점: 냉장고 문 쪽에서 코스 전체를 거꾸로 보는 넓은 샷 → 얼음 구멍·큐브 → 젤리 계단 위에서 내려다보는 반전 샷 → 출발 자리(멀리 결승 문빛이 보이게).

## 범위
- 포함: 위 규칙, `IceLogic`·`IceController`, 순수 로직 분리, 아트, IntroCamera, `inPool = false` 줄 삭제.
- 제외: 굴러오는 아이스크림(간장 늪 날치알과 겹침 — 플레이테스트 뒤 후보), 얼음이 깨지는 바닥, 미끄럼 소리.

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1 (`map-dessert-fridge`): `MapTypes.validate` 통과(Race, Spawns 24, FinishLine), 스폰은 A 구간 안 서로 3 이상.
- [ ] AC2: 진행도(로컬 −Z)가 출발 → 결승으로 단조 증가, `fallLineAt(z)`가 각 구간 바닥 − 25.
- [ ] AC3: B 구간 구멍 2개와 얼음 큐브 사이로 폭 4 이상의 길이 이어진다(격자 탐색). C 구간에 젤리 없이 쿠키 계단만으로 위 칸에 닿는 길이 있다(디딤 높이 ≤ 3).
- [ ] AC4: `fanState`: 송풍구 1은 t 0~0.5 Warn, 0.5~2.5 Blow, 2.5~4 Rest, 4에서 다시 Warn. 송풍구 2는 2초 어긋난다. 두 송풍구 밀기 방향이 반대이고 크기 1.
- [ ] AC5: 젤리 튕김 위 속도 72로 오르는 높이(g = 196.2)가 12 이상 15 이하.
- [ ] AC6 (`ice-logic`): `IceLogic.step`: 입력 방향 목표로 0.9초 뒤 90% 이상(±3%), 입력 없을 때 속도 16이 1초 뒤 약 5.9(16·e^−1), 반대 입력으로 0.35초 안에 방향이 바뀐다, 결과 크기가 `max(|current|, walkSpeed)`를 넘지 않는다, dt = 0이면 그대로.
- [ ] AC7: 장식 `MapKitLogic.validate` 통과, 600개 이하, `inPool` 없음 또는 true.
- [ ] AC8: 검증 5단계 통과 + 기존 `maps`·`movement-guard` 테스트 통과.

### Studio 확인 (`forceMapPlan = { "dessert-fridge", "hot-plate", "skewer-showdown" }`, **확인 뒤 nil**)
- [ ] AC9: 얼음 위에서 손을 떼면 쭉 미끄러지다 멈추고, 방향을 바꾸면 둥글게 돌아간다. 일반 바닥(출발·결승)에서는 바로 멈춘다. 얼음 위 다이브는 평소보다 멀리 미끄러진다.
- [ ] AC10: 구멍에 빠지거나 얼음 끝으로 미끄러져 떨어지면 1초 안에 탈락 연출이 나온다.
- [ ] AC11: 젤리를 밟으면 위 칸까지 튕겨 오르고, 못 타도 쿠키 계단으로 올라갈 수 있다.
- [ ] AC12: 송풍구 앞에서 서리가 보인 뒤 바람이 불어 얼음 위에서 옆으로 밀린다. 바람을 맞으며 반대로 누르면 버틸 수 있다.
- [ ] AC13: 2명(Clients and Servers)에서 상대가 얼음 위에서 미끄러지는 모습이 자연스럽게 보이고, 잡기(R2/마우스)가 얼음 위에서도 상대를 느리게 한다. 이동 감시 로그가 생기지 않는다.
- [ ] AC14: 혼자 60~90초 안에 완주할 수 있고, 4명 이상 랜덤 판에서 첫 라운드로 나와도 목표 인원이 찬다(사용자 체감, 수치는 Layout·IceLogic 상수만 고침).
- [ ] AC15: 이 맵이 끝난 뒤 다른 맵·로비에서는 이동이 평소와 같다(얼음 모드가 남지 않음).

### 아트 품질 (m5-23 렌더러, 2026-10-13 추가)
- [ ] AC16: 렌더 미리보기(`lune run tools/render-map dessert-fridge --view all`) → 아트 가이드 11절 체크리스트 비평(글로) → 고침을 **3회 이상 반복**했고, 마지막 반복에서 체크리스트 18개가 전부 "예"다. 반복 기록은 `docs/developer/m5-06-*.md`, 전/후 PNG는 `docs/renders/dessert-fridge/`에 있고 **최종 PNG 경로가 개발 메모에** 있다. 예산은 `MapKitLogic.checkBudget(Art.decor(), "Extended")` 테스트로 확인한다(AC7의 "600개 이하"는 Extended 1500으로 읽는다). 맵에 `lighting` 프리셋이 있고 `MapTypes.validate`를 통과한다.
- [ ] AC17 (Studio): 라운드가 시작되면 차가운 냉장고 조명으로 바뀌고 결승 문 쪽 따뜻한 빛이 출발에서도 보이며, 휴대폰 에뮬레이터에서 얼음 구멍과 코스 가장자리가 보인다.

## 공용 파일 변경
- 없음 (`IceController` 등록은 m5-03)

## 사용자 작업 (스펙을 막지 않음)
- AC14 체감, `FanGust`·`JellyBoing` 소리 id(USER-TODO A2). (선택) `assets/map-art/dessert-fridge.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 얼음을 어떻게 · 로블록스 Humanoid는 바닥 마찰을 거의 무시해서 재질·마찰값만으로는 안 미끄러짐 → **클라이언트가 실제 속도에서 출발해 목표 속도로 천천히 다가가는 관성 이동**. 우리 이동은 원래 클라이언트 물리이고 판정만 서버라(GDD 11.4) 구조가 맞음. 근거: DevForum "Ice-walking effect"(속도 누적 + 감쇠), Fall Guys 시즌 3 얼음 라운드·Stumble Guys Icy Heights("멈추기·꺾기 어려움") — REFERENCE-m5-maps 1·2.3. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 얼음 수치 · ACCEL 2.5(0.9초에 90%), DRAG 1.0(약 16 studs 미끄러짐), 속도를 늘리지 않음(이동 감시와 무관, 다이브 지름길 문제 없음). 미끄러짐이 너무 길면 처음 하는 아이가 구멍에 계속 빠져서 감쇠를 0.6 → 1.0으로 · **기본값, 플레이테스트 후 조정** · planner
- 2026-10-08 · D3 송풍구·젤리 · 송풍구 밀기 14(라멘 급류 소용돌이 옆 10보다 조금 세게, 얼음이라 체감은 더 큼), 0.5초 경고(서리). 젤리는 와사비와 같은 서버 튕김. 느린 길(쿠키 계단)을 함께 둬서 한 구간이 막히지 않게(라멘 급류 착지판 R1과 같은 원칙) · **기본값, 플레이테스트 후 조정** · planner

- 2026-10-13 · Q1 (developer, 질문) C 구간 배치 · 표의 "C 바닥 0 → 12"를 **앞쪽 바닥 y 0(z −96 ~ −124) + 뒤쪽 위 칸 착지대(y 0 ~ 12 통짜 블록, z −124 ~ −136)**로 구현. 젤리(위 72·앞 10)로 착지대 앞면을 넘으려면 오르는 0.3초 동안 몇 studs밖에 못 가서 발판을 착지대 앞면에 붙여야 하고, 8 × 8 발판 3개 + 쿠키 계단(폭 6)을 한 줄에 두려고 **C 폭만 30**(B 22, D 18)으로 했어요. 쿠키 계단은 x 9 ~ 15, 디딤 y 3·6·9 → 착지대 12. 낙하선은 표대로 C 전체 −25. 다르게 원하면 Layout 상수만 바꾸면 돼요 · planner 확인 필요
  - → 2026-10-13 **확정: C 폭 30 그대로** · 사용자
- 2026-10-13 · Q2 (developer, 질문) 송풍구 `MoveExempt` · 스펙은 송풍구 밀기에 `MoveExempt.mark`를 달라고 했지만 CLAUDE.md 규칙은 "연속 밀기에는 달지 않는다"예요. 스펙대로 달되 **한 번 불기(2초)마다 사람당 한 번, 2.5초**만 표시(매 프레임 속성 복제 없음). 밀기 14 + 걷기 16이라도 상한 80보다 한참 낮아서 빼도 오탐은 없을 것 같아요 — 빼는 쪽이 낫다면 알려 주세요 · planner 확인 필요
  - → 2026-10-13 **결정: 송풍구 `MoveExempt` 뺌** (CLAUDE.md "연속 밀기에는 달지 않는다", 속도 상한보다 한참 낮음 — PHASE B에서 코드 반영) · 메인 세션
- 2026-10-13 · Q3 (developer, 메모) 송풍구 2는 2초 어긋나서 라운드 시작(t 0)에 이미 불기 중이에요(경고 없이 시작). 선반까지 오는 데 30초 넘게 걸려서 체감 영향 없음 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### PHASE A (게임플레이, 2026-10-13) — 아트는 PHASE B(m5-23 비주얼 키트 이후)에서
- 바뀐 파일
  - 새 파일: `src/shared/IceLogic.luau`(순수 얼음 관성 계산), `src/shared/maps/DessertFridgeLayout.luau`(치수·튜닝), `DessertFridgeLogic.luau`(진행도·낙하선·송풍구 주기·젤리/송풍구 구역·길 찾기용 판정), `DessertFridgeArt.luau`(**자리 표시용 최소 장식** — 결승 문틀·문짝 4개 + IntroCamera 4점)
  - `src/shared/maps/DessertFridge.luau`: 껍데기 → 실제 맵. 판정 지오메트리(얼음 바닥 `Ice` 태그 + Ice 재질·하늘색, 얼음 큐브 8, 구멍 2, 젤리 3 `Jelly` 태그 반투명 빨강·초록, 쿠키 계단, 크림색 착지대, 송풍구 2 `ColdFan` 태그 + 서리 입자, 결승 바닥·FinishLine). 서버: 결승선·낙하 판정, 젤리 튕김(LinearVelocity 0.15초, 면제 1.5초, 쿨다운 0.6초, `JellyBoing`), 송풍구 주기·밀기(14까지 가속 40, `FanGust`). **`inPool = false` 줄 삭제 → 랜덤 풀 합류**
  - `src/client/input/IceController.luau`: 껍데기 채움. 땅 + 발밑 4.5 레이캐스트가 `Ice` 태그면 매 `Stepped` 실제 수평 속도 → `IceLogic.step` → 내 캐릭터에만 로컬 **수평(Plane) `LinearVelocity`**(힘 = 질량 × 600)로 적용. Humanoid 걷기가 직접 쓴 속도를 바로 덮어써서 제약으로 걷기 힘을 이기게 했어요. 공중·일반 바닥·넘어짐·앉음·죽음이면 제약을 끄고, 캐릭터가 바뀌면 지워요(AC15)
  - 테스트: 새 `tests/ice-logic.spec.luau`(8), `tests/map-dessert-fridge.spec.luau`(16). 풀 합류로 기존 가정 수정: `tests/maps.spec.luau`(풀 12 → 13), `tests/m4-foundation.spec.luau`(Race 목록), `tests/m4-12-hardening.spec.luau`(강제 플랜에 dessert-fridge 추가), `tests/m5-03-foundation.spec.luau`(SHELLS·껍데기 표에서 제외, infos 13)
- 검증 5단계 통과: rojo build, stylua --check, selene(0/0/0), lune run tests(1257 passed, 0 failed), luau-lsp analyze(끝 코드 0)
- Studio 확인 (`Config.DEBUG.forceMapPlan = { "dessert-fridge", "hot-plate", "skewer-showdown" }`, **확인 뒤 nil**)
  1. 얼음 쟁반(B)에서 앞으로 달리다 손을 떼면 약 16 studs 미끄러져 멈추는지, 옆으로 꺾으면 둥글게 도는지, 출발·결승 바닥에서는 바로 멈추는지 (AC9). 얼음 위 다이브(Shift)는 더 멀리 미끄러지는지
  2. 구멍(z −40 왼쪽, z −70 오른쪽)이나 얼음 끝으로 떨어지면 1초 안에 탈락 연출 (AC10)
  3. C 착지대 앞 젤리 3개(빨강·초록·빨강)를 밟으면 위 칸으로 튕겨 오르는지, 오른쪽 쿠키 계단으로도 올라가지는지 (AC11)
  4. D 선반에서 송풍구(회색 판) 앞 서리 → 2초 바람 → 옆으로 밀림, 반대로 누르면 버틸 수 있는지 (AC12)
  5. Clients and Servers 2명: 상대가 미끄러지는 모습, 얼음 위 잡기 감속, 출력 창에 `[MovementGuard]` 로그 없음 (AC13)
  6. 다음 맵(hot-plate)·로비에서 이동이 평소와 같은지 (AC15)
- 남은 이슈
  - 아트(PHASE B): 냉장고 벽·유리 선반·차가운 조명·디저트 장식·젤리 출렁임 애니메이션·결승 주방 불빛. 판정 파츠는 실루엣이 읽히게 이미 색·재질만 정해 둠
  - Q1·Q2 planner 확인
  - IceController의 제약 힘(질량 × 600)과 Studio 체감은 미확인 — 너무 끈적이거나 벽(큐브)에서 떨리면 `GLIDE_ACCEL`만 조절
  - 이 브랜치와 병렬인 m5-04·m5-05가 같은 테스트(`m5-03-foundation`·`maps`·`m4-foundation`·`m4-12-hardening`)의 맵 개수를 바꾸면 병합 때 충돌 — 숫자를 합쳐 맞추면 돼요
