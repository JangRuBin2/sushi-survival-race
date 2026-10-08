status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-06 — 다이브

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §6(다이브: Shift / E / 모바일 버튼, 앞으로 몸을 날림, 1.5초 쿨다운, 착지 후 0.5초 경직), §13(모바일 버튼 3개: 점프/다이브/잡기, 이동은 클라이언트 물리)
- 참고: `docs/REFERENCE-party-royale.md` §4 (Fall Guys 다이브: 결승선 직전 한 번 더 내밀기, 연타하면 오히려 느림)
- 담당 개발 worktree: `m3-dive` (Rojo 포트 34876)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작** (`Config.Dive`, `SfxCues`, `default.project.json`의 Shift Lock 끄기)
- **이 스펙이 고치는 파일**: `src/client/input/DiveController.luau`, 새 파일 `src/client/input/DiveButton.luau`(모바일 버튼), 새 파일 `src/shared/DiveLogic.luau`(순수), 새 파일 `tests/dive.spec.luau`

## 목표
Shift(또는 E, 모바일 다이브 버튼)를 누르면 초밥이 앞으로 배를 깔고 "슝" 몸을 던진다. 장애물을 피하거나 결승선·발판 끝에서 한 번 더 내미는 데 쓰고, 착지하면 잠깐 엎어져 있어서 **연타하면 그냥 달리는 것보다 느리다.**

## 범위
- 포함:
  1. **입력** — PC: `LeftShift`, `RightShift`, `E`. 게임패드: `ButtonX`. 모바일: `DiveButton`(터치 기기에서만, 아래 7). `gameProcessed`(채팅 입력 중 등)인 입력은 무시한다. 쿨다운 중에 누르면 무시한다(미리 눌러 두기 없음).
  2. **다이브할 수 있는 조건** — 순수 함수 `DiveLogic.canDive(state)`가 판단. 다음을 **모두** 만족해야 한다:
     - 내 캐릭터가 있고 `Humanoid.Health > 0`, `HumanoidRootPart`가 Anchored 아님, 앉아 있지 않음(`Sit = false`)
     - `Humanoid.WalkSpeed > 0` — 라운드 소개 이동 잠금·젓가락에 잡힘·탈락 고정 중에는 못 함 (서버가 이미 0으로 둠)
     - `Humanoid.PlatformStand = false` — 넘어진 동안 못 함
     - 다이브 중(Flying)이나 경직 중(Stunned)이 아님, 마지막 다이브 **시작**에서 `Config.Dive.Cooldown`(1.5초)이 지남
     - 관전 중이 아님 — `workspace.CurrentCamera.CameraSubject`가 내 Humanoid가 아니면 못 함 (`E`는 관전 "다음 사람" 키이기도 함)
     - 로비·대기석에서도 위 조건이면 할 수 있다 (판정과 무관한 놀이).
  3. **발사 속도** — 순수 함수 `DiveLogic.launch(input) -> { vx, vy, vz }` (숫자만, Lune 테스트용):
     - 방향: 이동 입력(`Humanoid.MoveDirection`의 수평 성분) 길이가 0.1보다 크면 그 방향, 아니면 캐릭터가 바라보는 수평 방향. 정규화.
     - 수평 속력: `Config.Dive.ForwardSpeed × min(1, 지금 WalkSpeed / Config.Character.WalkSpeed)` — 간장 웅덩이(속도 50%)에서는 다이브도 절반.
     - 수직 속도: 땅 위이고 `JumpPower > 0`이면 `Config.Dive.UpSpeed`, 땅 위인데 `JumpPower = 0`(간장 웅덩이)이면 0, 공중이면 지금 수직 속도를 그대로 둔다(점프 중 다이브 = 체공을 앞으로 늘림).
  4. **상태 흐름** — `DiveLogic.step(state, now, grounded, interrupted) -> state` (Ready → Flying → Stunned → Ready):
     - Flying: 발사한 순간부터. 초밥이 앞으로 약 80도 엎드린 자세로 날아간다. 발사 0.1초 뒤부터 땅에 닿으면 Stunned, `Config.Dive.MaxFlightTime`(1초)이 지나도 공중이면 **경직 없이** Ready(일어선 자세, 낙하 중일 수 있음).
     - Stunned: `Config.Dive.LandingStun`(0.5초) 동안 엎드린 채 이동·점프·다이브 입력이 먹지 않는다. 끝나면 일어서서 Ready. 이동 막기는 `RunService:BindToRenderStep`(우선순위 `Enum.RenderPriority.Input.Value + 2`)에서 `Humanoid:Move(Vector3.zero)`, 점프 막기는 로컬 `Humanoid:SetStateEnabled(Jumping, false)`로 한다 — 서버가 쓰는 `WalkSpeed`·`JumpPower`는 건드리지 않는다. (m3-07 잡기 감속은 `+1`이라 경직이 이긴다.)
     - 끊김(`interrupted`): 서버가 `PlatformStand = true`(넘어짐)·`WalkSpeed = 0`(젓가락·탈락)·Anchored로 바꾸거나 캐릭터가 사라지거나 죽으면 **즉시** Ready로 돌아가고 자세를 바로 세운다(경직 없음, 쿨다운은 그대로 흐름).
  5. **자세와 다른 사람에게 보이기** — 이동은 클라이언트 물리라 내 캐릭터의 위치·방향은 자동으로 서버와 다른 클라이언트에 복제된다. 엎드린 자세는 **HumanoidRootPart 방향(기울기)으로** 만들어서 다른 사람 화면에서도 엎드려 날아가는 게 보이게 한다 (예: 내 클라이언트가 루트에 로컬 `AlignOrientation`을 달고 `Humanoid.AutoRotate`를 잠깐 끔). 단:
     - `Humanoid.PlatformStand`는 **쓰지 않는다** — 넘어짐 신호로 m3-02 `CharacterFxController`와 서버 맵이 읽는 값이다.
     - 서버로 복제되는 속성(Attribute)·리모트를 만들지 않는다 (다이브는 판정이 없는 이동).
  6. **소리** — 발사 순간 `Sfx.play("Dive", 루트)`, Stunned로 들어가는 순간 `Sfx.play("DiveLand", 루트)`.
  7. **모바일 버튼 (`DiveButton`)** — `UserInputService.TouchEnabled`이고 기본 터치 컨트롤(`PlayerGui.TouchGui.TouchControlFrame.JumpButton`)이 있을 때만 만든다. 자기 ScreenGui(`DiveGui`, `ResetOnSpawn = false`)에 둔다. 위치: 점프 버튼 **왼쪽**에 점프 버튼과 같은 크기, 사이 간격은 버튼 폭의 0.15배. 글자 "다이브". 쿨다운 동안 위에서부터 줄어드는 어두운 덮개로 남은 시간을 보여 준다. 화면 크기가 바뀌면 다시 맞춘다.
- 제외:
  - 다이브로 다른 사람 밀치기·넘어뜨리기 (판정 추가 없음)
  - 다이브 중 맞으면 더 오래 넘어지기 (Fall Guys 규칙, 넘어짐은 서버 맵 소관이라 M3 범위 아님)
  - 서버 검증 (판정 없는 이동이라 서버는 관여하지 않음 — 결정 기록)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/dive.spec.luau`)
- [ ] AC1: `canDive`는 모든 조건이 맞으면 true, `WalkSpeed = 0`·`PlatformStand`·Anchored·Sit·사망·관전 중·Flying·Stunned·마지막 시작 뒤 1.49초 중 **하나만** 어긋나도 false다. 마지막 시작 뒤 1.5초면 true다.
- [ ] AC2: `launch` — 이동 입력 (1, 0)이면 수평 방향 (1, 0), 이동 입력이 (0.05, 0)이고 바라보는 방향이 (0, -1)이면 (0, -1). WalkSpeed 16이면 수평 속력 40, WalkSpeed 8이면 20, WalkSpeed 24여도 40.
- [ ] AC3: `launch` 수직 — 땅·JumpPower 50 → 16, 땅·JumpPower 0 → 0, 공중·지금 vy = -30 → -30.
- [ ] AC4: `step` — Flying에서 발사 0.05초 뒤 땅에 닿아도 Flying, 0.2초 뒤 땅에 닿으면 Stunned, Stunned 0.5초 뒤 Ready. 공중에서 1.0초가 지나면 Ready. 어느 상태든 `interrupted = true`면 Ready.
- [ ] AC5 (연타 손해): 중력 196.2(Roblox 기본) 기준 `DiveLogic.groundFlightTime(UpSpeed, 196.2)`로 구한 땅 다이브 한 번의 이동 거리(`ForwardSpeed × 체공`)가 같은 시간(체공 + 경직) 동안 걸어서 가는 거리(`WalkSpeed × (체공 + LandingStun)`)보다 짧다. 즉 쿨다운마다 다이브하는 것이 걷기만 하는 것보다 느리다 (`Config` 값이 바뀌어도 이 테스트가 지켜 준다).
- [ ] AC6: `lune run tests` 전체 통과.

### Studio 확인
- [ ] AC7: 혼자 F5 로비에서 Shift를 누르면 초밥이 앞으로 엎드려 몸을 던지고, 착지 후 약 0.5초 엎드려 있다가 일어난다. E와 게임패드 X도 같다. Shift Lock은 켜지지 않는다.
- [ ] AC8: 다이브 직후 1.5초 안에 다시 눌러도 나가지 않고, 1.5초 뒤에는 나간다.
- [ ] AC9: 점프 꼭대기에서 다이브하면 그냥 점프보다 앞으로 확실히 멀리 간다 (회전 벨트 틈이나 철판 층 사이에서 체감).
- [ ] AC10: 라운드 소개 중(스폰에 멈춘 동안), 젓가락에 들려 있는 동안, 날치알 공에 맞아 넘어진 동안, 탈락 연출 중에는 다이브가 나가지 않는다.
- [ ] AC11: 간장 웅덩이 안에서 다이브하면 위로 튀지 않고 짧게 나간다.
- [ ] AC12: Clients and Servers 2명 — 상대 화면에서 내가 엎드려 날아가는 모습이 보인다. 내 화면에 "@_@"(넘어짐 표시)가 뜨지 않는다.
- [ ] AC13: 탈락해서 다른 사람을 관전하는 중에 E를 누르면 관전 대상만 바뀌고 로비의 내 캐릭터는 다이브하지 않는다.
- [ ] AC14: 휴대폰 에뮬레이터 — 점프 버튼 왼쪽에 "다이브" 버튼이 겹치지 않게 있고, 누르면 다이브하며 쿨다운 덮개가 1.5초 동안 줄어든다. PC 화면에는 버튼이 없다.
- [ ] AC15: (회귀) 다이브를 섞어 4개 맵을 돌아도 결승선 통과·낙하 탈락 판정이 M2와 같다.

## 공용 파일 변경
- 없음 (읽기만: `Config.Dive`, `Config.Character`, `SfxCues`. Shift Lock 끄기는 m3-01이 `default.project.json`에서 함)

## 결정 기록
- 2026-10-08 · 다이브 수치 · `Config.Dive` = 쿨다운 1.5, 경직 0.5(GDD 6), 수평 40, 위로 16, 최대 체공 1초(m3-01). 땅 다이브 한 번 약 6.5 studs + 경직이라 연타가 걷기보다 느림(AC5). 참고: `docs/REFERENCE-party-royale.md` §4. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 서버 검증 없음 · 다이브는 걷기·점프처럼 클라이언트 물리 이동이고 통과·탈락 판정은 그대로 서버가 함(GDD 11.4·13). 속도를 조작하는 악용은 M4 출시 준비 때 서버 속도 감시로 검토. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 로비에서도 다이브 · 판정과 무관하고 기다리는 동안 놀 거리라 허용 · planner
- 2026-10-08 · 키 · Shift / E / 게임패드 X / 모바일 버튼. Fall Guys PC 기본은 Ctrl(다이브)·Shift(잡기)지만 GDD 6 표를 따름 · planner
- 2026-10-08 · 간장 웅덩이 · 다이브도 속도 배수를 따르고 위로 튀지 않음("점프 불가" 규칙 유지). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 관전 판정 보강 · `CameraSubject`가 내 Humanoid가 아니거나 `CameraType = Scriptable`이면 "관전 중"으로 봄. 탈락 대상 3초 비추기(위치만 남은 경우)는 카메라를 Scriptable로 두고 CameraSubject는 그대로라, 스펙 조건만으로는 E가 다이브로 새어 나감. 연출 중(소개·우승)에도 막히는데 그때는 어차피 WalkSpeed 0 · developer
- 2026-10-08 · 날아가는 동안 수평 속도 유지 · Humanoid 공중 제어가 수평 속도를 WalkSpeed 쪽으로 끌어내려서, Flying 동안 매 프레임(PreSimulation) 발사 수평 속도를 다시 넣음 (수직은 물리 그대로). 발판 끝에서 공중 다이브하면 최대 1초 × 40 = 40 studs까지 갈 수 있음 — 너무 멀면 m3-09에서 감쇠 검토 · developer
- 2026-10-08 · 기울인 자세 · 루트를 80도 기울이면 Humanoid가 넘어짐 상태로 빠질 수 있어 다이브 동안 로컬에서 `FallingDown`·`Ragdoll`·`GettingUp` 상태를 끔 (끝나면 다시 켬). 서버 값(PlatformStand 등)은 건드리지 않음 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 2026-10-08 · 브랜치 `m3-06-dive`
- 바뀐 파일
  - `src/shared/DiveLogic.luau` (새, 순수): `canDive`, `launch`, `begin`, `step`, `cooldownLeft`, `groundFlightTime`
  - `src/client/input/DiveController.luau`: 입력(Shift/E/ButtonX, gameProcessed 무시) → `canDive` → 루트 속도 설정, `AlignOrientation`(RigidityEnabled)로 80도 엎드림 + `AutoRotate` 끔, Flying 동안 수평 속도 유지, 착지하면 `BindToRenderStep("DiveStun", Input+2)`로 `Move(zero)` + 로컬 Jumping 끔, 끊김(PlatformStand/WalkSpeed 0/Anchored/Sit/사망/리스폰)이면 즉시 해제. `Sfx.play("Dive"/"DiveLand", root)`
  - `src/client/input/DiveButton.luau` (새): 터치 기기 + `TouchGui.TouchControlFrame.JumpButton`이 있을 때만 `DiveGui`(ResetOnSpawn false)에 점프 버튼 왼쪽·같은 크기·간격 폭×0.15. 쿨다운 덮개는 아래에 붙어 위에서부터 줄어듦. 점프 버튼 위치·크기·화면 크기가 바뀌면 다시 맞춤
  - `tests/dive.spec.luau` (새, 14개): AC1~AC5
- 공용 파일 변경 없음 (Config.Dive, Config.Character, SfxCues 읽기만)
- Studio 확인: 수용 기준 AC7~AC15. 혼자 F5 로비에서 Shift/E/게임패드 X, 연타(1.5초), 점프 꼭대기 다이브. `Config.DEBUG.forceMapPlan`으로 `soy-swamp`(AC11 간장 웅덩이), `rotating-belt`(AC10 젓가락), `skewer-showdown`(AC10 넘어짐). Clients and Servers 2명으로 AC12·AC13, 휴대폰 에뮬레이터로 AC14
- 남은 이슈 / Studio에서 봐야 할 위험
  - `FloorMaterial` 착지 판정과 80도 기울인 루트가 실제로 자연스러운지(엎드린 채 떠 보이거나 바닥에 박히는지)는 Studio 체감 필요. 어색하면 `PRONE_PITCH`나 착지 판정 조정
  - 경직 중 `Move(zero)`가 기본 ControlModule(Input 우선순위)보다 늦게 실행돼 이기는 것을 전제로 함
