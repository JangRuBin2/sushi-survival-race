# QA — m3-08 사운드 (효과음 재생기 · 배경음 · 음소거)

- 스펙: `docs/specs/m3-08-sound.md`
- 검증 커밋: `ca649f7` (`m3-08-sound`) + `origin/main`(`08d49fd`) 머지 `eed7d94`, 브랜치 `m3-08-qa`
- 결과: **통과 (P0/P1 없음, P2 2건, P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC6~AC10)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 261 passed, 0 failed (main 235 + 개발 5 + QA 추가 21) |

참고: `origin/main`을 머지하자 main에 먼저 들어간 `tests/m3-01-qa.spec.luau`의 `Sfx 껍데기` 테스트 1개가 실패했다 (`no fake service SoundService`). 이 테스트는 m3-01 때 껍데기 `Sfx.luau`를 `Players`·`ReplicatedStorage`만 있는 가짜 환경으로 불렀는데, 실제 구현은 `SoundService`·`TweenService`·`Remotes`·`SfxLibrary`가 필요하다. 동작 문제가 아니라 테스트 하네스 문제라서, 기대값(경고 개수, start 전 무시)은 그대로 두고 불러오는 방법만 새 `tests/lib/FakeSfxEnv.luau`로 바꿨다. 개발 브랜치는 m3-01 QA보다 먼저 갈라져서 이 실패를 볼 수 없었다. **main에 머지할 때 이 QA 브랜치 기준으로 머지해야 테스트가 통과한다.**

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `sfx-library.spec.luau` AC1 (SfxCues 32개 ↔ SfxLibrary 양방향) |
| AC2 | 통과 | `sfx-library.spec.luau` AC2 (볼륨 0~1, 그룹, 배경음 Music·looped, id 접두사). QA: `SfxLibrary: rbxasset:// 경로는 모두 클라이언트 매니페스트에 있는 기본 소리` |
| AC3 | 통과 | `sfx-library.spec.luau` AC3 + QA `musicFor: 우승 단계는 roundIndex가 없어도 Victory, 결승 건너뛰기(1→3/3)도 Final` |
| AC4 | 통과 | `sfx-library.spec.luau` AC4 — id 있는 효과음 20개, 핵심 6개 모두 |
| AC5 | 통과 | 위 자동 검증 (261/261) |
| AC6 | 사용자 확인 필요 | 체크리스트 1, 4. 코드상 배경음 흐름은 QA `배경음 흐름: 서버 순서…`로 확인 (기본은 무음) |
| AC7 | 사용자 확인 필요 | 체크리스트 2, 3. 통과음은 QA `통과음: 내 Passed만 Qualified…`로 확인. 냠·퐁당·다이브·휙·출발은 m3-03~06이 `Sfx.play`를 불러야 나므로 그 스펙 머지 뒤 확인 |
| AC8 | 사용자 확인 필요 | 체크리스트 5. 3단계 순환과 그룹 볼륨은 QA `음소거 3단계…`로 확인, `ResetOnSpawn = false`는 QA `start: …SoundGui(ResetOnSpawn=false)…` |
| AC9 | 사용자 확인 필요 | 체크리스트 6. 좁은 화면에서 겹칠 위험 있음 (B2) |
| AC10 | 사용자 확인 필요 | 체크리스트 7. 정리 로직은 QA 테스트 5개로 확인 (아래 "Sound 누수") |

요약: 순수 로직 AC1~AC5 통과(5/5), Studio AC6~AC10 사용자 확인 필요(5). 실패한 기준 없음.

## 코드 리뷰

### 바뀐 파일 (스펙 지정 범위 확인)
`git diff --name-only origin/main...origin/m3-08-sound`:
`src/client/Sfx.luau`, `src/shared/SfxLibrary.luau`(새), `tests/sfx-library.spec.luau`(새), `docs/specs/m3-08-sound.md`, `docs/developer/m3-08-sound.md`. 스펙의 "이 스펙이 고치는 파일" 3개 + 개발 메모·작업 기록뿐이다. **공용 파일(`Config`, `Remotes`, `Types`, `maps/init`, `default.project.json`, `SfxCues`) 변경 없음.**

### `Entry.pitch` 추가 결정의 영향
- 스펙 `Entry` 타입의 상위 호환(선택 필드, 없으면 1)이라 m3-08 안에서는 문제없다. 테스트(AC2)가 `0 < pitch ≤ 3`을 확인한다.
- 다른 스펙 중 `SfxLibrary`를 읽는 곳은 m3-09 `MapSfx`뿐인데, m3-09 스펙은 "id·볼륨은 SfxLibrary"라고만 적었다. pitch를 적용하지 않으면 장애물 소리가 의도와 다르게 난다 → B4.

### SfxCues ↔ SfxLibrary
32개 모두 있고 남는 이름 없음 (AC1). id 없음(소리 안 남): 효과음 8개(`VictoryFanfare`, `SpeechPop`, `ChefHand`, `FishClap`, `GrabStart`, `ChopstickWarn`, `HotTileSizzle`, `ChefHandWarn`) + 배경음 4개 — 개발 메모의 "사용자가 고를 목록"과 일치.

### 기본 소리 경로가 실제로 있나
QA가 공개 `MaximumADHD/Roblox-Client-Tracker`의 `rbxManifest.txt`를 직접 받아 `content\sounds\`를 확인했다: 정확히 11개(`action_falling.ogg`, `action_footsteps_plastic.mp3`, `action_get_up.mp3`, `action_jump.mp3`, `action_jump_land.mp3`, `action_swim.mp3`, `impact_explosion_03.mp3`, `impact_water.mp3`, `oof.ogg`, `ouch.ogg`, `volume_slider.ogg`). `SfxLibrary`가 쓰는 11개와 같다. 목록을 QA 테스트에 고정해 두었다 (나중에 없는 경로를 넣으면 실패). 소리가 어울리는지는 들어봐야 안다 (체크리스트 3).

### Sound 누수 · 동시 재생 상한 (`Sfx.luau:73-140`)
- 끝나는 경로 3개(`Ended`, `Destroying`, 10초 `task.delay`)가 모두 같은 `finish`를 부르고 `done` 플래그로 한 번만 개수를 뺀다 → QA `Ended가 안 와도 10초 뒤 지워지고…`, `play BasePart: …파트가 먼저 사라져도…`.
- Vector3 위치용 `Attachment`(`Terrain` 아래)도 `finish`에서 지운다 → QA `play Vector3…`.
- BasePart가 아닌 인스턴스를 넘기면 Sound를 바로 지우고 개수에 넣지 않는다 → QA `play: BasePart가 아닌 인스턴스면…`.
- 같은 cue 0.05초 제한, 16개 상한(넘으면 버림) → QA 2개.
- 배경음: 바뀔 때 이전 곡은 0.5초 페이드 뒤 `Completed`에서 지운다 → QA `setMusic: 바꾸면 이전 곡은…`. 같은 곡이면 아무것도 안 만든다.

### 배경음 흐름과 서버 방송 순서
`RoomService.beginMatch`는 `RoomUpdated`를 `task.defer`로 보내고(`RoomService.luau:94-106, 127-130`), `MatchService`는 바로 `MatchPhase Starting`을 보낼 수 있다. 그래서 클라이언트는 Starting을 InMatch보다 먼저 받을 수 있다. `Sfx`는 `phaseInfo`를 기억해 두므로 InMatch가 오면 바로 `Round`가 된다. 판이 끝나면 `endMatch` → `Waiting`에서 `phaseInfo = nil`이라 다음 판에 지난 결승 정보가 남지 않는다. 방을 나가면 `RoomUpdated(nil)` → `Lobby`. 결승 건너뛰기는 서버가 `roundIndex = roundCount`로 보내서(`MatchService.luau:142-154`) `Final`이 맞게 나온다. 전부 QA `배경음 흐름…` 테스트로 확인.

### 버튼 클릭음 (`Sfx.luau:197-203, 252-256`)
- start 전에 있던 버튼(`GetDescendants`)과 나중에 붙는 버튼(`DescendantAdded`, 자식을 먼저 만든 뒤 화면을 붙여도)이 모두 잡힌다. `TextBox`·`Frame`은 연결하지 않는다 → QA 테스트 2개.
- `init.client.luau`에서 `Sfx`가 `LobbyController.start()` 다음에 시작하므로 로비 버튼은 `GetDescendants`로 잡힌다.
- 부작용: "PlayerGui 아래의 모든 GuiButton"에는 Roblox 기본 모바일 점프 버튼, m3-06/m3-07의 다이브·잡기 버튼도 들어간다 → B1. 버튼을 다시 붙이면 연결이 하나 더 생긴다 → B3.

### 음소거 버튼
`SoundGui`(`ResetOnSpawn = false`, `DisplayOrder = 5`, `IgnoreGuiInset` 기본 false라 기본 메뉴 줄 아래). `MuteButton`은 오른쪽 위 `(1,-16, 0,60)`, 110×28. HUD 타이머(`HudScreen.luau:82-87`, y 16~52) 바로 아래라 PC 화면에서는 겹치지 않는다. 좁은 화면 → B2. 관전 패널은 아래 가운데(`SpectateScreen.luau:34-38`)라 겹치지 않는다.

## 버그

### [P2] B1 모바일 점프·다이브·잡기 버튼을 누를 때마다 "딸깍" 소리가 날 수 있음
- 재현: 휴대폰 에뮬레이터로 F5 → 라운드 중 화면의 점프 버튼을 누른다. (m3-06·m3-07 머지 뒤면 다이브·잡기 버튼도)
- 기대: 클릭음은 메뉴·UI 버튼에만. 조작 버튼은 조용하거나 자기 효과음(`Dive`, `GrabStart`)만.
- 실제(코드상): `hookButton`이 `PlayerGui`의 모든 `GuiButton`에 `ButtonClick`을 붙인다. Roblox 기본 터치 컨트롤(`PlayerGui.TouchGui.TouchControlFrame.JumpButton`, ImageButton), `ContextActionService` 터치 버튼(`PlayerGui.ContextActionGui`), m3-06 `DiveGui`, m3-07 `GrabGui`가 모두 대상이다. 점프할 때마다 딸깍 소리가 겹친다. (`Activated`가 기본 점프 버튼에서 실제로 발생하는지는 Studio 확인 필요 — 체크리스트 8)
- 스펙대로 구현한 것이므로 스펙 빈틈이다. 제안: `TouchGui`·`ContextActionGui` 아래는 건너뛰고, 조작 버튼은 속성(예: `NoClickSfx = true`)으로 빼는 규칙을 기획이 정한다. m3-06/m3-07 버튼이 그 속성을 달면 된다.
- 위치: `src/client/Sfx.luau:197-203, 253-256`

### [P2] B2 좁은 화면(휴대폰 가로)에서 음소거 버튼이 HUD 위 가운데 패널·로비 패널과 겹칠 수 있음
- 재현: 휴대폰 에뮬레이터(예: iPhone SE/7 가로, 폭 약 667px) → 로비 화면, 그리고 라운드 중 HUD.
- 기대: 음소거 버튼이 다른 UI와 겹치지 않는다 (AC9).
- 실제(계산상): 위 가운데 라운드 정보 패널은 420×84(y 16~100, `HudScreen.luau:47-49`), 음소거 버튼은 오른쪽에서 16~126px, y 60~88. 화면 폭이 약 672px보다 좁으면 둘이 가로로 겹친다 (HUD 타이머도 이미 같은 폭에서 위 가운데 패널과 겹친다). 로비 패널은 화면 0.92배 폭(`LobbyScreen.luau:54-63`)이라 좁은 화면에서는 패널 오른쪽 위(제목 줄, "코드로 참가" 버튼 위쪽 끝)를 `DisplayOrder = 5`인 음소거 버튼이 덮는다. PC(폭 1280 이상)에서는 겹치지 않는다.
- 제안: 좁은 화면에서는 아이콘만(🔊/🎵/🔇, 28×28)으로 줄이거나 왼쪽 아래 등 비어 있는 자리로 옮긴다. 체크리스트 6으로 확정.
- 위치: `src/client/Sfx.luau:213-216`

### [P3] B3 버튼을 다시 붙이면 Activated 연결이 하나 더 생김
- 재현: 어떤 UI가 같은 버튼을 `Parent = nil` 뒤 다시 `PlayerGui` 아래로 붙인다.
- 기대: 연결 하나.
- 실제: `DescendantAdded`가 또 불려 연결이 늘어난다. 같은 cue 0.05초 제한 덕에 소리는 하나만 난다 (QA 테스트로 확인). 지금 UI 코드에 재부모하는 곳은 없어 영향은 작다. 고친다면 연결한 버튼을 약한 키 표나 속성으로 기억한다.
- 위치: `src/client/Sfx.luau:197-203`

### [P3] B4 m3-09 서버 장애물 소리에 pitch·음소거가 적용되지 않을 수 있음 (m3-09 인계)
- `SfxLibrary`의 장애물 cue 중 `WasabiBoing`(점프 소리 ×1.7), `SkewerWhoosh`(낙하 ×1.6), `SoySlow`(수영 ×0.8), `TileVanish`(발소리 ×0.7)는 `pitch`가 있어야 의도한 느낌이 난다. m3-09 스펙은 "id·볼륨"만 적었다 → m3-09 `MapSfx`가 `PlaybackSpeed = entry.pitch or 1`(그리고 `pitchJitter`)을 적용해야 한다.
- 서버에서 만든 Sound는 클라이언트가 만든 로컬 `SoundGroup "Sfx"`에 넣을 수 없어서, 음소거 "🔇 모두 끔"이 장애물 소리를 끄지 못한다. m3-09에서 클라이언트가 `DescendantAdded`로 아레나의 Sound를 자기 `Sfx` 그룹에 넣거나, 서버는 위치만 알리고 소리는 클라이언트 `Sfx.play(cue, part)`가 내는 방식을 정해야 한다.
- 위치: `src/shared/SfxLibrary.luau:16, 72-78`, `docs/specs/m3-09-integration-polish.md:19`

### [P3] B5 10초보다 긴 효과음은 잘림
- `SFX_MAX_LIFETIME = 10`이라 사용자가 `VictoryFanfare` 등에 10초보다 긴 소리를 넣으면 10초에서 끊긴다. 지금 기본 소리는 모두 짧다. id를 넣을 때 길이를 알려 주거나, `TimeLength`를 보고 수명을 늘리면 된다.
- 위치: `src/client/Sfx.luau:27, 138`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 해당 없음. 새 리모트 없음, 클라이언트는 서버 이벤트(`RoomUpdated`·`MatchPhase`·`PlayerResult`)를 듣기만 한다.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — `Qualified`는 서버의 `PlayerResult Passed`를 받은 뒤에만 낸다.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음 (맵 수정 없음). `SfxLibrary`는 상수 표와 순수 함수.
- [x] 연결·인스턴스·스레드가 정리된다 — 효과음 Sound·Attachment·이전 배경음은 정리됨(위 "Sound 누수"). 전역 연결(`DescendantAdded`, 리모트 3개)은 접속 동안 한 번만 만들고 `start` 두 번 호출도 막혀 있다 (QA 테스트). 버튼 재부모 때 연결 중복은 B3.

## 사용자 Studio 확인 체크리스트
**사용자 확인 필요** — 모두 Studio에서만 확인할 수 있다.

1. (AC6) 혼자 F5 → 로비에서 "방 만들기", "빠른 참가" 등 버튼을 누른다 → 짧은 "딸깍" 소리가 난다. 방 대기실 버튼, 오른쪽 위 음소거 버튼도 딸깍.
2. (AC7) `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`(커밋 금지)로 한 판 → Race 결승선 통과 순간 "뿅"(`Qualified`, 일어나는 소리를 높게) 소리가 난다. 탈락 때는 m3-03 머지 뒤에 소리 확인.
3. (AC7) 소리 느낌 확인: 지금 쓰는 기본 소리 11개가 cue에 어울리는지 들어본다 (개발 메모 표). 어색한 것은 `src/shared/SfxLibrary.luau`에서 바꿀 cue를 적어 둔다. Output에 `Failed to load sound` 같은 빨간 줄이 없어야 한다.
4. (AC6) 배경음: `SfxLibrary.Entries`의 `Lobby = music(nil, 0.6)`의 `nil`을 Creator Store 무료 음악 `"rbxassetid://<id>"`로 잠깐 바꾸고(4곡 다 넣으면 더 좋음) F5 → 로비 곡 → 매치 시작 시 0.5초 동안 `Round`로 넘어감 → 결승 라운드 소개부터 `Final` → 우승 화면 `Victory` → 로비로 돌아오면 `Lobby`. 곡이 끊기지 않고 부드럽게 바뀌는지.
5. (AC8) 음소거 버튼을 누를 때마다 "🎵 음악 끔"(음악만 꺼짐) → "🔇 모두 끔"(딸깍도 안 남) → "🔊 소리 켬". "음악 끔" 상태에서 캐릭터를 리셋(Esc → Reset)해도 버튼 글자와 상태가 그대로인지.
6. (AC9, B2) PC 창 크기, 그리고 Device Emulator로 휴대폰 가로(예: iPhone 7, iPhone SE, Galaxy 계열 작은 화면) → (a) 로비 화면에서 음소거 버튼이 로비 패널 제목·"코드로 참가" 버튼을 가리는지, (b) 라운드 중 위 가운데 라운드 정보 패널·오른쪽 위 타이머와 겹치는지, (c) 탈락 후 관전 패널과 겹치는지, (d) 로블록스 기본 메뉴 버튼(왼쪽 위·오른쪽 위)과 겹치는지. 겹치면 기기 이름과 스크린샷을 남긴다.
7. (AC10) 한 판을 끝까지 돈 뒤 클라이언트 쪽 Explorer(Test 탭에서 Client 보기) → `SoundService`에는 `Sfx`·`Music` SoundGroup과 (배경음을 넣었다면) 지금 곡 하나만 있고, 다 울린 Sound가 쌓여 있지 않다. `Workspace.Terrain` 아래 `SfxAt` Attachment가 남아 있지 않다. Output의 `warn`은 `[Sfx] unknown …`(모르는 cue)만 나와야 한다.
8. (B1) Device Emulator 휴대폰으로 라운드 중 화면의 기본 점프 버튼을 여러 번 누른다 → 점프할 때마다 "딸깍"이 나는지 기록한다 (나면 B1 확정).

## 추가한 테스트
- `tests/m3-08-qa.spec.luau` (21개) — 클라이언트 `Sfx.luau`를 가짜 Roblox 환경에서 실제로 돌림:
  - SfxLibrary: 기본 소리 경로가 클라이언트 매니페스트 11개 안에 있음, 배경음 기본 무음·m3-08 cue 소리 있음, `musicFor` 경계(우승 단계 roundIndex 없음, 결승 건너뛰기, 매치 밖)
  - start 전 무시, 모르는 cue 이름당 1회 경고, id 없는 cue 조용히 무시
  - start: SoundGroup 볼륨 0.7/0.3, `SoundGui`·`MuteButton`, 두 번 불러도 하나씩
  - play 2D(그룹, RollOff 120, pitch±jitter, 끝나면 지움), Vector3(Attachment 정리), BasePart(파트가 먼저 사라져도 개수 복구), BasePart 아닌 인스턴스
  - 같은 cue 0.05초 제한, 동시 16개 상한, 10초 수명 + 늦은 Ended 이중 감산 없음
  - setMusic 페이드인·같은 곡 무시·이전 곡 페이드 후 삭제·nil이면 끔
  - 서버 방송 순서대로 배경음 Lobby→Round→Final→Victory→Lobby, 다음 판·방 나가기
  - 음소거 3단계 글자·그룹 볼륨
  - 버튼 클릭음: 기존·나중 버튼, TextBox·Frame 제외, 재부모해도 소리 하나
  - 통과음: 내 Passed만
- `tests/lib/FakeSfxEnv.luau` (새 도우미) — 인스턴스·시그널·SoundService·TweenService·Players·Remotes·`task.delay`·`os.clock` 가짜.
- `tests/m3-01-qa.spec.luau` — `Sfx 껍데기` 테스트의 불러오기만 `FakeSfxEnv`로 바꿈 (기대값 그대로, 위 "자동 검증" 참고).

## 인계 메모
- **브랜치**: `m3-08-qa` (`origin/m3-08-sound` + `origin/main` 머지, push함). main은 건드리지 않음.
- **끝난 것**: 검증 4종 통과(261/261), AC1~AC5 통과, 코드 리뷰, QA 테스트 21개 + 하네스, 리포트. 스펙 상태 `qa-passed`.
- **남은 것**: 사용자 Studio 확인(체크리스트 1~8). B1·B2는 기획이 규칙(클릭음 제외 대상, 좁은 화면 배치)을 정하고 개발이 고치면 된다. B4는 m3-09 스펙/개발에 반영.
- **다음에 할 첫 단계**: `m3-08-qa` 브랜치를 main에 머지 (`m3-08-sound`만 머지하면 `m3-01-qa`의 Sfx 테스트가 실패함). 그다음 사용자 체크리스트 6·8로 B1·B2 확정.
- **막힌 점**: 없음. 소리가 어울리는지는 사람이 들어봐야 한다.
