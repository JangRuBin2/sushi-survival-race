status: ready
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

### 아트 (장식 예산 파츠 600·파티클 8·조명 12)
- 냉장고 안: 흰 벽·투명 선반(유리 재질, 장식 쪽만), 차가운 파란 조명, 얼음 바닥(Ice 재질·밝은 하늘색), 디저트 장식(푸딩·케이크 조각·아이스크림 콘·마카롱 — 코스 밖, 충돌 없음), 젤리 발판은 반투명 빨강·초록, 송풍구는 냉장고 환풍구 모양 + 서리 입자, 결승은 열린 냉장고 문과 바깥 주방 불빛. `IntroCamera` 4점.

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

## 공용 파일 변경
- 없음 (`IceController` 등록은 m5-03)

## 사용자 작업 (스펙을 막지 않음)
- AC14 체감, `FanGust`·`JellyBoing` 소리 id(USER-TODO A2). (선택) `assets/map-art/dessert-fridge.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 얼음을 어떻게 · 로블록스 Humanoid는 바닥 마찰을 거의 무시해서 재질·마찰값만으로는 안 미끄러짐 → **클라이언트가 실제 속도에서 출발해 목표 속도로 천천히 다가가는 관성 이동**. 우리 이동은 원래 클라이언트 물리이고 판정만 서버라(GDD 11.4) 구조가 맞음. 근거: DevForum "Ice-walking effect"(속도 누적 + 감쇠), Fall Guys 시즌 3 얼음 라운드·Stumble Guys Icy Heights("멈추기·꺾기 어려움") — REFERENCE-m5-maps 1·2.3. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 얼음 수치 · ACCEL 2.5(0.9초에 90%), DRAG 1.0(약 16 studs 미끄러짐), 속도를 늘리지 않음(이동 감시와 무관, 다이브 지름길 문제 없음). 미끄러짐이 너무 길면 처음 하는 아이가 구멍에 계속 빠져서 감쇠를 0.6 → 1.0으로 · **기본값, 플레이테스트 후 조정** · planner
- 2026-10-08 · D3 송풍구·젤리 · 송풍구 밀기 14(라멘 급류 소용돌이 옆 10보다 조금 세게, 얼음이라 체감은 더 큼), 0.5초 경고(서리). 젤리는 와사비와 같은 서버 튕김. 느린 길(쿠키 계단)을 함께 둬서 한 구간이 막히지 않게(라멘 급류 착지판 R1과 같은 원칙) · **기본값, 플레이테스트 후 조정** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
