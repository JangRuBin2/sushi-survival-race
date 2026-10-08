status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-10 — 서버 이동 감시 (순간이동·속도 조작 막기)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §11.4("모든 판정은 서버"), §13(이동은 클라이언트 물리, 판정만 서버)
- 참고: `docs/qa/m1-retro.md` B11(결승선·진행도가 클라이언트 위치를 믿음, "공개 전 속도/순간이동 검사 권장"), m3-06·m3-07 결정 기록(다이브 서버 검증 없음, 잡기 감속 무시 악용 → M4 속도 감시)
- 담당 개발 worktree: `m4-guard` (Rojo 포트 34880)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작** (`RoundService.setPassValidator`, `RoundService.activeRoomOf`, `MoveExempt`, `Config.MovementGuard`)
- **병합 순서**: 맵 스펙(m4-02~m4-05)이 `MoveExempt.mark`를 넣은 뒤에 `main`에 병합한다(그 전에 병합하면 와사비·넉백에서 오탐이 날 수 있음). worktree에서 개발·순수 테스트는 병렬로 해도 되고, AC6은 맵 스펙이 병합된 `main`을 이 worktree에 merge한 뒤 확인한다.
- **이 스펙이 고치는 파일**: `src/server/MovementGuardService.luau`, 새 파일 `src/shared/MovementGuardLogic.luau`, `tests/movement-guard.spec.luau`

## 목표
익스플로잇 클라이언트가 결승선으로 순간이동하거나 속도를 올려 달려도 **통과로 인정되지 않고 제자리로 돌려진다**. 정상 플레이(다이브, 와사비 튕김, 벨트·급류 밀기, 꼬치·칼 넉백, 잡기)는 절대 걸리지 않는다. 오탐이 나도 탈락시키지 않고 되돌리기만 한다(억울함 최소).

## 범위
- 포함:
  1. **감시 대상**: `RoundService.activeRoomOf(player) ~= nil`인 레이서(출발한 라운드에서 달리는 중)만. 로비·대기석·관전·소개 중은 감시하지 않는다.
  2. **샘플링** (서버 Heartbeat, 플레이어마다 `Config.MovementGuard.SampleInterval` 0.2초 간격): HumanoidRootPart 위치를 기록. 직전 "정상 위치"와 비교:
     - 수평 이동 거리 > `MaxHorizontalSpeed × dt + Slack` 이거나, 위로 이동 > `MaxRiseSpeed × dt + Slack`이면 **위반**.
     - 캐릭터의 `MoveExemptUntil` 속성이 지금보다 뒤면(서버가 옮기거나 튕긴 직후) 검사하지 않고 지금 위치를 정상 위치로 삼는다.
     - 아래로 떨어지는 건 검사하지 않는다(낙하는 탈락 판정이 처리).
  3. **위반 처리**: 캐릭터를 마지막 정상 위치로 되돌리고(`PivotTo`, 속도 0) 그 플레이어의 위반 시각을 기록. 한 라운드에서 `StrikesToLog`(3)번 이상이면 서버 Output에 `[MovementGuard] userId … strikes …` 경고 한 줄(라운드당 한 번). **킥·탈락은 하지 않는다.**
  4. **통과 막기**: `RoundService.setPassValidator`에 등록 — 마지막 위반이 `PassBlockAfterViolation`(2초) 안이면 false(그 통과 무시, 계속 달림). 그 밖에는 true.
  5. **순수 로직** `MovementGuardLogic`: `check(prev: {x,y,z,t}, cur: {x,y,z,t}, exemptUntil: number?, cfg) -> "ok" | "exempt" | "violation"`, `allowPass(lastViolationAt?, now, cfg) -> boolean`, `strikeLog(strikes, alreadyLogged) -> boolean`.
  6. **튜닝 근거**(기본값 확인용, 개발 메모에 실측 기록): 걷기 16, 다이브 수평 40, 와사비 튕김·급류 밀기·꼬치/칼 넉백은 각 맵이 `MoveExempt.mark`를 부름. 그래서 `MaxHorizontalSpeed = 80`은 표시 안 된 경우의 여유. Studio에서 정상 플레이 중 최고 수평 속도를 재서 80의 절반을 넘으면 결정 기록에 적는다.
- 제외:
  - 벽 통과(noclip)·공중 비행 감지, 클라이언트 감속(잡기·간장) 무시 감지 — 오탐 위험이 커서 M5 이후 필요하면
  - 킥·밴, 신고 시스템
  - 로비 감시

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/movement-guard.spec.luau`)
- [ ] AC1: dt 0.2초에 수평 8 studs(40/s, 다이브) → ok, 수평 30 studs → violation(80×0.2+6 = 22 초과), 수평 30이지만 `exemptUntil > t` → exempt.
- [ ] AC2: 아래로 100 studs 떨어짐 → ok. 위로 35 studs(0.2초) → violation(140×0.2+6 = 34 초과).
- [ ] AC3: `allowPass(nil, …) = true`, 위반 1초 뒤 false, 2.5초 뒤 true.
- [ ] AC4: 같은 라운드에서 위반 3번째에 로그 true, 4번째는 false(이미 찍음).
- [ ] AC5: 검증 명령 4개 통과.

### Studio 확인
- [ ] AC6: (정상 플레이 오탐 없음) 혼자 `forceMapPlan`으로 6개 맵을 모두 한 번씩 돌면서(두 판) 다이브 연타·와사비 튕김·벨트 위·급류·꼬치에 맞기·칼에 맞기를 해도 서버 Output에 `[MovementGuard]` 경고가 없고 되돌려지는 일이 없다.
- [ ] AC7: (순간이동) Race 라운드 중 클라이언트 콘솔에서 `game.Players.LocalPlayer.Character:PivotTo(<결승선 위치 근처 CFrame>)`(개발 메모에 복사용 명령)를 실행하면 결승선 통과가 되지 않고 원래 자리로 돌아온다.
- [ ] AC8: (속도) 클라이언트 콘솔에서 `Humanoid.WalkSpeed = 120`으로 바꾸고 달리면 계속 뒤로 당겨지고 3번째 위반에서 서버 경고가 한 줄 찍힌다. 킥되지 않는다.
- [ ] AC9: 2명 이상에서 잡기·넉백으로 서로 부딪혀도 오탐이 없다.

## 공용 파일 변경
- 없음

## 결정 기록
- 2026-10-08 · 위반 처리 · 되돌리기 + 통과 2초 막기 + 로그만, 킥·탈락 없음 (어린 유저 대상, 오탐 시 억울함 최소). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 서버가 움직인 직후 면제는 `MoveExemptUntil` 속성 방식 · 맵 스펙(m4-02~05)이 각자 표시 · planner
- 2026-10-08 · 복제 멈춤 오탐 방지 · 거의 안 움직인(0.05 studs) 샘플은 기준 시각을 최대 `StallGrace` 1초까지 유지하고, check의 dt는 `MaxGap` 1초로 자른다 (`MovementGuardLogic` 상수, Config 공용 파일은 손대지 않음). 멈췄던 위치 복제가 한꺼번에 따라잡아도 짧은 dt로 재지 않게. 대신 오래 서 있다가 순간이동하면 허용 거리가 최대 80×1+6 = 86 studs · developer
- 2026-10-08 · 통과 순간 재검사 · 결승선으로 순간이동한 그 프레임에 맵이 `ctx.pass`를 부르면 0.2초 샘플보다 먼저일 수 있어서, pass validator 안에서 그 자리에서 한 번 더 `check`하고 위반이면 되돌리고 거부한다 · developer
- 2026-10-08 · strikeLog 시그니처 · `strikeLog(strikes, alreadyLogged, cfg?)` — cfg 생략 시 `Config.MovementGuard` (스펙 시그니처에 cfg만 선택 인자로 추가) · developer
- 2026-10-08 · 위반 기록 초기화 · 레이서가 아니게 되면(통과·탈락·라운드 끝) 기록을 지운다 → "라운드당" 횟수·로그. 같은 라운드에서 캐릭터가 바뀌면 위치 기준만 새로 잡는다 · developer
- 2026-10-08 · QA B1 수정: 면제 중에도 상한 · `MoveExemptUntil` 중에는 검사를 건너뛰지 않고 넉넉한 상한(수평 `ExemptMaxHorizontalSpeed` 130, 위 `ExemptMaxRiseSpeed` 200 studs/s → 0.2초에 32 / 46 studs)만 본다. 서버가 주는 가장 큰 충격은 칼 넉백 45(+걷기 16), 와사비 위 80 — 0.35초 몰림에도 안. 통과 순간 재검사도 같은 check라 면제 중 결승선 순간이동은 위반. 스폰 배치는 면제가 아니라 배치 알림으로 기준점을 다시 잡는다 · developer
- 2026-10-08 · QA B1 검토: 연속 밀기(벨트·급류·도마 기울기·간장)의 반복 `MoveExempt.mark`는 **남긴다**. 표시 없이도 기준 안인 건 맞지만(m4-10-qa 표), m4-02/m4-05/map-art-race/map-ramen-rapids-qa/m4-10-qa 테스트가 그 표시를 계약으로 고정하고 있어 이 스펙에서 다른 스펙의 QA 기대를 바꾸지 않았다. 남는 한계: 밀기 구간 위에서는 130 studs/s 아래 속도 조작(예 WalkSpeed 120)이 안 잡힌다. 표시를 빼면 바로 잡힘 — **기획/QA 판단 필요** (빼려면 위 테스트들 갱신) · developer
- 2026-10-08 · QA B2 수정: 배치 때부터 감시 · `RoundService`에 `setPlacementListener`(스폰 배치 순간 알림)와 `placedRoomOf`(소개 중 포함 배치된 레이서)를 추가(m4-01 서버 파일 최소 수정). 감시 대상은 `activeRoomOf` → `placedRoomOf`, 기준점은 스폰 위치. 소개 중 순간이동은 바로 되돌려진다. 감시 기록(Track)이 없을 때 들어온 통과는 거부(`passDecision`) · developer
- 2026-10-08 · QA B3: `StallGrace` 1 → 0.5초. **기본값으로 진행, 사용자 수정 가능.** 서 있다 순간이동 허용은 최대 80×0.7+6 = 62 studs(기준 나이 0.5 미만 + 샘플 0.2). QA의 0.6초 멈춤 + 다이브 테스트는 그대로 통과. 개발 테스트의 멈춤 시뮬은 0.45초로 바꿈(0.5초를 넘는 멈춤 뒤 전속력 따라잡기는 되돌려질 수 있음 — 되돌리기만) · developer
- 2026-10-08 · QA B5: 되돌린(배치한) 뒤 `RevertSettle` 0.5초 안의 위반은 되돌리기만 하고 횟수·통과 막기에 세지 않는다. 세는 위반만 이 창을 연다 → 속도 조작은 약 0.6초마다 한 번씩 세어 3번째(약 1.2초)에 경고. 통과 순간 재검사가 위반이면 창과 관계없이 그 통과는 거부 · developer
## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 2026-10-08 · developer · QA 반려(B1·B2·B3·B5) 수정 · 브랜치 `m4-10-guard`(origin/m4-10-qa 병합) → `m4-10-qa`에 push
- **바뀐 파일**: `src/shared/MovementGuardLogic.luau`(면제 상한, StallGrace 0.5, `passDecision`, `countsStrike`), `src/server/MovementGuardService.luau`(배치 알림 기준점, `placedRoomOf` 감시, 통과 거부, settle), `src/server/RoundService.luau`(`setPlacementListener`·`placedRoomOf`·`notifyPlaced`), `tests/movement-guard.spec.luau`(B1·B2·B3·B5 재현·계약 테스트). 맵 파일은 안 바꿈.
- **Studio 확인 추가**: AC7 (a) 출발 구역 (b) 벨트 위 (c) 소개 중 — 셋 다 `PivotTo(FinishLine…)` 뒤 통과 없이 원래 자리(소개 중이면 스폰)로. AC8은 출발 구역에서 확인(벨트 위는 위 결정 기록의 한계).- 2026-10-08 · developer · 브랜치 `m4-10-guard`
- **바뀐 파일**: `src/server/MovementGuardService.luau`(구현), 새 `src/shared/MovementGuardLogic.luau`(순수 판정), 새 `tests/movement-guard.spec.luau`(26개: AC1~4 + 정상 이동 시뮬레이션 — 걷기, 바닥 다이브 연타, 점프+공중 다이브, 와사비 무표시/표시, 꼬치 넉백, 손이 판 들어 올림, 벨트 밀기, 철판 낙하, 서버 프레임 지연 0.5초, 복제 멈춤 뒤 따라잡기, 스폰/로비 이동 면제 / 위반: 속도 120, 서 있다 결승선 순간이동).
- **동작**: Heartbeat마다 샘플 차례인 플레이어만(0.2초, 첫 샘플 시각을 흩음) 검사. 달리지 않는 사람은 `activeRoomOf`도 0.2초마다만 물음. 위반이면 마지막 정상 위치로 `PivotTo`(회전 유지) + 속도 0, 위반 시각·횟수 기록, 3번째에 `warn("[MovementGuard] userId … strikes …")` 한 번. 결승선 통과는 validator에서 즉석 재검사 + 위반 2초 안이면 거부.
- **튜닝 근거(코드 상수 기준)**: 걷기 16, 다이브 수평 40(공중 위 16 상한), 와사비 위 80·앞 30, 꼬치 넉백 바깥 32·위 22, 벨트 밀기 10, 서든데스 손이 판을 0.5초에 30 들어 올림(ease-out 최고 120/s, 0.2초 19 studs). 모두 0.2초 기준 수평 22 / 위 34 안 — 맵이 `MoveExempt.mark`를 안 불러도 걸리지 않음. 실측 최고 수평 속도는 Studio에서 재서 40(80의 절반)을 넘으면 결정 기록에 적을 것.
- **Studio 확인 방법**:
  - AC6: `Config.DEBUG.forceMapPlan`에 맵 3~4개씩 두 판(6개 맵 전부) → 다이브 연타·와사비·벨트·급류·꼬치/칼 맞기. 서버 Output에 `[MovementGuard]`가 없어야 함. (m4-02~05 병합된 `main`을 merge한 뒤)
  - AC7: Race 라운드 출발 뒤 클라이언트 명령창(Studio Test 탭의 클라이언트 쪽 Command Bar)에서
    `local f; for _, d in workspace:GetDescendants() do if d.Name == "FinishLine" and d:IsA("BasePart") then f = d end end; game.Players.LocalPlayer.Character:PivotTo(f.CFrame + Vector3.new(0, 3, 0))`
    → 통과 처리(통과 토스트·대기석 이동) 없이 원래 자리로 돌아와야 함.
  - AC8: `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 120` 후 달리기 → 계속 뒤로 당겨지고 서버 Output에 `[MovementGuard] userId … strikes 3 in this round` 한 줄. 킥 없음.
  - AC9: Test → Clients and Servers 2명 이상, 잡기·넉백으로 부딪히기 → 경고 없음.
- **남은 이슈**: 캐릭터끼리 물리 충돌로 튕겨 날아가는(fling) 경우는 표시가 없어 위반될 수 있음(되돌리기만, AC9에서 확인). 서 있다가 순간이동하면 86 studs까지는 못 잡음(복제 멈춤 오탐 방지와 맞바꿈).
- 2026-10-08 · qa · **반려 (in-dev)** — `docs/qa/m4-10-movement-guard.md`. P1 B1: 면제(MoveExemptUntil) 중에는 거리 무관 "exempt"라 벨트·급류 위(계속 면제)·와사비·젓가락·넉백 직후 결승선 순간이동이 통과됨. P1 B2: 소개 중·출발 0.2초 안 순간이동은 Track이 없거나 기준점이 순간이동한 자리라 통과됨. P2 B3: StallGrace로 86 studs 순간이동 허용(짧은 코스). 정상 플레이 오탐 시뮬레이션은 전부 기준 안(리포트 표). QA 테스트 `tests/m4-10-qa.spec.luau` 15개.
