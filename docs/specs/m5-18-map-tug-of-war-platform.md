status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-18 — 세 번째 결승 맵: 줄다리기 발판 (`tug-of-war-platform`)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.1(결승 = 마지막 1명 생존형), §5.2 Final 맵(90초 뒤 연장전, 연장전 표), §5.3 v0.6 "1차 확장 맵 6개" 11번 `tug-of-war-platform`, §11.4(맵 인터페이스, `overtime` 훅 필수)
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md` §3 11번(원안), `docs/specs/m5-01-final-overtime.md`(연장전 공통 계약), `docs/specs/m5-04-map-ikura-bombs.md`(같은 수준의 Final 맵 스펙 형식), `src/shared/maps/SkewerShowdown.luau`·`SkewerShowdownLogic.luau`(기존 Final 구현, 연장전 붕괴 패턴), `src/shared/maps/RamenRapidsLayout.luau`(연속 밀기에 `MoveExempt`를 안 다는 선례 — 머리 주석 "표시 없이도 감시 기준 안이라 밀기에는 `MoveExempt.mark`를 하지 않아요")
- 담당 개발 worktree: `m5-tugofwar` (Rojo 포트 **34879**)
- 공용 파일 수정 담당: 없음
- 의존: **m5-13 머지 후 시작** (껍데기 `src/shared/maps/TugOfWarPlatform.luau`를 덮어씀)
- **이 스펙이 고치는 파일**: `src/shared/maps/TugOfWarPlatform.luau`(덮어쓰기, 끝나면 `inPool = false` 줄 삭제), 새 파일 `src/shared/maps/TugOfWarPlatformLayout.luau`, `TugOfWarPlatformLogic.luau`, `TugOfWarPlatformArt.luau`, `tests/map-tug-of-war-platform.spec.luau`

## 목표
가게 마당에 놓인 거대한 저울 모양 발판 위에서 결승을 치른다. 발판은 **살아남은 사람이 어디에 몇 명 서 있는지**(무게 분포)에 따라 좌우로 기울고, 마찰이 낮아서 기울기가 일정 수준을 넘으면 그 쪽 끝으로 미끄러져 떨어진다. 꼬치 쇼다운(옆에서 오는 꼬치를 점프로 피함)·연어알 폭탄(위에서 오는 무작위 타격을 피함)과 달리, **남이 어디 서 있는지가 내 위험도를 바꾸는 유일한 결승**이다 — 몰려 있는 쪽을 피해 반대편으로 옮겨 균형을 잡을 수도, 일부러 한쪽에 몰려 상대를 떨어뜨릴 수도 있다. 연장전이 되면 발판이 강제로 거의 수직까지 흔들려 20초 안에 누구도 설 수 없게 된다.

## 규칙 (수치는 전부 기본값, `TugOfWarPlatformLayout`·`TugOfWarPlatformLogic` 상수)
### 무대
- origin 앞쪽(CENTER_Z = **-40**, 기존 Final 맵과 같은 배치 거리)에 직사각형 발판 하나. 길이(로컬 X축) **70**, 폭(로컬 Z축) **22**, 두께 **2**. 판정 파츠 1개(`Platform`, 태그 `TugOfWarPlatform`) + 가운데 받침대(장식, 충돌 없음, 피벗을 시각적으로 보여줌).
- 발판은 **원점(origin 기준 CENTER_Z 지점)을 축으로 로컬 Z축 회전만** 한다(이동 없음) — 로컬 X축 양 끝(왼쪽/오른쪽)이 번갈아 오르내리는 시소. `Logic.tilt`가 양수를 돌려주면 로컬 +X(오른쪽) 끝이 **아래로** 내려가야 한다(부호가 반대로 보이면 developer가 CFrame 부호만 뒤집는다 — Studio AC9로 확인).
- 재질: 마찰을 낮게 잡는다(`CustomPhysicalProperties`, Friction **0.35**, 그 외 SmoothPlastic 기본값 유지) — 작은 기울기(아래 `DEAD_ZONE`·중간값)에서는 버틸 수 있고, `MAX_ANGLE`(30°) 근처부터 실제 Roblox 물리로 미끄러지기 시작한다. **넉백·순간이동 없이 발판 자체의 CFrame만 돌리고, 사람이 미끄러지는 건 전부 중력+마찰의 실제 물리다** (아래 "이동 감시" 절 근거).
- `Spawns` 24개: 로컬 X축을 따라 왼쪽 12 · 오른쪽 12, 서로 3 studs 이상 떨어지게(`DessertFridge`/`IkuraBombs` 식 격자, y = 0.1 위, 전부 발판 판정면 위).
- 판정: 발판 중심(origin) 기준 월드 Y가 origin보다 **25 studs**(`FALL_DEPTH`) 아래로 떨어지면 `ctx.eliminate`(기존 Final 맵과 같은 패턴 — 발판이 기울어도 origin은 고정 기준이라 그대로 쓸 수 있다).
- 결승선·`ctx.pass` 없음. 시간 제한 = `Config.TimeLimit.Final`(90초) = 연장전 시작.

### 기울기 로직 (`TugOfWarPlatformLogic`, Roblox API 없음)
- 각 라운드 레이서의 **로컬 X 위치**(origin 기준, 중심 0, 왼쪽 음수·오른쪽 양수, 발판 절반 길이 35가 끝)를 모아 `Logic.tilt(positions: { number }): number`에 넘긴다.
  - torque = positions의 합(한 명당 무게 1, 중심에서 먼 사람일수록 지렛대가 커서 더 크게 기여 — "수와 위치"를 모두 반영).
  - `angle = clamp(torque * TORQUE_SCALE, -MAX_ANGLE, MAX_ANGLE)`, `TORQUE_SCALE = MAX_ANGLE / SATURATION_TORQUE`.
  - `MAX_ANGLE = math.rad(30)`, `SATURATION_TORQUE = 105`(= 끝(35)에 3명이 뭉쳤을 때 포화 — 한두 명이 끝에 서 있는 정도로는 완전히 기울지 않고, 여럿이 몰리면 빠르게 한계까지 간다).
- 서버는 매 Heartbeat `target = Logic.tilt(positions)`를 구하고 `Logic.approach(current, target, TILT_RATE * dt)`로 **서서히** 따라간다(순간 전환 없음, 무거운 저울이 천천히 움직이는 느낌). `Logic.TILT_RATE = math.rad(20)`(초당 20도).
  - `Logic.approach(current, target, maxDelta)`: 목표 쪽으로 `maxDelta`만큼만 움직이고 **목표를 넘어서지 않는다**(둘 중 가까운 값).
- 사람이 없거나 좌우가 같으면(torque = 0) 서서히 평평(0)으로 돌아온다 — 별도 로직 없이 `Logic.tilt`가 0을 돌려주는 것만으로 충분.

### 연장전 (`overtime(ctx, info)`, m5-01 계약)
- 연장전이 시작되면 **무게 분포를 더 이상 보지 않고**, 전적으로 `Logic.overtimeAngle(elapsed, collapseDuration, startAngle)`이 정하는 각도로 발판을 강제로 돌린다(elapsed = 연장전 시작 기준 경과초, startAngle = 연장전 시작 순간의 실제 각도 — 끊기지 않게 이어서).
- `Logic.overtimeAngle`은 4개의 꺾인점(keyframe)을 선형으로 잇는다: `collapseDuration`을 4등분한 시각마다(기본 20초면 5·10·15·20초) 각도가 **좌우 번갈아(+, -, +, -)** 커지며, 크기는 `MAX_ANGLE`(30°)에서 `LETHAL_ANGLE`(**math.rad(90)**, 완전 수직)까지 똑같이 4등분해 커진다(30°→50°→70°→90°). 중간 시각은 이전 꺾인점과 다음 꺾인점 사이를 1차 보간한다.
  - **90°(수직)를 마지막 꺾인점으로 고정한 이유**: 마찰 계수를 아무리 튜닝해도 "안전한 자리"가 남을 위험이 있는데(Jump Showdown infinite hang류), 발판이 완전히 수직이면 애초에 설 수 있는 수평면이 없다 — 물리 상수에 기대지 않고 **기하학적으로 보장**한다.
  - `collapseDuration`과 무관하게(시간축만 늘어나거나 줄어들 뿐) 마지막 꺾인점은 항상 `elapsed == collapseDuration`에서 각도 크기 정확히 `LETHAL_ANGLE`이다 — 안전 상한 전에 반드시 설 곳이 없어진다는 보장.
  - `elapsed`가 `collapseDuration`을 넘으면(루프가 한 틱 늦게 멈추는 경우 등) 그대로 clamp해서 마지막 꺾인점 각도를 돌려준다(에러 없음).
- 서버는 `overtime` 훅 안에서 기다리지 않는다 — 시작 시각·`startAngle`만 기록해 두고, 기존 Heartbeat 루프(또는 `task.spawn`을 `ctx.cleanup`에 등록한 별도 루프)가 매 틱 `Logic.overtimeAngle`을 불러 발판에 바로 적용한다(`task.wait` 금지, CLAUDE.md "연장전 훅" 절).

### 이동 감시 (`MovementGuard`가 오탐하지 않아야 함)
- 발판 기울기로 인한 미끄러짐은 **서버가 속도·위치를 직접 주는 넉백이 아니라, 발판 CFrame을 돌린 뒤 Roblox 물리(중력·마찰)가 자연히 만드는 연속적인 움직임**이다 — CLAUDE.md "이동 감시 면제" 절의 "벨트·급류·기울기 같은 연속 밀기에는 달지 않는다"에 정확히 해당한다. `RamenRapidsLayout`의 국물 밀기(목표 속도 20 studs/s, `Config.MovementGuard.MaxHorizontalSpeed` 80보다 한참 낮아서 표시 없이도 감시 기준 안)와 같은 근거로, **`MoveExempt.mark`를 달지 않는다**.
- 평평~`MAX_ANGLE`(30°) 구간에서 미끄러지는 수평 속도는 기울기가 완만해서 감시 상한(80 studs/s)에 크게 못 미친다(플레이테스트로 확인, Studio AC12). 연장전 후반(70°~90°)처럼 거의 수직이 되는 구간은 사실상 자유낙하에 가까워 이동 감시가 애초에 보지 않는 "아래로 떨어지는" 움직임으로 잡힌다(`MovementGuardLogic` 머리 주석 "아래로 떨어지는 건 보지 않아요").
- 그래도 혹시 순간적으로 상한을 넘으면(연장전 급격한 전환 순간) 되돌리기가 발동할 수 있으니, Studio AC15에서 Output에 감시 로그가 안 뜨는지 확인한다. 만약 뜨면(B 버그) `MoveExempt.mark(character, 0.5)` 정도의 짧은 면제를 발판이 **연장전 단계로 넘어가는 그 틱에 한해서만** 다는 것으로 개발 메모에 남긴다(상시로 달지 않는다 — 평상시 기울기는 계속 연속 밀기로 둔다).

### 아트 (`TugOfWarPlatformArt.luau`, m4-02 공통 규칙, 장식 예산 파츠 600·파티클 8·조명 12)
- 초밥 테마 유지: 발판 양 끝에 커다란 저울 접시 모양 테두리(장식, 충돌 없음), 가운데 받침대는 나무통에 얹힌 돌절구 느낌, 양 끝에 "줄다리기"를 상징하는 굵은 동아줄 장식(발판 끝에서 바깥으로 늘어진 모양, 충돌 없음). 발판 위에 간장통·초밥 접시 더미를 "추" 삼아 군데군데(장식, 발판과 함께 기울어지게 발판 Model 하위에 둔다). 가게 마당 배경(등불·포렴), `MapKit.introCamera` 4점(발판 전체 → 받침대 → 저울 접시 → 출발 자리).
- 장식은 발판 Model 하위에 두어 `PivotTo`/`CFrame` 회전에 같이 따라가게 한다(조각이 조각과 같이 흔들리는 `SkewerShowdown` 패턴과 동일).

## 범위
- 포함: 위 규칙 전부, 순수 로직 분리(`TugOfWarPlatformLogic`), 레이아웃 상수 분리(`TugOfWarPlatformLayout`), 아트, IntroCamera, `inPool = false` 줄 삭제(랜덤 결승 풀에 들어감 → 이 작업 시점에 `ikura-bombs`가 이미 `done`이면 결승 맵 3개 중 무작위, 아직이면 2개 중 무작위 — Studio AC14에서 실제 상태로 확인).
- 제외: 2축(앞뒤+좌우) 동시 기울기(원형 접시 — "줄다리기"는 좌우 한 축이 테마에 더 맞음, 결정 기록 D1), 발판을 직접 밀거나 당기는 입력(GDD 6 "잡기는 늦추기만" 원칙 유지, 플레이어는 자리 이동으로만 기울기에 영향), 새 효과음 외 소리.

## 수용 기준
### 순수 로직 (lune 테스트, `tests/map-tug-of-war-platform.spec.luau`)
- [ ] AC1: 레이아웃이 `MapTypes.validate` 통과(Final, `overtime` 함수), 스폰 24개가 전부 발판 판정면 위이고 서로 3 이상 떨어져 있으며 왼쪽·오른쪽에 12개씩 있다.
- [ ] AC2: `Logic.tilt`: `{}` → 0, `{0, 0, 0}`(중앙) → 0, `{35, -35}`(양 끝 팽팽히 맞섬) → 0, `{35}`(혼자 오른쪽 끝) → `rad(10)`(= `MAX_ANGLE * 35/105`), `{35, 35, 35}`(셋이 오른쪽 끝에 뭉침) → `MAX_ANGLE`(포화), `{35, 35, 35, 35, 35}`(다섯도 포화, 넘지 않음) → `MAX_ANGLE`, `{-35, -35, -35}` → `-MAX_ANGLE`.
- [ ] AC3: `Logic.approach`: `approach(0, rad(30), rad(20))` → `rad(20)`(목표에 못 미치면 `maxDelta`만큼만), `approach(rad(25), rad(10), rad(20))` → `rad(10)`(목표를 넘어서지 않고 딱 멈춤), `approach(rad(5), rad(5), rad(20))` → `rad(5)`(이미 목표).
- [ ] AC4: `Logic.overtimeAngle(collapseDuration, startAngle)` 꺾인점(기본 20초 기준): `overtimeAngle(0, 20, 0.2)` → `0.2`(시작 각도 유지), `overtimeAngle(2.5, 20, 0)` → `rad(15)`(첫 구간 절반 보간), `overtimeAngle(5, 20, 0)` → `rad(30)`, `overtimeAngle(10, 20, 0)` → `-rad(50)`, `overtimeAngle(15, 20, 0)` → `rad(70)`, `overtimeAngle(20, 20, 0)` → `-rad(90)`.
- [ ] AC5: `overtimeAngle`의 **끝 보장**: `collapseDuration`을 8·20·40으로 바꿔도 `overtimeAngle(collapseDuration, collapseDuration, startAngle)`의 절댓값은 항상 `LETHAL_ANGLE`(`rad(90)`)이고, `elapsed`가 `collapseDuration`을 넘겨도(예: `collapseDuration + 5`) 같은 값을 돌려준다(clamp, 에러 없음).
- [ ] AC6: 무작위 퍼즈: `positions`를 1,000번 무작위(레이서 1~24명, 각자 -35~35)로 뽑아 `Logic.tilt`를 돌려도 결과가 항상 `[-MAX_ANGLE, MAX_ANGLE]` 안이고, 오른쪽 합이 왼쪽 합보다 큰 모든 경우 각도가 음수가 아니다(부호 일관성).
- [ ] AC7: `MapTypes.validate`가 통과, 장식이 `MapKitLogic.validate` 통과, 파츠 600개 이하. `inPool`이 없거나 true다(삭제 확인).
- [ ] AC8: 검증 5단계 통과 + 기존 `maps`·`round-logic` 테스트 통과.

### Studio 확인 (`forceMapPlan = { "rotating-belt", "hot-plate", "tug-of-war-platform" }`, 빠른 연장전은 `DEBUG.overtimeAt = 15`, **확인 뒤 둘 다 nil**)
- [ ] AC9: 결승에서 한쪽 끝에 몰려 서면(혼자 또는 여럿) 그 쪽이 서서히(순간적으로 홱 꺾이지 않고) 아래로 기울고, 반대쪽으로 옮기면 다시 서서히 평평해진다. `Logic.tilt`가 양수를 돌려주는 쪽(오른쪽, +X)이 실제로도 내려간다(부호가 반대면 CFrame 부호를 뒤집는다).
- [ ] AC10: 2명(Clients and Servers)으로 한 명이 일부러 한쪽 끝에 서서 기울기를 키우면 다른 한 명이 그 쪽에 있을 때 미끄러져 떨어질 수 있다(의도적으로 상대를 떨어뜨리는 플레이가 성립). 반대로 둘이 반대편에 적당히 나뉘어 서면 평형에 가까워 오래 버틸 수 있다.
- [ ] AC11: 연장전 시작(기본 90초, 디버그 15초) 순간 배너가 뜨고, 그 뒤로는 사람이 어디 서 있든 발판이 강제로 좌우로 점점 크게(결국 거의 수직까지) 흔들린다. `Config.Final.CollapseDuration`(20초) 안에 누구도 서 있을 수 없어 전원 떨어지고, 더 늦게 떨어진 사람이 우승한다.
- [ ] AC12: 평평~30도 구간에서 미끄러지는 동안 Output에 이동 감시(`MovementGuard`) 경고 로그가 안 뜬다(되돌려지지 않는다). 연장전 후반 급격한 전환에서도 로그가 안 뜨면 그대로 두고, 뜨면 개발 메모에 남긴다(위 "이동 감시" 절의 대안 참고).
- [ ] AC13: 혼자(Play Solo) 결승도 연장전 → 수직 붕괴로 끝난다(멈추지 않는다).
- [ ] AC14: 랜덤 판(강제 플랜 없음, 4명 이상)을 여러 번 하면 결승이 지금 `inPool`인 Final 맵 전부(꼬치 쇼다운 + 연어알 폭탄이 이미 `done`이면 그것까지 + 줄다리기 발판) 중에서 무작위로 나온다.
- [ ] AC15: 휴대폰 에뮬레이터에서 저울 접시·동아줄 장식이 시야를 가리지 않고, 발판이 기울어도 카메라가 심하게 흔들리거나 어지럽지 않다.
- [ ] AC16: 재미 확인(사용자, 친구 테스트): 몰리면 위험하다는 느낌이 들고 "억울하게 미끄러졌다"보다 "자리를 잘못 골랐다"는 느낌. `MAX_ANGLE`·`SATURATION_TORQUE`·`TILT_RATE`·마찰 값을 알려 주면 Layout/Logic 상수만 고친다.

## 공용 파일 변경
- 없음 (m5-13이 등록 완료)

## 사용자 작업 (스펙을 막지 않음)
- AC16 체감. (선택) `assets/map-art/tug-of-war-platform.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · D1 1축 vs 2축(앞뒤+좌우) 기울기 · **1축(좌우, 로컬 X)만.** "줄다리기"는 본래 두 편이 한 축을 따라 당기는 개념이라 좌우 한 축이 테마와 가장 잘 맞고, 2축(원판형)은 이미 연어알 폭탄(원형 접시)이 쓰고 있어 차별화가 떨어진다. 꼬치 쇼다운(각도 판정)·연어알 폭탄(원형 칸)과 다른 "직사각형 시소" 형태로 결승 3개가 서로 다른 모양이 된다. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-09 · D2 연장전 끝 각도를 왜 정확히 90도로 고정했는지 · 마찰 계수를 아무리 낮춰도 "매달리거나 버틸 안전한 자리가 남으면 안 된다"(`MapTypes.luau` 연장전 약속, Fall Guys Jump Showdown infinite hang 교훈, m5-01 결정 기록 D6)는 요구를 **물리 튜닝이 아니라 기하학적으로** 만족시키기 위해서다. 완전히 수직인 발판 위에는 애초에 설 수평면이 없다. · planner
- 2026-10-09 · D3 이동 감시 면제를 왜 안 다는지 · CLAUDE.md "이동 감시 면제" 절이 "벨트·급류·기울기 같은 연속 밀기에는 달지 않는다"(조작 구멍 방지)고 명시하고, `RamenRapidsLayout`이 같은 논리(목표 속도가 감시 상한보다 한참 낮음)로 이미 그렇게 하고 있다. 발판 기울기도 서버가 CFrame만 돌리고 실제 미끄러짐은 Roblox 물리가 만드는 연속적인 현상이라 같은 원칙을 적용했다. 다만 수치 안전망으로 Studio AC12를 넣어, 혹시 감시가 오탐하면 developer가 좁은 범위(연장전 전환 순간만)로 짧은 면제를 고려할 수 있게 열어 뒀다. · planner
- 2026-10-09 · D4 수치 · `MAX_ANGLE` 30도(꼬치 쇼다운 급류 경사 12도보다는 훨씬 크지만, 과반수가 뭉쳐야 포화되게 `SATURATION_TORQUE` 105(끝에 3명)로 조절), `TILT_RATE` 초당 20도(무거운 저울이 서서히 움직이는 느낌, `SkewerShowdown` 꼬치 가속보다는 느림), 연장전 꺾인점 4개·30→50→70→90도(균등 4등분, 마지막이 정확히 수직). **기본값, 플레이테스트 후 조정** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 바뀐 파일
- `src/shared/maps/TugOfWarPlatform.luau` (덮어씀, `inPool = false` 줄 삭제): 발판 1개(`Platform`, 태그 `TugOfWarPlatform`) + 기울 때 같이 움직이는 `PlatformGroup`(발판 파츠 + 무게추 장식), 24개 스폰(왼쪽 12·오른쪽 12), 매 Heartbeat `Logic.tilt`→`Logic.approach`로 서서히 기울기 적용, 연장전은 `Logic.overtimeAngle`로 전환, 낙하 판정은 origin 기준 Y(기울어도 고정 기준)로 `ctx.eliminate`. `MoveExempt.mark` 안 씀(결정 기록 D3, 연속 밀기).
- `src/shared/maps/TugOfWarPlatformLayout.luau` (새 파일): 치수(길이 70·폭 22·두께 2·CENTER_Z -40), 마찰 0.35, 스폰 24개 격자 생성.
- `src/shared/maps/TugOfWarPlatformLogic.luau` (새 파일): `Logic.tilt`, `Logic.approach`, `Logic.overtimeAngle` + 상수(`MAX_ANGLE` 30°, `SATURATION_TORQUE` 105, `TILT_RATE` 20°/s, `LETHAL_ANGLE` 90°). Roblox API 없음.
- `src/shared/maps/TugOfWarPlatformArt.luau` (새 파일): `deckDecor()`(저울 접시 테두리·동아줄·무게추, 발판과 같이 기울어짐), `decor()`(받침대·가게 마당 배경, 고정), `introCamera()`.
- `tests/map-tug-of-war-platform.spec.luau` (새 파일): AC1~AC7 순수 로직 테스트 (24개 전부 통과).
- 기존 테스트 갱신(맵 풀이 6→7개로 늘어난 영향, tug-of-war-platform이 껍데기에서 실제 맵으로 바뀐 영향): `tests/maps.spec.luau`, `tests/m4-foundation.spec.luau`, `tests/m4-12-hardening.spec.luau`, `tests/m5-03-foundation.spec.luau`.

### 구현 메모
- 부호: `Logic.tilt`가 양수를 돌려주면 로컬 +X가 내려가야 하는데, `CFrame.Angles(0,0,z)`는 양수일 때 +X를 올리는 방향이라 `TugOfWarPlatform.luau`의 `TILT_SIGN = -1` 상수로 뒤집어 뒀어요. **AC9에서 반대로 보이면 이 상수 하나만 뒤집으면 돼요.**
- 발판·장식의 CFrame 갱신은 `SkewerShowdown.luau`의 `moveFood` 패턴과 같아요: build 때 flatPivot(원점 기준 CENTER_Z 지점, 기울지 않은 상태) 기준 오프셋을 한 번만 계산해 두고, 매 틱 `pivotCFrame * offset`을 `workspace:BulkMoveTo`로 적용해요. 넉백·순간이동 없음.
- 타입 검사에서 두 가지를 고쳤어요(참고용): `CFrame:ToObjectSpace(...)`가 가변 반환(`...CFrame`)이라 `table.insert`의 마지막 인자로 바로 쓰면 인자 수가 흔들려서 괄호로 값 하나만 받게 했고, `table.create(n)`은 요소 타입을 못 정해서 `:: { CFrame }`로 캐스팅했어요(SkewerShowdown과 동일 패턴).

### Studio 확인 (사용자, 아직 안 함 — AC9~AC16)
`docs/specs/m5-18-map-tug-of-war-platform.md`의 "Studio 확인" 절 그대로. `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "tug-of-war-platform" }`, 빠른 연장전 확인은 `Config.DEBUG.overtimeAt = 15` (확인 뒤 둘 다 nil로 되돌리기). 특히:
- AC9: 몰린 쪽이 서서히 내려가는지, 부호가 맞는지(반대면 `TILT_SIGN` 뒤집기).
- AC12: 평평~30도 구간에서 미끄러질 때 Output에 `[MovementGuard]` 류 경고가 안 뜨는지.
- AC14: ikura-bombs(m5-04)가 아직 `ready`라 지금은 결승 맵이 꼬치 쇼다운 + 줄다리기 발판 2개 중 무작위예요. ikura-bombs가 `done`이 되면 3개 중 무작위가 돼요.

### 남은 이슈
- 없음(알려진 버그 없음). 수치(`MAX_ANGLE`·`SATURATION_TORQUE`·`TILT_RATE`·마찰 0.35)는 전부 스펙 기본값 그대로이고, Studio 플레이테스트(AC16) 뒤 Layout/Logic 상수만 조정하면 돼요.
- 클라우드/CI 환경에서 Studio 확인(AC9~AC16)은 수행하지 못했습니다 — 위 절차로 사용자가 직접 확인해야 합니다.
