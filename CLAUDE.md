# CLAUDE.md — Sushi Survival Race

로블록스 라운드제 서바이벌 레이스 게임. 플레이어는 초밥이 되어 젓가락을 피해 달리고, 3~4라운드 뒤 1명만 우승한다.

- **기획서(단일 진실 공급원): `docs/GDD.md`** — 작업 전에 관련 섹션을 먼저 읽는다. 기획과 다르게 구현해야 하면 사용자에게 먼저 묻는다.
- 사용자와는 **한국어**로 대화한다. 코드 식별자·커밋 메시지는 영어.

## 현재 상태
- 기획서 v0.2 완료. **코드는 아직 없음.**
- 다음 단계: **M0 (Rojo 뼈대)** → **M1 (방 시스템 + 매치 상태 머신 + 회전 벨트 회색 박스 맵)**
- **스킨·상점·로벅스 결제는 가장 마지막에 개발한다.** 그 전까지는 모든 플레이어가 기본 계란초밥(회색 박스 캐릭터여도 됨)으로 플레이한다. 스킨이 나중에 붙을 수 있게 캐릭터 외형 적용 지점만 한 곳(`applyAppearance` 같은 함수)으로 모아 둔다.

## 확정된 기획 요약 (자세한 건 GDD)
- **방 시스템**: 방장이 방을 만들 때 최대 인원(4/8/12/16/24), 공개/비공개(4자리 코드)를 설정. 최소 4명이면 방장이 시작, 정원이 차면 자동 시작.
- **라운드 수**: 시작 인원 4~8명 → 3라운드, 9~24명 → 4라운드. 한 판 4~5분.
- **통과 인원**: `clamp(round(시작 × 비율), 2, 시작 - 1)`. 비율 3라운드 [0.60, 0.50, 결승], 4라운드 [0.65, 0.55, 0.50, 결승]. 결승 전 남은 인원 ≤ 2면 바로 결승.
- **맵**: 라운드마다 맵이 바뀌고 맵마다 규칙이 다르다. 종류는 Race / Survival / Final. 첫 라운드는 항상 Race, 마지막은 항상 Final, 한 판에 같은 맵 중복 없음, 4라운드면 Survival 최소 1번.
- **판정은 전부 서버**(결승선, 탈락, 순위, 구매). 클라이언트는 입력·UI·연출만.

## 기술 스택과 구조
- Roblox Studio + **Rojo**, 언어 **Luau** (`--!strict` 권장).
- 맵은 MVP 단계에서 **코드로 회색 박스를 생성**한다(스튜디오 에셋 의존 없이 에이전트가 만들고 검증할 수 있게). 아트 맵은 M4.
- MVP는 **한 플레이스 안에서** 로비와 매치를 같이 돌린다. 방마다 아레나를 좌표를 띄워 따로 생성한다. 로비/매치 플레이스 분리(TeleportService, MemoryStore)는 M4.

```
default.project.json
src/
  server/            -> ServerScriptService
    init.server.luau     # 서비스 부트스트랩
    RoomService.luau     # 방 생성/참가/퇴장/방장/시작
    MatchService.luau    # 방 하나의 매치 상태 머신
    RoundService.luau    # 맵 로드/시작/종료, 통과자 집계
    EliminationService.luau
  client/            -> StarterPlayerScripts
    init.client.luau
    ui/                  # 로비, 방 대기실, HUD, 결과
  shared/            -> ReplicatedStorage.Shared
    Config.luau          # 인원 선택지, 비율, 시간 제한, DEBUG 설정
    Rules.luau           # 순수 함수: roundCount, qualifyCount, buildRoundPlan
    Remotes.luau         # RemoteEvent/Function 이름을 한 곳에서 정의
    maps/                # 맵 모듈 (공통 인터페이스)
tests/               # 순수 로직 테스트 (스튜디오 없이 실행)
docs/GDD.md
```

### 맵 모듈 공통 인터페이스
```lua
export type MapModule = {
  id: string,
  kind: "Race" | "Survival" | "Final",
  displayName: string,
  timeLimit: number,
  build: (origin: CFrame) -> Model,          -- 회색 박스 생성
  start: (ctx: RoundContext) -> (),          -- 장애물 가동, 결승선/낙하 판정 연결
  cleanup: () -> (),
}
```
- 장애물은 `CollectionService` 태그(`Chopstick`, `Wasabi`, `SoySauce`, `HotTile`)로 동작시킨다.

## 규칙
- 공용 파일(`shared/Config.luau`, `shared/Remotes.luau`, `default.project.json`)은 **병렬 작업 중에는 한 에이전트만 수정**한다. 다른 에이전트는 필요한 변경을 사용자에게 알린다.
- `Rules.luau` 같은 순수 로직은 Roblox API에 의존하지 않게 분리하고 `tests/`에 테스트를 둔다.
- `Config.DEBUG.minPlayersToStart`처럼 **혼자 테스트할 수 있는 디버그 설정**을 둔다 (스튜디오 Test → Clients and Servers로 다인원 테스트).
- 클라이언트에서 온 RemoteEvent 인자는 서버에서 항상 검증한다 (타입, 범위, 방 소속, 방장 여부).

## 검증 (작업 끝내기 전에 반드시)
```bash
rojo build -o build.rbxl       # 프로젝트 구조 확인 (build.rbxl은 커밋하지 않음)
stylua --check src tests       # 포맷/문법
selene src                     # 린트 (설정 후)
lune run tests                 # 순수 로직 테스트 (Lune 설치 후)
```
스튜디오에서 직접 확인이 필요한 부분은 **사용자에게 무엇을 어떻게 테스트하면 되는지** 구체적으로 알려준다.

## 병렬 작업 계획 (M0 이후)
M0 뼈대가 `main`에 병합된 뒤에만 병렬로 진행한다. 각 에이전트는 `claude --worktree <이름>`으로 띄운다.

| worktree | 담당 | 주로 수정하는 파일 |
|---|---|---|
| `room-system` | 방 생성/참가/시작 + 로비·방 대기실 UI | `RoomService`, `client/ui/Lobby*`, `client/ui/Room*` |
| `match-flow` | 라운드 구성, 통과·탈락 집계, 관전, 우승 처리 + HUD | `MatchService`, `RoundService`, `EliminationService`, `shared/Rules`, `client/ui/Hud*` |
| `race-belt` | 회전 벨트 Race 맵 + 젓가락 장애물 | `shared/maps/RotatingBelt*`, 장애물 스크립트 |

- Rojo는 worktree마다 포트를 다르게: `rojo serve --port 34872`, `34873`, `34874`.
