status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-07 — 잡기

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §6(잡기: 마우스 좌클릭 / 잡기 버튼, 앞에 있는 플레이어를 잡아 늦추기, 최대 2초), §11.4(판정은 서버), §13(모바일 버튼 3개)
- 참고: `docs/REFERENCE-party-royale.md` §4 (Fall Guys 잡기: 누르고 있는 동안 잡음, 잡는 사람도 느려짐, 악용 사례)
- 담당 개발 worktree: `m3-grab` (Rojo 포트 34877)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작** (`Config.Grab`, RemoteEvent `GrabInput`, `Attributes.GrabbedBy/GrabbingUserId`, `RoundService.activeRoomOf`, `SfxCues`)
- **이 스펙이 고치는 파일**: `src/server/GrabService.luau`, `src/client/input/GrabController.luau`, 새 파일 `src/client/input/GrabButton.luau`(모바일 버튼), 새 파일 `src/shared/GrabLogic.luau`(순수), 새 파일 `tests/grab.spec.luau`

## 목표
달리는 중에 좌클릭(모바일 "잡기" 버튼)을 누르고 있으면 바로 앞의 초밥을 붙잡아 최대 2초 동안 느리게 만든다. 잡는 사람도 조금 느려져서 잡기만 하는 건 손해고, 결승선 앞 몸싸움 같은 웃긴 순간을 만든다. **누가 누구를 잡았는지는 서버가 정한다.**

## 범위
- 포함:
  1. **입력 (클라이언트 `GrabController`)** — PC: 마우스 왼쪽 버튼, 게임패드: `ButtonR2`, 모바일: `GrabButton`(아래 8). 누르면 `GrabInput:FireServer(true)`, 떼면 `FireServer(false)`. `gameProcessed`(UI 버튼 클릭 등)인 누름은 보내지 않는다. 관전 중(`CameraSubject`가 내 Humanoid가 아님)이면 보내지 않는다. 누른 채로 창 포커스를 잃거나(`WindowFocusReleased`) 캐릭터가 바뀌면 `false`를 보낸다.
  2. **서버 검증 (`GrabService`)** — `GrabInput` 인자가 boolean이 아니면 무시. `true`는 플레이어당 `Config.Grab.InputMinInterval`(0.1초)보다 잦으면 무시. `false`는 항상 처리(놓기가 씹히지 않게).
  3. **잡기 시작 (서버)** — 버튼을 누르고 있는 동안 0.1초마다 대상을 찾고, 찾으면 잡는다(누른 채로 다가가도 잡힘). 잡는 사람 조건:
     - `RoundService.activeRoomOf(grabber)`가 nil이 아님 (출발한 라운드에서 달리는 중 — 로비·대기석·소개 중·탈락 후엔 못 잡음)
     - 살아 있고 `WalkSpeed > 0`, `PlatformStand = false`
     - 지금 누구를 잡고 있지 않고, 누구에게 잡혀 있지 않고, 쿨다운(`Config.Grab.Cooldown` 1.5초, 직전 잡기가 **끝난** 때부터)이 지남
     - 한 번 잡기가 끝나면 버튼을 **뗐다가 다시 눌러야** 다음 잡기를 찾는다 (누른 채 연속 잡기 없음)
  4. **대상 고르기** — 순수 함수 `GrabLogic.pickTarget(grabber, candidates, config) -> userId?`. 후보는 같은 방(`activeRoomOf`가 같은 값)의 다른 레이서 중:
     - 살아 있고 `PlatformStand = false`(넘어진 사람은 못 잡음)
     - 이미 다른 사람에게 잡혀 있지 않음, 면역(`Config.Grab.Immunity` 1초, 풀려난 때부터) 아님
     - 두 `HumanoidRootPart` 사이 거리 ≤ `Config.Grab.Range`(5)
     - 앞쪽: 잡는 사람의 수평 바라보는 방향과 대상 쪽 수평 방향의 내적 ≥ `Config.Grab.FrontDot`(0.5)
     - 여럿이면 가장 가까운 사람. 장애물·벽·맵 파츠는 잡을 수 없다(플레이어만).
     위치·방향은 숫자 표로 받는다(Lune 테스트용).
  5. **잡힌 동안 (서버)** — 대상 캐릭터에 `GrabbedBy = 잡은 userId`, 잡는 캐릭터에 `GrabbingUserId = 대상 userId` 속성(`shared/Attributes.luau`)을 단다. 서버는 `WalkSpeed`를 바꾸지 않는다(아래 6). 0.1초마다 다음 중 하나면 **끝낸다**(`GrabLogic.shouldEnd`):
     - 잡는 사람이 버튼을 뗌, 잡은 지 `Config.Grab.MaxHold`(2초)가 지남
     - 두 루트 거리 > `Config.Grab.BreakRange`(9) (대상이 다이브로 빠져나가는 것도 여기에 해당)
     - 둘 중 하나가 더는 레이서가 아님(통과·탈락·퇴장·라운드 끝 = `activeRoomOf`가 nil 또는 달라짐), 죽거나 캐릭터가 바뀜
     - 둘 중 하나가 넘어짐(`PlatformStand`)이나 젓가락(`WalkSpeed = 0`)·Anchored 상태가 됨
     끝나면 두 속성을 지우고, 잡던 사람에게 쿨다운, 잡혔던 사람에게 면역을 건다. 플레이어가 게임을 나가면 그 사람과 관련된 잡기·기록을 지운다.
  6. **느려지기 (클라이언트, 자기 캐릭터만)** — 각 클라이언트의 `GrabController`가 **자기** 캐릭터의 속성을 보고 이동 입력을 줄인다: `GrabbedBy`가 있으면 × `Config.Grab.TargetSpeedMultiplier`(0.5), `GrabbingUserId`가 있으면 × `Config.Grab.GrabberSpeedMultiplier`(0.7). 방법: `RunService:BindToRenderStep`(우선순위 `Enum.RenderPriority.Input.Value + 1`, 기본 조작 다음)에서 `Humanoid:Move(Humanoid.MoveDirection × 배수)`. **서버 `WalkSpeed`·`JumpPower`는 건드리지 않는다** — 간장 웅덩이(감속)·젓가락(0)이 이미 `WalkSpeed`를 쓰고 있어서 겹치면 값이 꼬인다(결정 기록). 점프는 막지 않는다.
  7. **보이기 (모든 클라이언트, 로컬)** — `GrabbingUserId`가 있는 캐릭터마다 잡는 사람 루트 앞에서 대상 루트까지 굵은 흰 `Beam`("밥알 팔")을 그리고, 대상 머리 위에 작은 "잡혔다!" 표시를 띄운다. 속성이 지워지면 바로 지운다. 소리: 내 캐릭터에 `GrabbingUserId`가 생기면 `Sfx.play("GrabStart", 루트)`, `GrabbedBy`가 생기면 `Sfx.play("Grabbed", 루트)`.
  8. **모바일 버튼 (`GrabButton`)** — `TouchEnabled`이고 기본 점프 버튼이 있을 때만, 자기 ScreenGui(`GrabGui`, `ResetOnSpawn = false`)에. 위치: 점프 버튼 **위쪽**에 같은 크기, 간격은 버튼 높이의 0.15배 (m3-06 다이브 버튼은 왼쪽이라 겹치지 않음). 글자 "잡기". 누르고 있으면 잡기, 손을 떼면 놓기. 잡고 있는 동안 버튼 색이 바뀐다.
- 제외:
  - 잡아서 끌고 가기·밀기·던지기 (어린 유저 대상, 악용 줄이기 — 참고 문서 §4)
  - 잡기 애니메이션 에셋 (Beam 표시로 대신)
  - 장애물·벽 잡고 기어오르기 (Fall Guys에서 패치로 막은 동작)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/grab.spec.luau`)
- [ ] AC1: `pickTarget` — 앞으로 3 studs 떨어진 후보는 잡히고, 뒤쪽 3 studs(내적 -1)·옆 3 studs(내적 0)·앞 6 studs(거리 초과)는 안 잡힌다. 앞에 2명(거리 2, 4)이면 거리 2인 사람.
- [ ] AC2: `pickTarget`은 이미 잡힌 후보, 면역 중인 후보, 넘어진 후보, 자기 자신을 고르지 않는다. 후보가 없으면 nil.
- [ ] AC3: 기록(`GrabLogic.newBook()`) — 잡기가 t=10에 끝나면 잡던 사람은 t=11.49까지 시작 불가, t=11.5부터 가능. 잡혔던 사람은 t=10.99까지 면역, t=11부터 다시 잡힐 수 있다.
- [ ] AC4: `shouldEnd` — 놓음, 잡은 지 2초, 거리 9.1, 한쪽이 레이서 아님, 한쪽 넘어짐 각각 true, 그 밖(잡은 지 1.9초, 거리 8.9)은 false.
- [ ] AC5: 한 사람이 동시에 두 사람에게 잡히지 않는다 (먼저 시작한 잡기만 성립). 잡혀 있는 사람은 잡기를 시작할 수 없다.
- [ ] AC6: `lune run tests` 전체 통과.

### Studio 확인 (Clients and Servers 2~3명, `minPlayersToStart` 1, `forceMapPlan`으로 Race 맵 먼저)
- [ ] AC7: 라운드 중 A가 B 바로 뒤에서 B를 보고 좌클릭을 누르고 있으면 둘 사이에 흰 "밥알 팔"이 생기고 B 머리 위에 "잡혔다!"가 뜬다. B는 눈에 띄게 느려지고(약 절반), A도 조금 느려진다. 2초가 지나면 저절로 풀린다.
- [ ] AC8: 버튼을 2초 전에 떼면 바로 풀린다. 풀린 직후(1.5초 안) 다시 눌러도 잡히지 않고, B는 풀린 뒤 1초 동안 다시 잡히지 않는다.
- [ ] AC9: 옆이나 뒤에 있는 사람, 5 studs보다 먼 사람은 잡히지 않는다. 누른 채로 다가가면 거리 안에 들어오는 순간 잡힌다.
- [ ] AC10: B가 다이브로 멀어지거나 A가 날치알 공에 맞아 넘어지거나 B가 결승선을 통과하면 잡기가 바로 풀리고, 통과한 B는 대기석에서 느리지 않다.
- [ ] AC11: 로비·대기석·라운드 소개 중·탈락 후에는 좌클릭해도 아무도 잡히지 않는다. 로비의 UI 버튼을 클릭해도 잡기 요청이 가지 않는다.
- [ ] AC12: 다른 방의 레이서는 잡을 수 없다 (방 2개 × 2명 동시 진행, 같은 맵이어도 아레나가 떨어져 있어 거리로도 막히지만 방 비교로 막는다 — 서버 로그 또는 `GrabLogic` 테스트로 확인).
- [ ] AC13: 잡힌 B가 간장 웅덩이에 들어갔다 나와도, 잡기가 끝난 뒤 B의 속도가 정상(16)으로 돌아온다 (서버 `WalkSpeed` 값이 꼬이지 않음).
- [ ] AC14: 휴대폰 에뮬레이터 — 점프 버튼 위에 "잡기" 버튼, 왼쪽에 "다이브" 버튼이 서로 겹치지 않는다. "잡기"를 누르고 있으면 잡고, 떼면 놓는다.
- [ ] AC15: 잡는 도중 A나 B가 게임을 나가도 남은 사람의 속성·느려짐이 바로 풀리고 서버 Output에 에러가 없다.

## 공용 파일 변경
- 없음 (읽기만: `Config.Grab`, `Remotes.event("GrabInput")`, `Attributes.GrabbedBy/GrabbingUserId`, `RoundService.activeRoomOf`, `SfxCues`. 모두 m3-01이 만듦)

## 결정 기록
- 2026-10-08 · 잡기 수치 · `Config.Grab` = 거리 5, 앞쪽 내적 0.5(약 60도), 끊김 거리 9, 최대 2초(GDD 6), 대상 속도 ×0.5, 잡는 사람 ×0.7, 쿨다운 1.5, 면역 1, 입력 간격 0.1 (m3-01). 참고: `docs/REFERENCE-party-royale.md` §4. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 감속 방식 · 서버 `WalkSpeed`를 곱하지 않고 **각자 클라이언트가 자기 이동 입력을 줄임**. 이유: 간장 웅덩이·젓가락·이동 잠금이 이미 `WalkSpeed`를 직접 쓰고 되돌리는데, 잡기까지 같은 값을 바꾸면 되돌리는 순서에 따라 느린 채로 남는 버그가 생김(AC13). 잡기 성립·해제 판정은 서버가 하고, 감속 "효과"만 클라이언트가 적용. 감속을 무시하는 악용은 M4 서버 속도 감시에서 검토. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 잡기는 늦추기만 · 끌기·밀기·던지기 없음(GDD 6 "늦추기", 어린 유저 대상). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 잡을 수 있는 때 · 출발한 라운드에서 같은 방 레이서끼리만. 로비·대기석에서는 못 잡음(괴롭힘 방지). 넘어진 사람은 못 잡음. 잡혀 있는 사람은 잡기 시작 불가. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 누른 채 다가가기 · 버튼을 누르고 있으면 0.1초마다 대상을 찾음(Fall Guys처럼 팔 뻗고 다가가기). 한 번 끝나면 다시 눌러야 함 · planner
- 2026-10-08 · 게임패드 키 · `ButtonR2` (Fall Guys 콘솔 기본이 오른쪽 큰 숄더 버튼) · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 2026-10-08 · 브랜치 `m3-07-grab`
- **바뀐 파일**
  - `src/shared/GrabLogic.luau` (새, 순수): `pickTarget`, `shouldEnd`, `newBook` + `canStart/isGrabbed/isImmune/begin/finish/grabOf/grabberOf/removePlayer`. 후보 표에 `alive`, `down`(넘어짐·WalkSpeed 0·Anchored를 한 값으로), `grabbed`, `immune`을 받는다.
  - `src/server/GrabService.luau`: GrabInput 검증(boolean, true만 0.1초 간격 제한, false 항상 처리), Heartbeat 0.1초 틱으로 잡기 끝내기 → 시작 순서 처리, 속성 달기/지우기, PlayerRemoving 정리. 버튼을 새로 누를 때만 `armed`가 켜지고 잡기가 한 번 성립하면 꺼진다(누른 채 연속 잡기 없음). 이미 누른 상태의 중복 `true`는 다시 무장시키지 않는다.
  - `src/client/input/GrabController.luau`: 입력(MouseButton1/ButtonR2/GrabButton), 관전 중·gameProcessed 차단, 포커스 잃음·캐릭터 바뀜에 false, `BindToRenderStep(Input+1)`에서 `Humanoid:Move(MoveDirection × 배수)`, Beam("밥알 팔")·"잡혔다!" Billboard(매 Heartbeat에 속성과 동기화), `GrabStart`/`Grabbed` 소리, 잡는 동안 버튼 색.
  - `src/client/input/GrabButton.luau` (새): 터치 기기에서 `GrabGui`(ResetOnSpawn=false)에 점프 버튼 위(간격 = 높이×0.15) 같은 크기 "잡기" 버튼. 점프 버튼을 1초마다 찾아 붙고, 크기·위치 변화에 다시 맞춘다. `IgnoreGuiInset`/`ScreenInsets`는 TouchGui 값을 따른다.
  - `tests/grab.spec.luau` (새): 13개 (AC1~AC5 + 경계·나간 플레이어).
- **Studio 확인**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "soy-swamp", "skewer-showdown" }` 등 Race 먼저로 바꾸고(커밋 금지), Test → Clients and Servers 2~3명. AC7~AC15 순서대로. AC13은 간장 늪(soy-swamp)에서 잡힌 채로 웅덩이를 지나간 뒤 Explorer에서 B의 Humanoid.WalkSpeed가 16인지 본다. AC14는 Device 에뮬레이터(휴대폰)로 점프 버튼 위 "잡기" 확인.
- **남은 이슈/메모**
  - 감속은 `Humanoid:Move` 크기를 줄이는 방식이라 기본 ControlModule이 매 프레임 Move를 다시 부르는 것에 기대고 있다. 키보드는 MoveDirection 크기가 1이라 ×0.5가 그대로 먹지만, 다른 스크립트가 같은 프레임 뒤에 Move를 부르면 무시될 수 있다 (Studio로 확인).
  - 같은 틱에서 두 사람이 서로를 앞에 두고 동시에 누르면, `holding` 표를 도는 순서상 먼저 처리된 사람만 잡는다(다른 사람은 잡혀 있어서 시작 불가) — 스펙 AC5대로.
  - 공용 파일 변경 없음.
