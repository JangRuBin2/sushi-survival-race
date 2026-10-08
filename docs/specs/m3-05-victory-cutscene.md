status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-05 — 우승 연출 ("탈출 성공!")

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §8(가게 문을 박차고 부두에서 바다로 다이빙 → 물고기 박수), §4-5(결승 → 우승 연출 → 같은 방 대기실), §10(결과: 우승자 + 전체 순위표)
- 참고: `docs/REFERENCE-party-royale.md` §3 (Fall Guys 우승 왕관, 크고 두꺼운 결과 글씨)
- 담당 개발 worktree: `m3-victory` (Rojo 포트 34875)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작**. 인형은 `SushiBody.build` — m3-02 전에는 회색 박스, m3-02 머지 뒤 자동으로 계란초밥.
- **이 스펙이 고치는 파일**: `src/client/fx/VictoryCutsceneController.luau`, 새 파일 `src/client/fx/VictoryCutsceneScreen.luau`(큰 글씨), 새 파일 `src/client/fx/VictoryProps.luau`(가게 문·부두·바다·물고기 회색 박스), 새 파일 `src/shared/VictoryCutsceneLogic.luau`(순수), 새 파일 `tests/victory-cutscene.spec.luau`, `src/client/ui/HudScreen.luau`(Victory 분기에서 배너·순위표를 연출 뒤에 띄우기, **이 분기만**)

## 목표
결승이 끝나면 방의 모든 사람이 6초 동안 같은 장면을 본다: 우승한 초밥이 가게 문을 박차고 뛰어나와 부두를 달려 바다로 "풍덩" 다이빙하고, 물고기들이 물 위로 고개를 내밀어 박수를 친다. 이어서 지금(M2)처럼 우승자 이름과 전체 순위표가 4초 동안 나온다.

## 범위
- 포함:
  1. **언제·누가 보나** — `MatchPhase` = `Victory`(그리고 `winnerUserId`가 있음)를 받으면 방의 **모든 클라이언트**(달리던 사람·관전자·"로비로" 누른 사람·우승자 본인 모두)가 재생한다. 우승자 없이 매치가 끝나면(생존자 0명, M2 규칙) 재생하지 않는다.
  2. **장면은 클라이언트 로컬** — 각 클라이언트가 `VictoryCutsceneLogic.SCENE_ORIGIN`(로비·아레나 슬롯과 겹치지 않는 먼 곳, 기본 `(0, 1500, -4000)` — 숫자 표)에 회색 박스 장면을 만들고 끝나면 지운다. 서버는 아무것도 바꾸지 않는다. 여러 방이 동시에 끝나도 각자 로컬이라 겹치지 않는다.
     - `VictoryProps`: 초밥집 벽 + 문 2짝(가운데에서 바깥으로 열림) + 간판 "스시집", 문 앞에서 앞으로 뻗은 나무 부두(약 30 studs), 부두 끝 아래 파란 바다 판, 물고기 4~6마리(주황·파랑 박스 몸 + 꼬리 + 지느러미 "손").
     - 우승자 인형 = `SushiBody.build(우승자 캐릭터의 AppearanceId, 없으면 Config.Appearance.Default)`.
  3. **타임라인** — 순수 함수 `VictoryCutsceneLogic.timeline(duration)`이 박자 목록을 돌려준다. 기본 `duration = Config.Match.VictoryCutscene`(6초), 시간은 duration에 비례해 늘거나 준다:
     | 박자 | 시각(6초 기준) | 화면 | 소리 (`SfxCues`) |
     |---|---|---|---|
     | `DoorBurst` | 0.0~0.8 | 문이 쾅 열리며 인형이 튀어나옴, 먼지 조각 | `VictoryFanfare`(시작), `DoorBurst` |
     | `Run` | 0.8~2.8 | 인형이 통통 튀며 부두를 달림, 카메라는 옆에서 따라감 | — |
     | `Dive` | 2.8~3.8 | 부두 끝에서 점프해 앞으로 몸을 날려 물에 빠짐, 물보라 | `Splash`(입수 순간) |
     | `Clap` | 3.8~6.0 | 인형이 물 위로 고개를 내밀고, 물고기들이 둘러싸 지느러미로 박수(위아래로 흔들림) | `FishClap` |
     `VictoryCutsceneLogic.beatAt(timeline, t)`는 t초에 해당하는 박자 이름을, 범위 밖이면 nil을 돌려준다.
  4. **카메라** — `CameraDirector.request("VictoryCutscene", Priority.VictoryCutscene, …)`(Scriptable)로 duration 동안 잡고 끝나면 release. release 뒤에는 m3-01의 `SpectateController`가 지금처럼 로비의 우승자 캐릭터를 비춘다(우선순위 `Victory`).
  5. **큰 글씨** — `Clap` 박자 시작에 화면 가운데 위쪽에 크게 **"{우승자 이름} 탈출 성공!"**(우승자 본인 화면에는 **"탈출 성공! 🏆"**). 이름은 `standings`에 저장된 이름을 먼저 쓴다(우승자가 이미 나갔어도 이름이 나옴, M2 HUD와 같은 방식).
  6. **HUD 순서 바꾸기 (`HudScreen.luau` Victory 분기)** — 지금은 Victory를 받자마자 "🏆 우승!" 배너와 순위표를 띄운다. 연출을 재생할 때는 **연출이 끝난 뒤(`Config.Match.VictoryCutscene`초 뒤)** 배너와 순위표를 띄운다. 그 사이 매치가 끝나거나 새 단계가 오면 띄우지 않는다. 우승자가 없어 연출이 없으면 지금처럼 바로 띄운다.
  7. **정리** — duration이 끝나거나, 그 전에 `RoomUpdated`로 방이 대기실로 돌아가거나(state ≠ InMatch / nil) 새 `Starting`이 오면 장면·글씨를 모두 지우고 카메라를 release한다.
- 제외:
  - 로비 단상에 우승자 초밥 전시, 우승 횟수 칭호 (GDD 8) — 저장(DataStore)과 로비 아트가 필요해 **M4**
  - 우승 연출 팩(상점) — 스킨·상점은 마지막
  - 서버 변경 (`VictoryDuration` 10초는 m3-01이 바꿈)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/victory-cutscene.spec.luau`)
- [ ] AC1: `timeline(6)`의 박자가 `DoorBurst`, `Run`, `Dive`, `Clap` 순서이고, 각 박자의 끝 = 다음 박자의 시작, 첫 시작 = 0, 마지막 끝 = 6이다.
- [ ] AC2: `timeline(3)`은 같은 순서이고 모든 시각이 `timeline(6)`의 절반이다.
- [ ] AC3: `beatAt(timeline(6), 0)` = `DoorBurst`, `beatAt(…, 3.0)` = `Dive`, `beatAt(…, 5.99)` = `Clap`, `beatAt(…, -0.1)`·`beatAt(…, 6.1)` = nil.
- [ ] AC4: `titleText("민수", false)` = `"민수 탈출 성공!"`, `titleText("민수", true)` = `"탈출 성공! 🏆"`.
- [ ] AC5: `Config.Match.VictoryCutscene < Config.Match.VictoryDuration`이고, `SfxCues`에 `VictoryFanfare`, `DoorBurst`, `Splash`, `FishClap`이 있다.
- [ ] AC6: `lune run tests` 전체 통과.

### Studio 확인
- [ ] AC7: 혼자 F5, `forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }` — 결승에서 우승하면 문이 열리며 내 초밥이 뛰어나와 부두를 달리고 바다에 빠진 뒤 물고기들이 박수를 치고 "탈출 성공! 🏆"이 뜬다. 약 6초 뒤 카메라가 로비의 내 캐릭터로 돌아오고 "🏆 우승!" 배너와 순위표가 약 4초 보인 뒤 대기실로 돌아간다.
- [ ] AC8: Clients and Servers 3명 — 우승자가 아닌 두 사람(관전 중이든 "로비로"를 눌렀든)도 같은 연출을 보고 "{우승자 이름} 탈출 성공!"이 뜬다.
- [ ] AC9: 연출 중에는 순위표·배너가 보이지 않고, 연출이 끝난 뒤에 나온다.
- [ ] AC10: 대기실로 돌아온 뒤 클라이언트 Explorer의 Workspace에 문·부두·물고기·인형이 남지 않는다. 카메라가 내 캐릭터를 따라간다.
- [ ] AC11: 우승 연출 도중 우승자가 게임을 나가도 다른 사람 화면의 연출이 끝까지 재생되고(인형은 기본 계란초밥), 에러가 없다.
- [ ] AC12: 휴대폰 에뮬레이터에서 "탈출 성공!" 글씨가 잘리지 않는다.

## 공용 파일 변경
- 없음 (읽기만: `Config.Match.VictoryCutscene/VictoryDuration`, `Config.Appearance.Default`, `Attributes.AppearanceId`, `CameraDirector`, `SfxCues`, `SushiBody`)

## 결정 기록
- 2026-10-08 · 장면 위치 · 서버를 바꾸지 않게 클라이언트마다 먼 곳에 로컬 장면을 지음(`SCENE_ORIGIN`). 결승 맵 위에서 하지 않는 이유: 결승 맵은 라운드가 끝나면 서버가 바로 지움. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 누가 보나 · 방의 모든 사람이 같은 연출을 봄(우승을 함께 축하, GDD 4-5). 참고: `docs/REFERENCE-party-royale.md` §3. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 길이 · 연출 6초 + 순위표 4초 = `VictoryDuration` 10초(m3-01). 박자 배분은 위 표. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 글씨 · 다른 사람 "{이름} 탈출 성공!", 본인 "탈출 성공! 🏆". **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 단상 전시·칭호 · DataStore가 필요해 M4로 미룸 · planner
- 2026-10-08 · `HudScreen.luau` 수정 · m3-03은 `HudController.luau`만, 이 스펙은 `HudScreen.luau`의 Victory 분기만 고쳐서 병렬 중 같은 파일을 건드리지 않음 · planner
- 2026-10-08 · `HudScreen.luau` 범위 · Victory 분기 말고도 두 줄을 더 고침: 맨 위 `Config` require, `setPhase`·`setVisible(false)` 첫 줄의 `victoryToken += 1`(연출 중 단계가 바뀌거나 대기실로 돌아가면 늦게 뜨는 배너를 막는 용도). 그 밖의 분기는 그대로 · developer
- 2026-10-08 · 시작 시각 · 연출 시계는 각 클라이언트가 `Victory`를 받은 순간부터 잼(서버 시각 동기 안 함). HUD 배너도 같은 순간부터 `VictoryCutscene`초 뒤라서 서로 맞음. 네트워크 지연만큼 사람마다 조금 어긋날 수 있음 · developer
- 2026-10-08 · QA B3(우승자 화면 아래 "🏆 우승했어요!" 개인 결과가 연출 시작 4초 동안 겹침) · 고칠 곳이 `HudController.luau`(m3-03 담당 파일)라 이 스펙에서 손대지 않음. **m3-09로 넘김** (예: 내 결과가 `Won`이면 개인 결과 글씨를 띄우지 않기, 또는 Victory 동안 숨기기) · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 · developer · 브랜치 `m3-05-victory`
**바뀐 파일**
- 새 `src/shared/VictoryCutsceneLogic.luau` — 순수: `SCENE_ORIGIN`, `Layout`, `timeline`, `beatAt`, `cues`, `splashTime`, `titleText`, `winnerName`, `doorOpen`, `dollPose`, `fishRing`, `fishState`, `cameraPose` (6초 기준 시각을 duration에 비례, 좌표는 숫자 표)
- 새 `src/client/fx/VictoryProps.luau` — 회색 박스 장면: 벽·문 2짝(경첩 바깥 모서리, 앞으로 100도 열림)·처마·간판 "스시집"(SurfaceGui)·판자 부두 30·기둥·바다 판·땅·물고기 5마리(주황/파랑 몸, 꼬리, 지느러미 손, 눈). `setDoorsOpen`, `poseFish`
- 새 `src/client/fx/VictoryCutsceneScreen.luau` — 자기 ScreenGui(DisplayOrder 50), 화면 폭 90% + TextScaled(최대 84) + 외곽선, 쾅 커지는 등장
- `src/client/fx/VictoryCutsceneController.luau` — 껍데기를 채움. Victory+우승자 → 로컬 장면·인형(`SushiBody.build(우승자 AppearanceId 또는 Config.Appearance.Default)`, 모든 파츠 Anchored, 높이 `SushiBody.GROUND_OFFSET or 2.3`) → RenderStepped로 문/인형/물고기/카메라/먼지·물보라 조각 갱신, 효과음 `VictoryFanfare`·`DoorBurst`(0초), `Splash`(입수 3.45초), `FishClap`(3.8초), Clap 시작에 큰 글씨. 카메라 `CameraDirector` "VictoryCutscene"(50), 매 프레임 `isActive`일 때만 움직임. 끝/Starting/RoomUpdated(≠InMatch)/우승자 없는 Victory에 정리(카메라 release, 글씨 숨김, 장면 Destroy)
- `src/client/ui/HudScreen.luau` — Victory 분기: 우승자가 있으면 배너·순위표를 `Config.Match.VictoryCutscene`초 뒤에(그 사이 단계 변경·HUD 숨김이면 안 띄움), 없으면 바로
- 새 `tests/victory-cutscene.spec.luau` — 13개 (AC1~AC5 + 효과음 순서, 인형·카메라·물고기·장면 위치)

**Studio 확인 방법** (AC7~AC12, 사용자 확인 필요)
1. `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`로 바꾸고(커밋 금지) 혼자 F5 → 결승까지 가서 우승. 문이 열리고 인형이 튀어나와 부두를 달려 바다로 다이빙 → 물고기 박수 + "탈출 성공! 🏆". 약 6초 뒤 카메라가 로비의 내 캐릭터로, "🏆 우승!" 배너·순위표 약 4초 → 대기실.
2. Test → Clients and Servers 3명: 우승자가 아닌 두 화면에 "{우승자 이름} 탈출 성공!".
3. 연출 동안 배너·순위표가 안 보이는지.
4. 대기실로 돌아온 뒤 클라이언트 Explorer Workspace에 `VictoryCutscene` Model이 없는지, PlayerGui `VictoryCutscene` ScreenGui가 꺼져 있는지(Enabled=false, 재사용용으로 남음), 카메라가 내 캐릭터를 따라가는지.
5. 연출 중 우승자 클라이언트를 닫아도 다른 화면이 끝까지 재생되는지(인형은 시작 때 이미 만들어짐).
6. Device 에뮬레이터(휴대폰 가로)에서 글씨가 잘리지 않는지.

**남은 이슈**
- m3-02 머지 전에는 인형이 회색 박스 1개. 머지 뒤 계란초밥으로 바뀌는데, 인형의 앞이 -Z(LookVector)라고 가정함 — 반대면 박수 때 등을 보임(m3-09에서 yaw만 뒤집으면 됨).
- 소리는 m3-08 전에는 안 남(Sfx 껍데기).
- 연출 시계는 클라이언트 수신 시각 기준 (결정 기록).

### 2026-10-08 · developer · QA 반려 수정 (`docs/qa/m3-05-victory-cutscene.md`)
- B1 [P1]: `VictoryCutsceneLogic.cameraPose` 박수 장면 카메라 눈을 부두 위(z -23)에서 부두 끝 너머 물 위 `(0, WaterY + 6, DiveLandZ + 9)` = `(0, 1, -31)`로 옮김. 옆 카메라(18, 2, -38)에서 옮겨 가는 동안에도 내내 z < -30이라 부두가 시선을 가리지 않음. QA B1 테스트 통과.
- B2 [P2]: `VictoryCutsceneController` — 카메라를 처음 잡을 때 원래 FieldOfView를 저장하고, 정리(release) 때 되돌림.
- B3 [P3]: 범위 밖(`HudController.luau`) → 결정 기록에 m3-09로 넘김.
- Studio에서 볼 것: 박수 장면(3.8초~)에 인형 머리와 물고기 5마리가 부두 끝에 가리지 않고 보이는지, 연출 뒤 시야(FOV)가 원래대로(기본 70)인지.
