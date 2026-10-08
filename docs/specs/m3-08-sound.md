status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-08 — 사운드 (효과음 재생기 · 배경음 · 음소거)

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §12(M3: 사운드), §7(냠!·퐁당), §8(물고기 박수)
- 참고: `docs/REFERENCE-party-royale.md` §5 (밝고 장난스러운 음악, 짧고 과장된 효과음)
- 담당 개발 worktree: `m3-sound` (Rojo 포트 34878)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작** (`Sfx.luau` 껍데기, `SfxCues`, `init.client.luau`의 `Sfx.start(gui)` 호출)
- **이 스펙이 고치는 파일**: `src/client/Sfx.luau`, 새 파일 `src/shared/SfxLibrary.luau`(cue → 소리 정보 + 배경음 선택 순수 함수), 새 파일 `tests/sfx-library.spec.luau`

## 목표
다른 스펙들이 부르는 `Sfx.play("Chomp")` 같은 호출이 실제로 소리를 낸다. 로비·라운드·결승·우승마다 배경음이 바뀌고, 버튼을 누르면 "딸깍", 통과하면 "뿅" 하고 울린다. 시끄러우면 버튼 하나로 음악이나 소리를 끌 수 있다.

## 범위
- 포함:
  1. **`SfxLibrary` (shared, 순수 데이터 + 함수)** — `SfxCues`의 모든 이름에 대해 항목 하나:
     ```lua
     type Entry = {
         id: string?,          -- "rbxasset://sounds/..." 또는 "rbxassetid://..." (nil이면 소리 없음)
         group: "Sfx" | "Music",
         volume: number,       -- 0~1
         pitchJitter: number?, -- 효과음을 반복해도 덜 지루하게 ±비율 (예: 0.05)
         looped: boolean?,     -- 배경음은 true
     }
     ```
     - m3-09가 서버에서 장애물 소리를 낼 때도 이 표를 읽는다 (그래서 shared).
     - **소리 출처 (기본값)**: 에셋 업로드·저작권 확인 없이 바로 쓸 수 있게, 효과음은 우선 **Roblox 클라이언트에 들어 있는 기본 소리(`rbxasset://sounds/...`)**로 채운다. 개발자는 로컬 Roblox 설치 폴더(`%LOCALAPPDATA%\Roblox\Versions\<버전>\content\sounds`)에 **실제로 있는 파일만** 쓰고, 어떤 cue에 무엇을 썼는지 개발 메모에 표로 남긴다. 어울리는 기본 소리가 없는 cue는 `id = nil`로 두고 개발 메모의 "사용자가 Creator Store에서 고를 목록"에 적는다.
     - **배경음 (`Lobby`, `Round`, `Final`, `Victory`)**: 기본은 `id = nil`(음악 없음). 사용자가 Creator Store의 무료 음악(Roblox 라이선스) id를 넣으면 바로 나온다. 개발자가 공개 자료로 확인한 Roblox 공식 업로드 음악 id가 있으면 넣어도 되지만 "사용자 확인 필요"로 표시한다.
     - `SfxLibrary.musicFor(inMatch: boolean, phase: string?, roundIndex: number?, roundCount: number?) -> string?`: 방 대기실·로비(매치 아님) = `Lobby`, 매치 중 `Starting`·`RoundIntro`·`RoundActive`·`RoundResults` = `Round`(마지막 라운드면 `Final`), `Victory` = `Victory`.
  2. **`Sfx.play(cue, at?)`**:
     - `at`이 BasePart면 그 파트에서, Vector3면 그 위치(로컬 임시 Attachment)에서 3D로, 없으면 2D(`SoundService`)로 낸다. 3D 소리는 `RollOffMaxDistance` 120.
     - 모르는 cue면 cue당 한 번 `warn`, `id`가 nil이면 조용히 무시(경고 없음). 재생이 끝난 Sound는 지운다.
     - 같은 cue는 0.05초 안에 다시 울리지 않는다(24명이 한꺼번에 떨어질 때 소리 폭발 방지). 동시에 울리는 효과음은 최대 16개, 넘으면 새 소리를 버린다.
     - `start` 전에 불려도 에러 없이 무시(m3-01 계약).
  3. **`Sfx.setMusic(name?)`** — 지금 곡과 다르면 0.5초 동안 이전 곡을 줄이며 새 곡을 키운다. nil이면 음악을 끈다. `start`가 `musicFor` 결과로 직접 부르지만, 다른 스펙이 불러도 된다.
  4. **`Sfx.start(gui)`가 하는 일**:
     - `SoundService`에 로컬 `SoundGroup` 두 개: `Sfx`(볼륨 0.7), `Music`(볼륨 0.3) — 배경음은 효과음보다 작게.
     - `RoomUpdated`·`MatchPhase`를 듣고 `musicFor`로 배경음을 바꾼다.
     - **버튼 클릭음**: `PlayerGui` 아래의 모든 `GuiButton`(지금 있는 것 + 나중에 생기는 것)의 `Activated`에 `ButtonClick`을 붙인다 (다른 UI 파일을 고치지 않고).
     - **통과음**: 내 `PlayerResult`가 `Passed`면 `Qualified` (Won은 m3-05 `VictoryFanfare`, Eliminated는 m3-03 `Eliminated`가 냄).
     - **음소거 버튼**: 자기 ScreenGui(`SoundGui`, `ResetOnSpawn = false`)의 오른쪽 위(로블록스 기본 메뉴 줄 아래, HUD와 겹치지 않게)에 작은 버튼. 누를 때마다 "🔊 소리 켬" → "🎵 음악 끔"(Music 0) → "🔇 모두 끔"(Sfx·Music 0) → 처음으로. 이번 접속 동안만 기억한다(저장은 M4 DataStore).
  5. **cue를 누가 부르나** (확인용, 이 스펙은 아래 표의 m3-08 줄만 부른다):
     | 부르는 곳 | cue |
     |---|---|
     | m3-02 캐릭터 | `Knockdown` |
     | m3-03 탈락 연출 | `ChopstickClack`, `Struggle`, `SoyDip`, `Chomp`, `SpeechPop`, `ChefHand`, `MouthFall`, `Eliminated` |
     | m3-04 소개 | `IntroWhoosh`, `Go` |
     | m3-05 우승 연출 | `VictoryFanfare`, `DoorBurst`, `Splash`, `FishClap` |
     | m3-06 다이브 | `Dive`, `DiveLand` |
     | m3-07 잡기 | `GrabStart`, `Grabbed` |
     | **m3-08 (이 스펙)** | `ButtonClick`, `Qualified`, 배경음 `Lobby`·`Round`·`Final`·`Victory` |
     | m3-09 장애물 (서버) | `ChopstickWarn`, `WasabiBoing`, `SoySlow`, `HotTileSizzle`, `TileVanish`, `SkewerWhoosh`, `ChefHandWarn` |
- 제외:
  - 장애물 소리를 맵에 붙이기 (m3-09 — 서버 맵 파일을 고쳐야 해서 통합 단계에서)
  - 음소거 설정 저장 (M4 DataStore), 볼륨 슬라이더
  - 직접 만든 오디오 업로드 (사용자가 에셋을 고르면 `SfxLibrary`의 id만 바꾸면 됨)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/sfx-library.spec.luau`)
- [ ] AC1: `SfxCues`의 모든 이름이 `SfxLibrary`에 있고, `SfxLibrary`에 `SfxCues`에 없는 이름이 없다.
- [ ] AC2: 모든 항목의 `volume`이 0~1, `group`이 `Sfx` 또는 `Music`, 배경음 4개는 `group = "Music"`·`looped = true`, 나머지는 `group = "Sfx"`다. `id`가 있으면 `rbxasset://` 또는 `rbxassetid://`로 시작한다.
- [ ] AC3: `musicFor(false, nil)` = `Lobby`, `musicFor(true, "RoundActive", 1, 3)` = `Round`, `musicFor(true, "RoundIntro", 3, 3)` = `Final`, `musicFor(true, "RoundResults", 4, 4)` = `Final`, `musicFor(true, "Victory", 3, 3)` = `Victory`, `musicFor(true, "Starting")` = `Round`.
- [ ] AC4: `id`가 nil이 아닌 효과음이 **10개 이상**이다 (`Chomp`, `SoyDip`, `Go`, `Qualified`, `Eliminated`, `Dive` 중 최소 4개 포함) — 기본 소리만으로도 M3를 "소리 나는" 상태로 만들기 위함.
- [ ] AC5: `lune run tests` 전체 통과.

### Studio 확인
- [ ] AC6: 혼자 F5 — 로비 버튼(방 만들기 등)을 누르면 "딸깍" 소리가 난다. 배경음 id를 하나라도 넣었다면 로비에서 `Lobby` 곡이 나오고, 매치가 시작되면 `Round`, 결승 라운드에서 `Final`, 우승 때 `Victory`로 부드럽게 바뀐다.
- [ ] AC7: `forceMapPlan`으로 한 판 — Race 통과 때 `Qualified`, 탈락 연출의 냠·퐁당, 다이브, 소개 휙·출발 소리가 (id가 채워진 것은) 들린다. 다른 사람 근처에서 난 소리는 멀어질수록 작게 들린다.
- [ ] AC8: 음소거 버튼을 누를 때마다 "음악 끔" → "모두 끔" → "소리 켬"으로 바뀌고 실제로 소리가 그렇게 바뀐다. 리셋·리스폰해도 설정이 유지된다.
- [ ] AC9: 음소거 버튼이 HUD 타이머·라운드 표시, 관전 버튼, 로블록스 기본 메뉴와 겹치지 않는다 (PC·휴대폰 에뮬레이터).
- [ ] AC10: Output에 소리 관련 빨간 에러가 없고, `warn`은 모르는 cue에 대해서만 나온다. 클라이언트 Explorer `SoundService`·`Workspace`에 다 울린 Sound가 쌓이지 않는다(한 판 뒤 확인).

## 공용 파일 변경
- 없음 (읽기만: `SfxCues`. `Sfx.start` 등록은 m3-01이 `init.client.luau`에서 함)

## 결정 기록
- 2026-10-08 · 소리 출처 · Roblox 클라이언트 기본 소리(`rbxasset://sounds/...`)로 먼저 채우고, 없는 것은 비워 두고 사용자가 Creator Store에서 고름. 이유: 에이전트는 Toolbox를 볼 수 없고 2022년 오디오 비공개 정책 뒤로 남의 오디오 id는 재생되지 않을 수 있음. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 배경음 기본값 없음 · 쓸 수 있는 무료 음악 id를 에이전트가 확인할 수 없어 기본은 무음. 사용자가 4곡(로비/라운드/결승/우승) id를 넣으면 동작. **사용자 할 일**로 m3-plan에 적음 · planner
- 2026-10-08 · 볼륨 · 효과음 0.7, 배경음 0.3(배경음을 작게, 참고 문서 §5). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 음소거 · 3단계 버튼 하나, 저장 안 함(M4). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 버튼 클릭음 · 다른 UI 파일을 고치지 않게 `PlayerGui`의 모든 `GuiButton`에 자동으로 붙임 · planner
- 2026-10-08 · 기본 소리 확인 방법 · 이 개발 PC에는 Roblox가 설치돼 있지 않아 `content\sounds` 폴더를 직접 볼 수 없었음. 대신 공개 Roblox 클라이언트 추적 저장소(MaximumADHD/Roblox-Client-Tracker)의 `rbxManifest.txt`에 실제로 들어 있는 소리 11개만 썼음. 지금 클라이언트에 기본 소리가 11개뿐이라 한 소리를 여러 cue에 나눠 씀. **Studio에서 들어보고 어색하면 id를 바꾸면 됨** · developer
- 2026-10-08 · `Entry`에 `pitch: number?` 추가 · 같은 기본 소리를 cue마다 다른 느낌으로 쓰려고 기본 재생 속도 필드를 더함 (스펙 타입의 상위 호환, 없으면 1) · developer

## 개발 메모
브랜치 `m3-08-sound`.

### 바뀐 파일
- `src/shared/SfxLibrary.luau` (새 파일) — cue → `Entry`(id, group, volume, pitch, pitchJitter, looped), `get(name)`, `musicFor(...)`
- `src/client/Sfx.luau` — 껍데기를 실제 구현으로 (play/setMusic/start, SoundGroup, 배경음 전환, 버튼 클릭음, 통과음, 음소거 버튼)
- `tests/sfx-library.spec.luau` (새 파일) — AC1~AC4 + 모르는 이름

### cue → 기본 소리 표 (`rbxasset://sounds/...`)
| cue | 파일 | pitch |
|---|---|---|
| ButtonClick | volume_slider.ogg | 1.2 |
| IntroWhoosh | action_falling.ogg | 1.4 |
| Go | action_jump.mp3 | 1.3 |
| Qualified | action_get_up.mp3 | 1.4 |
| Eliminated | oof.ogg | 1 |
| ChopstickClack | action_jump_land.mp3 | 1.6 |
| Struggle | ouch.ogg | 1.1 |
| SoyDip | impact_water.mp3 | 1.1 |
| Chomp | action_jump_land.mp3 | 0.7 |
| MouthFall | action_falling.ogg | 0.9 |
| DoorBurst | impact_explosion_03.mp3 | 1.2 |
| Splash | impact_water.mp3 | 0.9 |
| Dive | action_jump.mp3 | 0.85 |
| DiveLand | action_jump_land.mp3 | 1 |
| Grabbed | ouch.ogg | 1.3 |
| Knockdown | action_jump_land.mp3 | 0.6 |
| WasabiBoing | action_jump.mp3 | 1.7 |
| SoySlow | action_swim.mp3 | 0.8 |
| TileVanish | action_footsteps_plastic.mp3 | 0.7 |
| SkewerWhoosh | action_falling.ogg | 1.6 |

### 사용자가 Creator Store에서 고를 목록 (지금 `id = nil`, 소리 없음)
- 효과음: `VictoryFanfare`(우승 팡파르), `SpeechPop`(말풍선 뿅), `ChefHand`(셰프 손), `FishClap`(물고기 박수), `GrabStart`(잡기 시작), `ChopstickWarn`(젓가락 경고), `HotTileSizzle`(철판 지글), `ChefHandWarn`(셰프 손 경고)
- 배경음: `Lobby`, `Round`, `Final`, `Victory` — `SfxLibrary.Entries`의 `music(nil, ...)`에서 nil을 `"rbxassetid://<id>"`로 바꾸면 바로 나옴
- 넣는 곳: `src/shared/SfxLibrary.luau`의 `SfxLibrary.Entries`

### Studio에서 확인하는 방법
1. F5 혼자: 로비의 "방 만들기" 등 버튼을 누르면 딸깍 소리 (AC6). 오른쪽 위 HUD 타이머 아래에 "🔊 소리 켬" 버튼.
2. 음소거 버튼을 누를 때마다 "🎵 음악 끔" → "🔇 모두 끔" → "🔊 소리 켬". 리셋해도 단계 유지 (AC8).
3. `Config.DEBUG.forceMapPlan`으로 한 판: Race 통과 때 Qualified 소리 (AC7). 다른 스펙(m3-03~06)이 머지된 뒤면 냠·퐁당·다이브·휙·출발 소리.
4. 배경음 id를 하나 넣어 보면 로비 → 매치(Round) → 결승(Final) → 우승(Victory)으로 0.5초 페이드 전환 (AC6).
5. 한 판 뒤 클라이언트 Explorer `SoundService`에 `Sfx`·`Music` SoundGroup과 지금 곡 하나만 있고, 다 울린 Sound나 `Workspace.Terrain`의 `SfxAt` Attachment가 쌓이지 않음 (AC10).
6. AC9: 휴대폰 에뮬레이터에서 음소거 버튼(오른쪽 위, y 60)이 HUD 타이머·관전 버튼과 겹치지 않는지.

### 남은 이슈
- 기본 소리는 들어보지 않고 이름으로만 골랐음 — Studio에서 어색한 것은 `SfxLibrary`에서 바꾸면 됨.
- 음소거 단계는 저장 안 함 (M4 DataStore).
