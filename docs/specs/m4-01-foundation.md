status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-01 — M4 기반 작업 (공용 파일 · 이벤트 훅 · 프로필 껍데기 · 맵 키트 · 새 맵 2개 stub · P3 2건)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §5.2(맵 6개), §8(우승 칭호·단상), §9.4(밥알 코인), §9.5(DataStore), §10(코인 표시·보상 정산), §11.2(플레이스 분리), §12(M4), §13(리스크)
- 참고: `docs/REFERENCE-map-production.md` §5·§7(A) (컴포넌트화, 그레이박스 → 아트 교체 순서), `docs/planner/m4-plan.md`
- 담당 개발 worktree: `main` (**순차, M4에서 가장 먼저**. 이 스펙이 `main`에 병합·push된 뒤에 m4-02~m4-10 worktree를 만든다)
- 공용 파일 수정 담당: **이 스펙** — `shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `shared/maps/MapTypes.luau`, `shared/Attributes.luau`, `default.project.json`, `src/server/init.server.luau`, `src/client/init.client.luau`. 병렬 단계(m4-02~m4-10)는 이 파일들을 고치지 않는다(필요하면 사용자에게 알린다). 병렬 단계 뒤 공용 파일 담당은 **m4-11 → m4-12 → m4-13 → m4-14** 순서로 그 스펙이 맡는다(모두 `main` 순차).
- 의존: 없음 (M3 done 상태의 `main`). → **m4-02 ~ m4-14가 이 스펙에 의존**
- **이 스펙이 고치는 기존 파일**: 위 공용 파일 + `src/server/MatchService.luau`, `src/server/EliminationService.luau`, `src/server/RoundService.luau`, `src/server/CharacterUtil.luau`, `src/shared/RoundLogic.luau`

## 목표
M4 병렬 개발(맵 아트 2 · 새 맵 2 · 로비 · 저장 · 보상 · 모바일 · 이동 감시)이 서로 같은 파일을 건드리지 않도록 공용 파일과 연결 지점을 한 번에 만든다. 플레이어가 보기에 달라지는 건 거의 없고(새 맵 2개가 회색 stub으로 풀에 들어감), 이후 스펙이 "자기 파일만 채우면" 되게 한다.

## 범위
- 포함:
  1. **`shared/Config.luau`** — 아래 값 추가 (전부 기본값, 사용자 수정 가능):
     ```lua
     -- 플레이스 분리 (m4-11). 사용자가 Match 플레이스를 만들고 id를 넣기 전까지 nil → 한 플레이스 모드(지금과 같음)
     Config.Places = { LobbyPlaceId = nil :: number?, MatchPlaceId = nil :: number? }
     Config.Teleport = {
         ArrivalTimeout = 20,      -- 매치 서버가 멤버 도착을 기다리는 최대 시간(초)
         RestoreWindow = 30,       -- 로비로 돌아온 멤버가 같은 방으로 다시 묶이는 시간(초)
         DirectoryRefresh = 5,     -- 방 목록을 MemoryStore에 다시 올리는 간격(초)
         DirectoryTtl = 30,        -- MemoryStore 방 항목 만료(초)
         MaxRetries = 3,
     }
     -- 저장 (m4-07)
     Config.Data = {
         StoreName = "PlayerData_v1",
         AutosaveInterval = 60,    -- 바뀐 프로필 자동 저장 간격(초)
         SessionLockExpiry = 1800, -- 다른 서버의 세션 잠금을 무시해도 되는 시간(초)
         LoadRetries = 5,          -- 잠금이 걸려 있을 때 다시 읽는 횟수 (텔레포트 직후 대비)
         RetryDelay = 2,
         SettingsMinInterval = 0.5,-- SaveSettings 요청 간격 제한(초)
     }
     -- 밥알 코인 (GDD 9.4, m4-08)
     Config.Rewards = { RoundPass = 10, FinalQualify = 30, Win = 100, DailyFirstMatch = 50 }
     -- 우승 칭호 (GDD 8). 승수 오름차순
     Config.Titles = {
         { wins = 1, name = "탈출 초밥" },
         { wins = 10, name = "전설의 참치" },
         { wins = 100, name = "바다의 왕" },
     }
     -- 화면 크기 대응 (m4-09)
     Config.Ui = {
         BaseShortSide = 720,  -- 이 짧은 변(px)에서 UIScale 1
         MinScale = 0.6, MaxScale = 1.25,
         CompactShortSide = 500, -- 짧은 변이 이하면 휴대폰 배치
         MinTouchSize = 44,     -- 터치 버튼 최소 크기(px, 스케일 적용 뒤)
     }
     -- 서버 이동 감시 (m4-10)
     Config.MovementGuard = {
         SampleInterval = 0.2,
         MaxHorizontalSpeed = 80, -- 다이브·와사비·벨트 밀기를 합친 여유 상한 (studs/s)
         MaxRiseSpeed = 140,      -- 와사비 튕김 포함 위로 가는 속도 상한
         Slack = 6,               -- 샘플마다 더 허용하는 거리 (studs)
         ExemptAfterServerMove = 1.0, -- 서버가 옮긴/튕긴 뒤 검사하지 않는 시간(초)
         PassBlockAfterViolation = 2, -- 위반 뒤 이 시간 동안 결승선 통과를 받지 않음(초)
         StrikesToLog = 3,
     }
     Config.DEBUG.persistDataInStudio = false -- true면 Studio에서도 진짜 DataStore에 저장 (API 접근 허용 필요, m4-07)
     ```
     스킨·상점 값(`Config.Shop` 등)은 넣지 않는다 — m4-13·m4-14가 그때 공용 파일 담당으로 넣는다.
  2. **`shared/Remotes.luau`** — RemoteEvent 3개 추가 (이후 16개):
     - 서버 → 클라이언트 `ProfileUpdated(view: ProfileView)` — 내 프로필이 로드되거나 바뀔 때 본인에게만
     - 서버 → 클라이언트 `RewardGranted(grant: RewardGrant)` — 코인을 받을 때 본인에게만 (m4-08이 보냄)
     - 클라이언트 → 서버 `SaveSettings(settings: { muteLevel: number })` — 서버가 타입·범위(정수 1~3)·간격(`Config.Data.SettingsMinInterval`)을 검증
  3. **`shared/Types.luau`**:
     ```lua
     export type Settings = { muteLevel: number }               -- 1 소리 켬, 2 음악 끔, 3 모두 끔 (m3-08 단계와 같음)
     export type ProfileView = {
         coins: number, wins: number, title: string?,
         equippedSkin: string, ownedSkins: { string },
         settings: Settings,
         persistent: boolean,  -- false면 저장되지 않는 프로필(Studio 메모리 모드·로드 실패)
     }
     export type RewardReason = "RoundPass" | "FinalQualify" | "Win" | "DailyFirstMatch"
     export type RewardGrant = { reason: RewardReason, amount: number, total: number }
     ```
  4. **`shared/Attributes.luau`** — 캐릭터 Model 속성 2개 추가:
     - `Title` (string): 머리 위 이름표에 붙는 칭호 (m4-08이 서버에서 단다)
     - `MoveExemptUntil` (number, `workspace:GetServerTimeNow()` 기준): 서버가 캐릭터를 옮기거나 튕긴 뒤 이동 감시(m4-10)가 검사하지 않는 시각
  5. **`shared/MoveExempt.luau`** (새, 실제 구현) — `MoveExempt.mark(character: Model, seconds: number?)`: `MoveExemptUntil = now + (seconds or Config.MovementGuard.ExemptAfterServerMove)`. 이미 더 늦은 값이면 줄이지 않는다. 맵 모듈(shared)도 쓸 수 있다. 이 스펙이 부르는 곳: `CharacterUtil.toLobby`, `RoundService`의 스폰 배치. 맵 장애물(와사비·꼬치·젓가락·칼 등)은 각 맵 스펙이 부른다.
  6. **`shared/ProfileSchema.luau`** (새, 실제 구현, 순수):
     ```lua
     export type Profile = {
         version: number, coins: number, wins: number, matchesPlayed: number,
         lastDailyBonusDay: number?,          -- UTC 날짜 번호 (os.time() // 86400)
         ownedSkins: { [string]: boolean },   -- 처음엔 { tamago = true }
         equippedSkin: string,                -- 처음엔 Config.Appearance.Default
         settings: Settings,                  -- 처음엔 { muteLevel = 1 }
     }
     ProfileSchema.VERSION = 1
     ProfileSchema.new(): Profile
     ProfileSchema.titleFor(wins: number): string?   -- Config.Titles에서 wins 이하 중 가장 높은 것, 0승이면 nil
     ProfileSchema.toView(profile, persistent: boolean): ProfileView   -- ownedSkins는 이름순 목록
     ```
  7. **`server/DataService.luau`** (새, **메모리 버전 실제 구현** — 진짜 저장은 m4-07이 같은 파일에 붙인다):
     - `DataService.get(player): Profile?` (로드 전·없으면 nil), `DataService.waitForProfile(player, timeout: number?): Profile?`
     - `DataService.update(player, mutate: (Profile) -> ()): boolean` — 로드 전이면 false. 바꾼 뒤 그 프레임 끝에 본인에게 `ProfileUpdated`(한 프레임에 여러 번 바꿔도 한 번).
     - `DataService.onLoaded(fn(player, profile))` (이미 로드된 사람에게도 바로 부름), `DataService.canPersist(player): boolean` (지금은 항상 false)
     - `PlayerAdded`에서 `ProfileSchema.new()`로 바로 로드, `PlayerRemoving`에서 지움.
     - `SaveSettings` 처리: 표·정수 1~3·간격 검증 후 `profile.settings.muteLevel` 갱신. 잘못된 값은 조용히 무시.
  8. **`client/ProfileStore.luau`** (새, 실제 구현) — `ProfileUpdated`를 받아 최신 `ProfileView`를 보관. `ProfileStore.get(): ProfileView?`, `ProfileStore.changed(fn(view)) -> RBXScriptConnection 같은 해제 가능한 연결`. `start(gui)`를 가진다 (컨트롤러 목록 맨 앞, Sfx보다 먼저).
  9. **`server/MatchEvents.luau`** (새, 실제 구현) — 매치 흐름을 다른 서비스가 듣는 곳. 핸들러는 `task.spawn` + pcall로 격리해서 하나가 에러 나도 매치가 멈추지 않는다.
     ```lua
     MatchEvents.onMatchStart(fn(roomId: string, userIds: { number }))
     MatchEvents.onRoundStart(fn(roomId: string, roundIndex: number, roundCount: number, userIds: { number }))  -- 출발(RoundActive) 순간, 그 라운드 레이서
     MatchEvents.onResult(fn(roomId: string, result: Types.PlayerResult))  -- PlayerResult를 방송할 때마다
     MatchEvents.onMatchEnd(fn(roomId: string, info: { winnerUserId: number?, standings: { Types.Standing }, participants: { number } }))
     MatchEvents.onWinnerShowcase(fn(info: { userId: number, name: string, appearanceId: string }))  -- 로비 단상에 세울 우승자
     -- 각각 fireXxx(...) 짝
     ```
     부르는 곳: `MatchService`(matchStart = Starting 방송 직후, roundStart = `prepared.run` 직전, matchEnd = 승부가 정해진 순간 — 우승자가 있으면 Victory 방송 **직후**(우승 연출·순위표 10초 동안 보상 정산을 보여 줄 수 있게), 없으면 `sendHome` 직전, 한 매치에 한 번만, winnerShowcase = 우승자가 있으면 Victory 단계가 끝난 뒤 `sendHome` 직전), `EliminationService`(result = 방송할 때). 한 플레이스 모드에서는 매치와 로비가 같은 서버라 winnerShowcase를 여기서 쏜다. 플레이스 분리 모드에서는 m4-11이 로비 서버에서 쏜다.
  10. **`RoundService.setPassValidator(fn: (player: Player) -> boolean)`** — 한 개만 등록(두 번째는 assert). 등록돼 있으면 `ctx.pass(player)` 때 먼저 묻고 false면 그 통과를 **무시**한다(통과 처리·방송 없음, 플레이어는 계속 달림). 결승 진출 2명 보장의 구제 통과는 묻지 않는다. 등록 안 돼 있으면 지금과 같다.
  11. **`shared/PlaceRole.luau`** (새, 실제 구현, 순수) — `PlaceRole.resolve(placeId: number, places, isStudio: boolean): "Single" | "Lobby" | "Match"`. Studio이거나 `LobbyPlaceId`·`MatchPlaceId` 중 하나라도 nil이면 `"Single"`, `placeId == MatchPlaceId`면 `"Match"`, 그 밖은 `"Lobby"`.
  12. **맵 키트 `shared/maps/MapKit.luau` + `shared/maps/MapKitLogic.luau`** (새, 실제 구현) — 맵 아트(m4-02~05)와 로비(m4-06)가 같이 쓰는 도구. **REFERENCE-map-production §5의 "그레이박스 → 아트 교체" 순서와 §7(A) 조각 헬퍼를 코드로**:
      - `MapKitLogic` (순수, lune 테스트): `export type DecorSpec = { name, shape: "Block"|"Ball"|"Cylinder"|"Wedge", size: {x,y,z}, color: {r,g,b}, material: string, offset: {x,y,z}, rotation: {x,y,z}?(도), transparency: number? }`. `validate(specs) -> string?`(크기 > 0, 색 0~255, 재질 이름이 `MapKitLogic.MATERIALS` 목록 안), `count(specs)`, `bounds(specs)`. `MapKitLogic.PALETTE`(밥 흰색, 김 검정, 간장 갈색, 와사비 연두, 연어 주황, 참치 빨강, 계란 노랑, 나무 결 갈색, 도자기 흰색·남색 테두리, 철판 회색, 옻칠 빨강, 노렌 남색). `MapKitLogic.DECOR_PART_BUDGET = 600`, `PARTICLE_BUDGET = 8`, `LIGHT_BUDGET = 12` (맵 하나당).
      - `MapKit` (Roblox): `MapKit.decorFolder(model): Folder` (맵 Model 아래 `Decor` 폴더, 없으면 만듦), `MapKit.buildDecor(specs, origin: CFrame, parent: Instance)` — **장식 파츠는 전부 `Anchored`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`** (게임 판정·충돌에 절대 영향 없음), `MapKit.introCamera(model, points: { { pos: {x,y,z}, lookAt: {x,y,z} } }, origin)` — m3-04 규칙대로 `IntroCamera` 폴더에 이름순(`01`, `02`, …) 투명 앵커 파츠, 앞면이 lookAt을 향하게. `MapKit.attachStudioArt(model, mapId, origin)` — `ServerStorage.MapArt[mapId]`(Model)가 있으면 복제해서 `Decor` 아래 `StudioArt`로 붙이고 `PivotTo(origin)`, 안의 모든 BasePart를 장식 규칙(충돌·쿼리·터치 없음, Anchored)으로 강제한다. 없으면 아무것도 안 한다. 서버가 아니면 아무것도 안 한다.
      - 기존 맵 4개의 `build`는 이 스펙에서 고치지 않는다 (m4-02·m4-03이 아트 패스 때 `attachStudioArt`를 부름).
  13. **새 맵 2개 stub** (파일 생성 + `maps/init.luau` `ALL`에 등록, m2-01과 같은 방식). id·종류·이름·규칙 문구는 **확정**(이후 스펙이 바꾸지 않는다):

      | 파일 | id | kind | displayName | rule |
      |---|---|---|---|---|
      | `maps/RamenRapids.luau` | `ramen-rapids` | Race | 라멘 국물 급류 | 국물 급류를 타고 차슈·나루토를 밟아 건너, 결승선까지! |
      | `maps/ChefBoard.luau` | `chef-board` | Survival | 셰프의 도마 | 칼이 내려치는 줄을 피하고, 잘려 나가는 도마 위에서 끝까지 버티세요! |

      stub: 회색 바닥 + `Spawns` 24개 (+ Race는 `FinishLine`과 결승선 통과 → `ctx.pass`), origin 아래 40 studs 낙하 → `ctx.eliminate`. 실제 맵은 m4-04·m4-05가 같은 파일을 덮어쓴다.
  14. **껍데기 파일**(만들고 `init`에 등록, 동작은 각 스펙이 채움):

      | 파일 | 채우는 스펙 | 껍데기가 하는 일 |
      |---|---|---|
      | `src/server/LobbyService.luau` | m4-06 | 없음 (`init`/`start`) |
      | `src/client/fx/LobbyFxController.luau` | m4-06 | 없음 (`start(gui)`) |
      | `src/server/RewardService.luau` | m4-08 | 없음 |
      | `src/client/ui/CoinController.luau` | m4-08 | 없음 |
      | `src/client/ui/UiScaleController.luau` | m4-09 | `UiScaleController.attach(screenGui: ScreenGui)` 빈 함수 (화면 크기 배율을 붙일 ScreenGui를 등록하는 자리 — m4-08 `CoinScreen` 등 새 화면도 부름) |
      | `src/server/MovementGuardService.luau` | m4-10 | 없음 |
      | `src/server/PlaceService.luau` | m4-11 | `PlaceService.role()` = `PlaceRole.resolve(game.PlaceId, Config.Places, RunService:IsStudio())` (지금은 항상 `"Single"`) |

      서버 등록 순서: `DataService`를 맨 앞, `PlaceService` 다음, 그 뒤 기존 서비스, 그 뒤 새 서비스. 클라이언트: `ProfileStore` → `Sfx` → 기존 → 새 컨트롤러.
  15. **P3 정리 2건** (이 스펙이 이미 고치는 파일 안이라 같이 한다):
      - **m2-07 I1 결승 같은 틱 낙하 + 리셋·퇴장**: 결승에서 한 판정 묶음 안에 낙하(`Fall`) 탈락과 리셋·퇴장(`Reset`/`Left`) 탈락이 섞이면, **리셋·퇴장한 사람이 더 먼저 탈락한 것으로**(더 나쁜 등수) 처리한다. 그래서 우승은 낙하한 사람 중 더 높이 버틴 사람이다. 묶음이 전부 리셋·퇴장이고 남은 사람이 0명이면 지금처럼 우승자 없이 끝낸다 (`RoundLogic`에 순수 함수로, 기존 테스트 유지).
      - **m3-03 B2 낙하 탈락 위치**: `cause = "Fall"`인 `PlayerResult.position`을 "판정 순간 위치(코스 20~40 studs 아래)" 대신 **그 레이서가 마지막으로 땅을 밟고 있던 위치**(`Humanoid.FloorMaterial ~= Air`인 마지막 HumanoidRootPart 위치, 0.1초 간격 기록)로 보낸다. 기록이 없으면 지금 값. → 탈락 연출이 코스 가장자리에서 보인다.
  16. **`default.project.json`**:
      - `ServerStorage` 아래 `MapArt` 폴더를 `assets/map-art`(`$path`)에 연결한다. 사용자가 Studio에서 만든 장식 Model을 `assets/map-art/<맵 id>.rbxm`로 넣으면 Rojo가 `ServerStorage.MapArt.<맵 id>`로 싣는다. 빈 폴더를 Git에 남기는 방법(예: `.gitkeep`이 Rojo 빌드를 깨지 않는지)은 개발이 확인해서 정한다.
      - `StarterGui.ScreenOrientation = "LandscapeSensor"` — 휴대폰을 가로로 고정 (m4-09 기준 화면).
  17. 테스트: `tests/m4-foundation.spec.luau`.
- 제외:
  - 진짜 DataStore 저장(m4-07), 코인 계산(m4-08), 로비 건물(m4-06), 모바일 배치(m4-09), 이동 감시 동작(m4-10), 텔레포트(m4-11)
  - 기존 맵의 모양·색 변경 (m4-02·m4-03), 새 맵의 실제 코스 (m4-04·m4-05)
  - 스킨·상점 (m4-13·m4-14, CLAUDE.md "가장 마지막")

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/m4-foundation.spec.luau`)
- [ ] AC1: `PlaceRole.resolve`가 (Studio = true) → `Single`, (id 둘 다 nil) → `Single`, (Lobby만 있음) → `Single`, (둘 다 있고 placeId = Match) → `Match`, (둘 다 있고 placeId = Lobby 또는 다른 값) → `Lobby`를 돌려준다.
- [ ] AC2: `ProfileSchema.new()`는 coins 0, wins 0, `ownedSkins = { tamago = true }`, `equippedSkin = "tamago"`, `settings.muteLevel = 1`, `version = 1`이고, 부를 때마다 다른 표다(하나를 고쳐도 다른 것이 안 바뀜).
- [ ] AC3: `titleFor(0) = nil`, `titleFor(1) = "탈출 초밥"`, `titleFor(9) = "탈출 초밥"`, `titleFor(10) = "전설의 참치"`, `titleFor(250) = "바다의 왕"`. `toView`의 `ownedSkins`는 이름순 목록이고 `title`은 `titleFor(wins)`다.
- [ ] AC4: `MapKitLogic.validate`가 크기 0, 색 300, 목록에 없는 재질을 각각 거부하고 정상 목록은 nil을 돌려준다. `count`·`bounds`가 손으로 계산한 값과 같다.
- [ ] AC5: (결승 같은 묶음) 남은 2명 중 A는 `Fall`(높이 10), B는 `Reset`(높이 50)으로 같은 묶음에서 탈락하면 우승은 A, B는 2등이다. 둘 다 `Reset`이면 우승자 없음. 기존 `round-logic` 테스트가 그대로 통과한다.
- [ ] AC6: `Maps.infos()`에 Race 3개(`rotating-belt`, `soy-swamp`, `ramen-rapids`), Survival 2개(`hot-plate`, `chef-board`), Final 1개가 있고 새 stub 2개가 `MapTypes.validate`를 통과한다. 시드 1~500의 4라운드 구성에서 중복 0회, Survival 1~2번.
- [ ] AC7: `Config.Places`의 두 id가 nil, `Config.DEBUG.forceMapPlan`이 nil, `Config.DEBUG.persistDataInStudio`가 false다. `Config.Titles`가 wins 오름차순이다.
- [ ] AC8: `rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests`가 통과한다 (기존 테스트 포함).

### Studio 확인
- [ ] AC9: 혼자 F5(`forceMapPlan = { "ramen-rapids", "chef-board", "soy-swamp", "skewer-showdown" }`) 한 판이 끝까지 돌고 서버·클라이언트 Output에 빨간 에러가 없다. 새 stub 2개가 회색 바닥으로 나온다.
- [ ] AC10: 접속하면 클라이언트 콘솔에서 `require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get()`이 coins 0, `persistent = false`인 표를 돌려준다.
- [ ] AC11: 서버 Explorer에서 `ServerStorage.MapArt` 폴더가 있다. 그 안에 이름이 `rotating-belt`인 Model(파트 하나)을 Studio에서 직접 넣고 (m4-02 전이라도) `MapKit.attachStudioArt`를 부르는 맵이 있으면 그 파트가 맵 `Decor/StudioArt` 아래에 나오고 밟고 지나갈 수 있다(충돌 없음). — m4-02 전에는 호출하는 맵이 없으므로 이 항목은 m4-02 QA 때 확인해도 된다.
- [ ] AC12: 2명(Clients and Servers)으로 결승에서 한 명이 떨어지는 장면을 다른 클라이언트가 보면, 떨어진 사람의 탈락 연출이 접시 무대 가장자리 높이에서 재생된다 (예전엔 무대 20 studs 아래).
- [ ] AC13: 기기 에뮬레이터(휴대폰)로 켜면 화면이 가로로 고정된다.
- [ ] AC14: (회귀) `docs/DEV-SETUP.md` 3-7·3-8의 핵심 항목(한 판 완주, 탈락·우승 연출, 다이브·잡기)이 그대로 된다.

## 공용 파일 변경
- `shared/Config.luau`: `Places`, `Teleport`, `Data`, `Rewards`, `Titles`, `Ui`, `MovementGuard`, `DEBUG.persistDataInStudio`
- `shared/Remotes.luau`: RemoteEvent `ProfileUpdated`(S→C), `RewardGranted`(S→C), `SaveSettings`(C→S)
- `shared/Types.luau`: `Settings`, `ProfileView`, `RewardReason`, `RewardGrant`
- `shared/Attributes.luau`: `Title`, `MoveExemptUntil`
- `shared/maps/init.luau`: `RamenRapids`, `ChefBoard` 등록
- `shared/maps/MapTypes.luau`: 변경 없음 (필요하면 이 스펙에서만)
- `default.project.json`: `ServerStorage.MapArt` → `assets/map-art`, `StarterGui.ScreenOrientation = LandscapeSensor`
- `init.server.luau` / `init.client.luau`: 새 서비스·컨트롤러 등록

## 결정 기록
- 2026-10-08 · M4 스펙 분할 · 기반(m4-01) → 병렬 9개(m4-02~10) → 플레이스 분리(m4-11) → 출시 점검(m4-12) → 스킨(m4-13) → 로벅스 상점(m4-14). 스킨·결제는 CLAUDE.md대로 맨 끝 · planner
- 2026-10-08 · 사용자 지시 "일단 개발하고 나중에 수정" → M4도 결정이 필요한 항목은 기본값으로 정하고 모두 ready · user (메인 세션 경유)
- 2026-10-08 · 결승 같은 묶음 낙하 + 리셋 (m2-07 I1) · 리셋·퇴장이 더 나쁜 등수, 우승은 낙하자 중 더 높이 버틴 사람. 근거: GDD 4.1 "리셋·퇴장은 구제 없음"과 같은 방향. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 탈락 연출 위치 (m3-03 B2) · 서버가 "마지막으로 땅을 밟은 위치"를 보냄. 클라이언트 연출 코드는 안 바꿈 · planner
- 2026-10-08 · Studio 아트 끼우는 방법 · 사용자가 Studio에서 만든 장식은 `assets/map-art/<id>.rbxm` → `ServerStorage.MapArt`, 장식 전용(충돌 없음). 충돌·판정 지오메트리는 계속 코드가 만든다 — 에이전트가 검증할 수 있는 상태를 유지 (REFERENCE-map-production §7(B) "회색 박스 치수 유지 + 표면만 교체" 쪽). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 휴대폰 화면 방향 · 가로 고정(`LandscapeSensor`). 세로 화면 배치는 M5 이후. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 새 맵 2개 · GDD 5.2 ③ 라멘 국물 급류(Race), ④ 셰프의 도마(Survival)로 MVP 6개를 채움 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
