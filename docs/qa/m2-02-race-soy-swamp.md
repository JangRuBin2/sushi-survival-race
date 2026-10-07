# QA — m2-02 Race 맵 "간장 늪 & 와사비 산"

- 스펙: `docs/specs/m2-02-race-soy-swamp.md`
- 검증 커밋: `97a9491` (구현 `24b37ee` + 기획의 AC11 수정. 브랜치 `worktree-m2-soy-swamp`)
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. Studio 확인(AC3~AC11)은 사용자 확인 필요.
- AC11은 기획이 고친 기준("약 15~60초")으로 판단한다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 113 passed, 0 failed (개발 106 + QA 추가 7) |

base(`03d752a`)에서 바뀐 `src`는 `maps/SoySwamp.luau`, 새 파일 `maps/SoySwampLayout.luau`·`maps/SoySwampHazards.luau`뿐이다. 공용 파일(Config, Types, Remotes, maps/init, default.project.json)과 서버 코드는 바뀌지 않았다. 간장의 점프 막기는 m2-01 F1 수정(`StarterPlayer.CharacterUseJumpPower = true`, `default.project.json:17`)이 이 브랜치에 들어 있어서 동작한다.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `SoySwamp: 풀에 등록된 Race 맵이고 이름·규칙이 m2-01 표와 같아요 (AC1)`, m2-01 `maps.spec` |
| AC2 | 통과 | 전체 통과. 세 모듈 모두 최상위에 Roblox API가 없다 (색은 `palette()` 안에서 만들고, 서비스는 함수 안에서만 부른다) |
| AC3 | 사용자 확인 필요 | `Spawns` 24개, `FinishLine`, `SoyPuddles` 3개(`SoySauce` 태그), `WasabiPads` 1개(`Wasabi` 태그) (`SoySwamp.luau:125-245`) |
| AC4 | 사용자 확인 필요 (로직 통과) | 구간이 빈틈없이 이어지고 길이 174 (`코스: 구간이 출발→늪→산→내리막→결승 순서로…`). 양옆·시작·끝 벽 높이 48. 와사비 최고점보다 높다 (`와사비 산: … 벽은 못 넘어요`) |
| AC5 | 사용자 확인 필요 (로직 통과) | 루트가 웅덩이 판 위 −1~+5 안이면 WalkSpeed 8·JumpPower 0, 벗어나면 즉시 `Config.Character` 값 (`SoySwampHazards.luau:48-88`). QA: 서 있으면 간장 안, 점프 최고점에서는 간장 밖. 간장을 한 번도 안 밟는 마른 길이 실제로 이어짐 (BFS) |
| AC6 | 사용자 확인 필요 (로직 통과) | 패드 위 0~4.5면 `LinearVelocity`(위 80·앞 30) 0.08초 + "매워!!" 1초, 1초 쿨다운 (`:117-169`). QA: 패드 앞·가운데·뒤 어디서 튀어도 공기 저항이 없다고 보면 산 몸통 위(z −79.5~−84.5)에 착지 |
| AC7 | 사용자 확인 필요 (로직 통과) | 2~3초 간격, 8초 또는 내리막을 벗어나면 삭제, 최고 속도 28, 서버 소유 (`:171-265`). QA: 동시에 많아야 5개, 내리막 위에서는 수명 전까지 남고 벗어나면 바로 삭제 |
| AC8 | 사용자 확인 필요 | 결승선 위치 판정(로컬 z, 높이 무관), 결승선은 끝 벽 4 studs 앞 (`SoySwamp.luau:254-283`). M1 B2 수정과 같은 방식 |
| AC9 | 사용자 확인 필요 | 맵·공·GUI·LinearVelocity·스레드 모두 `ctx.cleanup`. 간장 안에서 라운드가 끝나도 통과자는 `CharacterUtil.toLobby`, 탈락자는 3초 뒤 `toLobby`, 다음 라운드는 `placeAt`이 `resetMovement`로 WalkSpeed·JumpPower를 되돌린다 |
| AC10 | 사용자 확인 필요 | 간장 상태(`soaked`)·쿨다운이 플레이어별이고, 모두 `start` 안의 지역 변수라 방마다 따로다 |
| AC11 | 사용자 확인 필요 (기획 기준 15~60초) | 코스 174 studs, 개발 예상 18~25초. 측정은 체크리스트 7 |

요약: 순수 로직 AC1·AC2 통과, Studio AC3~AC11은 사용자 확인 필요. 실패한 기준은 없다.

## 버그
P0/P1/P2 없음.

### [P3] W1 (기존 N1, 이 맵에도 해당) 라운드 시작 순간 캐릭터가 리스폰 중이면 로비에서 바로 탈락할 수 있다
- 낙하 판정은 월드 Y < origin − 40이다. 로비 캐릭터가 `placeAt` 전에 판정되면 즉시 탈락한다. m2-05 범위 1번(소개 동안 배치를 끝냄)이 들어가면 해소된다.
- 위치: `src/shared/maps/SoySwamp.luau:277`

### [P3] W2 와사비 튕김 거리가 공중 조작(air control)에 따라 줄어들 수 있다 (Studio 확인)
- 계산상 앞 30 studs/s가 유지되면 패드 어디서든 산 위에 착지한다 (QA 테스트). 그런데 Roblox Humanoid는 공중에서도 입력 방향으로 수평 속도를 맞추려 한다. 그래서 W를 떼고 있으면 앞 속도가 줄어들 수 있다.
- 걷는 속도(16)만 남는다고 보면, 패드 맨 앞(z −61)에서 튄 경우 착지 z가 약 −70.9로 절벽(−72)보다 앞이라 산에 못 올라간다. 패드 가운데·뒤에서 튀면 올라간다.
- 개발 메모의 "패드에서 서 있기만 해도(입력 없이) 산 위에 착지하는지 Studio 확인 필요"와 같은 항목이다. 못 올라가면 `WASABI_FORWARD`를 올리거나 `WASABI_HOLD`를 늘리면 된다 (`SoySwampLayout.luau:70-74`).

## 플레이테스트로 확인할 것 (버그 아님)
- **웅덩이 점프 지름길**: 점프 한 번에 약 8 studs를 가므로 웅덩이 깊이(10)를 한 번에 건너뛰지는 못한다 (QA 테스트). 하지만 마른 가로길에서 점프하면 웅덩이의 약 80%를 공중으로 넘고 끝 2 studs만 간장 속도로 걷게 된다. 지그재그 마른 길과 비교해 어느 쪽이 빠른지는 체감으로 확인해 달라. 지름길이 너무 좋으면 웅덩이 깊이나 `SOY_ZONE_HEIGHT`를 조정하면 된다.
- 날치알 공은 `CanCollide = true`인 서버 소유 공이라, 판정(거리 4 이내 → 넘어짐)과 별개로 물리적으로도 캐릭터를 민다. 클라이언트 쪽에서 밀림이 튀어 보이지 않는지 확인.
- `PlatformStand` 1초가 클라이언트 화면에서 넘어짐으로 보이는지 (개발 메모와 같음).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트 없음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 결승선·낙하·간장·와사비·공 판정 모두 서버 Heartbeat. 공은 `SetNetworkOwner(nil)`로 서버 소유
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `soaked`, 쿨다운, 공 목록은 각 stepper 안의 지역 변수
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat, 공 생성 스레드, 공·폴더, BillboardGui, LinearVelocity·Attachment, 모든 `task.delay`
- [x] 태그 규칙 B10 (A) — `Hazards.taggedParts`가 `ctx.model:IsAncestorOf`로 거름

## 사용자 Studio 확인 체크리스트
이 worktree에서 `rojo serve --port 34873` → Studio 연결. `forceMapPlan`은 로컬에서만 바꾸고 끝나면 `nil`.

1. **AC3 구조** — 서버 Command bar:
   ```lua
   local M=require(game.ReplicatedStorage.Shared.maps).get("soy-swamp"); local m=M.build(CFrame.new(0,10,0)); m.Parent=workspace; print(#m.Spawns:GetChildren(), #m.SoyPuddles:GetChildren(), #m.WasabiPads:GetChildren(), m:FindFirstChild("FinishLine") ~= nil)
   ```
   - [ ] `24 3 1 true`. 웅덩이와 패드의 태그는 `game.CollectionService:GetTags(m.SoyPuddles.SoyPuddle1)` 등으로 `SoySauce` / `Wasabi` 확인. 끝나면 `m:Destroy()`
2. **AC4 (혼자)** — `forceMapPlan = { "soy-swamp", "rotating-belt", "skewer-showdown" } :: { string }?` → 시작.
   - [ ] 출발 → 간장 늪 → 와사비 산 → 날치알 내리막 → 결승 순서. 양옆 벽 때문에 코스 밖으로 못 나간다
3. **AC5** — 웅덩이에 들어가면 절반 속도, Space가 안 먹힌다. 나오면 바로 정상 속도와 점프
   - [ ] (참고) 마른 가로길에서 점프로 웅덩이를 넘는 지름길이 지그재그 길보다 얼마나 빠른지 기록
4. **AC6 / W2** — 초록 패드를 밟으면 크게 튀고 머리 위에 "매워!!"
   - [ ] W를 누른 채 튀면 산 위에 착지
   - [ ] **패드 맨 앞(산에서 먼 쪽)에서 아무 키도 누르지 않고** 튀어도 산 위에 착지하는지 (W2)
   - [ ] 오른쪽 통로 → 산 뒤 → 경사로로 돌아서도 올라갈 수 있다
5. **AC7** — 내리막에서 주황 공이 2~3초마다 굴러온다. 맞으면 약 1초 넘어졌다 일어난다. 점프로 공을 넘을 수 있다. 30초 뒤 Explorer `Round*_soy-swamp > TobikoBalls`의 자식이 5개 이하
6. **AC8** — 결승선 바로 앞에서 점프해 넘어도 "✅ 1번째로 통과했어요!"가 한 번만 뜨고, 끝 벽 때문에 밖으로 안 떨어진다
7. **AC11** — 혼자 처음부터 결승까지 걸린 시간을 기록한다 (기준 약 15~60초). 와사비 지름길로 한 번, 경사로로 돌아서 한 번
8. **AC9** — 간장 웅덩이 안에 선 채로 90초 시간 종료를 기다린다 → 다음 라운드(회전 벨트)에서 걷기·점프가 정상이고, 간장 늪 맵과 공이 사라졌다
9. **AC10 (4명)** — Test → Clients and Servers 4명, 같은 플랜. 한 명만 간장에 있을 때 그 사람만 느리고, 와사비·공 넘어짐도 각자에게만 걸린다. 서버 Output에 에러 없음

## 추가한 테스트
`tests/map-soy-swamp-qa.spec.luau` (7개, 모두 통과)
- 간장 늪: 웅덩이를 한 번도 밟지 않는 마른 길이 앞에서 뒤까지 이어짐 (0.5 studs 격자 BFS, 몸 반폭과 벽 고려)
- 점프 한 번(걷는 속도)으로 웅덩이 하나를 통째로 건너뛰지 못함
- 간장 판정: 서 있으면 안, 점프 최고점에서는 밖
- 와사비: 패드 앞·가운데·뒤 어디서 튀어도 (위 80·앞 30) 산 몸통 위에 착지
- 날치알: 동시 공 개수 상한, 서 있으면 맞고 점프 최고점에서는 넘어감, 내리막 위에서는 남고 벗어나면 삭제

## 인계 메모 (2026-10-08, qa)
- 브랜치: `worktree-m2-soy-swamp`. 리포트·테스트·스펙 상태(`qa-passed`)를 이 브랜치에 커밋하고 push했다.
- 끝난 것: 검증 4종(113 passed), 코드 리뷰, 수용 기준 판정, 테스트 추가.
- 남은 것: Studio 체크리스트 1~9 (사용자 확인 필요). 특히 W2(입력 없이 와사비로 산에 오르는지)와 AC11 시간 측정.
- 다음 첫 단계: Studio에서 문제가 나오면 이 리포트에 추가하고 P0/P1이면 `in-dev`.
- 막힌 점: 없음.
