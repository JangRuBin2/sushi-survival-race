# CLAUDE.md — Sushi Survival Race

로블록스 라운드제 서바이벌 레이스 게임. 플레이어는 초밥이 되어 젓가락을 피해 달리고, 3~4라운드 뒤 1명만 우승한다.

- **기획서(단일 진실 공급원): `docs/GDD.md`** — 작업 전에 관련 섹션을 먼저 읽는다. 기획과 다르게 구현해야 하면 사용자에게 먼저 묻는다.
- 사용자와는 **한국어**로 대화한다. 코드 식별자·커밋 메시지는 영어.

## 현재 상태
- 기획서 v0.2. **M0, M1 완료** (방 시스템, 매치 상태 머신, 회전 벨트 Race 맵, HUD). 자세한 내역은 `docs/CHANGELOG.md`.
- 맵 풀에는 아직 **`rotating-belt`(Race) 하나뿐**이다. `Rules.buildRoundPlan`이 모자란 종류를 다른 맵으로 채우므로 Survival·Final 라운드도 지금은 회전 벨트로 돈다 (결승도 `kind = "Race"`라 `EliminationService.won` 대신 `passed`가 불린다).
- 아직 없는 것: 관전 모드(탈락하면 연출 시간 뒤 로비 스폰으로 돌아감), 라운드 소개 플라이스루·카메라 연출, 젓가락 외 장애물(`Wasabi`, `SoySauce`, `HotTile` 태그는 예약만 됨), `applyAppearance`.
- 다음 단계: **M2 (한 판 MVP)** — Race 2 / Survival 1 / Final 1 회색 박스 맵, 랜덤 구성, 탈락·관전·우승. 기획 담당이 `docs/specs/`에 M2 스펙을 쓰는 것부터 시작한다. 진행 상황은 `grep -H "^status:" docs/specs/*.md`.
- 검토 대기 제안서: `docs/proposals/robux-gameplay.md` (사용자 승인 전, GDD 미반영). M4 맵 제작 리서치: `docs/REFERENCE-map-production.md` (참고용, 결정 아님).
- **스킨·상점·로벅스 결제는 가장 마지막에 개발한다.** 그 전까지는 모든 플레이어가 기본 계란초밥(회색 박스 캐릭터여도 됨)으로 플레이한다. 스킨이 나중에 붙을 수 있게 캐릭터 외형 적용 지점만 한 곳(`applyAppearance` 같은 함수, 아직 없음 — 캐릭터 외형을 처음 손댈 때 만든다)으로 모아 둔다.

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
- **판정은 전부 서버**(결승선, 탈락, 순위, 구매). 클라이언트는 입력·UI·연출만.

## 기술 스택과 구조
- Roblox Studio + **Rojo**, 언어 **Luau** (`--!strict` 권장).
- 맵은 MVP 단계에서 **코드로 회색 박스를 생성**한다(스튜디오 에셋 의존 없이 에이전트가 만들고 검증할 수 있게). 아트 맵은 M4.
- MVP는 **한 플레이스 안에서** 로비와 매치를 같이 돌린다. 방마다 아레나를 좌표를 띄워 따로 생성한다(`Config.Arena`: 높이 300, 방 슬롯 간격 2000 → `RoomService.getArenaOrigin`). 로비/매치 플레이스 분리(TeleportService, MemoryStore)는 M4.

```
default.project.json     # Rojo 트리 + Workspace의 Baseplate, LobbySpawn
rokit.toml               # rojo 7.7.1, stylua 2.5.2, selene 0.32.0, lune 0.10.5
selene.toml  stylua.toml
src/
  server/            -> ServerScriptService.Server
    init.server.luau     # 서비스 부트스트랩: 모든 서비스 init() 다음 start()
    RoomService.luau     # 방 생성/참가/퇴장/방장/시작, 요청 간격 0.3초 제한. onMatchStart/onMemberLeft/endMatch/getArenaOrigin
    MatchService.luau    # 방 하나의 매치 상태 머신 (MatchPhase 방송)
    RoundService.luau    # runRound: 맵 build/배치/start/판정/정리, RoundProgress 방송
    EliminationService.luau  # passed/won/eliminate → PlayerResult 방송, 탈락자 고정 후 로비 스폰 복귀
  client/            -> StarterPlayerScripts.Client
    init.client.luau     # LobbyController.start() → HudController.start(gui)
    ui/                  # LobbyScreen/Controller, RoomScreen, RoomUiKit, HudScreen/Controller
  shared/            -> ReplicatedStorage.Shared
    Config.luau          # Room, Rules(비율), Match(연출 시간), TimeLimit, Arena, Character, DEBUG (Roblox API 없음)
    Rules.luau           # 순수 함수: roundCount, qualifyCount, shouldSkipToFinal, nextRound, roundKinds, buildRoundPlan
    RoomLogic.luau       # 방 순수 로직: 설정 검증, 코드 생성, 참가/퇴장/방장 위임, 시작 조건, 빠른 참가
    Remotes.luau         # RemoteFunction 6 + RemoteEvent 5 이름을 한 곳에서 정의 (Remotes.fn / Remotes.event)
    Types.luau           # 리모트로 주고받는 데이터 모양
    Cleanup.luau         # 연결/인스턴스/스레드/함수 정리 목록 (new/add/run)
    maps/
      init.luau          # 맵 풀 (ALL에 맵 모듈 추가): Maps.get, Maps.infos, Maps.timeLimit
      MapTypes.luau      # 공통 인터페이스 타입(MapModule, RoundContext) + validate
      RotatingBelt.luau  # Race 맵 "회전 벨트" (id rotating-belt)
      RotatingBeltChopstick.luau  # 회전 벨트의 젓가락 장애물 (Chopstick 태그)
tests/               # 순수 로직 테스트 (스튜디오 없이 실행)
  init.luau            # 실행기: tests/*.spec.luau
  rules.spec.luau  room.spec.luau  maps.spec.luau
  lib/Test.luau        # 작은 테스트 도우미 (t.test, t.eq, t.ok)
  lib/RobloxRequire.luau  # src 모듈의 require(script.Parent.X)를 Lune에서 흉내
docs/
  GDD.md  WORKFLOW.md  CHANGELOG.md  DEV-SETUP.md  REFERENCE-map-production.md
  specs/  qa/  proposals/   # specs/qa는 _TEMPLATE.md에서 시작
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
- 라운드 종료(`RoundService`): Race/Final은 통과자가 `targetCount`에 닿는 순간 끝나고 나머지는 탈락. Survival은 남은 인원이 `targetCount` 이하가 되면 끝나고 남은 사람이 통과. 시간 종료 시에는 앞으로 간 순서로 빈 자리를 채운다. 결승 1등 처리는 맵 `kind == "Final"`일 때만 한다.
- 맵 상태는 모듈이 아니라 `ctx`에 둔다 (한 서버에서 여러 방이 같은 맵을 동시에 돌릴 수 있다).
- 장애물은 `CollectionService` 태그(`Chopstick`, `Wasabi`, `SoySauce`, `HotTile`)로 동작시킨다. 지금 구현된 건 `Chopstick`뿐.
- GDD 11절의 인터페이스 표기(`setup(map)`, `start(players, targetCount)`)는 초안이고, 실제 계약은 위 `MapTypes.luau`다.

## 규칙
- 공용 파일(`shared/Config.luau`, `shared/Remotes.luau`, `default.project.json`)은 **병렬 작업 중에는 한 에이전트만 수정**한다. 다른 에이전트는 필요한 변경을 사용자에게 알린다.
- `Rules.luau` 같은 순수 로직은 Roblox API에 의존하지 않게 분리하고 `tests/`에 테스트를 둔다.
- `Config.DEBUG.minPlayersToStart`(1)처럼 **혼자 테스트할 수 있는 디버그 설정**을 둔다. 서버는 `RunService:IsStudio()`일 때만 적용한다 (`RoomLogic.minPlayersToStart`). 다인원은 스튜디오 Test → Clients and Servers.
- 클라이언트에서 온 리모트 인자(지금은 전부 RemoteFunction)는 서버에서 항상 검증한다 (타입, 범위, 방 소속, 방장 여부).

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
