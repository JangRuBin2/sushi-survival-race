status: ready
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

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
