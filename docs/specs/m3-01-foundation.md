status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-01 — M3 기반 작업 (공용 파일 · 카메라 중재 · 연출/입력 껍데기)

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §4(라운드 소개), §6(다이브/잡기, 넘어짐), §7(탈락 연출), §8(우승 연출), §11.3(CameraController·MovementController), §12(M3)
- 참고: `docs/REFERENCE-party-royale.md` (참고용)
- 담당 개발 worktree: `main` (**순차, M3에서 가장 먼저**. 이 스펙이 `main`에 병합된 뒤에 m3-02~m3-08 worktree를 만든다)
- 공용 파일 수정 담당: **이 스펙** — `shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `default.project.json`, 그리고 `src/client/init.client.luau`, `src/server/init.server.luau`. M3의 다른 스펙은 이 파일들을 고치지 않는다 (필요하면 사용자에게 알린다).
- 의존: 없음 (M2 done 상태의 `main`). → **m3-02 ~ m3-09가 이 스펙에 의존**

## 목표
M3 병렬 개발이 서로 같은 파일을 건드리지 않도록 공용 파일 변경과 "빈 껍데기(stub)" 파일을 한 번에 만든다. 이후 연출·입력·사운드 담당은 자기 파일만 채우면 된다 (M2의 m2-01과 같은 방식).
특히 **카메라를 여러 기능(관전·라운드 소개·탈락 연출·우승 연출)이 동시에 잡으려 하는 문제**를 우선순위 중재 모듈 하나로 미리 정리한다.

## 범위
- 포함:
  1. **`shared/Config.luau`** — 아래 값 추가/변경 (전부 기본값, 사용자 수정 가능):
     ```lua
     Config.Match.VictoryDuration = 10   -- 6 → 10: 우승 연출(6초) + 순위표(4초)
     Config.Match.VictoryCutscene = 6    -- 우승 연출 길이 (VictoryDuration 안에서)
     -- EliminationCutscene = 3, IntroDuration = 3 은 그대로
     Config.Appearance = { Default = "tamago" }  -- 기본 스킨 id (계란초밥)
     Config.Dive = {
         Cooldown = 1.5,        -- GDD 6
         LandingStun = 0.5,     -- GDD 6
         ForwardSpeed = 40,     -- 다이브 순간 수평 속도 (studs/s)
         UpSpeed = 16,          -- 바닥에서 다이브할 때 위로 튀는 속도
         MaxFlightTime = 1.0,   -- 이 시간 안에 착지하지 않아도 엎드린 자세를 끝냄
     }
     Config.Grab = {
         Range = 5,                     -- 잡을 수 있는 거리 (HumanoidRootPart 사이)
         FrontDot = 0.5,                -- 앞쪽 판정 (바라보는 방향과 대상 방향의 내적, 약 60도 안)
         BreakRange = 9,                -- 잡은 뒤 이보다 멀어지면 놓침
         MaxHold = 2,                   -- GDD 6: 최대 2초
         TargetSpeedMultiplier = 0.5,   -- 잡힌 사람 이동 속도 배수
         GrabberSpeedMultiplier = 0.7,  -- 잡는 사람도 느려짐 (참고 문서 §4)
         Cooldown = 1.5,                -- 잡기가 끝난 뒤 다시 잡을 수 있을 때까지
         Immunity = 1.0,                -- 풀려난 사람을 다시 잡을 수 없는 시간
         InputMinInterval = 0.1,        -- GrabInput 요청 간격 제한
     }
     ```
  2. **`shared/Remotes.luau`** — RemoteEvent `GrabInput` 추가. **클라이언트 → 서버** 방향의 첫 RemoteEvent이므로 맨 위 주석에 "클라이언트 → 서버 알림 (RemoteEvent)" 절을 새로 만들고 `GrabInput(holding: boolean)`을 적는다. 서버는 타입(boolean)·간격을 검증한다 (구현은 m3-07, 여기서는 이름만).
  3. **`shared/Types.luau`** — 탈락 연출에 필요한 정보:
     ```lua
     export type EliminationCause = "Fall" | "Reset" | "Left"
     -- PlayerResult에 추가
     cause: EliminationCause?,  -- Eliminated일 때만. Fall = 맵 낙하 판정, Reset = 리셋·사망·캐릭터 없음, Left = 방/게임을 나감
     position: Vector3?,        -- Eliminated일 때 탈락 순간 HumanoidRootPart 위치 (없으면 nil)
     ```
     서버(`RoundService`, `EliminationService`)가 이 두 값을 채운다: `ctx.eliminate` 경로 = `"Fall"`, 사망·캐릭터 교체·캐릭터 없음 = `"Reset"`, `EliminationService.left` = `"Left"`(position nil). 결승 진출 2명 보장으로 구제된 사람은 Passed라 해당 없음.
  4. **`shared/Attributes.luau`** (새, 상수만) — 여러 스펙이 쓰는 Instance 속성 이름을 한 곳에:
     - 캐릭터 Model: `AppearanceId`(string, m3-02가 씀), `GrabbedBy`(number userId, m3-07), `GrabbingUserId`(number, m3-07)
     - 라운드 맵 Model: `RoomId`(string), `RoundIndex`(number), `MapId`(string) — **이 스펙의 `RoundService.prepareRound`가 맵을 Workspace에 넣기 전에 단다** (클라이언트가 자기 방의 맵을 찾는 데 씀, m3-04)
  5. **서버 질의 함수** `RoundService.activeRoomOf(player): string?` — 그 플레이어가 지금 **출발한(RoundActive) 라운드에서 스폰에 배치된 채 아직 달리는 레이서**면 방 id, 아니면 nil. 잡기(m3-07)가 "같은 방에서 달리는 중인가"를 판정할 때 쓴다.
  6. **카메라 중재** `src/client/CameraDirector.luau` (새, **이 스펙에서 실제 구현**):
     - `CameraDirector.request(owner: string, priority: number, apply: (camera: Camera) -> ())` / `CameraDirector.release(owner)`.
     - 요청 중 **우선순위가 가장 높은 owner의 `apply`만** 카메라에 반영한다. 그 owner가 release하면 다음 owner의 `apply`를 다시 부른다. 아무도 없으면 기본(`CameraType = Custom`, `CameraSubject = 내 Humanoid`)으로 돌린다.
     - `CameraDirector.Priority = { Spectate = 10, Victory = 20, Intro = 30, Elimination = 40, VictoryCutscene = 50 }`
     - 우선순위·현재 owner 선택은 순수 함수(`src/shared/CameraPriority.luau`의 `pick(requests) -> owner?`)로 분리해 테스트한다.
  7. **`SpectateController` 리팩터** — 카메라를 직접 바꾸지 않고 `CameraDirector`를 쓴다 (관전 = `Spectate`, 우승자 비추기 = `Victory`). 동작은 M2와 같아야 한다 (m2-06 AC5~AC12 회귀). 추가 동작 하나: **보고 있던 대상이 낙하/리셋(cause Fall·Reset)으로 탈락하면 바로 넘기지 않고 `Config.Match.EliminationCutscene` 동안 그 사람(탈락 위치)을 계속 비춘 뒤** 다음 대상으로 넘어간다 — 관전자가 먹히는 연출을 보게 (GDD 1.1 "탈락이 볼거리"). 통과·퇴장(Left)은 지금처럼 바로 넘긴다.
  8. **빈 껍데기 파일**(만들고 `init`에 등록, 동작은 각 스펙이 채움). 모든 클라이언트 컨트롤러는 `start(gui)`를, 서버 서비스는 `init()`/`start()`를 가진다.

     | 파일 | 채우는 스펙 | 껍데기가 하는 일 |
     |---|---|---|
     | `src/shared/SushiBody.luau` | m3-02 | `build(appearanceId: string): Model` — PrimaryPart `Body`가 있는 회색 박스 1개(약 2.4×4×1.8) 모델. `layout(appearanceId)`는 빈 목록 |
     | `src/server/AppearanceService.luau` | m3-02 | `applyAppearance(character: Model, appearanceId: string?)` — 캐릭터에 `AppearanceId` 속성만 단다. `start()`에서 모든 플레이어의 `CharacterAdded`에 연결 |
     | `src/client/fx/CharacterFxController.luau` | m3-02 | 없음 |
     | `src/client/fx/EliminationCutsceneController.luau` | m3-03 | 없음 |
     | `src/client/fx/IntroController.luau` | m3-04 | 없음 |
     | `src/client/fx/VictoryCutsceneController.luau` | m3-05 | 없음 |
     | `src/client/input/DiveController.luau` | m3-06 | 없음 |
     | `src/server/GrabService.luau` | m3-07 | `GrabInput`을 받아서 무시 |
     | `src/client/input/GrabController.luau` | m3-07 | 없음 |
     | `src/client/Sfx.luau` | m3-08 | `Sfx.play(cue: string, at: (BasePart \| Vector3)?)`, `Sfx.setMusic(name: string?)`, `Sfx.start(gui)`(빈 함수, `init.client.luau`에서 다른 컨트롤러와 함께 부름) — 아무 소리도 안 냄. 모르는 cue면 cue당 한 번 경고. cue 목록은 `src/shared/SfxCues.luau`(새, 상수만 — lune 테스트 가능)에 둔다. `Sfx.play`는 `start` 전에 불려도 에러 없이 무시한다 |

     **Sfx cue 이름 (`SfxCues`, 확정 목록, 다른 스펙은 이 이름만 씀)**:
     - UI·흐름: `ButtonClick`, `IntroWhoosh`, `Go`, `Qualified`, `Eliminated`(스탬프), `VictoryFanfare`
     - 탈락 연출: `ChopstickClack`, `Struggle`, `SoyDip`, `Chomp`, `SpeechPop`, `ChefHand`, `MouthFall`
     - 우승 연출: `DoorBurst`, `Splash`, `FishClap`
     - 조작: `Dive`, `DiveLand`, `GrabStart`, `Grabbed`, `Knockdown`
     - 장애물 (m3-09가 맵에 붙임): `ChopstickWarn`, `WasabiBoing`, `SoySlow`, `HotTileSizzle`, `TileVanish`, `SkewerWhoosh`, `ChefHandWarn`
     - 음악 (`setMusic`): `Lobby`, `Round`, `Final`, `Victory`
  9. **`default.project.json`** — `StarterPlayer`:
     - `EnableMouseLockOption = false` — Shift가 다이브 키라서 Shift Lock을 끈다 (GDD 6).
     - `LoadCharacterAppearance = false` — 플레이어 로블록스 아바타의 옷·액세서리·체형을 불러오지 않아 **모든 캐릭터의 히트박스가 같아진다** (GDD 6 "모든 스킨은 히트박스·속도가 똑같아요"). 겉모습은 m3-02가 계란초밥으로 덮는다.
- 제외:
  - 각 기능의 실제 동작 (m3-02 ~ m3-08), 장애물 사운드 (m3-09)
  - 회전 벨트를 태그 방식으로 바꾸기(M1 B10), 결승 같은 틱 리셋 우승(m2-07 I1) — M3 범위 아님

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/camera-priority.spec.luau`, 기존 테스트 파일에 추가 가능)
- [ ] AC1: `CameraPriority.pick`에 `{Spectate 10, Intro 30}`을 주면 `Intro`, `Intro`를 빼면 `Spectate`, 빈 목록이면 nil이다. 같은 우선순위면 나중에 요청한 owner가 이긴다.
- [ ] AC2: `Config.Dive`, `Config.Grab`, `Config.Appearance.Default`, `Config.Match.VictoryCutscene`이 있고 `VictoryCutscene < VictoryDuration`이다. `Config.DEBUG.forceMapPlan`은 nil이다.
- [ ] AC3: `Attributes`의 이름들이 서로 겹치지 않는 문자열이다. `SfxCues`에 위 목록의 이름(효과음·음악)이 모두 있고 중복이 없다.
- [ ] AC4: `rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests`가 통과한다 (기존 209개 포함).

### Studio 확인
- [ ] AC5: 혼자(F5, `forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`) 한 판이 M2처럼 끝까지 돌고 서버·클라이언트 Output에 빨간 에러가 없다 (껍데기 컨트롤러가 아무것도 안 해도 깨지지 않음).
- [ ] AC6: 라운드 중 서버 Explorer에서 맵 Model(`Round1_...`)에 `RoomId`, `RoundIndex`, `MapId` 속성이 있다. 캐릭터 Model에 `AppearanceId = "tamago"` 속성이 있다.
- [ ] AC7: Shift를 눌러도 Shift Lock(마우스 고정)이 켜지지 않는다. 내 캐릭터가 로블록스 아바타 옷·액세서리 없이 기본 체형으로 나온다.
- [ ] AC8: 2~3명(Clients and Servers)으로 낙하 탈락 시 다른 클라이언트에 온 `PlayerResult`에 `cause = "Fall"`과 `position`이 있고(디버그 print로 확인 가능), 리셋하면 `cause = "Reset"`, 매치 중 방을 나가면 `cause = "Left"`이다.
- [ ] AC9: (관전 회귀) m2-06 AC5~AC12가 그대로 통과한다. 추가로 보고 있던 사람이 떨어져 탈락하면 약 3초 동안 그 사람 쪽을 계속 비춘 뒤 다음 사람으로 넘어간다.

## 공용 파일 변경
- `shared/Config.luau`: `Match.VictoryDuration` 6→10, `Match.VictoryCutscene`, `Appearance`, `Dive`, `Grab`
- `shared/Remotes.luau`: RemoteEvent `GrabInput` (클라이언트 → 서버)
- `shared/Types.luau`: `EliminationCause`, `PlayerResult.cause/position`
- `shared/maps/init.luau`: 없음
- `default.project.json`: `StarterPlayer.EnableMouseLockOption = false`, `StarterPlayer.LoadCharacterAppearance = false`
- 그 밖에 이 스펙이 고치는 기존 파일: `src/server/RoundService.luau`, `src/server/EliminationService.luau`, `src/client/ui/SpectateController.luau`, `src/client/init.client.luau`, `src/server/init.server.luau`
- 이 스펙 머지 이후 위 파일을 바꿔야 하면 해당 worktree는 직접 고치지 말고 사용자에게 알린다. **예외 없음** — 잡기 감속(m3-07)은 서버 `WalkSpeed`를 건드리지 않고 클라이언트 입력 배수로 처리하므로 `CharacterUtil`·`RoundService`·`EliminationService`를 고칠 필요가 없다 (m3-07 결정 기록).
- 병렬 단계(m3-02~08)가 끝난 뒤의 공용 파일 수정 담당은 **m3-09**(통합·튜닝)이다.

## 결정 기록
- 2026-10-08 · M3 스펙 분할 · 기반(m3-01) → 병렬 7개(m3-02~08) → 통합(m3-09). 카메라 충돌을 막으려고 `CameraDirector` 우선순위 중재를 기반에 넣음 · planner
- 2026-10-08 · 우승 단계 길이 · `VictoryDuration` 6→10초(연출 6 + 순위표 4). 한 판이 4초 길어짐. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 아바타 처리 · `LoadCharacterAppearance = false`로 로블록스 아바타를 불러오지 않고 모두 계란초밥(로비 포함). 히트박스를 같게 하려는 GDD 6 원칙. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · Shift Lock 끄기 · GDD 6 다이브 키가 Shift라 끔. 다이브는 E로도 됨 · planner
- 2026-10-08 · 관전자가 탈락 연출을 보게 · 보던 대상이 낙하·리셋으로 탈락하면 연출 시간 동안 그 자리를 계속 비춤. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · `Sfx.start(gui)` 추가 · m3-08이 배경음 전환·버튼 클릭음·음소거 버튼을 자기 파일 안에서 하도록 `init.client.luau` 등록을 이 스펙이 미리 해 둔다 (병렬 중 `init` 수정 방지) · planner
- 2026-10-08 · m3-07 예외 삭제 · 잡기 감속을 클라이언트 입력 배수로 정해서 서버 이동 값 파일을 열어 둘 필요가 없어짐 · planner
- 2026-10-08 · 사용자 지시: "일단 개발 다 해 놓으면 나중에 수정 명령을 내리겠다" → M3 스펙은 결정이 필요한 항목도 기본값을 정해 모두 ready로 둔다 · user (메인 세션 경유)
- 2026-10-08 · 시간 종료 탈락의 cause · 스펙은 Fall/Reset/Left만 정함. 라운드 시간 종료·통과 인원이 다 차서 남은 사람이 탈락하는 경우는 `cause = nil`(position은 그 순간 위치)로 보냄 → m3-03 `shouldPlay(nil) = false`라 이 사람들은 탈락 연출이 없다. Race에서 가장 흔한 탈락이라 연출을 원하면 기획이 cause 값(예: `"Timeout"`)을 정해 m3-09에서 추가 · developer (질문, 막히지는 않음)

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 · developer (main)
**바뀐 파일**
- 공용: `src/shared/Config.luau`(Match.VictoryDuration 10·VictoryCutscene 6, Appearance, Dive, Grab), `src/shared/Remotes.luau`(RemoteEvent `GrabInput`, 클라이언트 → 서버 절), `src/shared/Types.luau`(`EliminationCause`, `PlayerResult.cause/position`), `default.project.json`(StarterPlayer `EnableMouseLockOption = false`, `LoadCharacterAppearance = false`)
- 새 shared: `Attributes.luau`, `SfxCues.luau`(`Effects`/`Music` 목록, `all()`, `isEffect`, `isMusic`), `CameraPriority.luau`(`pick`), `SushiBody.luau`(껍데기)
- 새 client: `CameraDirector.luau`(실제 구현: `request/release/current/isActive`, `Priority`), `Sfx.luau`(껍데기), `fx/CharacterFxController`·`fx/EliminationCutsceneController`·`fx/IntroController`·`fx/VictoryCutsceneController`·`input/DiveController`·`input/GrabController`(껍데기, `start(gui)`)
- 새 server: `AppearanceService.luau`(`applyAppearance` = AppearanceId 속성만), `GrabService.luau`(GrabInput 받고 무시)
- 수정: `init.client.luau`(컨트롤러 목록, Sfx 먼저), `init.server.luau`(Appearance·Grab 서비스 등록), `RoundService.luau`(맵 Model 속성, cause/position 추적, `activeRoomOf`), `EliminationService.luau`(`eliminate(roomId, player, place, cause?, position?)`, `left`는 cause "Left"), `ui/SpectateController.luau`(CameraDirector 사용 + 탈락 대상 3초 비추기)
- 테스트: `tests/camera-priority.spec.luau` (AC1~AC3, 6개)

**인터페이스 메모**
- `CameraDirector.request`는 같은 owner가 다시 불러도 순서는 처음 요청 그대로, 1등이면 apply를 다시 부른다. 매 프레임 움직이는 연출은 `isActive(owner)`일 때만 카메라를 움직일 것.
- `PlayerResult.cause`가 nil인 탈락 = 시간 종료·통과 인원이 다 참 (결정 기록 참고).
- `SushiBody`는 모듈 맨 위에서 Roblox 자료형을 쓰지 않는다 (lune에서 `layout` 테스트 가능하게) — m3-02도 유지할 것.

**Studio 확인 방법** (AC5~AC9)
1. `Config.DEBUG.forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`로 바꾸고 F5 → 방 만들고 시작 → 한 판 끝까지. Output에 빨간 에러 없어야 함. (커밋 전 nil로 되돌릴 것)
2. 라운드 중 서버 뷰 Explorer: `Workspace/Round1_soy-swamp` 속성에 RoomId·RoundIndex·MapId, 내 캐릭터 Model에 `AppearanceId = "tamago"`.
3. Shift를 눌러 Shift Lock이 안 켜지는지, 캐릭터가 아바타 옷·액세서리 없는 기본 모습인지.
4. Clients and Servers 2~3명: 클라이언트 콘솔에서 `game.ReplicatedStorage.Remotes.PlayerResult.OnClientEvent:Connect(function(r) print(r.userId, r.result, r.cause, r.position) end)` 실행 후 낙하(Fall)·리셋(Reset, Esc→R)·매치 중 방 나가기(Left) 확인.
5. 관전 회귀: m2-06 AC5~AC12 (`docs/DEV-SETUP.md` M2 관전 항목). 추가: 관전 중인 사람이 떨어지면 약 3초 그 사람을 계속 비춘 뒤 다음 사람으로.
