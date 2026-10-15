# QA — m5-38 새 결승 맵: 찻잎 정원 (`tea-garden`)

- 스펙: `docs/specs/m5-38-map-tea-garden.md`
- 검증 커밋: `6587818`(구현·아트) · `298c00b`(아트 반복 2~3·렌더·개발 메모), 브랜치 `m5-map-tea` (worktree `.claude/worktrees/agent-a4d9be83482554432`)
- 결과: **통과** (P0/P1/P2 없음, P3 없음, 참고 2건) → 스펙 `qa-passed`

## 자동 검증 (2026-10-15, Windows, QA 테스트 추가 뒤 다시 돌림)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공 (끝 코드 0) |
| `stylua --check src tests tools` | 통과 (끝 코드 0) |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests` | **2034 passed, 0 failed** (개발 2030 + QA 4), 끝 코드 0 |
| `luau-lsp analyze … --flag:LuauSolverV2=true src` | 끝 코드 0 |
| `lune run tools/render-map tea-garden --view all --quality fast` | decor 1133/1500, 조명 6/24(그림자 1/2), 파티클 12/16, anim 37/80, void 최대 4% (개발 메모와 같음) |

공용 파일: `git diff origin/main --stat` — 바뀐 파일은 `TeaGarden*.luau` 4개, `tests/map-tea-garden.spec.luau`, `docs/renders/tea-garden/*`, 스펙, 개발 메모뿐. `Config`·`Remotes`·`Types`·`Attributes`·`maps/init`·`MapTypes`·`SfxCues`·`SfxLibrary`·`MapFxPresets`·`default.project.json`·init 스크립트 변경 없음.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-tea-garden` AC1 4개(validate·Final·overtime·lighting = `Art.LIGHTING`, 단 표, 조각 5×12 `Ring`, 스폰 24 3·4단 서로 3 이상) |
| AC2 | 통과 | `map-tea-garden` AC2(심 20 − 6 > 6.4 + 5, 반지름 47 밖 충돌 파츠 없음). QA 1·3이 장식(Decor)까지 포함한 전체 충돌 파츠 수를 세어 장식이 충돌을 갖지 않음도 확인(89초 = 정확히 25 = 조각 24 + 심) |
| AC3 | 통과 | `map-tea-garden` AC3 |
| AC4 | 통과 | `map-tea-garden` AC4 + **QA 1**: 실제 소스를 가짜 시계로 돌려 보이는 찻잔 수 t=1·2.9 → 0, 10·25 → 1, 40 → 2, 70·100.5 → 3, +20 뒤 0, 선속도 13/16/18(오차 < 0.2) |
| AC5 | 통과 | `map-tea-garden` AC5 4개(1,000번 포함) + **QA 1·4**: 0 → 112초 동안 매 프레임 찻잔이 무너진 단 위를 구르는 일이 0번 |
| AC6 | 통과 | `map-tea-garden` AC6 + **QA 2**: 실제 소스에서 찻잔 자리의 레이서 → `MoveExemptUntil = now + 1.5`, `PlatformStand` 0.8초, `LinearVelocity` 위 18·수평 √(26²+12²), 0.12초 뒤 제거, 쿨다운 1초 안 재피격 없음·뒤에는 다시 맞음, 발 = 윗면 + 6.05면 안 맞음, 옆 단(2단 안쪽 끝)은 안 맞음 |
| AC7 | 통과 | `map-tea-garden` AC7 모의 실행 3개 + **QA 1**(시간 순서대로: 89초 25 → +10.5초 13 → +18초 13 → +20.2초 **0**, 장식 포함) + **QA 4**(3단 경고 중 43초에 연장전 → 45초 3단, +10 2단, +20 0) |
| AC8 | 통과 | `map-tea-garden` AC8 5개 + 소개 카메라 테스트. `inPool` 줄 없음(`TeaGarden.luau:956~965`) |
| AC9 | 통과 | 위 자동 검증 표(QA가 직접 실행). `maps`·`round-logic`·`movement-guard`·`m5-23-qa`·`m5-24-qa`·`m5-33-batch3`·`m5-33-qa` 모두 통과 |
| AC10 | 통과 | 개발 메모 반복 1~3 체크리스트 18개 비평(마지막 18개 "예", 15번은 경고 띠 임시 렌더로 확인), before 5장·after 10장 커밋, void 최대 4%(QA 재렌더로 같은 값), 시트 비교 표 6항목 + 분위기, 휴대폰 메모(벚꽃 138파츠 + 숲 30, Petals 5개 Rate 3). QA가 after-overview·intro-01·eye·mobile을 직접 봄 — 계단·찻사발·찻잔·정자·벚꽃이 읽힘 |
| AC11~AC16 | 사용자 확인 필요 | 아래 체크리스트 |

### 결정 기록 D6~D12 확인
| 결정 | 판단 | 근거 |
|---|---|---|
| D6 이웃 단 = 갈 수 있는 단 중 바로 안·바깥, 무너진 단은 건너뜀 | 스펙과 맞음 | 스펙 "이웃 단(무너지지 않았고 4초 안에 무너지지 않는 단)"을 구체화. `TeaGardenLogic.luau:286~332` |
| D7 지금 단이 4초 안에 무너지면 바로 옮김, 갈 곳 없으면 그대로 | 스펙과 맞음 | AC12 "무너진 단으로는 찻잔이 안 간다"를 지키는 유일한 방법. 경고 1.2 + 이동 0.5 = 1.7 < 4. QA 1·4가 매 프레임으로 확인 |
| D8 새 찻잔이 1단에 잠깐 겹칠 수 있음 → 다음 판단에서 꼭 옮김 | 스펙과 충돌 없음 | 스펙의 "겹치지 않게 고른다"는 단 옮기기 선택 규칙이고, 새 찻잔은 "1단에 들어온다"로 정해져 있음. 찻잔은 충돌 없는 물체라 겹침이 판정에 영향 없음 |
| D9 연장전은 경고 전(Solid) 단만 다시 잡고, 경고 중인 단은 본 경기 시각 | 스펙과 맞음 | 스펙 "디버그 overtimeAt이 일러 3~5단이 남아도 같은 20초 안에 전부". 경고 중인 단은 3초 안에 어차피 무너짐. QA 4(43초 연장전)와 개발 테스트(이른 연장전)로 확인. +collapseDuration에 남은 단 전부 + 심 + 찻잔을 끄는 안전망도 있음 |
| D10 조각 = 바깥 현 폭 상자, 같은 단 안쪽 겹침, 밑면 −6, Grass + Plastic 물성 | 스펙과 맞음 | 스펙 "상자로 근사, 틈 ≤ 0.5" — 틈 0. 이웃 단 상자는 공유 현 평면에서 맞닿고 겹치지 않음(위 단 상자는 자기 12각형 안). Plastic 물성으로 발 느낌이 다른 맵과 같음 |
| D11 소개용으로 Cup1을 build에서 1단에 세워 두고 start가 숨김 | 스펙과 충돌 없음 | 소개 카메라 ② 요구를 채우는 연출만. 찻잔은 충돌 없음, `start`가 숨기고 찻사발 안으로 옮김(QA 1: t=1 보이는 찻잔 0) |
| D12 경고 = 바깥 가장자리 띠 폭 2 + 흰 테두리 0.4, 0.2초 깜빡임·흔들림, 찻잎 이미터 1개 | 스펙과 맞음 | 스펙 "주황-빨강 + 흰 테두리 깜빡임, 경고 파츠 흔들림 — 판정 조각은 그대로". 경고 파츠는 `noCollide`(`TeaGarden.luau:107,117`) |

GDD §5.3 표(225줄)·연장전 문장(228줄)과도 맞음(한 단을 도는 찻잔·6초 단 옮김·15초 붕괴·+10/+20).

## 버그
P0/P1/P2/P3 없음.

### 참고 (버그 아님, AC16 손맛 확인 때 볼 것)
1. **연장전 +6초에 찻잔이 몰려 1단에 모임**: 300개 시드로 돌려 보니(QA 임시 탐침, 커밋 안 함) 2단이 +10초에 무너지기 4초 전(+6초)에 2단 찻잔이 모두 1단으로 옮김(D7). 그 직전(+1~+3초)에 2단으로 막 옮겨 간 찻잔은 2.5초 만에 다시 옮겨 감. +6 ~ +20초 동안 1단(반지름 7~15)에 찻잔 3개가 속도 18로 돌아 결승이 빨리 끝날 수 있음 — 스펙 의도(연장전 마무리)와 맞지만 너무 가혹하면 `TeaGardenLogic`의 `OVERTIME_CUPS`·`OVERTIME_SPEED`로 조정.
2. **렌더 overview 뷰**: 렌더러의 overview 카메라가 장식 전체(먼 산 공 포함 1437×1377)를 담아서 정원이 화면 위쪽에 작게 보임. 판정·게임 화면(intro·eye·mobile)에는 영향 없음. Studio에서 먼 산(분홍 공)이 덩어리처럼 떠 보이는지만 같이 확인.

## 확인한 항목 (요청 체크)
- **연장전 훅**: `task.wait` 없음(소스·모의 실행 `waits == 0`). 연장전의 `task.delay` 5개(경고·무너짐 2단씩 + 끝 1)가 모두 `ctx.cleanup`에(QA 1이 가짜 `task.delay`의 반환값이 전부 `ctx.cleanup`에 있는지 확인). 훅은 바로 반환. 라운드가 끝났으면(`isActive` false) 바닥을 건드리지 않음. `start`가 실패해도 `newState`로 무너뜨림.
- **설 곳 0 (m5-18 B1 교훈)**: +collapseDuration 뒤 `Spawns`·`IntroCamera`를 뺀 **모든** CanCollide 파츠(조각 장식·정원 장식 포함)가 0. 찻사발 심은 처음부터 윗면 20(1단 6 + 점프 6.4보다 7.6 높음), 찻잔·경고 띠·점선 호·찻잎 홀더·찻사발 빛은 처음부터 충돌 없음, 정원 밖 장식은 `MapKit.buildDecor`(충돌·쿼리·터치 없음). 찻잔 넉백은 바깥 12 + 위 18(최고 약 0.8 studs)이라 심 위로 올려 보낼 수 없음.
- **찻잔 넉백·MoveExempt**: `knock`(`TeaGarden.luau:716~734`)이 `MoveExempt.mark(character, 1.5)` 뒤 `LinearVelocity` 0.12초. QA 2가 실제 속성 값을 확인. 돌연변이(`MoveExempt.mark` 줄 삭제)를 QA 2가 잡음.
- **판정이 서버에만**: 찻잔 위치·맞음·낙하·붕괴 모두 `start`의 서버 Heartbeat와 `task.delay`. 클라이언트 코드·리모트 변경 없음. 찻잔은 충돌 없는 표시물이고 판정은 숫자(`Logic.cupHit`).
- **모듈 수준 상태**: 가변 상태는 `roundStates[ctx]` 하나(라운드 끝에 `ctx.cleanup`이 지움). `TeaGardenArt`·`Layout`·`Logic`은 상수와 함수뿐. QA 3이 같은 모듈로 두 방을 동시에 돌려 한 방의 연장전이 다른 방의 바닥(25)·찻잔(3)을 건드리지 않음을 확인.
- **`ctx.model` 하위 태그만**: `taggedInModel(ctx.model, tag)`(`TeaGarden.luau:294`)로만 `TeaTerrace`·`TeaBowlCore`·`TeaRollingCup`을 찾음. `CollectionService:GetTagged` 안 씀.
- **아트**: Extended 예산 안(1160/1500 목록 합, 런타임 이미터 1 포함), 조각·찻잔 하위 장식 `anim`·`light` 없음, 판정 파츠(조각 크기·위치·CanCollide, 심)는 `Layout` 값 그대로이고 아트는 색·재질(Grass, 물성은 Plastic)만. before/after PNG 커밋됨.
- **QA 돌연변이 확인** (복사 없이 작업 트리에서 바꾸고 `git checkout`으로 되돌림): ① `MoveExempt.mark` 삭제 → QA 2 실패 ② 연장전 끝 `core.CanCollide = false` 삭제 → QA 3개 + 개발 3개 실패 ③ 일어나기 `task.delay`를 `ctx.cleanup`에서 뺌 → QA 2 실패(개발 테스트는 못 잡음) ④ `safeRings` 4초 창을 없앰 → QA 2개 + 개발 1개 실패.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가·변경하지 않음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 낙하(로컬 y < −25)·찻잔 맞음 모두 서버 Heartbeat, 우승은 RoundService
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `roundStates[ctx]`, QA 3
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 연결·모든 `task.delay`·`LinearVelocity`·찻잎 홀더가 `ctx.cleanup`(QA 1·2)

## 사용자 Studio 확인 체크리스트 (AC11~AC16)
준비: `src/shared/Config.luau`에서 `DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "tea-garden" }`. **확인이 끝나면 `forceMapPlan = nil`, `overtimeAt = nil`로 되돌린다**(커밋 값 고정 테스트가 있음).
1. **(AC15 소개·조명)** Play(혼자). 3라운드 소개에서 노을 정원 → 찻사발과 1단의 찻잔 → 벚꽃 아래 → 바깥 5단 → 출발 자리 순서로 카메라가 지나가는지, 카메라가 찻주전자·나무를 뚫지 않는지. 조명이 해 질 녘(분홍 안개)으로 바뀌는지.
2. **(AC11 찻잔)** 출발 뒤 1.5초에 찻사발 아래가 금빛으로 깜빡이고 3초에 흰+남색 찻잔이 굴러 나와 1단을 도는지. 약 6초마다 찻잔이 노랗게 빛나고 옆 단에 노란 점선이 생긴 뒤 0.5초에 그 단으로 옮기는지. 찻잔과 같은 단에 서 있으면 맞아 날아가 넘어지고(약 0.8초), 한 단 위·아래로 옮기면 안 맞는지. 제자리 점프로는 못 넘는지.
3. **(AC14 이동 감시)** 찻잔에 여러 번 맞은 뒤 Output 창에 `[MovementGuard]` 경고·되돌림이 없는지.
4. **(AC12 붕괴)** 12초부터 가장 바깥 단 가장자리가 주황-빨강·흰 테두리로 깜빡이며 찻잎이 날리고 15초에 내려가며 사라지는지. 30초 4단, 45초 3단. 무너진 단 위로 찻잔이 가지 않는지. 30초에 찻잔 2개, 60초에 3개가 되고 빨라지는지.
5. **(AC13·AC14 연장전)** 빠른 확인은 `DEBUG.overtimeAt = 50`. 50초에 연장전 배너 → +10초에 2단, +20초에 1단이 무너지고 찻잔이 사라지며 모두 떨어지는지. 혼자면 연장전으로 끝나 우승 연출, 탈락 연출은 셰프 손. 2명(Test → Clients and Servers, 2명)이면 늦게 떨어진 사람이 우승하는지.
6. **(AC13 버티기 자리)** 연장전 막바지에 찻사발 위로 뛰어오르거나, 정원 밖 찻주전자·정자·벚꽃나무·다리 쪽으로 뛰어 매달리거나 올라설 수 없는지(전부 통과해서 떨어져야 함).
7. **(AC15 휴대폰)** Studio 기기 에뮬레이터(휴대폰 가로)에서 단 경계·경고 띠·찻잔이 잘 보이는지, 라운드가 끝나면 로비 조명으로 돌아오는지. 먼 산(분홍 공)이 떠 보이지 않는지(참고 2).
8. **(AC16 재미)** 친구와 몇 판: 결승이 보통 50~100초에 끝나는지, "단을 옮겨 피하기"가 꼬치 쇼다운(막대 점프)과 다르게 느껴지는지. 연장전 1단에 찻잔 3개가 몰리는 게 너무 가혹한지(참고 1). 수치는 `TeaGardenLogic` 상수만 고친다.

## 추가한 테스트
- `tests/m5-38-qa.spec.luau` (4개) — 가짜 시계(`os.clock`)·시간 순서 delay·프레임 Heartbeat로 실제 `TeaGarden.luau`를 돌림
  - QA 1: 0 → 112초 한 판(연장전 90초) — 찻잔 수 0/1/2/3/0, 선속도 13/16/18, 매 프레임 무너진 단 위 찻잔 0, 충돌 파츠(장식 포함) 25 → 13 → 0, 모든 `task.delay`·Heartbeat 연결이 `ctx.cleanup`
  - QA 2: 찻잔 넉백 — `MoveExemptUntil` 1.5초, `PlatformStand` 0.8초, `LinearVelocity` 18 + √(26²+12²) 0.12초, 쿨다운 1초, 점프(발 ≥ 윗면 + 6)·옆 단은 안 맞음, 넉백 delay도 `ctx.cleanup`
  - QA 3: 두 방 동시 실행 — 한 방 연장전이 다른 방 바닥·찻잔을 안 건드림
  - QA 4: 3단 경고 중(43초) 연장전 — 45초 3단, +10 2단, +20 설 곳 0, 찻잔 사라짐

## 인계 메모 (2026-10-15, QA)
- **브랜치**: `m5-map-tea` (worktree `.claude/worktrees/agent-a4d9be83482554432`). QA 커밋 push 함.
- **끝난 것**: 수용 기준 AC1~AC10 통과, 결정 D6~D12 확인, QA 테스트 4개 추가, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio AC11~AC16(위 체크리스트), 소리 id(`TeaCupRoll`·`TeaFieldCrumble`, USER-TODO A2). main 병합(메인 세션) — 병합 뒤 검증 5단계 다시(다른 배치 3 맵과 같은 시점 병합이면 m5-33 QA P3-1 `#Maps.infos() == 21` 고정).
- **다음에 할 첫 단계**: 메인 세션이 `m5-map-tea`를 main에 병합하고 검증 5단계를 다시 돌린다.
- **막힌 점**: 없음.
