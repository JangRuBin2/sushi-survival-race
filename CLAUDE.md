# CLAUDE.md — Sushi Survival Race

로블록스 라운드제 서바이벌 레이스 게임. 플레이어는 초밥이 되어 젓가락을 피해 달리고, 3~4라운드 뒤 1명만 우승한다.

- **기획서(단일 진실 공급원): `docs/GDD.md`** — 작업 전에 관련 섹션을 먼저 읽는다. 기획과 다르게 구현해야 하면 사용자에게 먼저 묻는다.
- 사용자와는 **한국어**로 대화한다. 코드 식별자·커밋 메시지는 영어.

## 현재 상태
- 기획서 **v0.3** (결승 = 마지막 1명이 남을 때까지 버티는 생존형, 폴가이즈 참고). **M0~M3 완료** (스펙 `done`) — M2·M3는 사용자 Studio 확인(`docs/DEV-SETUP.md` 3-7, 3-8) 대기. 자세한 내역은 `docs/CHANGELOG.md`.
- 맵 풀 4개: `rotating-belt`·`soy-swamp`(Race), `hot-plate`(Survival), `skewer-showdown`(Final). 3~4라운드 한 판이 처음부터 우승까지 돈다. 탈락하면 자동 관전, 우승 화면에 순위표.
- M3에서 들어온 것: 계란초밥 캐릭터(`AppearanceService.applyAppearance` + `SushiBody`), 탈락 연출("먹혔다!", 3초), 라운드 소개 플라이스루 + "출발!", 우승 연출(6초, 우승 단계 10초), 다이브, 잡기(서버 판정), 효과음·배경음·음소거, 장애물 소리(`MapSfx`). 카메라는 `CameraDirector` 우선순위로만 바꾼다.
- **M3 수치는 전부 기본값**(사용자 지시 "일단 개발하고 나중에 수정"). 목록: `docs/REFERENCE-party-royale.md` §7, `docs/CHANGELOG.md` M3. GDD에는 아직 안 넣었다 — 사용자가 확정하면 기획 담당이 GDD v0.4로 반영.
- 사용자 할 일: 배경음 4곡·효과음 8개 id 고르기(`shared/SfxLibrary.luau`에서 `id = nil`인 것), 친구 테스트(4명 이상, 3판 이상) 결과를 `docs/playtest/m3.md`에 판마다 한 줄씩 적고 바꿀 수치·연출 알려 주기.
- 아직 없는 것: 맵 아트·새 맵, 로비/매치 플레이스 분리, DataStore(음소거 저장, 우승 칭호), 서버 속도 감시(다이브·잡기 감속은 클라이언트 물리), 스킨·상점(가장 마지막).
- 남은 P3: 결승의 같은 틱 묶음에서 리셋·퇴장한 사람이 우승할 수 있음, 검증에 Luau 타입 검사 없음 (`docs/qa/m2-07-full-match-integration.md` I1·I2), 회전 벨트는 아직 태그가 아니라 `Hazards` 폴더로 장애물을 돌림(M1 B10). M3 보류: 낙하 탈락 연출 높이(m3-03 B2), Survival·Final 플라이스루 끝점(m3-04 B2), 공중 다이브 지름길(m3-06 B2·B3), 잡기 입력(m3-07 G1·G4), m3-09 B3·B4(B5는 음소거 버튼을 위쪽 바로 옮겨 해소) — 목록은 `docs/specs/m3-09-integration-polish.md` 결정 기록.
- 다음 단계: **사용자 Studio 확인·친구 테스트 결과에 따른 수정 지시 대기**, 그다음 **M4** (기획 담당이 `docs/specs/`에 M4 스펙을 쓰는 것부터). 진행 상황은 `grep -H "^status:" docs/specs/*.md`.
- 검토 대기 제안서: `docs/proposals/robux-gameplay.md` (사용자 승인 전, GDD 미반영). M4 맵 제작 리서치: `docs/REFERENCE-map-production.md`, M3 참고 자료: `docs/REFERENCE-party-royale.md` (참고용, 결정 아님).
- **스킨·상점·로벅스 결제는 가장 마지막에 개발한다.** 그 전까지는 모든 플레이어가 기본 계란초밥(`Config.Appearance.Default = "tamago"`)으로 플레이한다. 캐릭터 외형은 **`AppearanceService.applyAppearance(character, appearanceId?)` 한 곳에서만** 입힌다 — 스킨은 나중에 여기서 고른다. 캐릭터에 보이는 파츠를 붙이는 기능은 `Attributes.KeepVisible`을 달아야 숨김에서 빠진다.

## 역할 분담 (에이전트 협업)
기획 `planner` · 개발 `developer` · QA `qa` · 문서화 `docs-writer` 서브에이전트가 `.claude/agents/`에 있다.
작업은 **스펙 파일(`docs/specs/`) → 구현 → QA 리포트(`docs/qa/`) → 문서 반영** 순서로 파일을 통해 넘긴다.
흐름, 상태값, 파일 소유권, 실행 방법은 **`docs/WORKFLOW.md`**를 따른다.
- **세션이 끝날 수 있으니 커밋할 때마다 자기 브랜치를 push하고 스펙에 인계 메모를 남긴다.** 로컬 세션이 끝나면 클라우드 세션(`claude --cloud`)이 이어받는다 — `docs/WORKFLOW.md` "클라우드 세션으로 인계".

## 확정된 기획 요약 (자세한 건 GDD)
- **방 시스템**: 방장이 방을 만들 때 최대 인원(4/8/12/16/24), 공개/비공개(4자리 코드)를 설정. 최소 4명이면 방장이 시작, 정원이 차면 자동 시작.
- **라운드 수**: 시작 인원 4~8명 → 3라운드, 9~24명 → 4라운드. 한 판 4~5분.
- **통과 인원**: `clamp(round(시작 × 비율), 2, 시작 - 1)`. 비율 3라운드 [0.60, 0.50, 결승], 4라운드 [0.65, 0.55, 0.50, 결승]. 결승 전 남은 인원 ≤ 2면 바로 결승. 코드(`Rules.qualifyCount`)는 "시작"을 **그 라운드를 시작할 때 살아 있는 인원**으로 계산한다.
- **맵**: 라운드마다 맵이 바뀌고 맵마다 규칙이 다르다. 종류는 Race / Survival / Final. 첫 라운드는 항상 Race, 마지막은 항상 Final, 한 판에 같은 맵 중복 없음, 4라운드면 Survival 최소 1번.
- **결승**: 생존형. 1명이 남는 순간 우승, 같은 순간 다 떨어지면 더 높이 버틴 사람. **Survival** 시간 종료면 버틴 사람 전원 통과. Race 통과자는 대기석(로비 스폰)으로.
- **결승 진출 2명 보장**: 결승 전 라운드에서 낙하로 살아남을 사람이 2명 아래가 되면 더 멀리/높이 간 사람부터 구제(통과). 리셋·퇴장은 구제 없음. 결승 전 라운드에서 혼자 남으면 바로 부전승. 우승자는 항상 `Won`을 받은 사람이다.
- **판정은 전부 서버**(결승선, 탈락, 순위, 구매). 클라이언트는 입력·UI·연출만.

## 기술 스택과 구조
- Roblox Studio + **Rojo**, 언어 **Luau** (`--!strict` 권장).
- 맵은 MVP 단계에서 **코드로 회색 박스를 생성**한다(스튜디오 에셋 의존 없이 에이전트가 만들고 검증할 수 있게). 아트 맵은 M4.
- MVP는 **한 플레이스 안에서** 로비와 매치를 같이 돌린다. 방마다 아레나를 좌표를 띄워 따로 생성한다(`Config.Arena`: 높이 300, 방 슬롯 간격 2000 → `RoomService.getArenaOrigin`). 로비/매치 플레이스 분리(TeleportService, MemoryStore)는 M4.

```
default.project.json     # Rojo 트리 + Workspace의 Baseplate, LobbySpawn. StarterPlayer: Shift Lock 끔, 아바타 외형 안 불러옴
rokit.toml               # rojo 7.7.1, stylua 2.5.2, selene 0.32.0, lune 0.10.5
selene.toml  stylua.toml
src/
  server/            -> ServerScriptService.Server
    init.server.luau     # 서비스 부트스트랩: 모든 서비스 init() 다음 start()
    RoomService.luau     # 방 생성/참가/퇴장/방장/시작, 요청 간격 0.3초 제한. onMatchStart/onMemberLeft/endMatch/getArenaOrigin/getPlayers
    MatchService.luau    # 방 하나의 매치 상태 머신 (MatchPhase 방송, decideWinner로 우승 확정)
    RoundService.luau    # prepareRound(args) → { run(target), cancel(), racerCount() }: 맵 build/배치/start, 판정은 RoundLogic에 위임.
                         #   맵 Model에 RoomId/RoundIndex/MapId 속성, 탈락 cause·position 추적, 결승 마지막 탈락이면 3초 기다렸다 Won,
                         #   activeRoomOf(player), MapSfx.setAudience 등록
    EliminationService.luau  # passed/won/left/eliminate(roomId, player, place, cause?, position?) → PlayerResult 방송
    CharacterUtil.luau   # resetMovement(Config 값으로 이동 복구), toLobby(로비 스폰 = 대기석)
    AppearanceService.luau   # applyAppearance(character, appearanceId?) — 외형을 입히는 유일한 곳 (SushiBody를 HRP에 SushiJoint로 붙이고 원래 몸 숨김)
    GrabService.luau     # 잡기 판정 (GrabInput 검증, GrabLogic, 캐릭터에 GrabbedBy/GrabbingUserId 속성). 감속은 클라이언트가 함
  client/            -> StarterPlayerScripts.Client
    init.client.luau     # LobbyController.start() → 컨트롤러들 start(gui) (Sfx 먼저, Hud, Spectate, fx/*, input/*)
    CameraDirector.luau  # 카메라 중재: request(owner, priority, apply)/release/current/isActive.
                         #   Priority: Spectate 10 < Victory 20 < Intro 30 < Elimination 40 < VictoryCutscene 50. 카메라는 여기로만 바꾼다
    Sfx.luau             # play(cue, at?), setMusic(name?), start: SoundGroup, 배경음 전환, 버튼 클릭음, 음소거 버튼(SoundGui, ScreenInsets = TopbarSafeInsets로 Roblox 위쪽 바 오른쪽 끝), MapSfx 이벤트 재생(120 studs 안)
    ui/                  # LobbyScreen/Controller, RoomScreen, RoomUiKit, HudScreen/Controller, SpectateScreen/Controller
    fx/                  # CharacterFxController(걷기·넘어짐·이름표), EliminationCutscene{Controller,Screen} + CutsceneProps,
                         #   Intro{Controller,Screen}, VictoryCutscene{Controller,Screen} + VictoryProps
    input/               # DiveController + DiveButton, GrabController + GrabButton (모바일 버튼)
  shared/            -> ReplicatedStorage.Shared
    Config.luau          # Room, Rules(비율), Match(연출 시간), TimeLimit, Arena, Character, Appearance, Dive, Grab, Fx, DEBUG (Roblox API 없음)
    Rules.luau           # 순수 함수: roundCount, qualifyCount, shouldSkipToFinal, nextRound, roundKinds, buildRoundPlan, resolveForcedPlan
    RoundLogic.luau      # 라운드 판정·매치 순위 순수 로직: Mode(Race/Survival/Final), pass/eliminate/timeout → Outcome, Standings, decideWinner
    SpectateLogic.luau   # 관전 대상 후보·전환 순수 로직
    RoomLogic.luau       # 방 순수 로직: 설정 검증, 코드 생성, 참가/퇴장/방장 위임, 시작 조건, 빠른 참가
    Remotes.luau         # RemoteFunction 6 + RemoteEvent 7 이름을 한 곳에서 정의 (Remotes.fn / Remotes.event)
    Types.luau           # 리모트로 주고받는 데이터 모양 (PlayerResult.cause: Fall/Reset/Left/Timeout, position)
    Cleanup.luau         # 연결/인스턴스/스레드/함수 정리 목록 (new/add/run)
    Attributes.luau      # Instance 속성 이름 상수 (AppearanceId, GrabbedBy, GrabbingUserId, KeepVisible, NoClickSfx, RoomId, RoundIndex, MapId)
    CameraPriority.luau  # CameraDirector가 쓰는 순수 pick(requests)
    SushiBody.luau       # 계란초밥 파츠 layout/bounds/build, MODEL_NAME "SushiBody"·JOINT_NAME "SushiJoint" (연출 인형도 이걸 씀)
    EliminationCutsceneLogic.luau  # 탈락 연출 순수 로직: shouldPlay(cause), variantFor(젓가락/입/셰프 손), 대사, 타임라인, 동시 한도
    IntroCameraLogic.luau          # 플라이스루 경로 순수 로직 (숫자 표 {x,y,z}, autoPath/sample)
    IntroLayout.luau     # "출발!" 글씨 배치 순수 계산: HUD 위 배너(TopBanner) 아래로 가운데 높이·글씨 크기
    VictoryCutsceneLogic.luau      # 우승 연출 타임라인·자세·카메라 순수 로직
    DiveLogic.luau       # 다이브 상태(Ready/Flying/Stunned)·발사 속도 순수 로직
    GrabLogic.luau       # 잡기 대상 고르기·끝내기·쿨다운·면역 순수 로직 (Book)
    SfxCues.luau         # 효과음 28개 + 배경음 4개 이름 (이 이름만 씀)
    SfxLibrary.luau      # cue → 소리 id·볼륨·pitch, musicFor. id = nil이면 무음 (사용자가 채울 곳)
    maps/
      init.luau          # 맵 풀 (ALL에 맵 모듈 추가): Maps.get, Maps.infos, Maps.timeLimit
      MapTypes.luau      # 공통 인터페이스 타입(MapModule, RoundContext) + validate
      MapSfx.luau        # 서버 맵 모듈이 부르는 장애물 소리: play(part, cue) → RemoteEvent MapSfx (방 사람에게만), setAudience
      MapSfxLogic.luau   # 소리 간격 제한(0.2초)·roomIdOf·marks/crossedMark 순수 로직
      RotatingBelt.luau  # Race "회전 벨트" (+ RotatingBeltChopstick)
      SoySwamp.luau      # Race "간장 늪 & 와사비 산" (+ SoySwampLayout, SoySwampHazards)
      HotPlate.luau      # Survival "뜨거운 철판" (+ HotPlateLogic)
      SkewerShowdown.luau  # Final "회전 꼬치 쇼다운" (+ SkewerShowdownLogic)
tests/               # 순수 로직 테스트 (스튜디오 없이 실행, 38개 파일 493개)
  init.luau            # 실행기: tests/*.spec.luau
  *.spec.luau          # rules, room, maps, round-logic, spectate, map-*, camera-priority, sushi-body, elimination-cutscene,
                       #   intro-camera, intro-layout, victory-cutscene, dive, grab, sfx-library, map-sfx, 그리고 QA가 추가한 *-qa / m1-* / m3-09-* 테스트
  lib/Test.luau        # 작은 테스트 도우미 (t.test, t.eq, t.ok)
  lib/RobloxRequire.luau  # src 모듈의 require(script.Parent.X)를 Lune에서 흉내
  lib/FakeSfxEnv.luau  # 클라이언트 Sfx를 Lune에서 돌리는 가짜 Roblox 환경
docs/
  GDD.md  WORKFLOW.md  CHANGELOG.md  DEV-SETUP.md  REFERENCE-map-production.md  REFERENCE-party-royale.md
  specs/  qa/  proposals/   # specs/qa는 _TEMPLATE.md에서 시작
  planner/  developer/  docs-writer/   # 역할별 작업 기록(인계 메모)
  playtest/            # 친구 테스트 의견 기록 (m3.md: 판마다 한 줄, 양식은 DEV-SETUP 3-8 N)
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
  build: (origin: CFrame) -> Model,          -- 회색 박스 생성 (Spawns 폴더 필수)
  start: (ctx: RoundContext) -> (),          -- 장애물 가동, 결승선/낙하 판정 → ctx.pass / ctx.eliminate
  cleanup: ((ctx: RoundContext) -> ())?,     -- ctx.cleanup에 안 넣은 것만 정리
}

export type RoundContext = {
  model: Model, origin: CFrame, rng: Random,
  targetCount: number,                       -- 이번 라운드 통과(Survival은 생존) 목표 인원
  cleanup: Cleanup.Cleanup,                  -- 라운드가 끝나면 RoundService가 run()
  isActive: () -> boolean,
  getRacers: () -> { Player },               -- 아직 통과/탈락하지 않은 플레이어
  pass: (player: Player) -> (),              -- 결승선 통과 (Race/Final)
  eliminate: (player: Player) -> (),         -- 탈락 (낙하 등)
}
```
- `Spawns` 폴더에는 최대 인원(24)만큼 BasePart를 둔다 (이름순 배치). 코스는 `origin`의 앞쪽(LookVector, 로컬 -Z)으로 뻗는다 — 시간 종료 때 "가장 멀리 간" 순위를 이 축으로 잰다.
- 라운드 종료 판정은 `RoundLogic`(순수)이 한다. 맵은 `ctx.pass`/`ctx.eliminate`만 부르고, `ctx.eliminate`는 한 판정 틱 동안 모아서 한 묶음으로 처리된다. 결승 여부는 맵 종류가 아니라 "마지막 라운드인가"로 정한다. 규칙 요약은 `RoundLogic.luau` 맨 위 주석.
- 점수: Race는 진행도(로컬 -Z), Survival·Final은 높이(HumanoidRootPart Y). 같은 묶음·시간 종료 때 순위를 이걸로 정한다.
- `ctx.getRacers()`에는 스폰에 배치된 레이서만 나온다 (리스폰 중인 사람은 판정하지 않음).
- 맵 상태는 모듈이 아니라 `ctx`에 둔다 (한 서버에서 여러 방이 같은 맵을 동시에 돌릴 수 있다).
- 장애물은 `CollectionService` 태그를 달고, `start`에서 **`ctx.model` 하위의 태그 파츠만** 동작시킨다 (여러 방 동시 진행). 간장 늪(`SoySauce`, `Wasabi`), 철판(`HotTile`), 꼬치 쇼다운이 이 방식. 회전 벨트는 아직 `Hazards` 폴더 순회(태그만 붙임).
- 장애물 소리는 맵 모듈에서 `MapSfx.play(part, cue)` 한 줄로 낸다 (cue는 `SfxCues`의 장애물 이름). 판정·타이밍은 바꾸지 않는다.
- GDD 11절의 인터페이스 표기(`setup(map)`, `start(players, targetCount)`)는 초안이고, 실제 계약은 위 `MapTypes.luau`다.

### M3 연출·입력 공통 규칙
- **카메라**는 직접 바꾸지 않고 `CameraDirector.request/release`로만 바꾼다. 매 프레임 움직이는 연출은 `CameraDirector.isActive(owner)`일 때만 움직인다.
- **소리**는 `Sfx.play(cue, at?)`(클라이언트)·`MapSfx.play(part, cue)`(서버 맵)로만 낸다. 새 소리는 `SfxCues`에 이름을 넣고 `SfxLibrary`에 항목을 넣는다(`tests/sfx-library.spec.luau`가 1:1인지 본다).
- **탈락 원인** `PlayerResult.cause`: 맵 낙하(`ctx.eliminate`) = `Fall`, 사망·캐릭터 교체·캐릭터 없음 = `Reset`, 방/게임 나감 = `Left`, 그 밖에 RoundLogic이 정리한 탈락(시간 종료·정원 마감) = `Timeout`. 연출은 Left만 빼고 재생한다.
- 클라이언트 조작 UI 버튼에는 `Attributes.NoClickSfx = true`를 달아 클릭음을 뺀다.
- 다이브와 잡기 감속은 클라이언트 물리다(서버는 `WalkSpeed`를 건드리지 않음). 잡기 성립·해제만 서버가 정한다.

## 규칙
- 공용 파일(`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `default.project.json`)은 **병렬 작업 중에는 한 에이전트만 수정**한다. 다른 에이전트는 필요한 변경을 사용자에게 알린다.
- `Rules.luau` 같은 순수 로직은 Roblox API에 의존하지 않게 분리하고 `tests/`에 테스트를 둔다.
- `Config.DEBUG.minPlayersToStart`(1)처럼 **혼자 테스트할 수 있는 디버그 설정**을 둔다. 서버는 `RunService:IsStudio()`일 때만 적용한다 (`RoomLogic.minPlayersToStart`). 다인원은 스튜디오 Test → Clients and Servers.
- `Config.DEBUG.forceMapPlan`에 맵 id 3~4개를 넣으면 그 순서대로 라운드를 돌린다 (혼자여도 끝까지). 맵 하나를 Studio에서 확인할 때 쓰고, **커밋할 때는 `nil`**.
- 클라이언트에서 온 리모트 인자(RemoteFunction 6개와 RemoteEvent `GrabInput`)는 서버에서 항상 검증한다 (타입, 범위, 요청 간격, 방 소속, 방장 여부).

## 검증 (작업 끝내기 전에 반드시)
도구는 `rokit.toml`에 버전이 고정돼 있다. 처음 한 번 `rokit install` (Windows: `~/.rokit/bin`이 PATH에 있어야 함).
```bash
rojo build -o build.rbxl       # 프로젝트 구조 확인 (build.rbxl은 커밋하지 않음)
stylua --check src tests       # 포맷/문법 (고칠 때는 stylua src tests)
selene src                     # 린트
lune run tests                 # 순수 로직 테스트
```
스튜디오에서 직접 확인이 필요한 부분은 **사용자에게 무엇을 어떻게 테스트하면 되는지** 구체적으로 알려준다.
설치·Studio 연결·마일스톤별 확인 목록은 `docs/DEV-SETUP.md`에 있다. 새 마일스톤에서 확인할 항목이 생기면 거기에 추가한다.

## 병렬 개발
서로 다른 파일을 건드리는 스펙은 worktree를 나눠 동시에 개발한다 (`claude --worktree <이름>`, Rojo 포트는 worktree마다 34872, 34873, ...). 자세한 건 `docs/WORKFLOW.md`.
M1은 `room-system` / `match-flow` / `race-belt` 세 worktree로 병렬 개발해 `main`에 병합했다.
M3는 기반(m3-01, `main`, 공용 파일·껍데기) → 기능 7개(m3-02~08) worktree 병렬 → 통합(m3-09, `main`) 순서로 했다. 기반 스펙이 공용 파일과 빈 껍데기 파일을 먼저 만들어 두면 병렬 스펙끼리 같은 파일을 건드리지 않는다 (`docs/planner/m3-plan.md`).
