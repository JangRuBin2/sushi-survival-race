# QA — m2-03 Survival 맵 "뜨거운 철판"

- 스펙: `docs/specs/m2-03-survival-hot-plate.md`
- 검증 커밋: `ca87607` (브랜치 `worktree-m2-hot-plate`, 위에 인계 메모 커밋 `ce70d83`. 코드 동일)
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. Studio 확인(AC4~AC10)은 사용자 확인 필요.
- 범위 메모: Survival 시간 종료 "버틴 사람 전원 통과"는 m2-05 범위라 이 스펙의 실패로 보지 않았다 (스펙 "제외", 개발 메모에도 명시).

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 108 passed, 0 failed (개발 100 + QA 추가 8) |

이 브랜치가 base(`03d752a`)에서 바꾼 `src`는 `src/shared/maps/HotPlate.luau`, `src/shared/maps/HotPlateLogic.luau` 두 파일뿐이다. 공용 파일(Config, Types, maps/init, Remotes, default.project.json)은 바뀌지 않았다 → 스펙의 "이 worktree가 고치는 파일"을 지켰다.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m2-03 AC1: hot-plate는 인터페이스를 지키는 Survival 맵`, m2-01 `maps.spec` (id·이름·규칙 확정값 그대로) |
| AC2 | 통과 | 전체 통과. `HotPlate.luau`의 모듈 최상위에는 Roblox API가 없다 (`Vector3`·`RaycastParams`·서비스는 `build`/`start` 안에서만, `PROBE_OFFSETS_XZ`는 숫자 테이블) |
| AC3 | 통과 | `m2-03 AC3: 0초 회색, 0.75초 주황, 1.5초 빨강이면서 사라짐`. QA 추가: `heatVisual: 1.5초 전에는 절대 사라지지 않고, 1.5초부터는 항상 사라져요`, `음수 경과…`, `RGB가 항상 0~255 정수예요` |
| AC4 | 사용자 확인 필요 | 코드: 층 폴더 `Layer1~3` × `Tile01~81`(9×9, 6×1×6, `HotTile` 태그), `Spawns` 24개를 맨 위층 위에 6×4로 배치 (`HotPlate.luau:46-86`). 순수 치수는 `층 3개, 층 간격 18~24, 층마다 9×9 타일이 틈 없이…`, `스폰 24개가 맨 위층 안에 고르게…`, QA `공정성: 스폰 24개가 전부 서로 다른 타일 위에 있어요` |
| AC5 | 사용자 확인 필요 | 서버 Heartbeat에서 레이서 루트 중심과 ±0.9 studs 다섯 곳을 아래로 4.5 studs 레이캐스트한다. 이 방 타일만 Include (`:106-114, :152-157`) |
| AC6 | 사용자 확인 필요 | 한 번 달아오른 타일은 `heatStart`에 남아 계속 진행하고, 사라지면 `gone`이라 다시 시작하지 않는다 (`:116-133, :161-172`) |
| AC7 | 사용자 확인 필요 | 탈락 높이: 로컬 y < 맨 아래층 윗면 − 15 (= −55) (`HotPlateLogic.luau:102-104`, `HotPlate.luau:145`). 층 사이 여유 19 studs (QA `층 사이 여유…`) |
| AC8 | 사용자 확인 필요 | 종료 판정은 기존 `RoundService.roundShouldEnd`의 Survival 분기(남은 인원 ≤ 목표 → 남은 사람 전원 통과)를 그대로 쓴다. 이 맵은 `ctx.eliminate`만 부르고 `ctx.pass`는 부르지 않는다 (스펙대로) |
| AC9 | 사용자 확인 필요 | `startHeating`이 `heatStart[tile] == nil`일 때만 시각을 기록한다 → 두 번 밟아도 리셋되지 않는다 (`:120-124`) |
| AC10 | 사용자 확인 필요 | 연결은 Heartbeat 하나뿐이고 `ctx.cleanup`에 들어간다. 타일은 모델 안이라 RoundService가 지운다. 다른 방 타일은 `ctx.model:IsAncestorOf`로 거른다 (`:99-104`) |

요약: 순수 로직 AC1~AC3 통과, Studio AC4~AC10은 사용자 확인 필요. 실패한 기준은 없다.

## 버그
P0/P1/P2 없음.

### [P3] H1 (기존 N1, 이 맵에도 해당) 라운드 시작 순간 캐릭터가 리스폰 중이면 로비에서 바로 탈락할 수 있다
- 탈락 판정은 origin 기준 로컬 y < −55다. 로비(높이 ≈ 3, origin 높이 300)에 있는 캐릭터는 로컬 y ≈ −297이라, `placeAt`이 옮기기 전에 Heartbeat가 보면 즉시 탈락한다.
- 이 맵의 결함이 아니라 M1 재검증 N1과 같은 경로다. m2-05 범위 1번("소개 동안 배치를 끝내고 RoundActive에 start")이 들어가면 해소된다.
- 위치: `src/shared/maps/HotPlate.luau:145`, `src/server/RoundService.luau` `placeAt`

## 플레이테스트로 확인할 것 (버그 아님, 수치 조정)
- **타일 소모 속도 추정**: 걷는 속도 16 studs/s로 6 studs 타일을 지나면 한 사람이 초당 약 2.7개의 새 타일을 달군다(프로브 폭 때문에 경계에서는 더 많다). 한 층이 81개라서, Survival 최대 인원(16명)이면 맨 위층이 몇 초 안에 거의 사라질 수 있다. Survival은 남은 인원이 목표 이하가 되는 순간 끝나므로, 16명 판은 60초보다 훨씬 빨리(대략 10~20초) 끝날 가능성이 있다. 4~5명 판에서는 3층 243개로 충분히 버틸 수 있다. 다인원 플레이테스트 뒤 층 크기나 `HEAT_DURATION` 조정을 권한다. 스펙 AC10 취지("대부분 판에서 누군가는 떨어지게")와는 맞는 방향이다.
- **점프 중에는 타일이 달아오르지 않는다** (프로브 4.5 studs = 서 있을 때만 닿음). 개발 메모의 남은 이슈와 같다. 제자리에서 점프를 반복해도 착지한 타일은 1.5초 뒤 사라지므로 버티기 꼼수는 되지 않는다. 다만 연속 점프로 이동하면 소모하는 타일이 줄어든다. 의도인지 기획이 확인해 달라.
- **다른 사람 머리 위에 서면** 발밑 레이(4.5 studs)가 타일에 닿지 않아 아무 타일도 달구지 않는다. 아래 사람의 타일이 사라지면 같이 떨어지므로 큰 문제는 아니다.
- 같은 프레임에 둘이 떨어져 남은 인원이 목표 아래로 내려가면, 먼저 처리된 한 명만 탈락하고 라운드가 끝나서 다른 한 명은 통과한다. 동시 탈락 규칙은 m2-05 범위다(결승은 높이 기준, 중간 Survival은 정해진 규칙 없음).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트 없음. 발밑 판정은 서버 레이캐스트 (클라 신호 아님, 스펙 요구대로)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 탈락만 서버 Heartbeat에서 `ctx.eliminate`, 통과는 RoundService
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `heatStart`/`colorStep`/`gone`/`tiles`/`probeParams`는 `start` 지역 변수. 모듈 수준 상태 없음
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 하나 `ctx.cleanup`, 스레드·트윈 없음, 인스턴스는 모델 안
- [x] 태그 규칙 B10 (A) — `GetTagged("HotTile")`을 `ctx.model:IsAncestorOf`로 거름

## 사용자 Studio 확인 체크리스트
이 worktree에서 `rojo serve --port 34874` → Studio 연결. `Config.DEBUG.forceMapPlan`은 로컬에서만 바꾸고 끝나면 `nil`로 되돌린다 (커밋하면 `maps.spec` 테스트가 막는다).

1. **AC4 구조** — F5 → 서버 Command bar:
   ```lua
   local m = require(game.ReplicatedStorage.Shared.maps).get("hot-plate").build(CFrame.new(0,10,0)); m.Parent = workspace; for i=1,3 do print(m["Layer"..i].Name, #m["Layer"..i]:GetChildren()) end; print(#m.Spawns:GetChildren(), #game:GetService("CollectionService"):GetTagged("HotTile"))
   ```
   - [ ] `Layer1 81`, `Layer2 81`, `Layer3 81`, `24 243`
   - [ ] 노란 스폰 판이 맨 위층 전체에 흩어져 있고, 층 사이로 아래층이 보인다. 끝나면 `m:Destroy()`
2. **AC5~AC7 (혼자)** — `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" } :: { string }?` → 방 만들기 → 시작 → 1라운드 회전 벨트 통과 → 2라운드 "뜨거운 철판".
   - [ ] 캐릭터가 맨 위층 스폰에 선다
   - [ ] 가만히 서 있으면 발밑 타일이 회색 → 주황 → 빨강으로 변하고 약 1.5초에 사라져 둘째 층으로 떨어진다
   - [ ] 뛰어다니면 지나간 타일이 차례로 사라지고 다시 생기지 않는다
   - [ ] 둘째 층에 착지해서 계속 움직일 수 있다
   - [ ] 맨 아래층에서 떨어지면 "🥢 탈락했어요…"가 뜬다
   - [ ] (참고) 계속 점프하며 이동할 때 타일이 덜 사라지는지 기록 (기획 확인용)
3. **AC9 (2명)** — 같은 플랜, Clients and Servers 2명. A가 한 타일을 밟고 바로 비킨 뒤 0.5~1초 뒤 B가 그 타일에 올라선다.
   - [ ] 타일은 A가 처음 밟은 시각 기준으로 사라진다 (B가 올라섰다고 다시 회색이 되지 않는다)
4. **AC8 (4명)** — `forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" } :: { string }?`, Clients and Servers 4명 → "라운드 1 / 3 · 뜨거운 철판", 왼쪽 위 목표 2.
   - [ ] 두 명이 맨 아래층 밑으로 떨어지는 순간 라운드가 끝나고, 남은 두 명이 "✅ 통과" 안내를 받는다
   - [ ] (참고, m2-05 범위) 아무도 안 떨어지고 60초가 지나면 지금은 목표 2명만 통과하고 나머지는 탈락으로 보인다 — m2-05 머지 뒤 "전원 통과"로 바뀐다. 실패로 적지 않는다
5. **AC10** — 라운드가 끝난 뒤
   - [ ] Workspace에 `Round*_hot-plate` 모델이 없다
   - [ ] 서버 Output에 빨간 에러가 없다
   - 두 방 동시 진행은 m2-07에서 확인한다
6. **타일 소모 속도 기록** — 4명 판에서 맨 위층이 다 사라지기까지 걸린 시간을 대략 적어 둔다 (16명 판 수치 조정 근거)

## 추가한 테스트
`tests/map-hot-plate-qa.spec.luau` (8개, 모두 통과)
- `heatVisual`: 0~3초를 0.01초 간격으로 돌며 "1.5초 미만은 안 사라지고, 1.5초부터는 사라짐", 음수 경과도 회색, RGB가 0~255 정수
- 공정성: 스폰 24개가 모두 서로 다른 타일 위에 있음, 스폰 간 거리 ≥ 4 studs, 스폰 수 ≥ 최대 방 인원(24)
- 층 사이 여유 ≥ 6 studs(실제 19), 탈락 높이가 맨 아래층 밑면보다 아래
- 스펙 치수 범위: 층 간격 18~24, 9×9, 한 변 6

## 인계 메모 (2026-10-08, qa)
- 브랜치: `worktree-m2-hot-plate`. QA 리포트와 테스트를 이 브랜치에 커밋하고 push했다.
- 끝난 것: 검증 4종(108 passed), 코드 리뷰, 수용 기준 판정, 테스트 추가, 스펙 상태 `qa-passed`.
- 남은 것: Studio 체크리스트 1~6 (사용자 확인 필요).
- 다음 첫 단계: 사용자가 Studio 확인에서 문제를 찾으면 이 리포트에 버그로 추가한다. P0/P1이면 스펙을 `in-dev`로 되돌린다.
- 막힌 점: 없음. Survival 시간 종료 "전원 통과"와 동시 탈락 처리는 m2-05가 맡는다.
