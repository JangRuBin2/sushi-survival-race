status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-09 — M3 통합 · 장애물 소리 · 튜닝

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §12(M3 완료 기준: 친구 테스트에서 "웃기다" 반응), §5.2(장애물 경고·반응), §13(모바일 버튼 3개)
- 참고: `docs/REFERENCE-party-royale.md` §5
- 담당 개발 worktree: `main` (**순차, M3 마지막**. m3-02 ~ m3-08이 모두 `qa-passed`로 `main`에 병합된 뒤 시작)
- 공용 파일 수정 담당: **이 스펙** (병렬 단계가 끝났으므로 m3-01에 이어 공용 파일 `shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `default.project.json`을 이 스펙만 고친다)
- 의존: m3-01 ~ m3-08 전부
- **이 스펙이 고치는 파일**: 새 파일 `src/shared/maps/MapSfx.luau`(서버에서 맵 파트에 소리 내기), 새 파일 `src/shared/maps/MapSfxLogic.luau`(순수, 소리 간격 제한), 맵 파일 `RotatingBeltChopstick.luau`·`SoySwampHazards.luau`·`HotPlate.luau`(또는 `HotPlateLogic`을 부르는 쪽)·`SkewerShowdown.luau`(소리 호출 한 줄씩), 새 파일 `tests/map-sfx.spec.luau`, 그리고 통합 중 발견한 버그를 고치는 데 필요한 M3 파일·`shared/Config.luau`(튜닝 값)

## 목표
M3 기능 일곱 개가 한 판 안에서 서로 부딪히지 않고 함께 돈다. 장애물이 경고하고 움직일 때 소리가 나서 "곧 뭔가 온다"가 귀로도 느껴진다. 친구 테스트로 수치를 다듬을 준비를 한다.

## 범위
- 포함:
  1. **장애물 소리 (서버)** — `MapSfx.play(part: BasePart, cue: string)`: 서버가 그 파트 아래에 `Sound`(id·볼륨은 m3-08 `SfxLibrary`)를 만들어 재생하고 끝나면 지운다. 서버에서 만든 Sound는 그 위치 근처 클라이언트에 3D로 들린다. id가 nil이면 아무것도 안 한다. 같은 파트·같은 cue는 `MapSfxLogic.MIN_INTERVAL`(기본 0.2초) 안에 다시 울리지 않는다.
     | 맵 | 순간 | cue |
     |---|---|---|
     | 회전 벨트 | 젓가락 빨간 원 경고가 뜰 때 | `ChopstickWarn` |
     | 간장 늪 | 플레이어가 간장 웅덩이에 들어갈 때(감속이 걸리는 순간) | `SoySlow` |
     | 간장 늪 | 와사비 패드에 튕길 때 | `WasabiBoing` |
     | 뜨거운 철판 | 타일이 달아오르기 시작할 때 / 사라질 때 | `HotTileSizzle` / `TileVanish` |
     | 회전 꼬치 쇼다운 | 꼬치가 빨라질 때마다 | `SkewerWhoosh` |
     | 회전 꼬치 쇼다운 | 셰프 손이 조각을 집기 전 경고 | `ChefHandWarn` |
     맵 파일은 **소리 호출만** 넣는다 — 판정·타이밍·태그 규칙은 바꾸지 않는다.
  2. **통합 점검** — m3-02~08이 `main`에서 함께 돌 때 아래 "교차 시나리오"(AC)를 확인하고 깨지는 것을 고친다. 고친 내용은 원래 스펙의 결정 기록이 아니라 이 스펙 개발 메모에 적는다.
  3. **튜닝 자리** — 친구 테스트(사용자) 결과로 바꿀 값은 모두 `shared/Config.luau`에 있어야 한다. 통합 중 코드 안에 박힌 연출·조작 수치(다이브 기울기, 탈락 동시 재생 한도 6, 소리 간격 등) 중 **사용자가 바꾸고 싶어 할 만한 것**이 있으면 `Config`로 옮긴다 (`Config.Fx` 같은 새 묶음, 이 스펙이 공용 파일 담당).
  4. **Studio 확인 목록 넘기기** — 아래 Studio AC를 `docs/DEV-SETUP.md` M3 절에 넣을 수 있게 개발 메모에 정리한다(실제 반영은 docs-writer).
- 제외:
  - 수치 확정 — 친구 테스트 뒤 사용자가 정한다 (m3-plan의 "사용자 할 일")
  - 회전 벨트 태그 방식 전환(M1 B10), 결승 같은 틱 리셋 우승(m2-07 I1), Survival 탈락 0명 허용(m2-05 Q7) — M3 범위 아님
  - 맵 아트, 새 맵 (M4)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/map-sfx.spec.luau`)
- [ ] AC1: `MapSfxLogic` — 같은 (파트 키, cue)는 0.19초 뒤에는 막히고 0.2초 뒤에는 허용된다. 다른 파트나 다른 cue는 서로 막지 않는다. 기록이 무한히 쌓이지 않는다(오래된 항목 정리 또는 `ctx.cleanup`과 함께 버림).
- [ ] AC2: 위 표의 cue가 모두 `SfxCues`·`SfxLibrary`에 있다.
- [ ] AC3: `rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests` 전체 통과, `Config.DEBUG.forceMapPlan`은 nil.

### Studio 확인 — 장애물 소리
- [ ] AC4: 회전 벨트 빨간 원이 뜰 때, 간장에 들어갈 때, 와사비에 튕길 때, 철판 타일이 달아오르고 사라질 때, 꼬치가 빨라질 때, 셰프 손 경고 때 소리가 난다(id가 채워진 cue만). 멀리 있는 장애물 소리는 작거나 안 들린다.
- [ ] AC5: (회귀) 소리를 넣은 뒤에도 4개 맵의 판정·타이밍이 M2와 같다 (m2-07 통합 체크리스트 중 맵 항목).

### Studio 확인 — 교차 시나리오 (Clients and Servers 3명, 필요하면 `forceMapPlan`)
- [ ] AC6: 카메라 — 관전 중에 다음 라운드 소개가 와도(관전자는 플라이스루 없음) 관전 화면이 유지되고, 달리는 사람의 플라이스루 → "출발!" → 탈락 연출 카메라 → 자동 관전 → 우승 연출 → 우승자 비추기 → 대기실 내 캐릭터 순서로 카메라가 한 번도 엉뚱한 곳에 멈추지 않는다.
- [ ] AC7: 결승에서 마지막 두 사람이 거의 동시에 떨어져도 진 사람의 탈락 연출(셰프 손)이 우승 연출 시작과 함께 깨끗이 정리되고 모두 우승 연출을 본다.
- [ ] AC8: 잡힌 채로 젓가락에 들리거나 날치알 공에 맞으면 잡기가 풀리고, 내려온 뒤 속도가 정상이다. 잡힌 채로 다이브해 멀어지면 풀린다.
- [ ] AC9: 다이브 도중 낙하해 탈락하면 엎드린 자세가 아니라 탈락 연출 인형이 보이고, 연출 뒤 로비 캐릭터가 똑바로 서 있다.
- [ ] AC10: 탈락 연출·우승 연출·플라이스루 도중 방을 나가면 카메라가 로비의 내 캐릭터로 돌아오고 연출 소품이 남지 않는다.
- [ ] AC11: 계란초밥 외형이 연출 인형(탈락·우승)과 실제 캐릭터에서 같다. 리스폰·라운드 이동 뒤에도 초밥 파츠가 한 벌이다.
- [ ] AC12: 휴대폰 에뮬레이터 — 점프·다이브·잡기 버튼, 관전 버튼, 음소거 버튼, HUD가 서로 겹치지 않는다.
- [ ] AC13: 성능 — Clients and Servers 8명으로 1라운드에서 여러 명이 거의 동시에 떨어져도 클라이언트 프레임이 눈에 띄게 끊기지 않는다(Studio 성능 통계로 대략 확인, 30fps 아래로 오래 떨어지지 않음).
- [ ] AC14: 한 판(3~4라운드)을 처음부터 우승까지 두 번 연속 돌려도 Output에 빨간 에러가 없고, 두 번째 판도 첫 판과 같게 동작한다(연출 상태가 남지 않음).

### 사용자 확인 (M3 완료 기준)
- [ ] AC15: 친구 테스트(4명 이상)에서 탈락·우승 연출을 보고 "웃기다" 반응이 나온다. 바꾸고 싶은 수치·연출은 사용자가 메인 세션에 알려 주고, planner가 GDD·스펙에 반영한다.

## 공용 파일 변경
- `shared/Config.luau`: 통합 중 코드에 박힌 튜닝 값을 옮길 때만 (예: `Config.Fx = { EliminationMaxConcurrent = 6, ... }`). 옮긴 값과 원래 위치를 개발 메모에 적는다.
- `shared/Remotes.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `default.project.json`: 계획된 변경 없음 (통합 버그로 필요하면 이 스펙만 고침)

## 결정 기록
- 2026-10-08 · 장애물 소리는 서버에서 · 장애물 타이밍을 서버 맵 모듈이 알고 있어서 서버가 파트에 Sound를 붙여 재생(복제되면 클라이언트에 3D로 들림). 맵 파일은 소리 호출 한 줄씩만 고침. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 마지막 순차 단계 · 맵 파일과 공용 파일을 여러 worktree가 동시에 고치지 않게 장애물 소리와 튜닝을 통합 단계로 미룸 · planner
- 2026-10-08 · 수치 확정은 친구 테스트 뒤 사용자가 · M3 스펙의 기본값은 모두 "기본값으로 진행, 사용자 수정 가능" — 사용자 지시("일단 개발 다 해 놓으면 나중에 수정 명령을 내리겠다") · user (메인 세션 경유)
- 2026-10-08 · 장애물 소리를 내는 곳 (스펙 범위 1과 다름) · 서버가 Sound를 만들면 pitch는 넣을 수 있어도 클라이언트 음소거 "🔇 모두 끔"(로컬 SoundGroup)이 못 끄고 동시 재생 한도도 따로 돌아요 (m3-08 QA B4). 그래서 서버 `MapSfx.play(part, cue)`는 간격 제한(MapSfxLogic)과 id 확인만 하고 새 RemoteEvent `MapSfx(cue, part, position)`를 모든 클라이언트에 보내요. 클라이언트 `Sfx`가 카메라에서 `Config.Fx.SfxMaxDistance`(120) 안이면 `Sfx.play(cue, part)`로 3D 재생 (pitch·흔들림·음소거·한도 공통). **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 시간 종료·정원 마감 탈락 cause · `Types.EliminationCause`에 `"Timeout"` 추가, `RoundService`가 낙하·리셋이 아닌 탈락을 Timeout으로 채움. `EliminationCutsceneLogic.shouldPlay("Timeout") = true` — 연출 종류는 기존 규칙(Race·Survival = 젓가락, 결승 = 셰프 손). 관전 3초 비추기도 Timeout 포함. QA 테스트 `m3-03-qa` "shouldPlay: Fall·Reset 말고는 전부 false"의 Timeout 기대값을 true로 바꿈(이 결정 때문). **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 결승 마지막 탈락 뒤 우승 발표 시점 (m3-03 QA B1) · 출발 뒤 같은 판정 묶음에서 탈락(방에 남은 사람)과 우승이 같이 나오면, 서버가 `Config.Match.EliminationCutscene`(3초) 기다린 뒤 `Won` → `Victory`. 그동안 맵·우승자는 그대로(판정 없음). 한 판이 결승에서 최대 3초 길어짐. 소개 중 취소·상대 퇴장(Left)은 기다리지 않음. **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 공중 다이브 위쪽 속도 (m3-06 QA B1) · `vy = min(지금 vy, Config.Dive.AirMaxUpSpeed)`(기본 16 = UpSpeed). 꼭대기·내려가는 중 다이브는 그대로. QA 테스트 `m3-06-qa` "공중에서 위로 가는 중이면 그 수직 속도를 그대로 둬요"(45 → 45)는 B1의 원인이라 16으로 바꿈. 점프 0.02/0.05/0.1/0.2초 뒤 다이브 반복 시뮬레이션이 모두 걷기보다 느림. **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 잡기 기획 질문 (m3-07 QA G2·G3) · 잡고 있는 사람은 잡힐 수 없음(`GrabLogic.pickTarget`/`begin`, 감속 중첩 방지). 잡는 사람이 다이브하면 클라이언트가 `GrabInput(false)`를 보내 잡기 해제(`GrabController.cancelHold`). 계속 누르고 있어도 다시 눌러야 잡음. `grab.spec` "나간 플레이어…" 테스트는 begin으로 두 역할을 만들 수 없게 돼서 기록을 직접 넣도록 바꿈. **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 이름표 (m3-02 QA B2) · Head 투명 때문에 기본 이름표가 안 보일 위험을 없애려고 클라이언트 `CharacterFxController`가 다른 사람 초밥 Body 위에 이름표(BillboardGui, DisplayName, 거리 100)를 직접 띄우고 기본 휴머노이드 이름표는 로컬에서 끔(`DisplayDistanceType = None`). 탈락 연출로 숨겨진 동안은 이름표도 숨김. **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 외형 숨김 제외 규칙 (m3-02 QA B3) · 캐릭터 아래 BasePart·Decal은 SushiBody 밖이면 숨김. 자신이나 (캐릭터 아래) 조상에 `Attributes.KeepVisible = true`가 있으면 제외. 속성은 Parent를 넣기 전에 달아야 함. 이름 상수는 `SushiBody.MODEL_NAME/JOINT_NAME`로 옮김 (B4, `m3-02-qa` 이름 일치 테스트를 공용 상수 기준으로 바꿈) · developer
- 2026-10-08 · 클릭음 제외 규칙 (m3-08 QA B1) · `TouchGui`·`ContextActionGui` 아래 버튼과 자신이나 조상에 `Attributes.NoClickSfx = true`가 달린 버튼은 클릭음 없음(누를 때 확인). `DiveGui`·`GrabGui`에 속성을 달았음. `m3-06-qa` "다이브는 … 속성을 만들지 않아요"는 이 UI 전용 속성 한 줄만 빼고 보도록 바꿈. 같은 버튼은 한 번만 연결(B3) · developer
- 2026-10-08 · 좁은 화면 음소거 버튼 (m3-08 QA B2) · 화면 폭 < `Config.Fx.NarrowScreenWidth`(900px)이면 아이콘만(34×28) 오른쪽 끝에서 4px, y 60. 위 가운데 HUD 패널(420px)·로비 패널 내용(0.92배 폭 + 안쪽 여백 16px)에 닿지 않음 (폭 ≥ 약 530px). **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 관전 비추기 시간 (m3-01 QA B1) · `EliminationCutscene - Config.Fx.SpectateHoldMargin`(3 - 0.3초). 리셋 탈락 위치(B2): 옛 캐릭터 감시에서 온 리셋은 지금 `player.Character`(리스폰된 새 캐릭터)로 위치를 채우지 않음(서버 두 곳) → 위치 없으면 본인 스탬프만 · developer
- 2026-10-08 · 손대지 않은 QA 항목 · m3-03 B2(낙하 연출이 코스 20~40 studs 아래에서 재생 — M4 아트 때 보정), m3-04 B2(Survival·Final 플라이스루 끝점), m3-06 B2·B3(공중 다이브 지름길·와사비+다이브 — Studio 체감 후), m3-07 G1(0.1초 안 재누름)·G4(입력 공유), m3-02 B5(문서 문구). 장애물 cue 중 `ChopstickWarn`·`HotTileSizzle`·`ChefHandWarn`은 `SfxLibrary` id가 nil이라 지금은 소리가 안 남(사용자가 id를 넣으면 바로 남) · developer
- 2026-10-08 · QA 뒤 수정 (m3-09 QA B1, P2) · 우승 글씨: m3-09의 "Won 글씨 생략"은 결승 뒤 지연 3초 + RoundResults 5초 동안 우승자에게 아무 표시가 없게 만들었음(QA가 m3-05 B3 진단 오류도 확인). 이제 `HudController`가 Won 글씨 "🏆 우승했어요!"를 띄우고 4초 타이머 없이 Victory 단계까지 유지, `MatchPhase Victory`를 받으면 `HudScreen:clearPersonalResult()`로 지움. 이미 Victory 중이면 띄우지 않음(부전승처럼 Won 직후 Victory가 와도 연출과 겹치지 않음). `HudScreen.showPersonalResult(text, keep?)`·`clearPersonalResult` 추가 · developer
- 2026-10-08 · QA 뒤 수정 (m3-09 QA B2, P3) · 장애물 소리 신호를 그 방 사람에게만: `MapSfx.setAudience(fn)`로 서버 `RoundService.init`이 받을 사람 함수를 넣음(맵 파트는 조상 맵 Model의 `RoomId`, 캐릭터 파트는 그 플레이어의 방 → `RoomService.getPlayers`). 방을 모르면 기존처럼 `FireAllClients`. shared 모듈이 서버 모듈을 require하지 않아 순환 없음. 순수 `MapSfxLogic.roomIdOf` 추가 · developer
- 2026-10-08 · 보류 (m3-09 QA B3~B5, P3) · B3 리미터가 지워진 파트를 다음 호출까지 잡고 있음(1초마다 정리, 메모리 영향 매우 작음), B4 결승 소개 중 상대 리셋 시 리셋 연출이 Victory에 잘림(소개 중은 지연하지 않는 기존 결정), B5 900~980px 창에서 글자 음소거 버튼이 로비 패널 제목 줄 빈 곳 위에 놓임(글자는 안 가림). 친구 테스트 뒤 필요하면 처리 · developer
- 2026-10-08 · 사용자 수정 지시(클라우드 브랜치에서 가져옴) — 음소거 버튼을 Roblox 위쪽 바로 · `origin/claude/resume-agent-execution-2doypv` 커밋 7ba8571의 아이디어만 가져옴. `Sfx.luau` buildMuteButton: `SoundGui`에 `ScreenInsets = TopbarSafeInsets`(IgnoreGuiInset은 ScreenInsets를 덮어써서 설정 안 함), 버튼은 바 오른쪽 끝 세로 가운데, 높이 = 바 높이 - 8(최대 36), 폭 110(좁은 화면 < 900px는 아이콘만 36). 3단계·NoClickSfx 규칙 그대로. 게임 화면(LobbyGui)은 위쪽 바 아래에만 그려져 로비·방·HUD·관전과 겹치지 않고, Roblox 기본 버튼은 안전 영역이 피함 → QA B5(P3) 해소. `m3-09-qa`의 y 60 가로 겹침 계산 테스트 2개는 전제가 사라져 "TopbarSafeInsets·세로 가운데" 소스 확인 + "게임 UI가 IgnoreGuiInset을 켜지 않음" 확인으로 바꿈, `m3-08-qa` start 테스트에 ScreenInsets 확인 추가 · user (메인 세션 경유) / developer
- 2026-10-08 · 사용자 수정 지시(클라우드 브랜치에서 가져옴) — "출발!"이 HUD 배너를 덮지 않게 · 커밋 19a213f의 아이디어(배너 픽셀 아래 끝 기준 배치)만 가져옴. 순수 `shared/IntroLayout.luau`: HUD 위 배너(`HudScreen.TOP_BANNER_NAME` = "TopBanner")의 AbsolutePosition+AbsoluteSize(없으면 100 = y 16 + 84) 아래 6px부터, 가장 커진 1.4배 글씨가 들어가게 가운데 높이를 내리고, 모자라면 글씨를 줄임(120 → 최소 36, 화면 폭도 고려). 큰 화면은 예전 그대로 40%·120px·600×160. `IntroScreen`은 `showGo` 때마다 다시 계산 · user (메인 세션 경유) / developer

## 개발 메모
### 2026-10-08 — 사용자 수정 지시 2건 (developer, 브랜치 main)
- 음소거 버튼: `client/Sfx.luau`. Studio: 로비·방·매치·관전 중 버튼이 Roblox 위쪽 바 줄 오른쪽 끝에 있고(메뉴·채팅 버튼과 안 겹침) 우리 UI와 안 겹치는지. 창 폭 900 미만(Device 에뮬레이터 휴대폰 가로)에서는 아이콘만. 누르면 소리 켬 → 음악 끔 → 모두 끔, 클릭음 그대로.
- "출발!": `shared/IntroLayout.luau`(신규), `client/fx/IntroScreen.luau`, `client/ui/HudScreen.luau`(Hud·TopBanner 이름 상수). Studio: Device 에뮬레이터로 휴대폰 가로(예: 844×390, 667×375)에서 라운드 시작 때 "출발!"이 위쪽 맵 이름·규칙 배너 아래에 뜨고 커져도 배너를 덮지 않는지, PC 창에서는 예전 자리(40%)·크기인지.
- 테스트: `intro-layout.spec`(신규 7개), `m3-08-qa`·`m3-09-qa` 음소거 버튼 테스트 수정(결정 기록). 검증: rojo build OK, stylua OK, selene 0/0, lune 493 passed / 0 failed.

<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 — 구현 (developer, 브랜치 main)
**커밋**: `3926a36` 통합 수정, `f3eebe6` 장애물 소리 (+ 문서 커밋)

**바뀐 파일**
- 공용: `shared/Config.luau`(`Config.Fx` 새 묶음, `Config.Dive.ProneAngle`·`AirMaxUpSpeed`), `shared/Types.luau`(`EliminationCause`에 `"Timeout"`), `shared/Remotes.luau`(RemoteEvent `MapSfx`), `shared/Attributes.luau`(`KeepVisible`, `NoClickSfx`). `maps/init.luau`·`default.project.json`은 변경 없음.
- 새 파일: `shared/maps/MapSfx.luau`, `shared/maps/MapSfxLogic.luau`, `tests/map-sfx.spec.luau`(12), `tests/m3-09-integration.spec.luau`(8)
- 맵(소리 호출만): `RotatingBeltChopstick`(경고 원 → `ChopstickWarn`), `SoySwampHazards`(간장 감속 순간 → `SoySlow`, 와사비 튕김 → `WasabiBoing`), `HotPlate`(달아오르기 시작 → `HotTileSizzle`, 사라짐 → `TileVanish`), `SkewerShowdown`(10·20·…·60초 꼬치 가속 → `SkewerWhoosh`, 조각 경고 시작 → `ChefHandWarn`)
- 서버: `RoundService`(Timeout cause, 결승 우승 발표 지연, 리셋 위치), `EliminationService`(리셋 위치 대체 안 함), `GrabService`(후보에 `grabbing`), `AppearanceService`(공용 이름 상수, `KeepVisible`)
- 공용 로직: `EliminationCutsceneLogic`(Timeout, 한도 = `Config.Fx`), `DiveLogic`(공중 vy 상한), `GrabLogic`(잡는 사람은 대상 아님), `SushiBody`(`MODEL_NAME`/`JOINT_NAME`)
- 클라이언트: `Sfx`(MapSfx 재생, 클릭음 제외 규칙·중복 연결 방지, 좁은 화면 아이콘 음소거, 긴 소리 수명, Config.Fx 값), `CharacterFxController`(Anchored는 넘어짐 아님, 이름표), `IntroController`(소개 중 탈락 시 중단·"출발!" 없음), `HudController`(우승 개인 글씨 생략), `SpectateController`(Timeout 비추기, 비추기 시간), `DiveController`(원래 상태 복원, 기울기 Config, 다이브 시 잡기 해제), `GrabController`(`cancelHold`), `DiveButton`·`GrabButton`(`NoClickSfx`), `EliminationCutsceneController`(주석)
- 테스트 수정(이유는 결정 기록): `m3-01-qa`(Config.Dive 새 키), `m3-02-qa`(이름 상수), `m3-03-qa`(Timeout), `m3-06-qa`(공중 vy·NoClickSfx 줄 제외·B1 시뮬레이션 4개 추가), `grab.spec`(G2 테스트 추가·기록 직접 넣기), `camera-priority.spec`(Attributes 8개), `lib/FakeSfxEnv`(Config·Attributes·GetAttribute)

**Config로 옮긴 값 (원래 위치)**
| 값 | 원래 위치 |
|---|---|
| `Fx.EliminationMaxConcurrent = 6` | `EliminationCutsceneLogic.MAX_CONCURRENT` 상수 (이제 Config를 읽음) |
| `Fx.SfxVolume 0.7 / MusicVolume 0.3 / SfxMaxDistance 120 / SfxMaxActive 16` | `client/Sfx.luau` 지역 상수 |
| `Dive.ProneAngle = 80` | `DiveController.PRONE_PITCH` |
| 새 값: `Fx.MapSfxMinInterval 0.2`, `Fx.SpectateHoldMargin 0.3`, `Fx.NarrowScreenWidth 900`, `Dive.AirMaxUpSpeed 16` | — |

**검증**: `rojo build` OK, `stylua --check src tests` OK, `selene src` 0 errors/0 warnings, `lune run tests` 463 passed / 0 failed. `Config.DEBUG.forceMapPlan = nil`.

**Studio 확인 (DEV-SETUP M3 절로 옮길 목록)** — 준비: `rojo serve`, 필요하면 로컬에서만 `forceMapPlan`(커밋 금지).
1. **AC4 장애물 소리** — 간장 늪: 간장 웅덩이에 들어갈 때 "출렁"(수영 소리 낮게), 와사비 패드에서 "뾰잉"(점프 소리 높게). 철판: 타일이 사라질 때 발소리(낮게). 꼬치 쇼다운: 10초(높은 꼬치 등장)·20·30·40·50·60초마다 "휙". 회전 벨트 경고·철판 달아오름·셰프 손 경고는 `SfxLibrary` id가 비어 있어 지금은 무음(정상). 음소거 "🔇 모두 끔"이면 장애물 소리도 안 들림. 다른 방(2000 studs 떨어진 아레나) 소리는 안 들림.
2. **AC5 회귀** — m2-07 통합 체크리스트의 맵 항목(4개 맵 판정·타이밍)이 그대로.
3. **Timeout 연출** — Race(회전 벨트)에서 2명 이상이 통과 인원을 채우거나 90초가 지나 남은 사람이 탈락하면 그 사람에게도 젓가락 연출 + "먹혔다!" 스탬프(기존 "🥢 탈락했어요" 글씨 대신).
4. **AC7 결승 마지막 탈락** — 2명 결승에서 한 명이 떨어지면 셰프 손 연출이 3초 끝까지 보이고(진 사람 화면에 "먹혔다! 2등"), 그 뒤 우승 연출이 시작. 우승자 화면 아래에 "🏆 우승했어요!" 글씨가 연출과 겹쳐 뜨지 않음.
5. **넘어짐·이름표** — 탈락(낙하) 순간 내 화면·남 화면 모두 "@_@"·Knockdown 소리가 나지 않음. 날치알·꼬치에 맞으면 여전히 "@_@". 2명일 때 서로 초밥 머리 위에 흰 이름이 보이고(거리 100 안), 기본 이름표와 겹쳐 두 개로 보이지 않음. 탈락 연출 동안 그 사람 이름표가 숨겨짐.
6. **AC8 잡기** — 잡힌 채 젓가락에 들리거나 날치알에 맞으면 풀리고 내려온 뒤 정상 속도. 잡힌 B가 다이브해 멀어지면 풀림. A가 B를 잡고 있을 때 C가 A를 잡으려 해도 안 잡힘. A가 잡은 채 Shift(다이브)하면 바로 풀림.
7. **다이브** — 점프 직후 Shift 연타가 그냥 달리기보다 빠르지 않음(체감). 다이브 끝나면 캐릭터가 정상적으로 방향을 돌고 점프됨. AC9: 다이브 도중 낙하 탈락 → 인형 연출, 로비 캐릭터 똑바로 섬.
8. **AC6 소개 중 리셋** — 소개 3초 동안 Esc→R: 탈락 연출로 넘어가고 "출발!"·Go 소리가 뜨지 않으며, 플라이스루 카메라가 다시 잡히지 않음.
9. **관전 비추기** — 관전 중 보던 사람이 떨어지면 약 2.7초 그 자리를 비춘 뒤 다음 사람으로(로비로 순간이동하는 모습이 안 보임).
10. **AC12 휴대폰** — 에뮬레이터(iPhone SE 가로 등)에서 음소거 버튼이 아이콘(🔊)만 오른쪽 위 끝에 있고 HUD 위 가운데 패널·로비 패널 내용과 안 겹침. 점프·다이브·잡기 버튼을 눌러도 "딸깍" 클릭음이 안 남(메뉴 버튼은 남).
11. **AC10·AC11·AC13·AC14** — 스펙 AC 그대로 (연출 중 방 나가기, 외형 한 벌, 8명 성능, 두 판 연속).

**남은 이슈**: 결정 기록 "손대지 않은 QA 항목". 서버 결승 대기 3초 동안 우승자도 맵 위에 그대로 있음(판정 없음).

### 2026-10-08 — QA 뒤 수정 (developer, 브랜치 main)
- QA B1(P2): `client/ui/HudController.luau`, `client/ui/HudScreen.luau` — 우승 글씨를 띄우고 Victory 시작 때 지움. Studio: 2명 결승에서 이긴 사람 화면 아래에 "🏆 우승했어요!"가 마지막 탈락 3초 뒤부터 우승 연출 시작 직전까지 보이고, 우승 연출 중에는 안 보임.
- QA B2(P3): `shared/maps/MapSfx.luau`(`setAudience`), `shared/maps/MapSfxLogic.luau`(`roomIdOf`), `server/RoundService.luau`(init에서 등록) — 장애물 소리 신호는 그 방 사람에게만. Studio: 방 2개를 동시에 돌려도 소리·판정 그대로(다른 방 신호는 오지 않음, 들리는 건 전과 같음).
- 테스트: `map-sfx.spec`(roomIdOf, 받을 사람 소스 확인 2개 추가), `m3-09-integration.spec`(HUD 확인을 새 동작으로 바꿈). 검증: rojo build OK, stylua OK, selene 0/0, lune 486 passed / 0 failed.
- B3~B5는 결정 기록에 보류.
