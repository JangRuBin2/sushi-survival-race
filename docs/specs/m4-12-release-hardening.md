status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-12 — 출시 점검 (타입 검사 · 남은 P3 · 연속 매치 안정성 · 비공개 테스트 체크리스트)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §11.1(Luau 타입 체크), §12(M4 완료 기준 "비공개 테스트 → 공개"), §13(리스크)
- 참고: `docs/CHANGELOG.md` M3 "알려진 한계 · 보류 (P3)", `docs/qa/m2-07-full-match-integration.md` I2
- 담당 개발 worktree: `main` (**순차, m4-11 다음**)
- 공용 파일 수정 담당: **이 스펙** (m4-11 다음 차례)
- 의존: m4-11 병합
- **이 스펙이 고치는 파일**: `rokit.toml`, 검증 스크립트/문서에 들어갈 명령(`docs/DEV-SETUP.md`는 docs-writer가 반영), 타입 에러가 나는 `src/` 파일, `src/shared/maps/MapSfx.luau`(B3), `src/client/input/GrabController.luau`·`GrabButton.luau`(G1·G4), 새 파일 `tests/m4-12-hardening.spec.luau`

## 목표
친구·지인 비공개 테스트에 내놓아도 되는 상태로 다듬는다: 타입 검사가 검증에 들어가고, 한 서버에서 여러 판을 연달아 돌려도 맵·연결이 쌓이지 않으며, 남은 작은 버그를 정리하고, 사용자가 퍼블리시·설정할 것을 한 장 체크리스트로 만든다.

## 범위
- 포함:
  1. **타입 검사 (m2-07 I2)**: `rokit.toml`에 `luau-lsp`를 고정 버전으로 추가하고, `rojo sourcemap` + Roblox 타입 정의 파일로 `luau-lsp analyze`를 돌리는 명령을 검증 단계 5번째로 둔다. `--!strict` 파일의 에러를 0으로 만든다(동작 변경 없이 타입만). 정의 파일을 받는 방법(버전 고정 URL 또는 저장소에 커밋)은 개발이 정하고 개발 메모에 남긴다. 클라우드 세션처럼 도구를 못 받는 환경에서는 "타입 검사 못 함"을 보고에 적는 규칙을 WORKFLOW에 넣도록 docs-writer에게 알린다.
  2. **남은 P3 정리** (기본값: 고칠 것 / 둘 것):
     - 고침 — m3-09 B3: 장애물 소리 간격 기록이 지워진 파트를 붙잡음 → 약한 키 표(`__mode = "k"`) 또는 라운드 정리 때 비우기.
     - 고침 — m3-07 G1: 0.1초 안에 뗐다 다시 누른 잡기 입력이 무시됨 → 마지막 상태를 간격 뒤에 한 번 더 보냄. G4: 마우스·게임패드·터치 누름 상태를 입력원별로 따로 들고 "하나라도 누르고 있으면 잡기".
     - 둠 — m3-09 B4(결승 소개 중 상대 리셋 시 탈락 연출이 우승 연출에 잘림): 드물고 해가 없음.
     - 확인만 — m3-06 B2·B3(공중 다이브 지름길, 와사비 + 다이브): Studio에서 6개 맵을 돌며 지름길이 있는지 보고, 있으면 위치를 결정 기록에 적어 사용자에게 알림(고칠지는 사용자).
  3. **연속 매치 안정성** (Studio, 서버 하나): 혼자 `forceMapPlan`으로 **5판 연속**(6개 맵이 모두 한 번 이상) 돌린 뒤
     - `Workspace`의 자식 수와 `Lobby` 외 맵 Model 수가 첫 판 전과 같고(맵이 남지 않음),
     - 서버 메모리(Developer Console → Memory)가 판마다 계속 늘지 않고(5판 뒤 첫 판 끝 대비 +50MB 이하),
     - 클라이언트·서버 Output에 빨간 에러가 없다.
     이를 돕는 디버그 명령: 서버에 `Config.DEBUG.logArenaStats = false`(새) — true면 매치가 끝날 때 남은 아레나 Model 수·연결 수 추정치를 한 줄 찍음.
  4. **8명 부하 확인** (Studio Clients and Servers 8명 또는 사용자 친구): 24명 정원 방을 8명으로 4라운드 → 서버 Heartbeat가 55fps 이상(Developer Console → Server Stats).
  5. **출시 체크리스트** (이 스펙 아래 "사용자 작업" 표 — docs-writer가 `docs/DEV-SETUP.md` 3-9로 옮김).
- 제외:
  - 스킨·상점 (m4-13·14)
  - 분석 도구(AnalyticsService) — M5

## 수용 기준
### 순수 로직 / 도구
- [ ] AC1: 검증 명령 5개(`rojo build`, `stylua --check`, `selene`, `lune run tests`, 타입 검사)가 모두 통과하고, 타입 검사가 `src/`의 `--!strict` 파일 에러 0을 보고한다.
- [ ] AC2: (`tests/m4-12-hardening.spec.luau`) 잡기 입력 상태 순수 함수: 터치 누름 + 마우스 뗌 → 잡기 유지, 둘 다 뗌 → 놓음, 0.05초 안 뗌→누름 → 마지막에 "누름"이 한 번 보내진다.
- [ ] AC3: (소스 테스트 또는 순수 테스트) MapSfx 간격 기록이 라운드 정리 뒤 비거나 약한 키다.

### Studio 확인
- [ ] AC4: 위 3번 연속 5판 기준을 만족한다 (개발 메모에 숫자: 시작·끝 Workspace 자식 수, 메모리).
- [ ] AC5: 잡기 버튼을 아주 빨리 두 번 눌러도 두 번째 누름이 먹힌다. 휴대폰 버튼을 누른 채 마우스를 떼도 잡기가 유지된다.
- [ ] AC6: 6개 맵 다이브 지름길 확인 결과가 결정 기록에 있다.
- [ ] AC7: 8명 4라운드에서 서버 Heartbeat 55fps 이상 (사용자 확인 가능).

## 공용 파일 변경
- `shared/Config.luau`: `DEBUG.logArenaStats = false`
- `rokit.toml`: `luau-lsp` 추가 (공용 파일 목록 밖이지만 모든 worktree 검증에 영향 — 이 스펙 병합 뒤 열리는 worktree부터 적용)

## 사용자 작업 — 비공개 테스트 → 공개 체크리스트
| # | 할 일 | 언제 |
|---|---|---|
| 1 | 게임 이름·설명(한국어 + 영어 한 줄), 장르 "파티·캐주얼" 계열 설정 | 비공개 테스트 전 |
| 2 | 아이콘 512×512 1장, 썸네일 1920×1080 3장 이상 — **"먹히는 초밥"을 전면에**(GDD 13). Studio 스크린샷 + 편집 | 비공개 테스트 전 |
| 3 | 경험 설문(Experience Questionnaire, 성숙도 등급) 작성 | 비공개 테스트 전 |
| 4 | 지원 기기: 컴퓨터·휴대폰·태블릿 켬, 콘솔은 끔(게임패드 UI 확인은 M5) | 비공개 테스트 전 |
| 5 | 서버 최대 인원: Lobby 40, Match 24 (한 플레이스 모드로 내놓으면 40) | 비공개 테스트 전 |
| 6 | API 서비스 접근 켬(DataStore), MemoryStore 사용(별도 설정 없음) | m4-07 때 |
| 7 | 비공개 테스트: 접근을 친구/지정 사용자로 제한해 4명 이상이 5판 이상, 결과를 `docs/playtest/m4.md`에 (M3 양식 + "저장·텔레포트 문제" 칸) | m4-12 뒤 |
| 8 | 개인정보 삭제 요청(Right to Erasure) 오면 DataStore 키 `u_<UserId>` 삭제 — 절차를 메모해 둠 | 공개 전 |
| 9 | 개발자 상품 15개(스킨) 생성·가격 확인 (m4-14) | 공개 전 |
| 10 | 공개 전환 | m4-14 QA 통과 + 비공개 테스트 큰 문제 없음 |

## 결정 기록
- 2026-10-08 · P3 정리 범위 · B3·G1·G4는 고침, B4는 둠, 다이브 지름길은 확인만. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 비공개 테스트를 스킨 전에 · 게임 자체(맵·저장·텔레포트)를 먼저 검증하고, 스킨·결제는 마지막(CLAUDE.md) · planner
- 2026-10-08 · 콘솔 지원은 M5 · planner
- 2026-10-08 · 타입 검사 도구 · `luau-lsp` 1.70.1(rokit) + 같은 태그의 `globalTypes.None.d.luau`를 `types/`에 **커밋**(네트워크 없이 같은 결과). **새 타입 검사기(`--flag:LuauSolverV2=true`)** 사용: 옛 검사기는 이 버전에서 `pcall` 반환값·`Player ~= nil`·UI 자식 배열 같은 올바른 코드에 140건(중복 제외)을 내서 고치려면 캐스트가 코드 곳곳에 들어감. 새 검사기 72건은 전부 타입 표기만으로 0건으로 만듦(동작 변경 없음). 진짜 결함은 1건(`ChefBoard` `task.spawn(movePivot, …)` 인자 4개 → 5번째 `easeIn` 명시, 값은 같음) · developer
- 2026-10-08 · 남은 P3 처리 (메인 세션 목록 포함) · 고침: m3-09 B3, m3-07 G1·G4, m4-02 Q1(간장 늪 종이 등을 x 6으로 비킴)·Q2(회전 벨트 문·노렌을 3 올려 노렌 바닥 15.2), m4-03 B3(철판 테두리·꼬치 무대 테두리 윗면 = 바닥 윗면), m4-05 C2(칼이 도마 가운데 위·지금 기울기로 올라감)·C3(내려칠 때 매 프레임 기울기를 따라감), m4-07 D5(종료 때 로드 중인 사람도 기다림). **보류**: m3-09 B4(스펙 결정), m4-05 C1(밀기 반경은 판정 수치 — 바꾸지 않음, 사용자 판단), m4-03 B5(꼬치 음식 장식을 클라이언트가 따라가게 하는 구조 변경 — AC7 8명 부하 확인에서 문제가 보이면), m4-06 L2(단상 외형 — 스킨이 하나라 안 보임, m4-13 스킨 때 매치 시작 외형을 ctx에 저장), m4-07 D6(설계상 위험 메모 — 실서버 텔레포트 지연을 보고 `LoadRetries` 결정), m4-08 B4(Studio 확인 항목, 겹치면 토스트 위치 조정) · developer
- 2026-10-08 · 연속 5판 자동 확인 범위 · Studio 없이는 실제 Instance·연결 수를 셀 수 없어서, (1) 순수 로직으로 매치를 10판 연속 돌려(앞 5판은 6개 맵을 다 쓰는 강제 플랜) 방·잡기 기록·소리 기록이 0으로 돌아오는지, (2) 서버·클라이언트 모듈 전역 표마다 지우는 코드가 있는지(소스 점검), (3) `logArenaStats`로 Studio에서 숫자를 보게 함. 실제 Workspace 자식 수·메모리는 AC4 Studio 확인 · developer
- 2026-10-08 · 디버그 `DEBUG.forceMapPlans`(새, 공용 파일 Config) · 스펙은 "혼자 forceMapPlan으로 5판 연속, 6개 맵 모두"인데 forceMapPlan은 매치마다 같은 플랜(3~4개)이라 한 서버에서 6개 맵을 다 못 봄. 플랜 목록을 넣으면 매치마다 다음 플랜을 쓰게 함(Studio 전용, forceMapPlan이 우선). 판정·라운드 규칙 변경 없음 · developer
- 2026-10-08 · AC6 다이브 지름길 확인 · **확인 대기(Studio 필요)**. 에이전트 환경에 Studio가 없어 6개 맵을 직접 돌 수 없음. 개발 메모 "Studio 확인" 3번 절차로 사용자가 확인 후 위치를 여기에 적어 주면 고칠지 정함 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 구현 (커밋 98eadcb, 04e0fe6, ce9f470)
**검증 5단계** (PowerShell·bash 공통, 처음 한 번 `rokit install`)
```
rojo build -o build.rbxl
stylua --check src tests
selene src
lune run tests
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src
```
- 마지막 명령은 에러가 없으면 끝 코드 0, 출력은 `[INFO] Loading definitions…` 두 줄뿐. 에러가 있으면 `파일(줄,칸): TypeError …`와 끝 코드 1.
- `sourcemap.json`은 이미 `.gitignore`에 있음. 정의 파일 갱신 방법은 `types/README.md`.
- 도구를 못 받는 환경(클라우드 등)에서는 "타입 검사 못 함"을 보고에 적는다 → **docs-writer**: `docs/WORKFLOW.md`·`CLAUDE.md` "검증"·`.claude/agents/*.md`의 검증 명령에 5번째 단계와 이 규칙을 넣어 주세요.
- VS Code luau-lsp 확장을 쓰면 설정 `luau-lsp.fflags.enableNewSolver = true`로 같은 결과를 봄.

**바뀐 파일**
- 도구: `rokit.toml`(luau-lsp 1.70.1), `types/globalTypes.None.d.luau`(새, 1.70.1 태그 그대로), `types/README.md`(새).
- 타입만 고침(동작 같음): `client/fx/IntroController`·`LobbyFxController`·`VictoryProps`, `client/ui/HudScreen`·`LobbyController`, `server/RewardService`·`RoundService`, `shared/PlacePayload`·`ProfileLogic`·`RewardLogic`·`RoomDirectoryLogic`·`RoomLogic`·`RoundLogic`(정렬 비교 함수·결과 표 타입 표기만, 판정 그대로)·`Rules`·`VictoryCutsceneLogic`, `shared/maps/ChefBoardArt`·`RamenRapidsLogic`·`RotatingBelt`·`SkewerShowdown`·`init`.
- G1·G4: `shared/GrabInputLogic.luau`(새, 입력원별 누름·0.1초+0.03 여유 안 재누름은 예약 후 한 번 더), `client/input/GrabController.luau`(마우스·게임패드·터치를 따로, `cancelHold`는 전부 뗌). `GrabButton.luau`는 바꿀 필요 없었음(터치 하나를 이미 따로 듦).
- B3: `shared/maps/MapSfxLogic.luau` 간격 기록을 약한 키 표로.
- 남은 P3: `SoySwampArt`(종이 등 x 6), `RotatingBeltArt`(문 기둥 19·보 18.6·노렌 16.6), `HotPlateArt`(테두리 윗면 = 층 윗면, 기름 자국·김 위치 같이 내림), `SkewerShowdownArt`(RimLip 윗면 = 무대 윗면), `ChefBoard`(`movePivot`가 함수 목표를 받아 칼이 기울기를 따라감, 쉬는 위치 = 도마 가운데 위), `server/DataService`(종료 때 `loading`도 기다림).
- 연속 매치: `shared/Config.luau` `DEBUG.logArenaStats = false`·`DEBUG.forceMapPlans = nil`(새, 매치마다 다음 강제 플랜), `server/MatchService`(`forcedPlan` 순환, `finish`에서 2초 뒤 `[ArenaStats]` 한 줄), `server/RoundService.debugHookCount()`.
- 테스트: `tests/m4-12-hardening.spec.luau`(18개).

**Studio 확인 (사용자)**
1. **연속 5판 (AC4)**: `src/shared/Config.luau`에서 `DEBUG.logArenaStats = true`, `DEBUG.forceMapPlan = nil`(그대로), `DEBUG.forceMapPlans`에 아래 5개 플랜 목록을 넣는다. Play 한 번(서버 하나)에서 방 만들기 → 시작을 5번 하면 매치마다 다음 플랜을 쓴다(6개 맵이 모두 나옴, 혼자여도 끝까지).
   ```lua
   forceMapPlans = {
   	{ "rotating-belt", "hot-plate", "skewer-showdown" },
   	{ "soy-swamp", "chef-board", "skewer-showdown" },
   	{ "ramen-rapids", "hot-plate", "rotating-belt", "skewer-showdown" },
   	{ "soy-swamp", "ramen-rapids", "chef-board", "skewer-showdown" },
   	{ "rotating-belt", "soy-swamp", "skewer-showdown" },
   } :: { { string } }?,
   ```
   - 기준: Output의 `[ArenaStats] … workspace children N, arena models 0, open matches 0, round hooks 0, … memory M MB`에서 판마다 **children 같음, arena models 0, round hooks 0**. 첫 판 끝 대비 5판 뒤 memory **+50MB 이하**. 빨간 에러 없음. 숫자(시작·끝 children, memory)를 이 메모에 적어 주세요.
   - 끝나면 `logArenaStats = false`, `forceMapPlans = nil` (커밋 금지).
2. **잡기 (AC5)**: 좌클릭을 아주 빨리 두 번(두 번째는 누른 채) → 0.1초쯤 뒤 잡기가 켜짐(근처에 상대가 있으면 잡힘). Device 에뮬레이터(휴대폰)에서 잡기 버튼을 누른 채 마우스 왼쪽을 눌렀다 떼도 잡기가 유지되고, 버튼을 떼면 놓음.
3. **다이브 지름길 (AC6)**: 6개 맵을 돌며 벽 끝·절벽·국물 구간에서 점프 → 다이브로 코스를 건너뛸 수 있는 곳이 있는지 본다(간장 늪 와사비 위 다이브 포함). 있으면 맵·위치(대략 좌표)를 결정 기록에 적는다. 고칠지는 사용자 판단.
4. **8명 부하 (AC7)**: Test → Clients and Servers 8명, 24명 방 → 시작(8명이면 3라운드. 4라운드를 보려면 `forceMapPlan`에 4개) → Developer Console(F9) → Server Stats의 Heartbeat ≥ 55. 꼬치 쇼다운 결승에서 특히 확인(m4-03 B5).
5. **P3 눈 확인**: 간장 늪 소개 플라이스루 마지막 구간에 빨간 종이 등이 화면을 덮지 않음, 회전 벨트 결승 문 노렌이 머리 위로 높아짐, 철판 층 테두리·꼬치 무대 테두리가 턱처럼 보이지 않음, 셰프의 도마 칼이 기울 때 도마를 따라 내려치고 친 뒤 도마 가운데 위로 올라감.
6. **m4-08 B4**: 작은 창(세로 720 이하)에서 우승할 때 "+100 🍚 우승!" 토스트가 우승 큰 글씨와 겹치는지.

**출시 체크리스트 (비공개 테스트 → 공개)** — 위 "사용자 작업" 표를 그대로 쓰고, 사용자 할 일은 `docs/USER-TODO.md`에 이미 있는 칸으로 연결한다(중복해서 적지 않음).
| 표 # | 할 일 | USER-TODO 칸 | 에이전트 쪽 상태 |
|---|---|---|---|
| 1·2 | 이름·설명·아이콘·썸네일 | A3 | 없음 (사용자) |
| 3·4·5 | 경험 설문, 지원 기기(콘솔 끔), 서버 최대 인원 Lobby 40 / Match 24 | C4 (+ C2-3 인원) | 없음 |
| 6 | API 서비스 접근 | C1 | 코드 완료 (m4-07) |
| 7 | 비공개 테스트 4명+ × 5판+, `docs/playtest/m4.md` | D (새 줄 필요) | 양식: M3 `docs/playtest/m3.md` + "저장·텔레포트 문제" 칸 |
| 8 | 개인정보 삭제 요청(Right to Erasure) | C4 | 절차 아래 |
| 9 | 개발자 상품 15개 | C3 | m4-14 |
| 10 | 공개 전환 | C4 | m4-14 QA 통과 + 비공개 테스트 큰 문제 없음 |

개인정보 삭제 요청 절차 (Roblox가 메시지로 UserId를 보내옴):
1. Creator Dashboard → 이 게임 → **Data Stores**(Data Stores Manager) → 스토어 `PlayerData_v1` (`Config.Data.StoreName`) → 키 `u_<UserId>` 삭제. (또는 Open Cloud DataStore API로 같은 키 DELETE)
2. 다른 저장 위치 없음: MemoryStore(방 목록·매니페스트·복귀 티켓)는 몇 분 안에 만료되는 임시 값이라 따로 지울 것 없음. OrderedDataStore 없음.
3. 30일 안에 처리, 처리한 날짜·UserId를 사용자 메모에 남김. 스토어 이름을 바꾸면(`_v2`) 옛 스토어의 같은 키도 지운다.

**남은 이슈**
- AC4~AC7 Studio 확인 대기. 보류 P3는 결정 기록.
- `.claude/agents/*`·`WORKFLOW.md`·`CLAUDE.md` 검증 명령 갱신은 docs-writer.
