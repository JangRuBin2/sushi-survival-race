# QA — m3-05 우승 연출 ("탈출 성공!")

- 스펙: `docs/specs/m3-05-victory-cutscene.md`
- 검증 커밋: `6bab2fe` (`m3-05-victory`) + `origin/main` 병합 `1e1868a` (m3-02 캐릭터·m3-03 탈락 연출 포함, 충돌 없음)
- 결과: **반려 (P1 1건)** → 스펙 상태 `in-dev`. P2 1건, P3 2건. Studio 확인(AC7~AC12)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | **310 passed, 1 failed** — 실패 1개는 QA가 B1을 재현하려고 추가한 `m3-05-qa.spec.luau > QA B1: …`. 개발 테스트(`victory-cutscene.spec.luau` 13개)와 기존 테스트는 모두 통과 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `victory-cutscene.spec.luau` `AC1` 2개 + QA `beatAt: 박자 경계는 다음 박자 …`, `timeline은 부를 때마다 새 표` |
| AC2 | 통과 | `AC2: timeline(3)은 같은 순서, 모든 시각이 절반` + QA 경계 테스트(3초) |
| AC3 | 통과 | `AC3: beatAt` + QA 경계 테스트(±1e-6) |
| AC4 | 통과 | `AC4: titleText`, `AC4: winnerName은 standings 이름을 먼저 써요` |
| AC5 | 통과 | `AC5` + QA `서버 타이밍: VictoryDuration 10 = 연출 6 + 순위표 4` |
| AC6 | **실패 (QA 회귀 테스트)** | 개발 테스트는 전부 통과. B1 재현 테스트 1개가 실패해 전체가 빨강 — B1을 고치면 통과해야 한다 |
| AC7 | 사용자 확인 필요, **B1로 실패 예상** | 박수 장면에서 인형·물고기가 부두 끝에 가려 보이지 않을 것으로 계산됨 (B1). 나머지(문, 달리기, 다이빙, 글씨, 6초 뒤 로비 카메라, 배너·순위표 4초)는 체크리스트 1 |
| AC8 | 사용자 확인 필요 | 체크리스트 2. 코드상 모든 클라이언트가 `MatchPhase` Victory+winnerUserId로 재생, 글씨는 `standings` 이름 우선 |
| AC9 | 사용자 확인 필요 | 체크리스트 3. 코드상 `HudScreen.luau:305-314` |
| AC10 | 사용자 확인 필요 | 체크리스트 4. 코드상 정리 경로 4개(시간 끝·Starting·RoomUpdated≠InMatch·우승자 없는 Victory) 모두 카메라 release + 글씨 숨김 + Model Destroy |
| AC11 | 사용자 확인 필요 | 체크리스트 5. 인형·이름은 시작 때 정해짐(`VictoryCutsceneController.luau:107-119`) |
| AC12 | 사용자 확인 필요 | 체크리스트 6. 화면 폭 90% + `TextScaled` + `UITextSizeConstraint`(18~84) |

요약: 순수 로직 AC1~AC5 통과(5/5), AC6 실패(QA가 추가한 B1 회귀 테스트), Studio AC7~AC12 사용자 확인 필요(6, 그중 AC7은 B1 때문에 실패 예상).

## 코드 리뷰

### 파일 범위
`git diff 6bab2fe^ 6bab2fe --name-only` = 스펙이 지정한 6개(`VictoryCutsceneController`, 새 `VictoryCutsceneScreen`·`VictoryProps`·`VictoryCutsceneLogic`, `tests/victory-cutscene.spec.luau`, `HudScreen`) + 스펙·개발 기록 문서. 공용 파일(`Config`, `Remotes`, `Types`, `maps/init`, `default.project.json`)과 서버 코드는 바뀌지 않았다.

`HudScreen.luau`는 Victory 분기 밖에서 세 곳을 고쳤다: 맨 위 `Config` require(`:9`), `victoryToken` 선언(`:230-231`), `setVisible(false)`(`:238`)·`setPhase` 첫 줄(`:249`)의 `victoryToken += 1`. **타당하다.** 스펙 범위 6 "그 사이 매치가 끝나거나 새 단계가 오면 띄우지 않는다"를 지키려면 늦게 도는 `task.delay`를 무효화할 토큰이 분기 밖에서 바뀌어야 하고, `root.Visible`만 보면 6초 안에 숨김→다시 표시가 일어날 때 막지 못한다. 기존 분기의 동작은 바뀌지 않았다(토큰은 Victory 지연에만 쓰임). 개발이 스펙 결정 기록에 남겼다.

### 판정이 서버에 있는가
- 연출 3파일은 `MatchPhase`·`RoomUpdated`만 읽고 `FireServer`/`InvokeServer`/`Remotes.fn`이 없다 (QA 정적 테스트). 장면·인형은 클라이언트 로컬 Model.
- 서버는 우승자가 있을 때만 Victory를 보내고 `VictoryDuration`(10초) 기다린 뒤 `sendHome`·`endMatch`(`MatchService.luau:243-254`). 그래서 `HudScreen`의 "우승자 없음 → 바로 띄움" 분기는 지금 서버에서는 오지 않는다(해롭지 않음).

### 타이밍
- 연출 시계(`os.clock` 기준)와 HUD 지연(`task.delay(VictoryCutscene)`)이 둘 다 클라이언트가 Victory를 받은 순간부터라 서로 맞는다. 서버 `VictoryDuration` 10초 = 연출 6 + 순위표 4, 그 뒤 `RoomUpdated`(≠InMatch)로 HUD 숨김·연출 정리. 네트워크 지연만큼만 어긋남(결정 기록대로).

### 카메라 (CameraDirector)
- `VictoryCutscene`(50) > Elimination(40) > Intro(30) > Victory(20) > Spectate(10) (QA 정적 테스트). Victory를 받으면 SpectateController가 Victory(20)로 로비 우승자를 요청하지만 50이 이기고, 연출이 매 프레임 `isActive(OWNER)`일 때만 카메라를 움직인다. SpectateController의 주기 `render()`가 Victory(20)를 다시 요청해도 1등이 아니므로 `update(false)` → 카메라를 건드리지 않는다. release 뒤 Victory(20)의 apply가 `CameraType = Custom` + 우승자 Humanoid로 돌린다. 우승자가 나가 Humanoid가 없으면 기본(내 캐릭터).
- **FOV는 돌려놓지 않는다** (B2).

### 정리
- 세션 하나당 `Cleanup` 하나: 장면 Model(문·부두·바다·물고기·인형·먼지/물보라 조각 모두 그 아래), RenderStepped 연결, 카메라 release + 글씨 숨김. `play()`는 먼저 `stop()`해서 중복 재생이 없다. `VictoryCutscene` ScreenGui는 재사용용으로 남고 `Enabled = false`.
- 정리 경로: 시간 끝(`t >= duration`), 새 `Starting`, `RoomUpdated`(nil 또는 ≠InMatch), 우승자 없는 Victory. 스펙 범위 7과 같다.

### m3-02 SushiBody 연동
- 실제 `SushiBody`의 앞은 -Z(눈·입 offset z < 0), `GROUND_OFFSET = 2.3` = 레이아웃 바닥(-2.3) — 개발이 가정한 "-Z 앞"이 맞다 (QA 테스트). 박수 때 yaw = π라 얼굴이 +Z(카메라 쪽)를 본다.
- `build`는 Body만 Anchored, 나머지는 WeldConstraint. 컨트롤러가 전부 Anchored로 바꾸고 `PivotTo`(PrimaryPart = Body 중심)로 옮기므로 발바닥 = `dollPose.position`. 박수 때 눈 높이는 수면 위(QA 테스트).
- `AppearanceId`는 `AppearanceService`가 캐릭터에 다는 속성(`Attributes.AppearanceId`)을 읽고, 없으면 `Config.Appearance.Default`. `build` 실패 시 기본으로 한 번 더 시도.

### m3-03 탈락 연출과의 전환 (m3-03 QA B1 영향)
- 결승의 마지막 탈락은 같은 틱에 `PlayerResult`(Eliminated) → `Victory` 순서로 온다. 탈락 연출은 Victory를 받으면 `stopAll`로 지워지고(`EliminationCutsceneController.luau:418-423`), Victory 뒤에 오는 탈락 결과는 무시한다. 카메라는 50 > 40이라 충돌 없이 우승 연출로 넘어간다. 결과: 마지막 탈락자는 자기 "먹혔다!" 연출을 못 보고 곧바로 우승 연출을 본다 — m3-03 B1 그대로이며 이 스펙이 새로 만든 문제는 없다. m3-09에서 서버가 Victory를 늦추면 우승 연출·HUD 시각은 Victory 수신 기준이라 그대로 맞는다(단, 늦춘 만큼 `VictoryDuration` 밖에서 시간이 더 든다).

## 버그

### [P1] B1 박수 장면에서 인형과 물고기가 부두 끝에 가려 보이지 않음
- 재현: 결승 우승 → 우승 연출 3.8초 이후(Clap). 순수 계산: `cameraPose(t, 6)`의 눈 = `(0, WaterY + 6, DiveLandZ + 17)` = `(0, 1, -23)`, 부두 판자는 x -4~4, y -1~0, z 0~-30. 카메라가 부두 윗면 1 stud 위에 있고 인형(z -40)은 수면 근처라, 부두 끝(z -30)을 넘어가는 시선은 y ≥ 약 -1.3인 것만 보인다. 인형 꼭대기 y ≈ -2.9, 눈 y ≈ -4.3, 물고기 꼭대기 y ≈ -3.2 → 전부 가려짐.
- 기대: 박수 장면(약 4.1~6.0초)에서 물 위로 고개를 내민 인형과 둘러싼 물고기의 박수가 보인다 (AC7).
- 실제: 카메라가 옮겨 간 뒤(약 4.1초부터 끝까지) 화면에는 부두 판자와 바다 먼 쪽만 보이고 인형·물고기는 부두 끝 뒤에 숨는다. QA 테스트 `QA B1: …`에서 4.1~6.0초 20개 시각 모두 가려짐.
- 위치: `src/shared/VictoryCutsceneLogic.luau:237` (`toEye`), 부두 배치 `src/client/fx/VictoryProps.luau:131`
- 제안: 박수 카메라 눈을 부두 끝 너머(예: z = `DiveLandZ + 9` = -31)로 옮기거나, 부두 폭 밖(x ±8 이상)으로 비키거나, 충분히 높이기. 고친 뒤 `tests/m3-05-qa.spec.luau`의 B1 테스트가 통과해야 한다. (Studio 미확인 — 계산 결과. 사용자 확인 체크리스트 1에서 함께 본다.)

### [P2] B2 우승 연출 뒤 카메라 FOV가 60으로 남음
- 재현: 우승 연출을 한 번 본다 → 대기실로 돌아와 다음 매치·로비에서 카메라를 본다.
- 기대: 연출이 끝나면 카메라가 원래 상태(기본 FOV 70)로 돌아간다 (스펙 범위 7 "카메라를 release").
- 실제: `applyCamera`가 `camera.FieldOfView = 60`을 넣고(`src/client/fx/VictoryCutsceneController.luau:169`), release 경로(CameraDirector 기본 apply, SpectateController apply)는 FOV를 건드리지 않아 세션 내내 60으로 남는다. 시야가 조금 좁아 보인다.
- 위치: `src/client/fx/VictoryCutsceneController.luau:167-171, 209-212`
- 제안: 시작 때 원래 FOV를 저장해 cleanup에서 되돌리기(또는 FOV를 바꾸지 않기).

### [P3] B3 연출 시작 동안 우승자 화면 아래쪽에 "🏆 우승했어요!" 개인 결과가 4초 겹침
- 서버가 Victory 직전에 `Won`을 보내 `HudController`가 개인 결과 글씨(화면 아래, 4초)를 띄운다. 스펙이 늦추라고 한 건 배너·순위표뿐이라 스펙 위반은 아니고, 연출 위에 작은 글씨가 겹치는 정도. 관전 바(SpectateScreen)도 Victory 동안 보일 수 있음 — 체크리스트 3에서 함께 확인.
- 위치: `src/client/ui/HudController.luau:16-17, 52`

### [P3] B4 (관찰) 연출 시작 타이밍은 클라이언트 수신 기준
- 결정 기록대로라 버그는 아님. 지연이 큰 클라이언트는 순위표가 4초보다 짧게 보일 수 있다(서버 10초 뒤 RoomUpdated에 HUD가 숨겨짐).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 새 리모트·서버 변경이 없다 (연출 코드에 서버 호출 없음, 정적 테스트)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 연출은 `MatchPhase`/`RoomUpdated`를 읽기만 한다
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음(맵 변경 없음). 연출 상태는 `play()` 지역 변수·세션 Cleanup에 있다
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 장면 Model·RenderStepped·카메라·글씨. HUD 지연 스레드는 토큰으로 무효화(취소는 안 함, 해롭지 않음)

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`(커밋 금지).

1. (AC7) 혼자 F5 → 방 만들기 → 시작 → 결승에서 우승.
   - 0~0.8초: 가게 문 두 짝이 바깥으로 쾅 열리고 계란초밥 인형이 튀어나오며 먼지 조각이 튄다.
   - 0.8~2.8초: 인형이 통통 튀며 부두를 달리고, 카메라는 옆에서 따라간다.
   - 2.8~3.8초: 부두 끝에서 앞으로 몸을 날려 물에 빠지고 물보라가 튄다.
   - 3.8초~: "탈출 성공! 🏆"이 위쪽에 크게 뜬다. **인형이 물 위로 고개를 내밀고 물고기 5마리가 박수 치는 게 보이는지** 확인 (B1: 부두 끝에 가려 안 보일 것으로 예상 — 보이면 알려주세요).
   - 약 6초 뒤 카메라가 로비의 내 캐릭터로 돌아오고 "🏆 우승!" 배너·순위표가 약 4초 → 대기실.
2. (AC8) Test → Clients and Servers, 3명. 한 명이 우승. 다른 두 화면(하나는 관전 중, 하나는 탈락 후 "로비로"를 누른 상태)에서도 같은 연출과 "{우승자 이름} 탈출 성공!"이 뜨는지.
3. (AC9) 연출 6초 동안 "🏆 우승!" 배너와 순위표가 보이지 않는지, 끝난 뒤에 나오는지. 관전 바나 개인 결과 글씨가 거슬리게 겹치는지도 봐 주세요(B3).
4. (AC10) 대기실로 돌아온 뒤 클라이언트 Explorer → Workspace에 `VictoryCutscene` Model이 없는지, PlayerGui의 `VictoryCutscene` ScreenGui가 `Enabled = false`인지, 카메라가 내 캐릭터를 따라가는지. 연출 전과 비교해 화면이 살짝 확대돼 보이는지(B2: Workspace.CurrentCamera.FieldOfView가 60이면 B2 재현).
5. (AC11) 3명 중 우승자 클라이언트 창을 연출 도중(예: 2초) 닫는다 → 나머지 화면에서 연출이 끝까지 재생되고 인형은 계란초밥, Output에 에러가 없는지.
6. (AC12) Device 에뮬레이터(휴대폰 가로, 예: iPhone SE)에서 "{긴 이름} 탈출 성공!"이 잘리지 않는지.

## 추가한 테스트
`tests/m3-05-qa.spec.luau` (15개, 1개 실패 = B1)
- `beatAt: 박자 경계는 다음 박자, 끝 시각은 마지막 박자 (6초, 3초)`
- `timeline은 부를 때마다 새 표`
- `서버 타이밍: VictoryDuration 10 = 연출 6 + 순위표 4`
- `인형 자세는 박자 경계에서 순간이동하지 않아요` (0.8, 2.8, 입수, 3.8)
- `다이빙 입수 위치는 부두 끝을 지난 바다 위`
- `m3-02 SushiBody: GROUND_OFFSET = 발바닥까지 거리, 앞(눈) = -Z`
- `박수 때 인형 얼굴이 카메라 쪽`
- `박수 때 인형 눈은 수면 위로 나와요`
- `QA B1: 박수 장면에서 카메라 → 인형 머리 시선이 부두에 가리지 않아요` (**실패 — B1**)
- `DoorBurst·Run·Dive 카메라 시선은 부두에 가리지 않아요`
- 정적: 카메라 우선순위, 정리 경로, 서버 호출 없음, 서버 Victory 타이밍, HUD 지연·토큰

## 인계 메모 (2026-10-08 · qa)
- 브랜치: `m3-05-qa` (`origin/m3-05-victory` + `origin/main` 병합, push함). main은 건드리지 않음.
- 끝난 것: 자동 검증 4개, AC1~AC6 확인, 코드 리뷰, QA 테스트 15개, 리포트. 스펙 상태 `in-dev`로 반려.
- 남은 것: 개발이 B1(P1) 수정 — 박수 카메라 위치 조정 후 `tests/m3-05-qa.spec.luau` B1 테스트 통과. B2(P2) FOV 복원 권장. 그 뒤 QA 재검증, Studio 체크리스트 1~6(사용자).
- 다음 첫 단계: developer가 `m3-05-qa`(또는 `m3-05-victory`에 이 브랜치 병합)에서 `VictoryCutsceneLogic.cameraPose`의 Clap `toEye`를 고치고 `lune run tests` 전부 통과 확인.
- 막힌 점: 없음. B1은 Studio 미확인 계산 결과(박스 교차 계산)라 사용자 체크리스트 1에서 눈으로도 확인 필요.
