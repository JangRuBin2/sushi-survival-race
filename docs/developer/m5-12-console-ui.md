# developer 작업 기록 — m5-12 콘솔(게임패드) UI

## 2026-10-15 (최신) — 구현 끝, in-qa
- **브랜치**: `m5-12-console` (origin/main 3893c8a 기준, push됨). main 병합 안 함.
- **끝난 것**: 스펙 AC1~AC4(순수 로직 + 검증) 구현, 클라이언트 화면 등록(로비·방 만들기·대기실·탈의실·뽑기 3창·상점·코드·관리자·관전), 10피트 여백·채팅 끄기, ⚙·터치 편집 숨김. 결정 D4~D12는 스펙 "결정 기록", 바뀐 파일·Studio 확인 방법은 스펙 "개발 메모".
- **검증**: rojo build, `stylua --check src tests tools`, selene 0/0/0, `lune run tests` 2369 passed 0 failed(새 gamepad-nav 12개), luau-lsp 0.
- **남은 것**: QA, 사용자 Studio 확인 AC5~AC11 (패드 또는 Studio Controller Emulator, 콘솔 Device 에뮬레이터).
- **다음에 할 첫 단계**: QA 리포트(`docs/qa/m5-12-console-ui.md`)가 오면 그 버그부터. 엔진 동작이 예상과 다르면 손댈 곳:
  - 선택 모드에서 B를 Roblox가 먼저 먹어 창이 안 닫히면 → `GamepadNav.onInput`을 `ContextActionService:BindActionAtPriority`(High, ButtonB/L1/R1)로 바꾸기.
  - 스크롤이 튀면 → `GamepadNav.scrollIntoView` 끄기(Roblox 자동 스크롤만 쓰기).
  - `UIPadding`이 ScreenGui 바로 아래에서 안 먹으면 → `UiScaleController.attach`의 TvSafePadding 대신 각 화면 루트 프레임에 여백.
- **막힌 점**: 없음. 질문 없음(세부 판단은 결정 기록에 기본값으로).

### 구조 메모
- `GamepadNav.window/page/anchor`를 **화면 모듈이 만들 때** 부르고, `GamepadNav.start`(init.client 마지막)가 Heartbeat마다 열린 창을 맞춰요(`GamepadNavLogic.reconcile`). 게임패드 모드가 아니면 아무것도 안 해요.
- 창은 "조상까지 보이는가"로 열림을 판단(ScreenGui면 Enabled) — 컨트롤러 코드를 안 바꿔도 돼요.
- 잠금 상태(`navAllowed`)는 GamepadNav가 RoomUpdated·MatchPhase·PlayerResult를 직접 들어요(ShopController와 같은 기준).
