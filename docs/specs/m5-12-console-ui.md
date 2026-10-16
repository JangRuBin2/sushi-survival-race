status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-12 — 콘솔(게임패드) UI: 방향키로 모든 창 다루기

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §1(플랫폼 PC·모바일·콘솔 — "콘솔 UI 확인은 M5"), §6(게임패드 조작표), §10(UI 목록 — "콘솔 UI는 M5")
- 레퍼런스: [`docs/REFERENCE-console-ui.md`](../REFERENCE-console-ui.md) (Roblox 콘솔 가이드라인 원문)
- 담당 개발 worktree: **main (순차, 단계 2 — 마지막)**. UI 화면을 거의 다 건드려서 단계 1(m5-07 탈의실, m5-08 상점, m5-10 코드, m5-11 관리자 패널)이 **전부 머지된 뒤** 시작.
- 공용 파일 수정 담당: **이 스펙** (단계 2라 병렬 없음) — 필요하면 `src/client/init.client.luau`(새 컨트롤러 등록)만
- **범위가 크면 뒤로 미룰 수 있음**: 사용자가 콘솔 출시를 당장 안 하면 이 스펙은 `ready`로 두고 M5 다음 묶음으로 넘겨도 됨(결정 기록 D1). 콘솔을 끈 채 출시해도 다른 스펙은 막히지 않음.
- **이 스펙이 고치는 파일**: 새 `src/client/ui/GamepadNav.luau`(공통 도우미), 새 `src/shared/GamepadNavLogic.luau`(순수), `src/client/ui/LobbyScreen.luau`·`LobbyController.luau`, `RoomScreen.luau`, `ShopScreen.luau`·`ShopController.luau`, `OfferScreen.luau`·`OfferController.luau`, `CodeScreen.luau`·`CodeController.luau`, `SpectateScreen.luau`·`SpectateController.luau`, `HudScreen.luau`(버튼 힌트만), `AdminPanel.luau`, `RoomUiKit.luau`(선택 테두리 스타일), `UiScaleController.luau`(10피트 안전 여백), `src/client/ui/ChatTagController.luau`(10피트에서 채팅 창 끄기), (필요하면) `src/client/init.client.luau`, 테스트 `tests/gamepad-nav.spec.luau`(새)

## 목표
Xbox·PlayStation 패드(또는 PC에 꽂은 패드)만으로 로비에서 방 만들기·참가, 탈의실·상점·코드 창, 관전, 관리자 패널까지 **방향키 + A(선택) + B(뒤로)**로 다룰 수 있다. TV 화면 가장자리에 UI가 잘리지 않는다.

## 규칙 (기본값, 사용자 수정 가능)
### 언제 콘솔 모드인가
- **마지막 입력이 게임패드**(`UserInputService.LastInputType`이 `Gamepad1~8`)면 게임패드 내비게이션을 켜고, 마우스·터치·키보드를 쓰면 지금 그대로(선택 테두리·패드 힌트 숨김). PC에 패드를 꽂아도 같음.
- **10피트 화면**(`GuiService:IsTenFootInterface()`, 콘솔 기기)에서만 추가로: TV 안전 여백 화면 각 변 5%(지금 안전 영역은 ScreenGui `ScreenInsets`로 Roblox가 처리 — 그 위에 `UiScaleController.attach`가 10피트일 때 각 ScreenGui에 `UIPadding` 5%를 더함), 채팅 창 끄기(`TextChatService.ChatWindowConfiguration.Enabled = false` — Roblox 콘솔 가이드라인).
- 순수 판단 `GamepadNavLogic.isGamepadInput(inputTypeName)`, `GamepadNavLogic.insetsFor(tenFoot, width, height)`.

### 공통 동작 (`GamepadNav` 도우미)
- 창이 열리면(게임패드 모드일 때) **첫 버튼을 자동 선택**(`GuiService.SelectedObject`). 창이 닫히면 그 창을 연 버튼으로 선택을 돌려놓음(없으면 선택 해제).
- **B(`ButtonB`) = 닫기/뒤로**: 맨 위에 열린 창 하나만 닫음(탈의실·상점·코드·관리자 패널·방 만들기 창). 로비 첫 화면에서는 아무 일 없음.
- 선택된 버튼은 굵은 흰 테두리(`RoomUiKit` 공통 스타일, `SelectionImageObject`). 장식 프레임·글씨는 `Selectable = false`.
- 열린 창 밖의 버튼으로 선택이 빠져나가지 않게 창마다 `SelectionGroup`(또는 `NextSelection*`)으로 묶음.
- 로비 첫 화면에서 아무것도 선택 안 됐을 때 **Select(뷰) 버튼** 또는 방향키 한 번으로 첫 버튼(빠른 참가)을 선택 — `GuiService.AutoSelectGuiEnabled`(기본 동작) 확인 후 필요하면 직접.
- 버튼 힌트: 창 아래쪽에 "Ⓐ 선택 · Ⓑ 닫기" 한 줄(게임패드 모드일 때만). 관전 화면은 "LB ◀ 관전 대상 ▶ RB".

### 화면별
| 화면 | 게임패드 동작 |
|---|---|
| 로비 | 방 목록·빠른 참가·방 만들기·코드로 참가·"🍣 스킨"·"🎁 상점"·"🎟 코드" 버튼을 방향키로 오감. 방 목록 스크롤은 선택을 따라 자동 |
| 방 만들기 창 | 인원 버튼 5개·공개/비공개·이름 칸(A 누르면 화면 키보드)·만들기/취소 |
| 방 대기실 | 시작(방장)·나가기·코드 복사 대신 코드 크게 표시 |
| 탈의실 | 탭(LB/RB로 탭 이동 추가) → 카드 격자 → 행동 버튼. 카드 선택 = 미리보기 바뀜 |
| 상점·코드·관리자 패널 | 카드/버튼 목록, 코드 칸은 A로 화면 키보드 |
| 라운드 중 HUD | 선택 없음(조작이 게임 입력으로만 가게 — 라운드 시작 때 `SelectedObject = nil`) |
| 관전 | **LB/RB = 이전/다음 대상**(Q/E와 같음), "로비로" 버튼은 Y(`ButtonY`) |
| 우승·결과 | 선택 없음 |
- 라운드 소개·달리는 중에는 게임패드 내비게이션을 끄고(`GuiService.SelectedObject = nil`, 창도 닫힘), A·B·X·R2는 게임 조작(점프·다이브·잡기)으로만.

## 범위
- 포함: 위 전부, 기존 마우스·터치 동작은 바뀌지 않음.
- 제외: 콘솔 전용 큰 글씨 테마(UIScale은 m4-09 그대로), 진동(가이드라인도 아껴 쓰라 함 — 후속), Roblox `InputActionLabel` 아이콘(글자 힌트로 대신), 콘솔 출시 설정(대시보드 — 사용자 작업).

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1: `isGamepadInput("Gamepad1") == true`, `"MouseButton1"`·`"Touch"`·`"Keyboard"`는 false.
- [ ] AC2: `insetsFor(true, 1920, 1080)`이 가로 96·세로 54(각 변 5%), `insetsFor(false, ...)`는 0.
- [ ] AC3: `GamepadNavLogic.nextTab(tabs, current, dir)`가 LB/RB로 탭을 돌고 끝에서 멈춘다(돌아가지 않음).
- [ ] AC4: 검증 5단계 통과 + 기존 UI 테스트(`ui-layout`, `m4-09-qa`) 통과.

### Studio 확인 (사용자 확인 필요 — Studio **Test → 컨트롤러 에뮬레이터**(Controller Emulator) 또는 실제 패드)
- [ ] AC5: 패드만으로: 로비 → 방 만들기(인원·이름 입력·만들기) → 대기실 → 시작(방장) 까지 마우스 없이 된다.
- [ ] AC6: 탈의실을 열면 첫 카드가 선택되고, LB/RB로 탭, 방향키로 카드, A로 입기·해금, B로 닫으면 "🍣 스킨" 버튼으로 선택이 돌아온다.
- [ ] AC7: 상점·코드 창도 같은 방식으로 다룰 수 있고, 코드 칸에서 A를 누르면 화면 키보드가 뜬다.
- [ ] AC8: 라운드가 시작되면 선택 테두리가 사라지고 A = 점프, X = 다이브, R2 = 잡기가 UI를 누르지 않는다.
- [ ] AC9: 탈락 뒤 관전에서 LB/RB로 대상이 바뀌고 Y로 "로비로".
- [ ] AC10: 마우스를 움직이면 선택 테두리·패드 힌트가 사라지고 지금과 똑같이 동작한다. 휴대폰 에뮬레이터 배치도 그대로.
- [ ] AC11 (사용자, 선택): Studio Device 에뮬레이터의 콘솔(Xbox) 화면에서 UI가 TV 가장자리 5% 안쪽에 있고 채팅 창이 안 보인다.

## 공용 파일 변경
- (필요하면) `src/client/init.client.luau`: 새 컨트롤러 등록. 단계 2라 다른 스펙과 겹치지 않음.

## 사용자 작업
- 콘솔 출시 여부 결정 → 켜려면 Creator Dashboard에서 지원 기기에 콘솔 켜기(USER-TODO C4 "콘솔 끔"을 바꿈), 경험 설문(콘텐츠 성숙도) 완료 확인(콘솔 필수).
- (선택) 실제 패드·콘솔 기기로 AC5~AC9.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 이 스펙의 순서 · UI 화면을 거의 다 고쳐서 **마지막 단계(단계 2)에 혼자**. 콘솔은 출시 체크리스트에서 꺼 둔 상태(USER-TODO C4)라 늦어도 다른 것을 막지 않음 → 사용자가 원하면 다음 묶음으로 미룸 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 콘솔 모드 판단 · 기기 종류가 아니라 **마지막 입력이 패드인가**(PC 패드 사용자도 편하게). 채팅 끄기·안전 여백만 10피트 기기에서. 근거: Roblox 콘솔 가이드라인(모든 UI를 방향키·선택·뒤로로, 몇 번만 눌러서, TV 안전 영역, 콘솔 채팅 창 끄기) — REFERENCE-console-ui 1·3절 · planner
- 2026-10-08 · D3 버튼 아이콘 · Roblox `InputActionLabel` 대신 글자 힌트("Ⓐ 선택 · Ⓑ 닫기") — 지금 UI 키트로 충분하고 PlayStation 글자(✕○)는 후속 · **기본값, 사용자 수정 가능** · planner
- 2026-10-15 · D4 추가 범위 (스펙 뒤에 생긴 화면) · 화면 목록에 없던 **🎫 뽑기 화면(DrawScreen — 본 창·결과 창·ⓘ 확률 상세 3개 창, 휴대폰 탭은 LB/RB)**, **⚙ 설정 메뉴(SettingsButton)·터치 버튼 편집(TouchLayoutEditor)**도 다룸. 🎁 상점·🎟 코드·🛠 관리자는 스펙 목록 그대로 · developer
- 2026-10-15 · D5 터치 버튼 편집·⚙ (터치 전용) · 게임패드 모드에서는 **숨김**: ⚙ 버튼·메뉴가 안 보이고(TouchGui가 켜져 있어도), `TouchLayoutEditor.open()`은 거절, 편집 중에 패드를 쓰면 SettingsButton이 편집을 취소(바꾼 것 버림 — 기존 "TouchGui 꺼짐" 경로와 같음). 근거: GDD 6 "PC·게임패드는 해당 없음" · developer
- 2026-10-15 · D6 기본 화면에서 B · 로비·대기실(창 없음)에서 B는 **창을 닫지 않고 선택만 끔**(Roblox 기본 동작과 같음) → 왼쪽 스틱으로 캐릭터를 움직일 수 있게. 다시 고르려면 방향키 한 번 또는 Select. 스펙 "아무 일 없음"을 "닫는 창 없음"으로 읽음 · developer (사용자 수정 가능)
- 2026-10-15 · D7 Select(뷰) 버튼 · `GuiService.AutoSelectGuiEnabled = false`로 Roblox 자동 선택을 끄고 우리가 처리: 아무것도 안 골랐으면 맨 위 창 → 기본 화면 → (관전 중 등) 왼쪽 위 "🍣 스킨"·"🎁 상점"·"🎟 코드"·"🛠" 버튼 순으로 첫 버튼, 골랐으면 선택 끄기(창 안에서는 그대로). 방향키는 창·기본 화면이 있을 때만 첫 버튼 · developer
- 2026-10-15 · D8 버튼 힌트 자리 · 창마다 넣지 않고 **화면 아래 가운데 한 줄**(자체 ScreenGui `GamepadHintGui`, DisplayOrder 60)에 맨 위 창 기준으로: 창 "Ⓐ 선택 · Ⓑ 닫기", 탭 있는 창 "LB/RB 탭 · Ⓐ 선택 · Ⓑ 닫기", 로비·대기실 "Ⓐ 선택 · Ⓑ 선택 끄기"/"방향키로 메뉴 고르기". 관전은 관전 패널 안에 "LB ◀ 관전 대상 ▶ RB · Ⓨ 로비로" (Strings.csv `gamepad.hint.*` 6개) · developer
- 2026-10-15 · D9 잠금 기준 · "라운드 소개·달리는 중"을 탈의실 버튼이 숨는 때와 같은 기준으로(`GamepadNavLogic.navAllowed`): 시작 카운트다운·소개·달리는 중(내가 레이서)·우승 연출 = 잠금, 탈락해 관전·통과해 대기석·라운드 결과 = 풀림. 잠금이면 선택 지움 + `GuiNavigationEnabled = false` + (게임패드 모드면) 열린 창 닫기 · developer
- 2026-10-15 · D10 창별 첫 선택 · 로비 = 빠른 참가, 방 만들기 = 지금 고른 인원 버튼, 대기실 = 시작(방장)/나가기, 탈의실 = 보이는 첫 카드(카드에 선택이 오면 미리보기가 바뀜), 상점 = 맨 위 칸 버튼, 코드 = 코드 칸(A → 화면 키보드), 관리자 = 지금 탭, 뽑기 = "뽑기 시작하기", 결과 = "확인", ⓘ = 닫기. 창을 다시 그려 버튼이 바뀌면 같은 이름 자리로, 없으면 첫 버튼 · developer
- 2026-10-15 · D11 방 대기실 코드 · 지금 대기실에는 복사 버튼이 없고 코드가 이미 큰 글씨(22) → 그대로 둠. HUD(`HudScreen`)도 고칠 것 없음(버튼 없음, 잠금이 처리) · developer
- 2026-10-15 · D12 10피트 안전 여백 · `UiScaleController.attach`가 비율 `UIPadding` 5%(`TvSafePadding`)를 붙임 — 화면 전체를 덮는 어두운 배경도 TV 가장자리 5%는 비어 보임(받아들임). 위쪽 바 gui는 그대로 · developer
- 2026-10-16 · D13 QA P3-1~P3-5 고침 · 오른쪽 스틱 = 글만 든 스크롤 굴리기, 동시에 열린 창은 DisplayOrder 순, 화면이 바뀌면 새 기본 화면 첫 버튼으로 이어 선택(처음 진입은 D6대로 자동 선택 없음), **D7 변경**: 기본 화면에서 View = 앵커 차례("🍣 스킨"…위쪽 바 음소거, 읽는 순서) → 마지막 다음 선택 끄기, 소개 배너 TV 여백 보정. P3-6(스틱 드리프트)은 실제 기기 확인 뒤 · 메인 세션

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 2026-10-15 구현 (브랜치 `m5-12-console`)
**새 파일**: `src/shared/GamepadNavLogic.luau`(순수: isGamepadInput·modeFor·insetsFor·nextTab·navAllowed·reconcile·pickFirst·scrollToShow), `src/client/ui/GamepadNav.luau`(공통 도우미·컨트롤러), `tests/gamepad-nav.spec.luau`.
**바뀐 파일**: `LobbyScreen`(로비 page + 방 만들기 window), `RoomScreen`(page), `ShopScreen`(window·LB/RB 탭·카드 선택 = 미리보기), `DrawScreen`(window 3개), `OfferScreen`, `CodeScreen`, `AdminPanel`(window·LB/RB 탭), `SpectateController`(LB/RB·Y), `SpectateScreen`(패드 힌트 줄), `RoomUiKit`(`selectionImage`, 스크롤 목록 `Selectable = false`), `UiScaleController`(10피트 5% 여백), `ChatTagController`(10피트 채팅 창 끄기), `SettingsButton`·`TouchLayoutEditor`(게임패드 모드에서 숨김), `src/shared/Localization/Strings.csv`(`gamepad.hint.*` 6개 — 탭 힌트 키는 AC12 `.tab` 검사에 안 걸리게 `gamepad.hint.withTabs`), 공용 `src/client/init.client.luau`(GamepadNav 등록 한 줄). `ShopController`·`OfferController`·`CodeController`·`LobbyController`·`HudScreen`은 안 고침(화면 모듈에서 등록).
테스트: 새 `tests/gamepad-nav.spec.luau` 12개, `tests/m4-09-qa.spec.luau` 가짜 환경에 GuiService·GamepadNavLogic 추가(UiScaleController 의존이 늘어서). 검증 5단계 통과 — rojo build, stylua, selene 0/0/0, `lune run tests` **2369 passed, 0 failed**, luau-lsp 0.
**판정·권한·서버 코드 변경 없음.**

**Studio 확인 방법** (사용자):
1. 패드 준비: 실제 패드(Xbox/PS)를 PC에 꽂거나, Studio **Test → Controller Emulator**(테스트 탭의 컨트롤러 에뮬레이터)를 켜고 Play.
2. AC5: 패드 버튼을 한 번 누르면 패드 모드. 로비에서 방향키 → "빠른 참가"에 흰 굵은 테두리, 아래 가운데 "Ⓐ 선택 · Ⓑ 선택 끄기". "방 만들기" A → 창이 뜨고 인원 버튼 선택됨, 방향키로 인원·공개/비공개·이름 칸(A = 키보드)·만들기 → 대기실 → "시작" A (Studio는 1명이면 시작 가능).
3. AC6: 대기실/로비에서 "🍣 스킨"으로 이동해 A → 첫 카드 선택·미리보기 바뀜, LB/RB로 탭(끝에서 멈춤), A로 입기/해금, B → 창이 닫히고 "🍣 스킨"이 다시 선택됨. "🎫 뽑기" A → 뽑기 화면("뽑기 시작하기" 선택), B로 탈의실로.
4. AC7: "🎁 상점"·"🎟 코드" 같은 방식. 코드 칸에서 A → 입력(콘솔은 화면 키보드). 관리자면 "🛠" 패널도 LB/RB 탭·B 닫기.
5. AC8: 라운드가 시작되면 테두리·힌트가 사라지고 A = 점프, X = 다이브, R2 = 잡기가 UI를 누르지 않음 (Select·방향키를 눌러도 UI가 선택되지 않음).
6. AC9: 탈락 → 관전 패널 아래 "LB ◀ 관전 대상 ▶ RB · Ⓨ 로비로", LB/RB로 대상, Y로 로비로/관전하기.
7. AC10: 마우스를 움직이면 테두리·힌트가 바로 사라지고 예전과 같음. Device 에뮬레이터 휴대폰 가로 배치·⚙ 그대로(패드를 쓰면 ⚙ 숨음).
8. AC11(선택): Test → Device 에뮬레이터에서 콘솔(Xbox One) 화면 → UI가 가장자리 5% 안쪽, 채팅 창 안 보임.
- 확인 못 한 엔진 동작(Studio에서 봐야 함): 선택 모드에서 B를 누를 때 Roblox가 먼저 선택을 끄는지(그래도 다음 프레임에 연 버튼으로 돌려놓게 짰음), ScrollingFrame 자동 스크롤과 우리 스크롤이 겹쳐 튀는지, ScreenGui 바로 아래 `UIPadding`이 적용되는지.
