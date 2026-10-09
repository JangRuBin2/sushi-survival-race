status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-15 — 새 Race 맵: 등불 다리 건너기 (`lantern-bridge`)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.3 (v0.6, 1차 확장 맵 6개 중 `lantern-bridge`), §5.3 "맵 테마 원칙"(개별 맵은 다른 테마여도 됨 — 일본 축제), §5.2 Race(최대 90초)
- 참고: `CLAUDE.md` "맵 모듈 공통 인터페이스", "이동 감시 면제" 규칙(연속 밀기는 면제 안 함), `docs/proposals/map-expansion-and-quality.md` §3 "5. `lantern-bridge`", `src/shared/maps/RamenRapids.luau`+`RamenRapidsLayout.luau`/`RamenRapidsLogic.luau`(움직이는 발판·밀기 패턴), `src/shared/maps/ChefBoardLogic.luau`의 `tiltCFrameParams`/`TILT_PUSH_SPEED`(기울어진 바닥이 미는 방식 — 연속 밀기라 MoveExempt 없음), `docs/specs/m4-04-map-ramen-rapids.md`(형식·디테일 수준)
- 담당 개발 worktree: `m5-lantern` (Rojo 포트 34876)
- 공용 파일 수정 담당: 없음
- 의존: **m5-13 머지 후 시작** (`src/shared/maps/LanternBridge.luau` 껍데기를 덮어씀. 이 스펙 작성 시점에 `shared/maps/init.luau`는 아직 m5-13의 6개를 등록하지 않음 — 머지 후 `ALL` 목록에 `LanternBridge`가 `inPool = false`로 들어와 있을 것)
- **이 스펙이 고치는 파일**: `src/shared/maps/LanternBridge.luau`(껍데기 덮어쓰기, `inPool = true`로 전환), 새 파일 `src/shared/maps/LanternBridgeLayout.luau`, `src/shared/maps/LanternBridgeLogic.luau`, `src/shared/maps/LanternBridgeArt.luau`, `tests/map-lantern-bridge.spec.luau`

## 목표
일본 축제 분위기의 흔들리는 구름다리(외나무다리) 여러 개를 건너는 Race. 다른 Race 맵은 전부 "개인 대 지형" 싸움이지만, 이 맵은 **다리 위에 몰린 사람이 많을수록 그 다리가 더 심하게 흔들리는** 유일한 맵 — 다른 플레이어의 존재 자체가 내 위험도를 올린다(군중 압박감).

## 범위
- 포함 (수치는 전부 기본값, `LanternBridgeLayout` 상수로 모은다):
  1. **코스** (origin 앞 = 로컬 -Z, 전체 길이 약 150 studs, 높이는 평탄 — 다리는 전부 물/계곡 위에 뜬 평평한 외나무다리, 떨어지면 아래로 낙하):
     - **출발 평지** (z 0 ~ -14, 폭 16, 안전): 스폰 24개. 축제 입구(도리이 모양 장식, 장식 전용).
     - **다리 1** (폭 8, 길이 20, 최대 흔들림 각도 낮음): 가장 쉬운 입문 다리.
     - **쉼터 1** (안전 평지, 폭 10, 길이 10, 등불이 늘어선 장식).
     - **다리 2** (폭 6, 길이 24, 최대 흔들림 각도 중간).
     - **쉼터 2** (안전 평지, 폭 10, 길이 10).
     - **다리 3** (폭 4, **가장 좁음**, 길이 20, 최대 흔들림 각도는 1·2보다 **낮게** 설정 — 좁은 다리는 물리적으로 크게 휘청이지 않지만, 폭이 좁아서 **같은 정도로 밀려도 더 쉽게 떨어진다**. 이게 "좁을수록 덜 흔들려도 더 쉽게 떨어진다"의 구현).
     - **쉼터 3** (안전 평지, 폭 10, 길이 10).
     - **다리 4** (폭 8, **가장 길음**(30) — 한 번에 가장 많은 인원이 몰릴 수 있어 군중 효과가 가장 잘 보이는 "피날레" 다리, 최대 흔들림 각도가 네 다리 중 가장 높음).
     - **결승 평지** (폭 16, 길이 14): `FinishLine` 통과 → `ctx.pass`.
  2. **흔들림 메커니즘** (`LanternBridgeLogic`, 전부 순수 함수):
     - 서버가 매 틱 그 다리 위에 있는 레이서 수를 센다(다리별 로컬 z·x 범위 안에 있는 `ctx.getRacers()`의 HumanoidRootPart 위치로 판정, `RamenRapids`의 `onBroth`와 같은 방식).
     - `Logic.swayAmplitudeDeg(riders, maxDeg)` — 혼자여도 기본 흔들림(`SWAY_BASE_DEG`)이 있고, 인원이 늘수록(`SWAY_PER_RIDER_DEG`씩) 커지다가 `SWAY_RIDER_CAP`명부터는 더 안 늘고, 항상 그 다리의 `maxDeg`를 넘지 않는다.
     - `Logic.swayAngle(t, amplitudeDeg, period, phase)` — 사인파로 좌우(roll, 로컬 Z축 기준 회전)를 흔든다. 다리마다 `phase`가 달라 같이 안 흔들린다.
     - 서버는 이 각도로 **다리 파츠의 CFrame을 Heartbeat에서 직접 갱신**한다(아래 "구현 방식" 참고).
     - **미는 힘**: 다리가 기운 동안 낮은 쪽으로 계속 밀린다 — `ChefBoard`의 기울어진 바닥과 같은 방식(`Logic.pushSpeedFor(angleRad, maxDeg)`로 목표 속도를 구하고, `Logic.pushDelta`로 가속). **연속 밀기라 `MoveExempt`는 달지 않는다** (`CLAUDE.md` 규칙 — 벨트·급류·기울기와 같은 분류).
     - **낙하 판정**: 다리 폭의 절반(`halfWidth`)을 넘어 로컬 X로 벗어나면 그 아래엔 바닥이 없어서(다리 파츠 자체가 그 폭만큼만 있음) 자연히 떨어진다. 떨어짐은 다른 맵처럼 `fallLineAt(z)`(그 구간 바닥 높이 - 여유) 아래로 로컬 Y가 내려가면 `ctx.eliminate` (RamenRapids 패턴 재사용).
  3. **장애물 구현 규칙**: 태그 `LanternBridgePlank`(흔들리는 다리 파츠, `start`에서 CFrame 갱신 + 인원 집계 + 미는 힘). `ctx.model` 하위 태그 파츠만 동작시켜(여러 방 동시 진행 섞임 방지), 상태는 `start` 지역 변수에 둔다.
  4. **소리**: 기존 cue만 쓴다(`MapSfx`) — 다리에 올라설 때/크게 흔들릴 때 쓸 cue가 마땅히 없으면 새로 만들지 않고 결정 기록에 적어 사용자에게 알린다(SfxCues 추가는 이 스펙 범위 밖).
  5. **아트** (`LanternBridgeArt`, 축제 테마 — 캐릭터·탈락/우승 연출은 그대로 회전초밥집 세계관, 맵만 다른 테마): 종이 등불(빨강·주황·흰색 구체 또는 원기둥, 다리 양옆 밧줄에 매달림, 충돌 없음), 다리 난간 밧줄(장식, 충돌 없음 — 판정은 다리 바닥 폭으로만), 쉼터의 나무 울타리·석등, 입구 도리이 모양 기둥, 등불 중 일부만 `PointLight`(예산 12 안에서 전체 다리 수에 맞춰 분배). `IntroCamera` 4점, `MapKit.attachStudioArt`.
  6. **순수 로직 분리**: `LanternBridgeLayout`(치수·스폰·다리/쉼터 구간 표, 다리별 `halfWidth`·`maxSwayDeg`·`phase`), `LanternBridgeLogic`(흔들림 각도, 미는 속도, 낙하선, 진행도, 다리 찾기, 위험도 비교) — Roblox 자료형 없이 숫자로.
  7. **맵 등록**: `inPool`을 m5-13의 `false`에서 **`true`로 바꿔** 랜덤 판 풀에 포함시킨다. `id`·`kind`·`displayName`·`rule`은 m5-13이 확정한 값 그대로 유지한다(바꾸지 않음 — 머지 후 실제 값 확인).
- 제외:
  - 다리가 실제로 처지는(sag) 곡선 지오메트리 — 판정은 평평한 판으로 단순화(다른 맵과 같은 원칙: 판정 지오메트리는 단순하게, 장식만 화려하게)
  - 밧줄을 붙잡는 등의 조작 — 다이브·잡기는 기존 전역 기능만

### 구현 방식: 다리 CFrame 직접 갱신 vs TweenService (직접 갱신 추천)
- **TweenService (서버)**: 서버가 Tween을 만들어 재생해도 엔진이 매 프레임 서버 인스턴스의 CFrame을 실제로 바꾸는 건 같아서(클라이언트가 보간하는 게 아니라 서버 값 자체가 변함), 네트워크로 나가는 양은 직접 갱신과 다르지 않다. 게다가 흔들림 진폭이 인원수에 따라 **매 틱 계속 바뀌어야** 하는데, Tween은 고정된 시작/끝 값으로 만들어서 진폭이 바뀔 때마다 기존 Tween을 취소하고 새로 만들어야 해 끊기고(jerky), 끝나는 시점이 결정적이지 않아 순수 함수로 테스트하기도 어렵다.
- **CFrame 직접 갱신 (Heartbeat, 추천)**: `Logic.swayAngle(t, amplitudeDeg, period)`처럼 시간의 순수 함수로 각도를 구해 매 틱 CFrame을 다시 쓴다. `RamenRapids`(차슈·회전 막대)·`ChefBoard`(기울기)가 이미 이 방식을 같은 빈도로 쓰고 있고, 이 맵은 다리가 4개뿐(ChefBoard의 칼 줄 61칸보다 훨씬 적음)이라 네트워크 비용이 기존에 이미 출시된 맵보다 낮다. 인원수가 바뀌어도 진폭 값만 다음 틱에 반영하면 되고 끊김이 없다. **추천: 직접 갱신.** (대역폭이 더 걱정되면 갱신 주기를 Heartbeat 전체가 아니라 일정 간격으로 줄일 수 있지만, 기본값은 매 Heartbeat로 시작하고 느껴보고 조정한다.)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/map-lantern-bridge.spec.luau`)
- [ ] AC1: `MapTypes.validate`를 통과하고(Spawns 24, FinishLine), 스폰 24개가 출발 평지 안에서 서로 3 studs 이상 떨어져 있다.
- [ ] AC2: `Logic.swayAmplitudeDeg(riders, maxDeg)`가 riders에 대해 감소하지 않고(단조 비감소), `SWAY_RIDER_CAP`명 이상에서는 더 늘지 않으며, 항상 `maxDeg` 이하다. riders=0일 때도 0보다 크다(기본 흔들림).
- [ ] AC3: 네 다리의 `maxSwayDeg`가 다리 1→4로 폭이 좁아질수록(1,2,3) 낮아지다가 4(가장 길고 넓음)에서 다시 가장 높다 — 레이아웃 표가 GDD 의도(폭 다양성)대로 설정됐는지 확인.
- [ ] AC4: 같은 riders 수에서 **위험도**(`Logic.fallRisk(amplitudeDeg, halfWidth)` = 진폭을 반폭으로 나눈 값 같은 비례식)가 가장 좁은 다리(3번)에서 가장 넓은 다리들보다 더 크다 — "좁을수록 덜 흔들려도 더 쉽게 떨어진다"가 수치로 성립하는지.
- [ ] AC5: `Logic.swayAngle(t, amplitudeDeg, period, phase)`가 사인파로 ±`amplitudeDeg`(라디안 환산) 안에서만 움직이고, `period`마다 한 바퀴 돈다(극값 시각 확인).
- [ ] AC6: `Logic.pushSpeedFor(angleRad, maxDeg)`가 각도 0에서 0, `maxDeg`(라디안)에서 최고 속도이며 부호가 기운 방향과 같다. `Logic.pushDelta`가 목표 속도까지만 가속하고 줄이지 않는다(기존 맵들과 같은 계약).
- [ ] AC7: `Logic.isOffPlank(localX, halfWidth)`가 경계(`±halfWidth`)에서 정확히 갈린다.
- [ ] AC8: `fallLineAt(z)`가 각 구간 바닥보다 일정 여유만큼 낮고, `Logic.progress(z)`가 코스를 따라 단조 증가(결승이 가장 큼)한다.
- [ ] AC9: 다리·쉼터 구간 표가 서로 안 겹치고 z 순서대로 이어지며, `FinishLine`이 결승 평지 안에 있다.
- [ ] AC10: 장식이 `MapKitLogic.validate` 통과, 파츠 600개·파티클 8개·조명 12개 이하.
- [ ] AC11: 검증 명령 5단계 통과(`rojo build`, `stylua --check`, `selene`, `lune run tests`, `luau-lsp analyze`) + 기존 `maps` 풀 테스트 통과(이 맵이 `inPool = true`로 들어간 뒤에도 랜덤 플랜 구성 로직이 깨지지 않음).

### Studio 확인 (`forceMapPlan = { "lantern-bridge", "hot-plate", "soy-swamp", "skewer-showdown" }`)
- [ ] AC12: 혼자서도 완주할 수 있고, 가만히 서 있어도 다리가 늘 약하게 흔들리는 게 느껴진다.
- [ ] AC13: Test → Clients and Servers로 2명 이상이 **같은 다리**에 모이면, 혼자일 때보다 눈에 띄게 더 심하게 흔들린다. 서로 다른 다리에 나뉘어 있으면 각 다리가 자기 다리 위 인원수로만 흔들린다(섞이지 않음).
- [ ] AC14: 가장 좁은 다리(3번)는 인원이 적어도 쉽게 떨어질 만큼 아슬아슬하고, 가장 넓고 긴 다리(4번)는 몰려도 상대적으로 여유 있다 — 난이도 체감(사용자 확인, 바꿀 수치는 `LanternBridgeLayout` 상수).
- [ ] AC15: 다리 밖(폭 바깥)으로 밀리거나 걸어 나가면 1초 안에 탈락 연출이 나오고, 결승선을 넘으면 통과(대기석으로).
- [ ] AC16: 2개 방이 동시에 이 맵을 돌려도 각 방의 다리 흔들림·인원 집계가 자기 방에서만 동작한다.
- [ ] AC17: 등불·도리이·난간 장식이 예산 안에서 보이고, 과거 다른 맵에서 있었던 "큰 장식이 카메라를 가림" 문제가 이 맵에서 재현되지 않는다(소개 카메라 경로 확인).
- [ ] AC18: 휴대폰 화면 배율에서 조작 버튼·카메라가 흔들리는 다리 위에서도 정상 동작한다.
- [ ] AC19: `inPool = true`로 바뀐 뒤 일반 랜덤 방 생성 시 이 맵이 로테이션에 실제로 등장할 수 있다(디버그 설정 없이 여러 번 방 생성해 확인).

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- AC14 난이도 체감, 등불 색·소리를 더 넣고 싶으면 알려주기(현재는 기존 cue만 사용).
- (선택) `assets/map-art/lantern-bridge.rbxm`.

## 결정 기록
- 2026-10-09 · 다리 CFrame은 서버 Heartbeat에서 직접 갱신(순수 함수 `swayAngle`로 계산), TweenService는 진폭이 매 틱 바뀌어야 해서 안 씀(위 "구현 방식" 참고) · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-09 · 인원수 → 흔들림: 기본 흔들림(혼자서도 약간) + 인원당 증가, `SWAY_RIDER_CAP`명부터 더 안 늘어남(24명이 한 다리에 몰려도 과도하게 안 흔들리게) · **기본값, 수정 가능** · planner
- 2026-10-09 · 다리 폭·최대 흔들림각을 다리별로 독립적으로 둬서, 가장 좁은 다리(3번)는 최대 흔들림각을 오히려 낮게 설정해도 폭이 좁아 위험도가 더 높게 나오도록 함(GDD "좁을수록 덜 흔들려도 더 쉽게 떨어진다") · **기본값, 수정 가능** · planner
- 2026-10-09 · 다리가 기운 동안의 미는 힘은 `ChefBoard` 기울기와 같은 분류(연속 밀기) → `MoveExempt` 안 닮 · planner
- 2026-10-09 · 판정 지오메트리는 처지지 않는 평평한 판으로 단순화(처짐은 장식 수준에서도 생략), 장식(등불·난간·도리이)으로 분위기를 냄 · **기본값, 수정 가능** · planner
- 2026-10-09 · `inPool`을 이 스펙에서 `true`로 전환(m5-13 머지 후 실제 값 확인 필요 — 개발 메모에 기록) · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
