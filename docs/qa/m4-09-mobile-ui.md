# QA — m4-09 모바일 UI (화면 크기 대응 · 터치 버튼 배치 · 안전 영역)

- 스펙: `docs/specs/m4-09-mobile-ui.md`
- 검증 커밋: `21747af` (브랜치 `m4-09-mobile`) + `origin/main` `aa4cc72`(m4-08 병합) 병합 = `5f0e52c` (충돌 없음)
- QA 브랜치: `m4-09-qa`
- 결과: **반려** (P1 1건) → `in-dev`

## 자동 검증
병합 뒤(`5f0e52c`) + QA 테스트 추가 상태.

| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | **583 passed / 1 failed** — 실패 1개는 QA가 추가한 B1 재현 테스트 (`m4-09-qa.spec` "QA 병합: m4-08 CoinGui가 attach 뒤에도 TopbarSafeInsets를 유지"). QA 테스트 추가 전 병합 상태는 573 passed / 0 failed |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `ui-layout.spec` "AC1 배율…", "AC1 compact…". QA 보강: `m4-09-qa.spec` "QA 배율: 경계값(432 → 0.6, 720 → 1, 900 → 1.25)과 단조 증가", "QA compact: 500/501 경계…" |
| AC2 | 통과 | `ui-layout.spec` "AC2 터치 버튼 3개…" (10개 화면). QA 보강: 짧은 변 320~1200 × 16:9·19.5:9·4:3 전 구간 + 경계 바로 옆에서 화면 안·8px 이상·방향·85%·조이스틱 구역(왼쪽 40%) 밖, 작은 점프 버튼이면 간격 최소 8px, compact 관전 ◀ ▶ 전 구간 |
| AC3 | **실패** | 병합 상태 자체는 4개 모두 통과지만, B1(병합 뒤 m4-08 코인 배지 깨짐)을 재현하는 QA 테스트가 실패 |
| AC4 | 사용자 확인 필요 | 아래 체크리스트 1~5. 단 B1이 고쳐지기 전에는 코인 배지가 모든 기기에서 화면 왼쪽 가운데로 내려와 실패할 것 |
| AC5 | 사용자 확인 필요 (계산상 통과) | 계산: 667×375 → 배율 0.6, 버튼 높이 `touchSize(44)` = 74 가상 × 0.6 = 44.4px. QA 전 구간 테스트 "QA 터치·글씨 최소 크기"로 모든 화면 크기에서 44px 이상 확인 |
| AC6 | 사용자 확인 필요 | 위치 계산은 AC2로 확인. 실제 점프 버튼 기준 배치(`DiveButton.luau:122-142`, `GrabButton.luau:76-91`)는 코드 확인 |
| AC7 | 사용자 확인 필요 (코드상 통과) | `SpectateController.luau:337-343` Q/E만. QA "QA 관전 키: ←/→ 바인딩 없음, Q/E만" |
| AC8 | 사용자 확인 필요 | 1920×1080은 배율 1.25라 M3보다 UI가 25% 큼(스펙 상한대로, 개발 메모에 명시) |
| AC9 | 사용자 확인 필요 | 실제 휴대폰 |

수용 기준 9개: 자동 통과 2 (AC1, AC2), 실패 1 (AC3), 사용자 확인 필요 6 (AC4~AC9).

## 버그
### [P1] B1 병합 뒤 m4-08 코인 배지가 화면 왼쪽 가운데로, 지급 토스트가 화면 아래 밖으로 간다 (모든 기기)
- 재현: `m4-09-qa`(= m4-09 + main 병합)로 Studio Play → 로비 화면을 본다. 매치에서 라운드를 통과해 토스트를 받는다.
- 기대: 스펙 범위 3 "위쪽 바 줄에 들어가는 것(음소거 m3, 코인 배지 m4-08)은 예외(`TopbarSafeInsets`)". 코인 배지는 Roblox 위쪽 바 줄 왼쪽, 토스트는 그 바로 아래.
- 실제: `CoinScreen.new`가 `CoinGui`를 `ScreenInsets = TopbarSafeInsets`로 만든 뒤 `CoinController.start`가 `UiScaleController.attach(screenGui)`를 부르고, m4-09의 `attach`가 무조건 `ScreenInsets = CoreUISafeInsets`로 덮어쓴다. 그러면 `CoinGui`가 위쪽 바 줄이 아니라 화면 전체가 되어:
  - 배지(`AnchorPoint (0, 0.5)`, `Position (0, 4, 0.5, 0)`, 높이 최대 36)가 화면 **왼쪽 가운데**에 떠서 로비 패널·HUD 위에 겹친다.
  - 토스트 목록(`Position (0, 4, 1, 4)`)이 gui 아래 끝 밖에 놓여 **보이지 않는다** (m4-08 AC6·AC8 깨짐).
- 원인: m4-01 껍데기 `attach`는 아무것도 하지 않아 m4-08은 그걸 전제로 짰고, m4-09는 "attach 뒤 m4-08이 TopbarSafeInsets로 되돌리면 된다"고 개발 메모에만 적었다. 두 브랜치가 따로 qa를 통과해 병합에서 처음 만난다.
- 고칠 방향(제안, m4-09 범위 안): `UiScaleController.attach`가 이미 `TopbarSafeInsets`인 gui는 그대로 두게 한다(스펙 범위 3의 예외 규칙을 attach가 지킴). 또는 `CoinController`가 attach 뒤 되돌린다(m4-08 파일이라 이 스펙의 "고치지 않는 파일" — 사용자/코디네이터 승인 필요). QA 테스트는 어느 쪽으로 고쳐도 통과하게 썼다.
- 함께 볼 것(P3, B4): 위쪽 바 gui에 UIScale을 붙이면 휴대폰에서 배지 글씨가 18 × 0.6 = 10.8px.
- 위치: `src/client/ui/UiScaleController.luau:95` (`screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets`), `src/client/ui/CoinController.luau:24-27`, `src/client/ui/CoinScreen.luau:31-37, 78-85`
- 테스트: `tests/m4-09-qa.spec.luau` "QA 병합: m4-08 CoinGui가 attach 뒤에도 TopbarSafeInsets를 유지 (m4-09 QA B1)" (지금 실패)

### [P3] B2 방 만들기 창 최대 높이를 화면(ViewportSize) 기준으로 잡아, 위쪽 바만큼 아래가 잘릴 수 있다
- 재현: iPhone SE 에뮬레이터 → 로비 → 방 만들기 → 창 맨 아래까지 스크롤.
- 기대: 창 전체(마지막 안내 문구 줄 포함)가 LobbyGui 안에 들어온다.
- 실제(계산): compact에서 창은 `Position y = 8`, 높이 `min(content, virtualHeight × 0.9 - 8)`인데 `virtualHeight`는 `ViewportSize.Y / scale`(위쪽 바 포함)이다. LobbyGui는 `CoreUISafeInsets`라 실제 높이가 위쪽 바만큼 작다. 667×375 · 위쪽 바 58px이면 gui 528 가상 vs 창 아래 끝 562 가상 → 약 20px(실제) 잘림. 잘리는 건 아래 여백·안내 문구 줄이라 "만들기" 버튼은 보일 것으로 예상. 위쪽 바 36px 기기면 들어간다.
- 고칠 방향: `virtualHeight`를 `parent.AbsoluteSize.Y / scale`(gui 실제 높이)로.
- 위치: `src/client/ui/LobbyScreen.luau:400-401, 481`

### [P3] B3 큰 화면 기본 점프 버튼 위치가 Roblox 실제 값과 10px 다르다 (스펙 숫자 오기)
- 기대: Roblox `TouchJump`는 큰 화면에서 `UDim2.new(1, -(120 × 1.5 - 10), 1, -120 × 1.75)` = 오른쪽에서 **170**, 아래에서 210 (같은 저장소 `SpectateScreen.luau` 주석도 170).
- 실제: 스펙·`UiLayout.JUMP_LARGE.right = 180`.
- 영향: 거의 없음. 실제 버튼 배치는 실제 점프 버튼 위치를 받아 계산하고, `defaultJump`는 점프 버튼을 못 찾을 때 대비·compact 관전 ◀ ▶(작은 버튼만 씀)에만 쓰인다. 스펙 숫자와 함께 바로잡으면 됨.
- 위치: `src/shared/UiLayout.luau:26`, 스펙 범위 5

### [P3] B4 위쪽 바 gui(CoinGui)에 UIScale이 붙어 휴대폰에서 코인 글씨가 10.8px
- 기대: 스펙 범위 4의 compact 글씨 최소 14px 취지.
- 실제: `CoinController`가 `CoinGui`에도 attach → 배율 0.6에서 `TextSize 18` = 10.8px, 배지 높이 최대 21.6px. 음소거 버튼(`Sfx.luau`)은 attach하지 않아 크기가 그대로라 두 위쪽 바 요소 크기가 다르다.
- 위치: `src/client/ui/CoinController.luau:24-27` (m4-08 파일). B1을 고칠 때 위쪽 바 gui는 attach하지 않거나 배율 하한을 따로 두는 것을 같이 검토.

## 코드 리뷰 (요청 항목)
- **UIScale 뒤 Absolute* → Offset** (병합 상태 기준)
  - `IntroScreen.place` (`IntroScreen.luau:78-92`): `parent.AbsoluteSize`·배너 `AbsolutePosition`(실제 픽셀)로 계산하고 `/ scale`로 넣음 → 맞음. LobbyGui의 UIScale은 LobbyGui 자신의 AbsoluteSize를 바꾸지 않으므로 계산 입력도 맞다. 참고: TextSize 상한 100 때문에 배율 0.6에서 계산값 60px 초과 글씨는 작게 그려짐(넘치지 않는 쪽이라 문제 없음).
  - `SpectateScreen` compact ◀ ▶ (`SpectateScreen.luau:118-134`): 화면 픽셀 → `/ s`, 오른쪽·아래 끝 기준 → 맞음. 기준 크기는 ViewportSize라 iPhone 홈 표시줄 아래 안전 영역만큼 위로 어긋날 수 있음(겹치는 쪽이 아니라 위로 뜨는 쪽) → Studio 확인 항목.
  - `Sfx` 음소거 버튼: 자기 ScreenGui + `TopbarSafeInsets`, attach 안 함 → 영향 없음.
  - `CoinScreen`/`CoinSummaryGui`: Absolute* 사용 없음. 정산 줄(`CoinSummaryGui`)은 원래 기본 insets라 attach 뒤에도 같은 자리, 크기만 배율. **배지·토스트는 B1**.
  - `DiveButton`/`GrabButton`: UIScale 없이 점프 버튼 AbsolutePosition을 자기 gui 기준으로 빼서 씀 → 맞음 (QA 테스트로 attach 안 함 확인).
  - `HudScreen`·`RoomScreen`·`LobbyScreen`: Absolute*를 Offset으로 쓰지 않음. Offset·Scale만.
- **관전 ←/→ 제거와 E 키**: 관전 E(다음 대상)와 다이브 E가 같은 키지만 `DiveController.tryDive`가 `camera.CameraSubject ~= humanoid`면 막아(`DiveController.luau:80-86, 184`) 관전 중 E는 대상만 바꾼다. 관전이 아닐 때는 `SpectateController.cycle`이 `not watching`이면 무시(`SpectateController.luau:232-235`). 충돌 없음.
- **다이브·잡기 위치**: 점프 85% 크기, 간격 `max(8, ceil(점프 × 0.15))`, 가운데 맞춤. QA 전 구간 테스트에서 겹침·화면 밖·조이스틱 구역 침범 없음.
- **스펙 외 파일 수정**: `tests/m3-06-qa.spec.luau` 2줄 → 스펙이 요구한 글씨 "🤸 다이브"와, 간격 상수를 `UiLayout.TOUCH_GAP_RATIO`로 옮긴 데 따른 문자열 검사 갱신. 원래 의도(글씨 존재, 간격 0.15)를 그대로 검사하고 `UiLayout.touchButtons` 사용 검사를 더함 → 타당. 그 밖에 `src/` 수정은 전부 스펙 "이 스펙이 고치는 파일" 안. 공용 파일 수정 없음.
- **M3 UI 회귀**: `intro-layout`·`m3-09-qa`·`victory-cutscene`·`m3-06-qa`·`m3-07-qa` 테스트 통과. `VictoryCutsceneScreen`에서 `IgnoreGuiInset = true`를 빼서 큰 글씨가 위쪽 바 아래 기준 22% 높이로 조금 내려감(의도된 안전 영역 적용).
- **UiScaleController**: attach 두 번·start 재호출에 UIScale 하나, 화면 크기 변경 시 배율·리스너 갱신, 같은 크기 무시, 리스너 해제 → QA 런타임 테스트(가짜 Roblox 환경)로 확인.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 클라이언트 UI만, 새 리모트 없음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 변경 없음
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 화면들이 `onChanged`를 끊지 않지만 화면은 세션 동안 한 번만 만들어져 문제 없음. `UiScaleController.scales`는 gui가 사라지면 다음 화면 크기 변경 때 정리

## 사용자 Studio 확인 체크리스트
준비: B1이 고쳐진 빌드에서. `Config.DEBUG.forceMapPlan`에 맵 3개를 넣으면 혼자 한 판을 빨리 볼 수 있다(커밋 금지). Test 탭 → Device 드롭다운에서 기기 선택 → Play.

1. **iPhone SE** (667×375)
   1. 로비: 패널이 화면 위쪽에 붙고 위쪽 바와 안 겹친다. 왼쪽 위 위쪽 바 줄에 코인 배지(🍚), 오른쪽 위에 음소거 버튼. 방 목록이 손가락(마우스 드래그)으로 스크롤된다. 빠른 참가·방 만들기·참가 버튼 높이가 손가락만 하다(AC5: 스크린샷에서 44px 이상인지 재 보기).
   2. 방 만들기: 방 이름 칸이 맨 위, 인원 버튼 5개가 두 줄(4+1), 창을 맨 아래까지 스크롤해서 "만들기"와 그 아래 안내 줄이 잘리지 않는지 (B2).
   3. 방 이름 칸 탭 → (에뮬레이터에서는 키보드가 안 뜰 수 있음) 칸이 화면 위쪽 절반에 있는지.
   4. 방 대기실: 참가자 목록 스크롤, 시작·나가기 버튼 크기.
   5. 매치 HUD: 위쪽 가운데 한 줄에 [인원] [라운드 n/m · 맵 이름] [남은 시간], 글씨가 읽힌다. 내 결과(통과!/탈락)가 위쪽 오른쪽. "출발!" 글씨가 위쪽 줄과 안 겹친다. 코인 토스트(+10 🍚)가 배지 아래에 보이고 HUD 인원 글씨와 심하게 겹치지 않는지.
   6. 터치 버튼(AC6): 오른쪽 아래 점프, 그 왼쪽 "🤸 다이브", 위쪽 "✊ 잡기". 셋이 안 겹치고, 각각 눌러서 다이브·잡기가 된다. 왼쪽 아래 조이스틱과 안 겹친다. 다이브 뒤 쿨다운 동안 버튼이 어두워진다.
   7. 탈락 → 탈락 도장 글씨가 화면 안. 관전: ◀가 왼쪽 아래, ▶가 오른쪽(잡기 버튼 바로 위), "로비로"·이름 줄이 아래 가운데. ◀ ▶ 눌러 대상이 바뀐다. ◀를 누를 때 조이스틱이 같이 반응하지 않는지.
   8. 우승 순위표: 패널이 화면 안, 정산 줄("이번 판 +…🍚")과 안 겹침.
2. **iPhone 14 Pro Max** (932×430, 노치): 1의 1·5·6·7을 반복. 노치 쪽(왼쪽/오른쪽)에 글씨·버튼이 가리지 않는지. ▶와 잡기 버튼 사이가 홈 표시줄 때문에 어긋나지 않는지.
3. **iPad** (1024×768): compact가 아닌 배치(PC와 같은 모양, 배율 약 1.07). 로비·HUD·관전·순위표 잘림 없음. 터치 버튼은 큰 점프 버튼(120) 기준 85%.
4. **1366×768 PC 창**: 로비 → 한 판. 잘림·겹침 없음.
5. **1920×1080 PC** (AC8): M3와 같은 배치이고 25% 커진 정도. 코인 배지는 위쪽 바 왼쪽, 음소거는 오른쪽.
6. **관전 키** (AC7, PC): 탈락 후 관전 중 ←/→를 눌러 대상이 안 바뀌고 카메라만 기본대로 도는지(우리 코드가 안 받음), Q/E로 대상이 바뀌는지, 관전 중 E를 눌러도 대기석 캐릭터가 다이브하지 않는지.
7. **화면 크기 바꾸기**: Device를 플레이 중에 iPhone SE ↔ 1920×1080으로 바꿔 배치가 바로 바뀌는지.
8. **실제 휴대폰** (AC9): 퍼블리시 후 Android·iOS로 한 판, 불편한 점을 `docs/playtest/`에.

## 추가한 테스트
`tests/m4-09-qa.spec.luau` (11개, 1개는 B1 재현으로 실패)
- QA 배율: 경계값(432 → 0.6, 720 → 1, 900 → 1.25)과 단조 증가
- QA compact: 500/501 경계, 세로 입력, iPad·PC는 compact 아님
- QA 터치·글씨 최소 크기: 짧은 변 320~1200 전 구간
- QA 터치 버튼 3개: 짧은 변 320~1200 전 구간에서 화면 안·8px 이상·방향·조이스틱 구역 밖
- QA 터치 버튼: 점프 버튼이 작으면 간격은 최소 8px
- QA compact 관전 ◀ ▶: compact 전 구간에서 화면 안·터치 버튼과 8px 이상·서로 안 겹침
- QA UiScaleController.attach: 두 번 불러도 UIScale 하나, 배율 = scaleFor (가짜 Roblox 환경에서 실제 모듈 실행)
- QA UiScaleController: 화면 크기가 바뀌면 배율·리스너 갱신, 끊으면 더 안 불림
- QA 병합: m4-08 CoinGui가 attach 뒤에도 TopbarSafeInsets를 유지 (m4-09 QA B1) — **실패 중**
- QA 관전 키: ←/→ 바인딩 없음, Q/E만 (+ 관전 중 다이브 차단 확인)
- QA 터치 버튼 gui에는 UIScale을 붙이지 않음

## 인계 메모
- **지금 브랜치**: `m4-09-qa` (= `origin/m4-09-mobile` 21747af + `origin/main` aa4cc72 병합, 충돌 없음) + QA 커밋. push 완료.
- **끝난 것**: 자동 검증 4개, 수용 기준 코드 리뷰, QA 테스트 11개, 리포트, 스펙 상태 `in-dev`.
- **남은 것**: 개발이 B1 수정(가능하면 B2·B3도) → 재QA(QA 테스트 B1 통과 확인) → 사용자 Studio 체크리스트·AC9.
- **다음에 할 첫 단계**: developer가 `m4-09-qa`(또는 main을 병합한 `m4-09-mobile`)에서 `UiScaleController.attach`가 `TopbarSafeInsets` gui를 덮어쓰지 않게 고치고 `lune run tests`로 `m4-09-qa.spec` 11개 통과 확인.
- **막힌 점**: 없음. B1을 CoinController 쪽에서 고치려면 m4-08 파일이라 사용자/코디네이터 승인 필요.
