status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-09 — 모바일 UI (화면 크기 대응 · 터치 버튼 배치 · 안전 영역)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §1(PC / 모바일 / 콘솔), §6(모바일: 조이스틱, 점프·다이브·잡기 버튼), §10(UI 목록), §13("모바일 조작이 어려움 → 버튼 3개로 제한")
- 담당 개발 worktree: `m4-mobile` (Rojo 포트 34879)
- 공용 파일 수정 담당: 없음 (가로 고정 `ScreenOrientation`은 m4-01이 넣음)
- 의존: **m4-01 머지 후 시작** (`UiScaleController` 껍데기, `Config.Ui`)
- **이 스펙이 고치는 파일**: `src/client/ui/UiScaleController.luau`, `src/client/ui/LobbyController.luau`, `src/client/ui/LobbyScreen.luau`, `src/client/ui/RoomScreen.luau`, `src/client/ui/RoomUiKit.luau`, `src/client/ui/HudScreen.luau`, `src/client/ui/HudController.luau`, `src/client/ui/SpectateScreen.luau`, `src/client/ui/SpectateController.luau`, `src/client/fx/IntroScreen.luau`, `src/client/fx/EliminationCutsceneScreen.luau`, `src/client/fx/VictoryCutsceneScreen.luau`, `src/client/input/DiveButton.luau`, `src/client/input/GrabButton.luau`, 새 파일 `src/shared/UiLayout.luau`, `tests/ui-layout.spec.luau`
- **고치지 않는 파일**: `src/client/Sfx.luau`(m4-07), `src/client/fx/CharacterFxController.luau`(m4-08), `src/client/ui/CoinController.luau`·`CoinScreen.luau`(m4-08)

## 목표
휴대폰(가로)·태블릿·작은 PC 창에서도 모든 화면이 잘리거나 겹치지 않고, 글씨를 읽을 수 있고, 손가락으로 누르기 쉽다. 달리는 중에는 점프·다이브·잡기 버튼 3개가 엄지 닿는 곳에 모여 있다.

## 범위
- 포함:
  1. **배율** (`UiLayout`, 순수): `scaleFor(width, height) -> number` = `clamp(min(width, height) / Config.Ui.BaseShortSide, MinScale, MaxScale)`. `isCompact(width, height)` = 짧은 변 ≤ `CompactShortSide`(500).
  2. **`UiScaleController`**: `attach(screenGui)`가 그 ScreenGui에 `UIScale`을 하나 붙이고 화면 크기(`workspace.CurrentCamera.ViewportSize`)가 바뀔 때마다 배율을 갱신한다. 같은 gui에 두 번 불러도 하나. `start`에서 이 스펙이 고치는 화면들의 ScreenGui를 붙인다(각 화면 파일이 만들 때 `attach`를 불러도 됨).
  3. **안전 영역**: 모든 게임 ScreenGui의 `ScreenInsets = CoreUISafeInsets`(노치·로블록스 위쪽 바 피함). 위쪽 바 줄에 들어가는 것(음소거 m3, 코인 배지 m4-08)은 예외(`TopbarSafeInsets`).
  4. **화면별 배치** (짧은 변 ≤ 500인 compact 배치 추가, PC 큰 화면은 지금 모양 유지):
     - **로비·방 대기실**: 패널이 화면 높이의 90%를 넘지 않고, 방 목록·참가자 목록은 터치 스크롤(`ScrollingFrame`, `ScrollingDirection = Y`, 스크롤바 두께 8 이상). 버튼(방 만들기·빠른 참가·코드 입력·시작·나가기) 최소 `Config.Ui.MinTouchSize`(44px, 배율 적용 뒤). 방 만들기 창의 인원 선택 버튼 5개가 한 줄에 안 들어가면 두 줄. 코드 입력 TextBox는 탭하면 숫자 키보드가 아니어도 되지만 키보드가 올라와도 입력칸이 보인다(창을 위쪽 절반에 둠).
     - **HUD**: 맵 이름·남은 시간·인원은 위쪽 가운데 한 줄로(compact에서 글씨 최소 14px). 내 순위는 왼쪽 아래가 아니라 위쪽 줄 오른쪽(오른쪽 아래는 터치 버튼 자리).
     - **관전**: ◀ ▶ 버튼을 화면 아래 양쪽 끝(엄지 위치), "로비로"/"내 캐릭터 보기"는 아래 가운데. **←/→ 키 바인딩을 없애고 Q/E만 남긴다** (M2부터 남은 P3 "←/→가 카메라도 같이 돌림" 해소).
     - **라운드 소개·탈락 도장·우승 순위표**: compact에서 글씨가 화면 밖으로 안 나가게 `TextScaled` + 최대 크기 제한, 순위표는 24명이면 스크롤.
  5. **터치 버튼 3개** (`UiLayout.touchButtons(width, height) -> { jump, dive, grab }`, 각각 `{ x, y, size }` 픽셀):
     - Roblox 기본 점프 버튼 위치·크기(짧은 변 ≤ 500: 크기 70, 오른쪽 아래에서 (95, 90); 그 밖: 크기 120, (180, 210))를 기준으로, **다이브는 점프 왼쪽**, **잡기는 점프 위쪽**에 같은 크기의 85%로, 서로·점프와 8px 이상 떨어지게. (지금 m3-06·m3-07 위치 규칙을 순수 함수로 옮기고 화면 크기에 따라 다시 계산)
     - 버튼은 터치 기기(`UserInputService.TouchEnabled`이고 마지막 입력이 터치)일 때만 보인다(지금과 같음). 버튼에 아이콘 글씨(🤸 다이브, ✊ 잡기)와 쿨다운 동안 어두워지는 표시.
  6. **콘솔(게임패드)**: 범위 밖이지만 깨지지 않게 — 로비 버튼들이 `Selectable = true`라 게임패드로 고를 수 있으면 됨(따로 확인하지 않음).
- 제외:
  - 세로 화면 배치 (가로 고정, m4-01)
  - 새 버튼·새 기능 (코인 배지 m4-08, 상점 m4-13·14)
  - 볼륨 슬라이더

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/ui-layout.spec.luau`)
- [ ] AC1: `scaleFor(1920, 1080) = 1.25`(상한), `scaleFor(1280, 720) = 1`, `scaleFor(667, 375) ≈ 0.6`(하한 0.6), `isCompact(667, 375) = true`, `isCompact(1280, 720) = false`.
- [ ] AC2: `touchButtons`가 (667×375), (896×414), (1024×768), (2732×2048)에서 세 버튼이 화면 안에 있고 서로 겹치지 않으며 간격이 8px 이상이고, 다이브는 점프 왼쪽·잡기는 점프 위쪽이다.
- [ ] AC3: 검증 명령 4개 통과 (기존 `intro-layout` 등 UI 순수 테스트 포함).

### Studio 확인 (Test 탭 → Device 에뮬레이터: iPhone SE, iPhone 14 Pro Max, iPad, 1366×768 PC 창)
- [ ] AC4: 기기 4종에서 로비 → 방 만들기 → 방 대기실 → 매치 HUD → 탈락 도장 → 관전 → 우승 순위표 화면이 잘리거나 서로/로블록스 기본 버튼과 겹치지 않는다 (기기마다 스크린샷).
- [ ] AC5: iPhone SE에서 로비·방 버튼을 손가락(마우스 클릭으로 흉내)으로 누르기 충분히 크다(44px 이상, 개발 메모에 측정값).
- [ ] AC6: 휴대폰 에뮬레이터에서 점프·다이브·잡기 버튼이 오른쪽 아래에 모여 있고 서로 겹치지 않으며, 각각 눌러서 동작한다. 조이스틱(왼쪽 아래)과 겹치지 않는다.
- [ ] AC7: 관전 중 ←/→ 키가 아무것도 안 하고(카메라가 같이 돌지 않음), Q/E와 화면 ◀ ▶로 대상이 바뀐다.
- [ ] AC8: PC 1920×1080 큰 화면은 M3와 거의 같은 모습이다(회귀).
- [ ] AC9: 실제 휴대폰으로 한 판 (사용자, 퍼블리시 후 휴대폰 Roblox 앱) — 조작·글씨에 불편한 점을 알려 줌.

## 공용 파일 변경
- 없음

## 사용자 작업
- AC9 실제 휴대폰 테스트 (Android·iOS 각 1대면 좋음). 불편한 점을 `docs/playtest/`에 적기.

## 결정 기록
- 2026-10-08 · 배율 방식 · 짧은 변 720px 기준 UIScale 0.6~1.25. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 관전 ←/→ 바인딩 제거, Q/E + 화면 버튼만 · M2 P3 해소 · planner
- 2026-10-08 · 콘솔 UI 확인은 M5 · GDD 13은 모바일만 요구 · **기본값으로 진행, 사용자 수정 가능** · planner

- 2026-10-08 · compact 관전 ◀ ▶ 높이 · "아래 양쪽 끝"을 그대로 두면 ▶가 점프 버튼과 겹쳐서, 양 끝이되 오른쪽 터치 버튼 묶음(잡기 버튼) 바로 위 높이(`UiLayout.spectateArrows`)로 둠 · **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · 터치 버튼(DiveGui·GrabGui)에는 UIScale을 붙이지 않음 · 실제 점프 버튼 픽셀 위치에 맞춰야 해서. 위치는 실제 점프 버튼을 기준으로 `UiLayout.touchButtons(w, h, jump)`가 계산(점프 버튼을 못 찾으면 버튼을 숨기는 기존 동작 유지) · developer
- 2026-10-08 · 잡기 버튼 쿨다운 표시 · 잡기에는 쿨다운 값이 없고 GrabController(이 스펙 밖)가 버튼에 넘기지도 않아서, 지금처럼 잡는 동안 색이 바뀌는 표시만 둠 · 질문: 잡기 쿨다운이 생기면 GrabController 담당이 `setCooldown`을 요청 · developer
- 2026-10-08 · 음소거 버튼(Sfx.luau, m4-07)은 이 스펙에서 손대지 않음 · 이미 자기 ScreenGui + `TopbarSafeInsets`라 예외 규칙과 맞음 · developer
- 2026-10-08 · `tests/m3-06-qa.spec.luau` 글자 검사 갱신 · DiveButton 글씨가 "🤸 다이브", 간격 상수가 `UiLayout.TOUCH_GAP_RATIO`로 옮겨져서 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 브랜치 `m4-09-mobile`. 새 파일 `src/shared/UiLayout.luau`(순수: scaleFor, isCompact, metrics, px/touchSize/textSize/lineHeight/scrollBarThickness, gridRows, defaultJump, touchButtons, spectateArrows), `tests/ui-layout.spec.luau`(9개, AC1·AC2).
- `UiScaleController`: `attach(gui)`(UIScale 하나 + `ScreenInsets = CoreUISafeInsets`, 두 번 불러도 하나), `metrics()`, `onChanged(fn)`. LobbyController가 LobbyGui를 만들 때 붙이고(`start`도 같은 gui를 다시 붙임, 무해), VictoryCutsceneScreen이 자기 gui를 붙임.
  - **다른 스펙 주의**: LobbyGui 안의 Offset은 이제 × scale로 그려져요. AbsolutePosition/AbsoluteSize(실제 픽셀)를 Offset에 넣으려면 `UiScaleController.metrics().scale`로 나눠야 해요(IntroScreen 참고). m4-08 CoinGui는 `attach` 뒤 `ScreenInsets = TopbarSafeInsets`로 바꾸면 돼요.
- 화면별: LobbyScreen·RoomScreen(버튼 높이 `touchSize`, compact면 패널을 위쪽 3%에 0.9 높이, 방 만들기 창은 ScrollingFrame + compact에서 위쪽·방 이름 칸 먼저, 인원 버튼은 UIGridLayout으로 모자라면 두 줄), HudScreen(compact 한 줄 배치, 내 결과는 위쪽 오른쪽), SpectateScreen(compact ◀ ▶ 양 끝), SpectateController(←/→ 제거), IntroScreen(실제 픽셀 → UIScale 좌표), VictoryCutsceneScreen(배율·안전 영역, `IgnoreGuiInset` 제거), DiveButton·GrabButton(85% 크기, 🤸/✊ 글씨). EliminationCutsceneScreen은 이미 TextScaled + 최대 크기라 그대로.
- 측정값(계산): iPhone SE 667×375 → scale 0.6, 로비·방 버튼 높이 74(가상) × 0.6 = 44.4px, 글씨 최소 24 × 0.6 = 14.4px, 스크롤바 14 × 0.6 = 8.4px. 1920×1080 → scale 1.25(버튼 55px).
- Studio 확인: Test 탭 → Device에서 iPhone SE / iPhone 14 Pro Max / iPad / 1366×768 고르고 Play. `Config.DEBUG.forceMapPlan`으로 한 판을 빨리 돌려 로비 → 방 만들기 → 대기실 → HUD → 탈락 도장 → 관전 → 우승 순위표를 기기마다 확인(AC4). 휴대폰 에뮬레이터에서 점프 왼쪽 다이브·위쪽 잡기(AC6), 관전 중 ←/→ 무반응·Q/E 전환(AC7), PC 1920×1080 회귀(AC8).
- 남은 이슈: UIScale을 ScreenGui 바로 아래에 둬서 전체를 키우는 방식이 실제 기기에서 예상대로(스케일 기반 크기 유지)인지 Studio 확인 필요. 관전 E 키는 다이브 키(E)와 같음(기존과 같음, 관전 중엔 캐릭터가 대기석). 1920×1080에서는 배율 1.25라 M3보다 UI가 25% 커요(스펙 상한대로).
