# QA — m5-12 콘솔(게임패드) UI

- 스펙: `docs/specs/m5-12-console-ui.md`
- 검증 커밋: `750924f` (구현) + `71b2f18` (origin/main e252681 병합, 문서만 — 충돌 없음)
- 결과: **통과 (qa-passed)** — P0/P1/P2 없음, P3 7개(아래). Studio 확인 AC5~AC11은 사용자 확인 필요.

## 인계 메모 (최신)
- **브랜치**: `m5-12-console` (worktree `agent-a435732ea06140e3a`), origin/main e252681 병합함. main에는 아직 안 합침.
- **끝난 것**: 자동 검증 5단계, AC1~AC4, 결정 D4~D12 대조, 잠금·입력 전환·비패드 회귀·연결 정리·현지화·서버 무변경 코드 검토, 회귀 테스트 `tests/m5-12-qa.spec.luau` 12개 추가, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인(아래 체크리스트, AC5~AC11과 P3 확인 항목), main 병합 뒤 검증 재실행, 문서 반영(docs-writer: GDD 1·10절, M5 표, CLAUDE.md의 "m5-12 ready" 문구).
- **다음 첫 단계**: 메인 에이전트가 `m5-12-console`을 main에 병합하고 5단계 검증을 다시 돌린다. 그다음 docs-writer.
- **막힌 점**: 없음. 엔진 동작(B를 Roblox가 먼저 처리하는지, ScreenGui 바로 아래 UIPadding, 자동 스크롤 겹침)은 Studio에서만 확인할 수 있다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests tools` | 통과 |
| `selene src` | 0 errors / 0 warnings / 0 parse errors |
| `lune run tests` | **2381 passed, 0 failed** (개발 시점 2369 + QA 12) |
| `luau-lsp analyze` (새 검사기) | 오류 0, 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 isGamepadInput | 통과 | `gamepad-nav` "AC1", `m5-12-qa` "입력 전환" (Gamepad0/9/10 false 포함) |
| AC2 insetsFor | 통과 | `gamepad-nav` "AC2", `m5-12-qa` "AC2 경계"(4K·1440p·1366×768), "D12 런타임"(가짜 Roblox에서 attach가 `TvSafePadding` 5% 하나만, 위쪽 바 gui·PC는 없음) |
| AC3 nextTab | 통과 | `gamepad-nav` "AC3", `m5-12-qa` "nextTab"(탭이 줄어도 범위 안, 관리자 2탭) |
| AC4 검증 + 기존 UI 테스트 | 통과 | 위 표. `ui-layout`, `m4-09-qa`, `localization` 전부 0 failed |
| AC5 패드로 로비 → 방 만들기 → 대기실 → 시작 | 사용자 확인 필요 | 체크리스트 1 |
| AC6 탈의실 (첫 카드·LB/RB·A·B → 🍣 복귀) | 사용자 확인 필요 | 체크리스트 2. 코드로는 opener 복귀(`GamepadNav.luau:335-346`)·카드 미리보기(`ShopScreen.luau:444-449`) 확인 |
| AC7 상점·코드 (코드 칸 A → 키보드) | 사용자 확인 필요 | 체크리스트 3 |
| AC8 라운드 중 선택 없음, A/X/R2가 UI를 안 누름 | 사용자 확인 필요 | 체크리스트 4. 코드: `setLocked`(`GamepadNav.luau:490-511`), 기준은 `m5-12-qa` "D9" 테스트 |
| AC9 관전 LB/RB·Y | 사용자 확인 필요 | 체크리스트 5 |
| AC10 마우스로 바꾸면 그대로, 휴대폰 배치 그대로 | 사용자 확인 필요 | 체크리스트 6. 코드: 비패드 경로 가드(`m5-12-qa` "비패드 경로") |
| AC11 콘솔 화면 5% 여백·채팅 창 없음 | 사용자 확인 필요 (선택) | 체크리스트 7 |

현지화 기준(m5-26 AC11 한국어 하드코딩 금지·AC12 탭 글자 수): 통과. 새 코드의 문자열 리터럴에 한글 없음(주석만), `localization.spec` 20개 통과. 새 키 6개 ko/en·자리표시자 일치·코드↔CSV 대응은 `m5-12-qa` "현지화"로 고정. 탭 힌트 키는 `gamepad.hint.withTabs`라 `.tab` 검사(10자)에 걸리지 않는데, 이 문구는 탭 버튼이 아니라 힌트 한 줄이라 맞는 분류다.

## 결정 D4~D12 대조
| 결정 | 스펙·GDD와 맞는가 | 메모 |
|---|---|---|
| D4 추가 범위(뽑기 3창, ⚙·터치 편집) | 맞음 | DrawScreen 창 3개 등록 확인 |
| D5 패드 모드에서 ⚙·터치 편집 숨김 | 맞음 (GDD 6 "PC·게임패드는 해당 없음") | ⚙ 메뉴 항목은 "버튼 위치 편집" **하나뿐**(`SettingsButton.luau` 메뉴 `input.layout.menuItem`만, 주석 "다른 설정 항목은 아직 없어요"). 숨겨도 패드 사용자가 잃는 기능은 없다. 음소거 버튼은 ⚙ 메뉴가 아니라 위쪽 바의 별도 버튼(P3-4 참고). 원래 ⚙는 TouchGui가 켜졌을 때만 보여서 PC 패드 사용자에게는 처음부터 없었다 |
| D6 기본 화면 B = 선택만 끔 | 맞음 | `onInput`: `closeTop()`이 false(닫을 창 없음)이고 선택이 있을 때만 `SelectedObject = nil`(`GamepadNav.luau:444-448`). 스펙 "아무 일 없음"을 "닫는 창 없음"으로 읽은 것은 Roblox 기본 동작과 같고 왼쪽 스틱 이동을 살려서 받아들일 만함 |
| D7 Select 직접 처리 | 맞음 | `AutoSelectGuiEnabled = false`, 창 → 기본 화면 → 앵커 순 |
| D8 힌트 한 줄 | 맞음 | `GamepadHintGui` DisplayOrder 60 |
| D9 잠금 기준 | 맞음 | `navAllowed`가 `ShopController.canShow`와 **모든 조합(2×6×2×2)에서 같음**(테스트로 고정). 차이는 탈락 연출 중(`hiddenUntil`) — 이때 내비가 켜져 있지만 앵커가 숨어 있어 고를 것이 없다 |
| D10 창별 첫 선택 | 맞음 | 탈의실 첫 카드는 `order` 정렬 = 격자 `LayoutOrder`와 같음(`ShopScreen.luau:375`) |
| D11 대기실 코드·HUD 그대로 | 맞음 | |
| D12 10피트 여백 | 맞음 | 런타임 테스트로 확인(가짜 Roblox). 실제 엔진에서 ScreenGui 바로 아래 UIPadding이 먹는지는 Studio 확인 |

## 잠금 동작 (코드 검토)
- **켜짐**: `RoomUpdated`·`MatchPhase`·`PlayerResult`로 상태를 맞추고 `navAllowed`가 false면 `setLocked(true)` → 선택 지움 + `GuiNavigationEnabled = false` + (패드 모드면) 쌓인 창을 위에서부터 `close`. 소개(`RoundIntro`, 통과 안 함)·달리는 중(`RoundActive`, 생존·미통과)·카운트다운(`Starting`)·우승(`Victory`)·단계 모름(`nil`) 모두 잠김.
- **풀림**: `GuiNavigationEnabled = true`만 되돌리고 선택은 비워 둔다. 창이 남아 있으면 다음 프레임 `step`이 그 창 첫 버튼을 고르고, 기본 화면이면 방향키 한 번으로 고른다. 잠긴 동안 닫힌 창은 `reconcile`이 이미 스택에서 뺐으므로 풀린 뒤 엉뚱한 복귀가 없다.
- **입력 전환**: 마우스·터치·키보드로 바뀌면 선택을 지우고 스택을 비움(`setMode`). 잠긴 동안 바꿔도 `GuiNavigationEnabled`는 잠금이 쥐고 있어 꼬이지 않는다. 화면 키보드 입력(`Keyboard`+글자 칸 포커스)은 모드 유지. 순서별 전환은 `m5-12-qa` "입력 전환"으로 고정.
- **서버 잠금과의 관계**: 서버 `ShopService.isLocked`는 "이번 라운드에 배치된 레이서 + 연출 잠금 시간"이고, 클라이언트 내비 잠금은 탈의실 버튼 기준(클라이언트 UI)이다. 내비 잠금은 UI 편의일 뿐 권한이 아니고, 서버 거절은 그대로라 어긋나도 보안 문제는 없다. 통과자는 서버도 배치에서 빠지므로 두 기준이 같은 방향.

## 비패드(PC·휴대폰) 회귀 검토
- `step`·`onInput`은 첫 줄에서 `not gamepad`면 끝(테스트로 고정). 카드 `SelectionGained` 미리보기도 `isGamepad()` 가드.
- 등록 때 바뀌는 속성(`SelectionGroup`, `SelectionBehavior*`, 스크롤 틀·장식 프레임 `Selectable = false`)과 `AutoSelectGuiEnabled`, `SelectionImageObject`는 게임패드 선택에만 쓰이는 속성이라 마우스·터치 동작에 영향 없음. 잠금 중 `GuiNavigationEnabled = false`도 마우스·터치에 영향 없음.
- 화면 14개 수정은 모두 "생성 끝에 등록 한 번 추가"이고 기존 클릭·렌더 경로는 그대로(`Kit.onClick`은 `Activated`라 패드 A도 같은 경로). 관전은 `action` 콜백을 `toggleWatching`으로 이름만 뽑음(같은 본문). 관전 힌트 줄은 `Visible = false`라 UIListLayout 자리를 차지하지 않음.
- ⚙ 표시 조건은 기존 조건(TouchGui 켜짐) + `not isGamepad()`만 추가. 휴대폰에서 `LastInputType = Touch`면 그대로.
- `UiScaleController`: `IsTenFootInterface()`가 false면 아무것도 안 붙임(테스트로 고정).
- **m4-09-qa 가짜 환경 변경**: `GuiService`(항상 PC = false)와 `GamepadNavLogic` require 한 가지만 허용 목록에 더했고, 그 밖의 require는 여전히 assert로 막는다. 기존 단언은 하나도 빠지거나 느슨해지지 않음 → 약화 아님. 10피트 경로는 그 환경에 `UDim`이 없어 확인할 수 없어서 `m5-12-qa`에 별도 가짜 환경으로 추가했다.

## 연결 정리
- 화면 모듈은 컨트롤러마다 **한 번만** 만들어진다(`Screen.new(` 호출 1회씩, 관리자는 IsAdmin 늦게 와도 연결을 끊고 1회). 등록(`window/page/anchor/onModeChanged`)은 생성 함수 안에서 한 번, render·루프 안에서 부르지 않음 → 누적 없음(테스트로 고정).
- `GamepadNav.start`는 `started` 가드, Heartbeat 연결 1개.
- 창 쌓기: `reconcile`은 입력 스택을 바꾸지 않고 새 표를 돌려줌(테스트). 닫힌 창의 `opener`는 복귀 때 nil로 지움. 다시 그려 사라진 버튼은 `lastPath`(이름 경로)로 같은 자리 → 첫 버튼. `previousSelected`가 파괴된 인스턴스를 한 프레임 쥘 수 있지만 다음 프레임에 덮어써서 누수가 아니다.

## 서버 · 권한
- `git diff 3893c8a --stat`: `src/server/` 변경 **없음**, `src/shared/Remotes.luau`·`Config`·`Types`·`Attributes` 변경 **없음**. 공용 파일은 `src/client/init.client.luau` 한 줄(스펙이 허용한 것)뿐.
- 새 코드는 리모트를 보내지 않음(`FireServer`/`InvokeServer` 없음 — 테스트로 고정), 서버 → 클라이언트 이벤트만 듣는다.

## 버그
P0·P1·P2 없음.

### [P3-1] ⓘ 확률 상세(글자만 든 스크롤)가 패드로 굴려지지 않을 수 있음
- 재현: 패드 모드, 탈의실 → 🎫 뽑기 → ⓘ. 글이 창보다 길면(작은 TV·큰 글씨·영어).
- 기대: 오른쪽 스틱/방향키로 끝까지 읽을 수 있다.
- 실제: `sanitize`가 모든 ScrollingFrame을 `Selectable = false`로 만들고, 안에 고를 버튼이 없어 `scrollIntoView`도 안 움직인다. 지금 분량(10종)은 창 안에 들어갈 가능성이 크다 — Studio 확인.
- 위치: `src/client/ui/GamepadNav.luau:164-173`, `src/client/ui/DrawScreen.luau:631-642`

### [P3-2] 마우스로 관리자 패널과 탈의실을 같이 연 뒤 패드로 바꾸면 가려진 관리자 패널이 "맨 위"
- 재현: 마우스로 🛠 패널을 열고 🍣 탈의실도 연다(탈의실이 위, DisplayOrder 20 > 15) → 패드 버튼을 누른다.
- 기대: 보이는 탈의실 안에 선택.
- 실제: 모드를 바꿀 때 스택을 비우고 등록 순서로 다시 쌓는데 관리자 패널이 마지막에 등록돼서 맨 위가 되어, 선택이 탈의실 뒤에 가려진 패널 안으로 간다. B 한 번이면 풀린다(관리자 전용, 입력을 섞을 때만).
- 위치: `src/client/ui/GamepadNav.luau:481`, `src/shared/GamepadNavLogic.luau` `reconcile`

### [P3-3] 방을 만든 뒤 대기실에서 선택이 자동으로 오지 않음
- 재현: 패드로 방 만들기 창 → "만들기".
- 기대(스펙 AC5 흐름): 대기실에서 바로 "시작"을 누를 수 있으면 좋다.
- 실제: 창이 닫히며 연 버튼("방 만들기")이 숨어 있어 선택이 꺼진다. 방향키를 한 번 눌러야 "시작"이 고른다. 힌트가 "방향키로 메뉴 고르기"를 보여 주므로 막히지는 않음(UX).
- 위치: `src/client/ui/GamepadNav.luau:335-346`

### [P3-4] 위쪽 바 음소거 버튼이 패드로 닿는지 보장되지 않음
- 재현: 패드 모드에서 음소거 버튼(🔊)을 고르려 한다.
- 실제: 앵커 목록에 없고 기본 화면에는 울타리가 없어 방향키 기하로만 닿는다(될 수도 안 될 수도 있음). 콘솔은 Roblox 메뉴 볼륨으로 대신할 수 있다. Studio 확인.
- 위치: `src/client/Sfx.luau`(SoundGui.MuteButton), `GamepadNav.anchor` 호출부

### [P3-5] 10피트 화면에서 라운드 소개 배너 아래 요소가 여백만큼 내려갈 수 있음
- 내용: `IntroScreen`이 `banner.AbsolutePosition.Y - gui.AbsolutePosition.Y`를 Offset으로 쓰는데, `TvSafePadding`(위 5%)이 붙은 ScreenGui에서는 자식 원점이 5% 내려가 그만큼 더 내려간다. 겹침이 아니라 간격이 커지는 쪽이라 표시 문제만. AC11 확인 때 같이 본다.
- 위치: `src/client/fx/IntroScreen.luau:35-36`, `src/client/ui/UiScaleController.luau:112-123`

### [P3-6] 패드 스틱 흔들림(드리프트)이 있으면 마우스 사용 중 모드가 깜빡일 수 있음
- 내용: `LastInputTypeChanged`가 Gamepad로 바뀌면 바로 패드 모드(선택 테두리·힌트 표시). Roblox 데드존 밖으로 흔들리는 패드를 꽂은 PC에서 마우스와 번갈아 바뀔 수 있다. 실제 기기에서 문제가 보이면 스틱 입력은 무시하고 버튼만 보는 쪽으로.
- 위치: `src/client/ui/GamepadNav.luau:588-591`

### [P3-7] 문서: GDD·CLAUDE.md에 m5-12가 아직 "시작 전/ready"
- 위치: `docs/GDD.md:28`, `:560`, `:597`, `CLAUDE.md` 현재 상태. docs-writer가 done 때 반영.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 해당 없음(새 리모트·서버 변경 없음)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 판정 코드 변경 없음
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음
- [x] 연결·인스턴스·스레드 정리 — 화면은 한 번 생성, 등록 누적 없음(위 "연결 정리")

## 사용자 Studio 확인 체크리스트
준비: **Test 탭 → Controller Emulator**(컨트롤러 에뮬레이터)를 켜고 Play(실제 Xbox/PS 패드를 PC에 꽂아도 됨). 에뮬레이터 창의 버튼(A/B/X/Y, LB/RB, View=Select, D-pad)을 누른다. 패드 버튼을 한 번 누르면 패드 모드, 마우스를 움직이면 PC 모드.

1. **AC5 로비 → 대기실 → 시작**: 방향키 한 번 → "빠른 참가"에 굵은 흰 테두리, 화면 아래 가운데 "Ⓐ 선택 · Ⓑ 선택 끄기". 방향키로 "방 만들기" → A → 창이 뜨고 지금 인원 버튼 선택. 인원·공개/비공개 → 이름 칸 A(입력) → "만들기" A → 대기실. 방향키 한 번 → "시작" A(Studio 1명 시작 가능). 방 목록이 길면 아래로 갈 때 목록이 따라 굴러가는지, 튀지 않는지.
   - B를 로비에서 누르면 창 없이 테두리만 사라지고 왼쪽 스틱으로 캐릭터가 움직이는지(D6). Ⓐ·Ⓑ 글자가 네모(□)로 깨지지 않는지.
2. **AC6 탈의실**: "🍣 스킨" A → 첫 카드 선택 + 미리보기 바뀜, 힌트 "LB/RB 탭 · Ⓐ 선택 · Ⓑ 닫기". LB/RB로 탭(처음·끝에서 멈춤), 방향키로 카드(창 밖으로 안 나감), A 입기·해금. "🎫 뽑기" A → "뽑기 시작하기" 선택 → ⓘ → B로 닫힘 → B로 탈의실로 → B로 닫으면 "🍣 스킨"이 다시 선택. ⓘ 상세가 끝까지 보이는지(P3-1).
3. **AC7 상점·코드·관리자**: "🎁 상점"·"🎟 코드"도 A로 열고 B로 닫으면 연 버튼으로 복귀. 코드 칸에서 A → 입력(콘솔 기기는 화면 키보드). 관리자 "🛠" 패널 LB/RB 탭·B 닫기.
4. **AC8 라운드**: 탈의실을 연 채로 라운드가 시작되면 창이 닫히고 테두리·힌트가 사라짐. 달리는 동안 A=점프, X=다이브, R2=잡기가 UI를 누르지 않음, View·방향키를 눌러도 UI가 선택되지 않음. 결승 우승 연출 중에도 마찬가지. Race를 통과해 대기석에 가면 다시 방향키로 "🍣 스킨"을 고를 수 있음(View로).
5. **AC9 관전**: 탈락 → 관전 패널 아래 "LB ◀ 관전 대상 ▶ RB · Ⓨ 로비로". LB/RB로 대상이 바뀌고 Y로 "로비로"/"관전하기". 힌트 글자가 패널 폭 안에 들어가는지(영어 포함).
6. **AC10 마우스·휴대폰**: 패드로 고른 상태에서 마우스를 움직이면 테두리·힌트가 바로 사라지고 클릭이 예전과 같음. Device 에뮬레이터 휴대폰 가로에서 터치 버튼·⚙·편집 화면 그대로. 휴대폰 에뮬레이터에서 패드 버튼을 누르면 ⚙가 숨고(편집 중이었으면 취소), 다시 터치하면 ⚙가 돌아옴.
7. **AC11(선택) 콘솔 화면**: Test → Device 에뮬레이터에서 **Xbox One**(콘솔) 선택 → Play. 모든 창·버튼이 화면 가장자리 5% 안쪽(로비 패널, 탈의실, 힌트 줄), 채팅 창이 안 보임. 라운드 소개 배너 아래 글이 너무 내려가지 않는지(P3-5). 어두운 배경 가장자리 5%가 비어 보이는 것은 D12로 받아들인 것.
8. (P3-4) 패드 모드에서 방향키로 위쪽 바 음소거 버튼까지 갈 수 있는지.

## 추가한 테스트
`tests/m5-12-qa.spec.luau` (12개)
- QA D9: navAllowed = ShopController.canShow (모든 조합 96개)
- QA D9: 우승 연출·카운트다운은 탈락자·통과자도 잠김
- QA 잠금 소스: 단계 리셋 규칙 동일, setLocked가 GuiNavigationEnabled·선택·(패드만) 창 닫기
- QA 입력 전환 순서(패드↔마우스↔화면 키보드↔터치)
- QA 비패드 경로 가드(step·onInput·setMode·카드 미리보기·⚙ 기존 조건)
- QA reconcile 경계(같은 상태 두 번, 아래 창만 닫힘, 다시 열면 맨 위, 미등록 id, 입력 표 불변)
- QA nextTab 탭 수 변화
- QA AC2 경계 해상도
- QA D12 런타임(가짜 Roblox, 10피트 UIPadding 하나·위쪽 바 없음·PC 없음)
- QA 현지화 6키(ko/en, 자리표시자, 코드↔CSV)
- QA 서버 무관(리모트 없음, 순수 로직)
- QA 연결(화면 1회 생성, 등록 수 고정, start 가드)
