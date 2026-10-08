# CLAUDE.md — Sushi Survival Race

로블록스 라운드제 서바이벌 레이스 게임. 플레이어는 초밥이 되어 젓가락을 피해 달리고, 3~4라운드 뒤 1명만 우승한다.

- **기획서(단일 진실 공급원): `docs/GDD.md`** — 작업 전에 관련 섹션을 먼저 읽는다. 기획과 다르게 구현해야 하면 사용자에게 먼저 묻는다.
- 사용자와는 **한국어**로 대화한다. 코드 식별자·커밋 메시지는 영어.

## 현재 상태
- 기획서 **v0.4** (M3·M4 기본값, 맵 6개, 저장·이동 감시·플레이스 분리, 스킨 가격 A안 확정). **M0~M4 개발 완료** — 모든 스펙(m2-01~m4-14)이 `done`. 자세한 내역은 `docs/CHANGELOG.md`.
- **지금은 사용자 차례**: Studio 확인(`docs/DEV-SETUP.md` 3-7·3-8·3-9), 기본값 결정, 소리 고르기, 퍼블리시·Match 플레이스·개발자 상품 만들기, 비공개 테스트. 할 일 전체는 **[`docs/USER-TODO.md`](docs/USER-TODO.md)** (끝낸 항목·결정은 그 파일 "답변 기록"에 사용자가 적는다).
- **다음 단계**: 사용자 확인·테스트 결과(`docs/USER-TODO.md` 답변 기록, `docs/playtest/m3.md`·`m4.md`)에 따른 수정(planner가 스펙·GDD, developer가 Config·코드) → 비공개 테스트 → 공개 → **M5**(새 맵, 시즌 스킨, VIP·연출 팩·스타터 팩, 콘솔 UI). 진행 상황은 `grep -H "^status:" docs/specs/*.md`.
- 맵 풀 6개: Race `rotating-belt`(회전 벨트)·`soy-swamp`(간장 늪 & 와사비 산)·`ramen-rapids`(라멘 국물 급류), Survival `hot-plate`(뜨거운 철판)·`chef-board`(셰프의 도마), Final `skewer-showdown`(회전 꼬치 쇼다운). 판정 지오메트리는 코드, 색·재질·장식(`MapKit`)도 코드, 사용자 Studio 장식은 `assets/map-art/<id>.rbxm`(장식 전용).
- 들어간 것: 방 시스템, 한 판 전체 흐름, 관전, 계란초밥 캐릭터, 탈락·우승·라운드 소개 연출, 다이브·잡기, 소리(일부 무음 — 사용자가 id를 고름), 회전초밥집 로비·우승자 단상, DataStore 저장(세션 잠금), 밥알 코인·승수·칭호, 휴대폰 UI, 서버 이동 감시, 로비/매치 플레이스 분리(플레이스 id 없으면 한 플레이스 모드), 스킨 16종·탈의실·코인 해금, 로벅스 개발자 상품 결제(상품 id 입력 전이라 버튼은 "곧 열려요").
- 남은 P3·보류 요약 (자세한 건 CHANGELOG M4 "알려진 한계 · 보류"):
  - 이동 감시: 복제가 0.6초 넘게 멈추면 정상 플레이어도 되돌려질 수 있음(m4-10 R1, 허용 0.5초와 맞바꿈), 지속 속도 약 110 studs/s 미만 조작은 못 잡음(R2), 캐릭터끼리 튕김 오탐(B4).
  - 다이브 지름길 확인 대기(m3-06 B2·B3, m4-12 AC6), 결승 소개 중 리셋 연출 잘림(m3-09 B4, 둠).
  - 맵: 철판·결승 큰 장식의 카메라 가림(m4-03 B2, Studio 확인), 꼬치 음식 장식 서버 복제(B5), 도마 계단 모양 가장자리(m4-05 C1).
  - 저장·서버 이동: 퇴장 저장이 10초를 넘으면 마지막 진행 유실 가능(m4-07 D6·m4-11 R4), 정원 복귀 방 10초 뒤 자동 출발(m4-11 R6, 기획 확인).
  - 단상·연출: 우승자가 일찍 나가면 단상 칭호·승수 없음·우승 연출 인형 기본 외형(m4-13 N4), 매치 서버 늦은 프로필로 라운드 중 외형 바뀜(N2), 잡기 재전송 네트워크 흔들림(m4-12 N2).
- 검토 대기 제안서: `docs/proposals/robux-gameplay.md` (사용자 승인 전, GDD 미반영). 참고 자료: `docs/REFERENCE-map-production.md`(맵 제작), `docs/REFERENCE-party-royale.md`(파티 로얄 장르), `docs/REFERENCE-roblox-monetization.md`(가격·수익화, A안 근거).

## 스킨 · 상점 규칙
- 스킨은 **겉모습만** 바꾼다(토핑·색·효과 1개 이하). 크기·히트박스·속도는 모두 같다. 능력치 판매·뽑기 없음 (GDD 9.1).
- 캐릭터 외형은 **`AppearanceService.applyAppearance` 한 곳**에서만 입힌다. `appearanceId`가 nil이면 `ShopService`가 등록한 resolver가 장착 스킨을 고른다. `Attributes.AppearanceId`를 쓰는 곳도 여기뿐. 인형(탈락·우승 연출·단상·탈의실 미리보기)은 `SushiBody.build`로 따로 만든다.
- 카탈로그는 `shared/Skins.luau`(16종). **가격 A안 확정**: 로벅스 일반 29 / 레어 59 / 에픽 99 / 전설 199, 코인 일반 300 / 레어 900, 에픽·전설은 로벅스만. 코인을 로벅스로 파는 상품은 만들지 않는다.
- 로벅스 결제는 `RobuxShopService`의 `ProcessReceipt` 하나. 프로필 `saveNow` 성공 → 구매 기록(`Purchases_v1`, 키 PurchaseId) 성공일 때만 `PurchaseGranted`, 아니면 `NotProcessedYet`. 판단은 순수 `ReceiptLogic`. 상품 id는 사용자가 만든 뒤 `Skins.luau`의 `productId`에.
- 달리는 중(소개 포함)·탈락 연출·우승 연출 중에는 장착·코인 해금을 거절한다.

## 역할 분담 (에이전트 협업)
기획 `planner` · 개발 `developer` · QA `qa` · 문서화 `docs-writer` 서브에이전트가 `.claude/agents/`에 있다.
작업은 **스펙 파일(`docs/specs/`) → 구현 → QA 리포트(`docs/qa/`) → 문서 반영** 순서로 파일을 통해 넘긴다.
흐름, 상태값, 파일 소유권, 실행 방법은 **`docs/WORKFLOW.md`**를 따른다. 역할별 작업 기록은 `docs/<역할>/`.
- **세션이 끝날 수 있으니 커밋할 때마다 자기 브랜치를 push하고 인계 메모를 남긴다.** 로컬 세션이 끝나면 클라우드 세션(`claude --cloud`)이 이어받는다 — `docs/WORKFLOW.md` "클라우드 세션으로 인계".

## 확정된 기획 요약 (자세한 건 GDD)
- **방 시스템**: 방장이 방을 만들 때 최대 인원(4/8/12/16/24), 공개/비공개(4자리 코드)를 설정. 최소 4명이면 방장이 시작, 정원이 차면 자동 시작.
- **라운드 수**: 시작 인원 4~8명 → 3라운드, 9~24명 → 4라운드. 한 판 4~5분.
- **통과 인원**: `clamp(round(시작 × 비율), 2, 시작 - 1)`. 비율 3라운드 [0.60, 0.50, 결승], 4라운드 [0.65, 0.55, 0.50, 결승]. 결승 전 남은 인원 ≤ 2면 바로 결승. 코드(`Rules.qualifyCount`)는 "시작"을 **그 라운드를 시작할 때 살아 있는 인원**으로 계산한다.
- **맵**: 라운드마다 맵이 바뀌고 맵마다 규칙이 다르다. 종류는 Race / Survival / Final. 첫 라운드는 항상 Race, 마지막은 항상 Final, 한 판에 같은 맵 중복 없음, 4라운드면 Survival 최소 1번.
- **결승**: 생존형. 1명이 남는 순간 우승, 같은 순간 다 떨어지면 더 높이 버틴 사람. 같은 묶음에 낙하와 리셋·퇴장이 섞이면 리셋·퇴장이 더 나쁜 등수. **Survival** 시간 종료면 버틴 사람 전원 통과. Race 통과자는 대기석(로비 스폰)으로.
- **결승 진출 2명 보장**: 결승 전 라운드에서 낙하로 살아남을 사람이 2명 아래가 되면 더 멀리/높이 간 사람부터 구제(통과). 리셋·퇴장은 구제 없음. 결승 전 라운드에서 혼자 남으면 바로 부전승. 우승자는 항상 `Won`을 받은 사람이다.
- **보상**: 라운드 통과 +10, 결승 출발 +30, 우승 +100, 하루 첫 판 +50(UTC, 매치 끝까지 방에 남은 사람). 칭호 1승 "탈출 초밥", 10승 "전설의 참치", 100승 "바다의 왕".
- **판정은 전부 서버**(결승선, 탈락, 순위, 코인, 구매, 이동 감시). 클라이언트는 입력·UI·연출만.

## 기술 스택과 구조
- Roblox Studio + **Rojo**, 언어 **Luau** (`src/`는 전부 `--!strict`, 타입 검사는 luau-lsp 새 검사기).
- 맵 판정은 **코드로 생성한 지오메트리**(에이전트가 만들고 검증할 수 있게), 아트도 코드 장식(`MapKit`) + 선택적인 사용자 Studio 장식.
- **플레이스**: `PlaceService.role()` = `"Single"`(Studio 또는 `Config.Places` 비어 있음 — 한 플레이스 안에서 로비와 매치) / `"Lobby"` / `"Match"`. 한 플레이스 모드에서는 방마다 아레나를 좌표를 띄워 따로 생성한다(`Config.Arena`: 높이 300, 슬롯 간격 2000 → `RoomService.getArenaOrigin`). 분리 모드는 MemoryStore 매니페스트(키 PrivateServerId)를 믿고, TeleportData는 힌트로만 쓴다.

```
default.project.json     # Rojo 트리 + Workspace의 Baseplate, LobbySpawn, ServerStorage.MapArt ← assets/map-art, 가로 고정
rokit.toml               # rojo 7.7.1, stylua 2.5.2, selene 0.32.0, lune 0.10.5, luau-lsp 1.70.1
selene.toml  stylua.toml
types/                   # globalTypes.None.d.luau (luau-lsp 1.70.1 Roblox 정의, 커밋), README.md (타입 검사 방법)
assets/map-art/          # 사용자 Studio 장식 <맵 id>.rbxm → ServerStorage.MapArt (README.md)
src/
  server/            -> ServerScriptService.Server
    init.server.luau     # 서비스 부트스트랩: 모든 서비스 init() 다음 start(). DataService → PlaceService → 기존 → M4 서비스
    DataService.luau     # 프로필 DataStore(PlayerData_v1, u_<UserId>), 세션 잠금, 자동 저장. get/waitForProfile/update/onLoaded/canPersist/saveNow
    PlaceService.luau    # 역할(Single/Lobby/Match), 로비→매치 텔레포트, 매치 서버 도착 대기, 같은 방 복귀, MatchResult
    PlaceBackend.luau    # TeleportService·MemoryStore 래퍼 (Studio 메모리 가짜)
    RoomDirectory.luau   # 서버 간 공개 방 목록·비공개 코드 (MemoryStore)
    RoomService.luau     # 방 생성/참가/퇴장/방장/시작, 요청 간격 0.3초. onMatchStart/endMatch/getArenaOrigin, setPlaceHooks
    MatchService.luau    # 방 하나의 매치 상태 머신 (MatchPhase 방송, decideWinner, finish → 로비/텔레포트)
    MatchEvents.luau     # 매치 훅: onMatchStart/onRoundStart/onResult/onMatchEnd/onWinnerShowcase (핸들러 격리)
    RoundService.luau    # prepareRound(args) → { run, cancel, racerCount }. setPassValidator, setPlacementListener, placedRoomOf, activeRoomOf
    EliminationService.luau  # passed/won/left/eliminate → PlayerResult 방송
    CharacterUtil.luau   # resetMovement, toLobby(로비 스폰 = 대기석)
    AppearanceService.luau   # applyAppearance (외형 단일 지점), setResolver, refresh
    GrabService.luau     # 잡기 판정 (GrabInput)
    LobbyService.luau    # 로비 건물·조명·우승자 단상 (Match 역할이면 로비 안 지음)
    RewardService.luau   # 코인·승수·칭호 지급 (MatchEvents 구독)
    MovementGuardService.luau  # 서버 이동 감시: 되돌리기, 통과 막기, 로그 (킥 없음)
    ShopService.luau     # EquipSkin, BuyWithCoins, grantSkin, 장착 resolver
    RobuxShopService.luau    # RequestRobuxPurchase, ProcessReceipt, Studio 가짜 결제
    PurchaseLog.luau     # 구매 기록 DataStore Purchases_v1 (키 PurchaseId, UserId 메타데이터)
  client/            -> StarterPlayerScripts.Client
    init.client.luau     # LobbyController.start() → 컨트롤러들 start(gui) (ProfileStore → Sfx → 나머지)
    CameraDirector.luau  # 카메라 우선순위 중재 (관전 < 우승자 비추기 < 소개 < 탈락 연출 < 우승 연출)
    ProfileStore.luau    # ProfileUpdated 보관: get/changed
    Sfx.luau             # 효과음·배경음, 음소거 버튼(위쪽 바, 단계 저장)
    ui/                  # Lobby*, Room*, RoomUiKit, Hud*, Spectate*, Coin*(배지·알림·정산), Shop*(탈의실), UiScaleController
    fx/                  # CharacterFxController(이름표·칭호), EliminationCutscene*, Intro*, VictoryCutscene*, CutsceneProps, VictoryProps, LobbyFxController
    input/               # DiveController/DiveButton, GrabController/GrabButton
  shared/            -> ReplicatedStorage.Shared
    Config.luau          # 튜닝 값 전부 + DEBUG (Roblox API 없음)
    Rules.luau           # 순수: roundCount, qualifyCount, shouldSkipToFinal, nextRound, roundKinds, buildRoundPlan
    RoundLogic.luau      # 라운드 판정·매치 순위 순수 로직 (Race/Survival/Final, Outcome, Standings, decideWinner, finalBatchOrder)
    RoomLogic.luau  SpectateLogic.luau
    Remotes.luau         # RemoteFunction 9 + RemoteEvent 11 = 20개 (Remotes.fn / Remotes.event)
    Types.luau           # 리모트로 주고받는 데이터 모양 (ProfileView, RewardGrant, RoomListing.remote 등)
    Attributes.luau      # 공유 Instance 속성 이름 (AppearanceId, Title, MoveExemptUntil, PlaceRole, …)
    Cleanup.luau  CameraPriority.luau
    SushiBody.luau       # 초밥 몸 레이아웃(스킨 16종)·build·bounds
    Skins.luau  ShopLogic.luau  ReceiptLogic.luau            # 스킨 카탈로그·가격, 탈의실·코인 해금 판단, 결제 처리 판단
    ProfileSchema.luau  ProfileLogic.luau  RewardLogic.luau  # 프로필 모양·칭호, 마이그레이션·잠금, 코인 지급
    PlaceRole.luau  PlacePayload.luau  RoomDirectoryLogic.luau   # 역할 판단, 매니페스트·티켓 검증, 방 목록 합치기
    MoveExempt.luau  MovementGuardLogic.luau                 # 서버가 튕긴 뒤 면제 표시, 이동 감시 판정
    LobbyLayout.luau  UiLayout.luau  IntroLayout.luau        # 로비 배치·조명, 화면 배율·터치 버튼, "출발!" 위치
    EliminationCutsceneLogic.luau  IntroCameraLogic.luau  VictoryCutsceneLogic.luau
    DiveLogic.luau  GrabLogic.luau  GrabInputLogic.luau  SfxCues.luau  SfxLibrary.luau
    maps/
      init.luau          # 맵 풀 (ALL에 맵 모듈 추가): Maps.get, Maps.infos, Maps.timeLimit
      MapTypes.luau      # 공통 인터페이스 타입(MapModule, RoundContext) + validate
      MapKit.luau  MapKitLogic.luau      # 장식(충돌 없음)·IntroCamera·Studio 아트, DecorSpec 검사·팔레트·예산
      MapSfx.luau  MapSfxLogic.luau      # 장애물 소리 (그 방 사람에게만)
      RotatingBelt.luau  (+ RotatingBeltChopstick, RotatingBeltArt)          # Race 회전 벨트
      SoySwamp.luau      (+ SoySwampLayout, SoySwampHazards, SoySwampArt)    # Race 간장 늪 & 와사비 산
      RamenRapids.luau   (+ RamenRapidsLayout, RamenRapidsLogic, RamenRapidsArt)  # Race 라멘 국물 급류
      HotPlate.luau      (+ HotPlateLogic, HotPlateArt)                      # Survival 뜨거운 철판
      ChefBoard.luau     (+ ChefBoardLogic, ChefBoardArt)                    # Survival 셰프의 도마
      SkewerShowdown.luau (+ SkewerShowdownLogic, SkewerShowdownArt)         # Final 회전 꼬치 쇼다운
tests/               # 순수 로직 테스트 (Studio 없이 실행, 68개 파일 1021개)
  init.luau            # 실행기: tests/*.spec.luau
  *.spec.luau          # 기능별 테스트 + QA가 추가한 *-qa / m*-qa 테스트 (가짜 Roblox 환경으로 서비스 소스를 직접 돌리는 것도 있음)
  lib/Test.luau  lib/RobloxRequire.luau  lib/FakeSfxEnv.luau
docs/
  GDD.md  WORKFLOW.md  CHANGELOG.md  DEV-SETUP.md  USER-TODO.md
  REFERENCE-map-production.md  REFERENCE-party-royale.md  REFERENCE-roblox-monetization.md
  specs/  qa/  proposals/            # specs/qa는 _TEMPLATE.md에서 시작
  planner/  developer/  docs-writer/ # 역할별 작업 기록(인계 메모)
  playtest/                          # 사용자가 채우는 친구·비공개 테스트 기록 (m3.md, m4.md)
.claude/agents/          # planner, developer, qa, docs-writer
```

### 맵 모듈 공통 인터페이스 (`shared/maps/MapTypes.luau`)
```lua
export type MapModule = {
  id: string,
  kind: "Race" | "Survival" | "Final",
  displayName: string,
  rule: string,                              -- 라운드 소개 한 줄 규칙
  timeLimit: number?,                        -- 없으면 Config.TimeLimit[kind]
  build: (origin: CFrame) -> Model,          -- 판정 지오메트리 + 장식 (Spawns 폴더 필수)
  start: (ctx: RoundContext) -> (),          -- 장애물 가동, 결승선/낙하 판정 → ctx.pass / ctx.eliminate
  cleanup: ((ctx: RoundContext) -> ())?,     -- ctx.cleanup에 안 넣은 것만 정리
}

export type RoundContext = {
  model: Model, origin: CFrame, rng: Random,
  targetCount: number,                       -- 이번 라운드 통과(Survival은 생존) 목표 인원
  cleanup: Cleanup.Cleanup,                  -- 라운드가 끝나면 RoundService가 run()
  isActive: () -> boolean,
  getRacers: () -> { Player },               -- 아직 통과/탈락하지 않은 플레이어
  pass: (player: Player) -> (),              -- 결승선 통과 (Race/Final). 이동 감시가 거부할 수 있음
  eliminate: (player: Player) -> (),         -- 탈락 (낙하 등)
}
```
- `Spawns` 폴더에는 최대 인원(24)만큼 BasePart를 둔다 (이름순 배치). **24개 모두 판정 바닥 위**여야 한다(테스트로 확인). 코스는 `origin`의 앞쪽(LookVector, 로컬 -Z)으로 뻗는다 — 시간 종료 때 "가장 멀리 간" 순위를 이 축으로 잰다.
- 라운드 종료 판정은 `RoundLogic`(순수)이 한다. 맵은 `ctx.pass`/`ctx.eliminate`만 부르고, `ctx.eliminate`는 한 판정 틱 동안 모아서 한 묶음으로 처리된다. 결승 여부는 맵 종류가 아니라 "마지막 라운드인가"로 정한다. 규칙 요약은 `RoundLogic.luau` 맨 위 주석.
- 점수: Race는 진행도(로컬 -Z), Survival·Final은 높이(HumanoidRootPart Y). 같은 묶음·시간 종료 때 순위를 이걸로 정한다. 낙하 탈락 위치는 마지막으로 땅을 밟은 자리.
- `ctx.getRacers()`에는 스폰에 배치된 레이서만 나온다 (리스폰 중인 사람은 판정하지 않음).
- 맵 상태는 모듈이 아니라 `ctx`(또는 `start` 지역 변수)에 둔다 (한 서버에서 여러 방이 같은 맵을 동시에 돌릴 수 있다).
- 장애물은 `CollectionService` 태그를 달고, `start`에서 **`ctx.model` 하위의 태그 파츠만** 동작시킨다. 태그: `Conveyor`·`Chopstick`(회전 벨트), `SoySauce`·`Wasabi`(간장 늪), `Broth`·`Chashu`·`NoodleSweeper`(라멘), `HotTile`(철판), `ChefBoardCell`·`ChefKnife`(도마), `SkewerShowdownSkewer`·`SkewerShowdownSlice`·`SkewerShowdownHand`(꼬치). (`MapTypes.luau` 머리 주석의 태그 목록은 M2 것이라 일부만 있다.)
- **장식**은 `<Map>Art.luau`의 `DecorSpec` 목록(순수 데이터) → `MapKit.buildDecor`(Anchored, 충돌·쿼리·터치 없음). 판정 파츠의 크기·위치·CanCollide는 아트 때문에 바꾸지 않는다. 재질을 바꾸면 `CustomPhysicalProperties`로 원래 물성을 유지한다. 예산 맵당 파츠 600·파티클 8·조명 12. `build` 끝에서 `MapKit.introCamera`(소개 경로)와 `MapKit.attachStudioArt(model, id, origin)`를 부른다.
- **이동 감시 면제**: 서버가 캐릭터를 순간적으로 튕기거나 옮기면(넉백, 와사비, 젓가락 집기·놓기, 날치알, 간장 경계) `MoveExempt.mark(character, seconds?)`. 벨트·급류·기울기 같은 **연속 밀기에는 달지 않는다**(기본 기준 안이고, 달면 속도 조작 구멍이 된다).
- GDD 11절의 인터페이스 표기는 개요이고, 실제 계약은 위 `MapTypes.luau`다.

## 규칙
- **공용 파일**(`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/Attributes.luau`, `shared/maps/init.luau`, `shared/maps/MapTypes.luau`, `default.project.json`, `src/server/init.server.luau`, `src/client/init.client.luau`, `rokit.toml`)은 **병렬 작업 중에는 스펙에 지정된 한 에이전트만 수정**한다. 다른 에이전트는 필요한 변경을 사용자에게 알린다.
- `Rules.luau` 같은 순수 로직은 Roblox API에 의존하지 않게 분리하고 `tests/`에 테스트를 둔다.
- 클라이언트에서 온 리모트 인자는 서버에서 항상 검증한다 (타입, 범위, 길이, 방 소속, 방장 여부, 요청 간격). 서버 → 클라이언트 이벤트는 서버가 `OnServerEvent`를 듣지 않는다.
- 데이터 변경은 `DataService.update`(동기) 안에서만. 결제처럼 "저장된 뒤에만" 끝나야 하는 일은 `saveNow`의 결과를 본다. Studio는 기본으로 메모리 저장이다.
- **디버그 설정** (`Config.DEBUG`, 서버는 `RunService:IsStudio()`일 때만 적용). **커밋할 때는 아래 기본값** — 테스트가 커밋 값을 고정한다. 사용법은 `docs/DEV-SETUP.md` 3-9 "디버그 설정".
  - `minPlayersToStart = 1` — 혼자 시작 (`RoomLogic.minPlayersToStart`). 다인원은 Studio Test → Clients and Servers.
  - `forceMapPlan = nil` — 맵 id 3~4개를 넣으면 그 순서대로 라운드 (혼자여도 끝까지).
  - `forceMapPlans = nil` — 플랜 목록, 매치마다 다음 플랜 (`forceMapPlan`이 우선).
  - `persistDataInStudio = false` — true면 Studio에서도 진짜 DataStore (API 접근 허용 필요).
  - `simulateMatchServer = false` — true면 Studio를 매치 서버처럼.
  - `logArenaStats = false` — true면 매치 끝마다 `[ArenaStats]` 한 줄.
  - `fakeRobuxInStudio = false` — true면 상품 id 없이 가짜 영수증 결제 (`persistDataInStudio`와 같이 켜면 꺼짐).

## 검증 (작업 끝내기 전에 반드시, 5단계)
도구는 `rokit.toml`에 버전이 고정돼 있다. 처음 한 번(그리고 도구가 추가되면) `rokit install` (Windows: `~/.rokit/bin`이 PATH에 있어야 함).
```bash
rojo build -o build.rbxl       # 1. 프로젝트 구조 확인 (build.rbxl은 커밋하지 않음)
stylua --check src tests       # 2. 포맷/문법 (고칠 때는 stylua src tests)
selene src                     # 3. 린트
lune run tests                 # 4. 순수 로직 테스트
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src   # 5. 타입 검사 (끝 코드 0)
```
- **도구를 받을 수 없는 환경(클라우드 세션 등)에서는 돌리지 못한 단계를 "타입 검사 못 함"처럼 보고에 분명히 적는다.** 돌려 보지 않은 것을 통과로 적지 않는다.
- 스튜디오에서 직접 확인이 필요한 부분은 **사용자에게 무엇을 어떻게 테스트하면 되는지** 구체적으로 알려준다. 설치·Studio 연결·마일스톤별 확인 목록은 `docs/DEV-SETUP.md`. 새 마일스톤에서 확인할 항목이 생기면 거기에 추가한다. 사용자가 손으로 할 일(퍼블리시·상품·결정)은 `docs/USER-TODO.md`에 모은다.

## 병렬 개발
서로 다른 파일을 건드리는 스펙은 worktree를 나눠 동시에 개발한다 (`claude --worktree <이름>`, Rojo 포트는 worktree마다 34872, 34873, ...). 자세한 건 `docs/WORKFLOW.md`.
M1은 3개, M4는 기반(m4-01) 뒤 9개(m4-02~m4-10) worktree로 병렬 개발했고, 공용 파일을 바꾸는 스펙(m4-01, m4-11~m4-14)은 `main`에서 순서대로 했다. 따로 QA를 통과한 브랜치가 병합에서 처음 만나 깨질 수 있으니(m4-09 B1) 병합 뒤에도 검증을 다시 돌린다.
