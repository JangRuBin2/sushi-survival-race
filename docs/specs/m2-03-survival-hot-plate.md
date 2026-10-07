status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m2-03 — Survival 맵 "뜨거운 철판" (회색 박스)

- 마일스톤: M2
- GDD 근거: `docs/GDD.md` §5.2 ⑤, §5.2 Survival 공통("떨어지면 탈락", 최대 60초), §11.4(`HotTile` 태그)
- 담당 개발 worktree: `m2-hot-plate` (Rojo 포트 34874)
- 공용 파일 수정 담당: 없음
- 의존: **m2-01 머지 후 시작** (stub `src/shared/maps/HotPlate.luau`). m2-02, m2-04~m2-06과 동시에 개발 가능.

## 목표
첫 Survival 맵. 밟은 철판 타일이 달아올라 사라지니 계속 움직여야 하고, 3층이라 떨어져도 아래층에서 한 번 더 기회가 있다. 맨 아래층에서 떨어지면 탈락.

## 범위
- 포함 (이 worktree가 고치는 파일: `src/shared/maps/HotPlate.luau`, 새 파일 `src/shared/maps/HotPlate*.luau`, 새 파일 `tests/map-hot-plate.spec.luau`(선택))
  - **구조**: 같은 크기의 층 3개를 위아래로 쌓는다. 층 사이 높이 18~24 studs.
    - 층마다 정사각 타일 격자. 초기값 9×9 타일, 타일 한 변 6 studs(층 54×54 studs), 두께 1. 타일 사이 틈 없음.
    - Survival은 2라운드 이후라 최대 인원이 16명(24명 방의 2라운드)이다. 16명이 맨 위층에 서도 붐비지 않는 크기.
    - 맨 위층 위에 `Spawns` 24개 (CanCollide false 표시용 파츠, 위층 전체에 고르게 흩어짐).
    - 층 가장자리에 벽은 없다 (밖으로 떨어지는 것도 탈락 경로). 대신 위층에서 밖으로 떨어지면 아래층 범위 밖이라 바로 바닥 아래로 떨어진다 — 그래도 괜찮다.
  - **`HotTile` 태그 타일 동작 (서버 판정)**:
    - 레이서가 타일 위에 **올라서는 순간** 그 타일이 달아오르기 시작한다(서버에서 레이서 발밑 판정 — 레이캐스트나 영역 검사, 클라 신호 아님).
    - 1.5초에 걸쳐 회색 → 주황 → 빨강으로 색이 변하고, 1.5초가 되면 사라진다(`CanCollide = false`, 투명). 위에 있던 플레이어는 아래로 떨어진다.
    - 한 번 달아오르기 시작한 타일은 그 위에서 내려와도 멈추지 않는다. 사라진 타일은 그 라운드에서 다시 생기지 않는다.
  - **판정**: 레이서의 HumanoidRootPart가 **맨 아래층보다 15 studs 아래**로 내려가면 `ctx.eliminate(player)`. 결승선은 없다 (`ctx.pass`를 부르지 않는다 — 통과자 결정은 `RoundService`가 한다).
  - 모든 연결·스레드는 `ctx.cleanup`에. 상태는 `ctx`/지역 변수에 (여러 방 동시 진행).
  - 태그 규칙은 확정된 B10 (A)를 따른다: `ctx.model` 하위의 `HotTile` 태그 파츠만 동작.
  - 코스 축 약속(로컬 -Z)은 Survival에서는 쓰지 않지만, Model은 origin 근처에 지어 다른 맵과 같은 아레나 영역을 쓴다.
- 제외:
  - 시간 종료 처리 → `RoundService`(**m2-05**). 확정: 폴가이즈 서바이벌처럼 **시간 끝까지 버틴 사람 전원 통과**. 그래서 이 맵은 60초 동안 타일이 충분히 줄어들어 대부분 판에서 누군가는 떨어지도록 만든다.
  - 타일 달아오르는 소리·연기 (M3), 철판 아트 (M4)

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `Maps.get("hot-plate")`이 `MapTypes.validate`를 통과하고 kind가 `Survival`이다 (m2-01 maps.spec).
- [ ] AC2: `lune run tests` 전체 통과 (require만으로 Roblox API를 부르지 않는다).
- [ ] AC3 (선택, 헬퍼를 분리했다면): 타일 색 계산 함수가 0초 → 회색, 0.75초 → 주황 계열, 1.5초 → 빨강, 1.5초 이상 → "사라짐"을 돌려준다.

### Studio 확인
구조: Command bar로 `Maps.get("hot-plate").build(CFrame.new(0,10,0))`. 동작: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`로 혼자 시작해서 2라운드에서 확인.
- [ ] AC4: 지은 Model에 층 3개가 있고 각 층에 `HotTile` 태그 타일이 81개(9×9, 초기값을 바꿨다면 그 개수)씩 있다. `Spawns` 24개가 맨 위층 위에 흩어져 있다.
- [ ] AC5: 라운드가 시작되면 캐릭터가 맨 위층에 서 있다. 가만히 서 있으면 발밑 타일이 약 1.5초에 걸쳐 빨갛게 변하고 사라져서 아래층으로 떨어진다.
- [ ] AC6: 타일을 밟고 바로 지나가도, 지나간 타일들이 순서대로 빨개져 사라진다 (다시 생기지 않는다).
- [ ] AC7: 맨 위층에서 떨어지면 둘째 층에 착지해서 계속 플레이할 수 있다. 맨 아래층에서 떨어지면 잠시 뒤 "🥢 탈락했어요…"가 뜬다.
- [ ] AC8: 플레이어 4명(Test → Clients and Servers)으로 `forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" }`(철판을 1라운드로, 목표 2명)으로 돌리면, 떨어진 사람 수만큼 탈락하고 남은 인원이 목표 이하가 되는 순간 라운드가 끝난다. 남은 사람은 통과 안내를 받는다.
- [ ] AC9: 다른 사람이 밟아서 달아오른 타일 위에 내가 올라가도, 그 타일은 처음 밟힌 시각 기준 1.5초에 사라진다 (두 번 밟는다고 리셋되지 않는다).
- [ ] AC10: 라운드가 끝나면 맵 Model이 사라지고, 서버 Output에 에러가 없다. 같은 서버에서 두 방이 동시에 이 맵을 돌려도 한 방의 타일이 다른 방에 영향을 주지 않는다 (m2-07에서 같이 확인해도 됨).

## 공용 파일 변경
- `shared/Config.luau`: 없음
- `shared/Remotes.luau`: 없음

## 결정 기록
- 2026-10-08 · "서 있으면 달아오르다가 1.5초 뒤 사라져요"의 해석 · 올라서는 순간부터 1.5초 카운트, 내려와도 멈추지 않음, 재생성 없음 (GDD "계속 움직여야 살아요"와 같은 결) · planner (사용자 이의 시 변경)
- 2026-10-08 · 층 크기·높이 · 9×9 타일(6 studs), 층 간격 18~24 studs를 초기값으로. 플레이테스트로 조정 · planner
- 2026-10-08 · **확정 Q1** (메인 세션 경유) · 중간 Survival은 시간 끝까지 버틴 사람 전원 통과. 결승은 생존형으로 바뀌었지만 이 맵은 중간 Survival로 남는다 (m2-05 Q8 추천안 기준) · user

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 바뀐 파일
- `src/shared/maps/HotPlate.luau` (stub 덮어씀): 실제 맵.
  - `build`: Model 아래 `Layer1`(맨 위)·`Layer2`·`Layer3` 폴더, 각 81개 `Tile01`~`Tile81` (6×1×6, DiamondPlate, `HotTile` 태그, 속성 `Layer`). 층 윗면 높이 0 / -20 / -40 (origin 기준), 철판 중심은 로컬 z = -27 (origin 앞쪽). `Spawns`에 `Spawn01`~`Spawn24` (맨 위층에 6×4 칸으로 고르게, CanCollide/CanTouch/CanQuery false). 벽 없음.
  - `start`: `CollectionService:GetTagged("HotTile")`을 `ctx.model:IsAncestorOf`로 걸러 이 방 타일만 씀 (B10 (A)). Heartbeat 하나에서
    1) 레이서 HumanoidRootPart가 맨 아래층 윗면보다 15 studs 아래(로컬 y < -55)면 `ctx.eliminate`.
    2) 발밑 판정: 루트 중심과 앞뒤좌우 ±0.9 studs, 5개 지점에서 아래로 4.5 studs 레이캐스트(이 방 타일만 Include). 닿은 타일은 처음 밟힌 시각을 기록 — 이미 달아오르는 타일은 리셋 안 됨, 내려와도 계속 진행.
    3) 달아오르는 타일 색을 0.1초 단위로 갱신, 1.5초가 되면 `Transparency 1`, `CanCollide/CanQuery false` (재생성 없음).
  - 상태(`heatStart`, `colorStep`, `gone`)는 `start` 지역 변수, 연결은 `ctx.cleanup`. `ctx.pass`는 부르지 않음. `cleanup` 함수 없음(모델은 RoundService가 지움).
- `src/shared/maps/HotPlateLogic.luau` (새, 순수 로직): 치수 상수(3층, 9×9, 타일 6, 간격 20, 탈락 깊이 15, 스폰 24), `heatVisual(elapsed) -> (rgb, gone)`(0초 회색 163,162,165 → 0.75초 주황 255,140,0 → 1.5초 빨강 220,30,0, 1.5초 이상 gone), `tileOffsets`, `spawnOffsets`, `layerTopY`, `centerZ`, `eliminationY`.
- `tests/map-hot-plate.spec.luau` (새): AC1, AC3, 색이 빨강 쪽으로만 변함, 층/타일 81개 틈 없음/층 간격 범위, 스폰 24개 분포, 탈락 높이. 6 passed.
- 공용 파일 변경 없음. `StubMap.luau`는 그대로 둠 (다른 stub이 아직 씀).

### 검증
`rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests` → 빌드 성공, stylua 통과, selene 0 errors/0 warnings, **100 passed, 0 failed**.

### Studio 확인 방법 (사용자 확인 필요)
- AC4: Play(F5) 중 서버 Command bar에서
  `local m = require(game.ReplicatedStorage.Shared.maps).get("hot-plate").build(CFrame.new(0,10,0)); m.Parent = workspace; for i=1,3 do print(m["Layer"..i].Name, #m["Layer"..i]:GetChildren()) end; print(#m.Spawns:GetChildren(), #game:GetService("CollectionService"):GetTagged("HotTile"))`
  → Layer1~3 각 81, Spawns 24, HotTile 243. 노란 스폰 판이 맨 위층 전체에 흩어져 있는지 눈으로 확인.
- AC5~AC7, AC9: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`로 혼자 시작 → 2라운드. 가만히 서 있으면 발밑 타일이 회색→주황→빨강 후 약 1.5초에 사라지고 아래층으로 떨어짐. 뛰어다니면 지나간 타일이 차례로 사라짐. 맨 아래층에서 떨어지면 "🥢 탈락했어요…". (AC9는 2인: 한 명이 밟은 타일에 다른 사람이 늦게 올라가도 처음 밟힌 시각 기준으로 사라지는지.)
- AC8: Test → Clients and Servers 4명, `forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" }` → 목표 2명. 두 명이 떨어지는 순간 라운드 종료, 남은 두 명 통과 안내.
- AC10: 라운드 종료 후 Workspace에서 `Round*_hot-plate` 모델이 사라지고 Output에 에러 없음. 두 방 동시 진행은 m2-07에서.
- 확인 뒤 `forceMapPlan`은 `nil`로 되돌린다.

### 남은 이슈 / 알아둘 점
- **시간 종료 처리(m2-05 범위)**: 지금 main의 `RoundService.finish(isTimeout=true)`는 Survival도 `settleLeftover`로 목표 인원까지만 통과시키고 나머지를 탈락시킨다. 확정 Q1("시간 끝까지 버틴 사람 전원 통과")은 m2-05가 고칠 부분이라 이 worktree에서는 건드리지 않았다. m2-05 머지 전 Studio에서 60초를 버티면 목표 초과 인원이 탈락으로 보일 수 있다.
- 발밑 판정은 "서 있을 때"만(레이 길이 4.5) 잡는다. 점프 중 공중에 떠 있는 동안은 타일이 달아오르지 않는다 — 계속 점프만 하면 착지할 때만 달아오름. 의도와 맞는지 플레이테스트로 확인 필요.
- 위층 가장자리에서 밖으로 떨어지면 아래층 범위 밖이라 바로 탈락 깊이까지 떨어진다 (스펙상 허용).
- 수치(층 간격 20, 9×9, 1.5초)는 초기값. 60초 안에 누군가 떨어지는지는 다인원 플레이테스트로 조정.

### 인계 메모 (2026-10-08)
- 브랜치: `worktree-m2-hot-plate` (base `03d752a`, 구현 커밋 `ca87607`). push됨.
- 끝난 것: 스펙 범위 구현 전부. 검증 4종 통과(100 passed). 상태 `in-qa`.
- 남은 것: QA 결과 대기. Studio 확인 AC4~AC10은 사용자 확인 필요.
- 다음 첫 단계: `docs/qa/m2-03-survival-hot-plate.md`가 생기면 읽고, P0/P1이 있으면 그 버그부터 고친다. 없으면 할 일 없음.
- 막힌 점: 없음. Survival 시간 종료(남은 사람 전원 통과)는 m2-05 담당이고 메인 세션이 m2-05에 전달했다.
