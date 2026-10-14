status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-41 — 모바일 터치 버튼 위치·크기 편집 (점프·다이브·잡기)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §6(조작 — 터치 버튼 3개), §10(UI 목록), §11.5(데이터 저장)
- 레퍼런스: [`docs/REFERENCE-touch-button-layout.md`](../REFERENCE-touch-button-layout.md)
- 참고 코드: `src/shared/UiLayout.luau`(`defaultJump`·`touchButtons`·`spectateArrows`·`gapBetween`·`inside`), `src/client/input/DiveButton.luau`·`GrabButton.luau`(점프 버튼을 찾아 옆에 붙음, UIScale 없음), `src/client/Sfx.luau`(위쪽 바 음소거 버튼 자리, `SaveSettings` 보내기 간격), `src/server/DataService.luau` `onSaveSettings`, `src/shared/ProfileSchema.luau` `sanitizeSettings`·`toView`, `src/client/ui/SpectateScreen.luau`
- 담당 개발 worktree: `m5-touch-layout` (Rojo 포트 **34902**)
- 공용 파일 수정 담당: **이 스펙** — `src/shared/Types.luau`(`Settings`에 `touchLayout` 한 필드), `src/shared/Remotes.luau`(`SaveSettings` 설명 주석 한 줄만, 리모트 개수 그대로 26), `src/client/init.client.luau`(새 컨트롤러 등록). `Config.luau`·`Attributes.luau`·`default.project.json`은 안 바꿈(상수는 `TouchLayoutLogic`에).
- **순서·겹침**:
  - `m5-26`(현지화, ready)도 `Types`·`Remotes`·`init.client`를 고친다 → **둘을 동시에 개발하지 않는다**(공용 파일 한 명 규칙). 먼저 들어간 쪽 뒤에 시작. m5-26이 먼저면 이 스펙의 새 문구도 키·CSV로.
  - `m5-12`(콘솔 UI, ready)가 `SpectateScreen`·위쪽 바를 고칠 수 있다 → 같이 돌리면 병합 때 다시 검증.
  - `m5-32`(고등어 스킨 — `Skins`·`SushiBody*`·`AppearanceService`·`CharacterFxController`·`SfxCues`/`SfxLibrary`), `m5-33`~`m5-40`(맵 파일·`SfxCues`·`MapFxPresets`·맵 테스트)과는 **파일이 안 겹친다**.
- **이 스펙이 고치는 파일**: 새 `src/shared/TouchLayoutLogic.luau`(순수), `src/shared/UiLayout.luau`(`touchButtons`·`spectateArrows`가 저장된 배치를 받게), `src/shared/ProfileSchema.luau`(`sanitizeSettings` 부분 저장 + `touchLayout`, `toView`), `src/server/DataService.luau`(`onSaveSettings` 병합), `src/client/input/DiveButton.luau`·`GrabButton.luau`(배치 적용), 새 `src/client/input/TouchLayoutController.luau`(배치 보관·점프 버튼 옮기기·편집 중 입력 끄기), 새 `src/client/ui/TouchLayoutEditor.luau`(편집 화면), 새 `src/client/ui/SettingsButton.luau`(⚙ 버튼), `src/client/ui/SpectateScreen.luau`(화살표 연동), 공용 3개(위), 테스트 `tests/touch-layout.spec.luau`

## 배경
사용자(2026-10-14): 모바일 다이브·잡기 버튼 배치를 플레이어가 바꿀 수 있게. 메인 세션 제안("버튼 위치 편집"에서 끌어 옮기기·크기 조절·화면 비율로 저장·기본값으로 되돌리기·간단한 프리셋)에 사용자 "진행해".

## 목표
휴대폰·태블릿에서 ⚙ → "버튼 위치 편집"을 누르면 점프·다이브·잡기 버튼을 손가락으로 끌어 옮기고 크게/작게 바꿀 수 있다. 저장하면 다음에 들어와도, 같은 종류의 다른 기기(다른 휴대폰)에서도 비슷한 자리에 있다. 버튼은 화면 밖·이동 조이스틱 자리·Roblox 위쪽 바·노치에 못 가고, 서로 겹치지 않고, 44px보다 작아지지 않는다. 편집하지 않은 사람은 지금과 **완전히 같은** 배치를 본다.

## 범위
### 포함
1. **배치 데이터** (순수, `TouchLayoutLogic`)
   - 기기 묶음 `bucket`: `"phone"`(짧은 변 ≤ `UiLayout.JUMP_SMALL_SHORT_SIDE` 500 — Roblox 작은 점프 버튼 기준과 같음) / `"tablet"`(그 밖). 묶음마다 배치 하나씩 저장.
   - 버튼 하나 = `{ x, y, s }`: `x`·`y` = 버튼 **가운데**의 위치를 **안전 영역**(노치·위쪽 바 제외 화면) 폭·높이에 대한 비율(0~1), `s` = 크기를 짧은 변에 대한 비율. 저장은 소수 셋째 자리까지.
   - 배치 = `{ v = 1, preset = "default" | "large" | "compact" | "custom", jump, dive, grab }`.
   - `TouchLayoutLogic.toScreen(layout, screen) -> TouchButtons` / `fromScreen(buttons, screen) -> layout`: 왕복하면 1px 안으로 같다. `screen = { width, height, safe = { left, top, right, bottom } }`.
2. **클램프** (순수, 매 프레임이 아니라 끌 때·화면 크기가 바뀔 때·불러올 때) `TouchLayoutLogic.clamp(buttons, screen) -> (TouchButtons, { problem: string }?)`:
   - 크기: 실제 픽셀 ≥ `Config.Ui.MinTouchSize`(44), ≤ 짧은 변 × 0.35, 기본 크기의 0.7~1.6배.
   - 위치: 안전 영역 안(여백 8px), **위쪽 금지 띠**: 버튼 윗변 ≥ max(위쪽 바 높이(`GuiService:GetGuiInset()`의 위) + 8, 화면 높이 × 0.2) — Roblox 위쪽 바·채팅·메뉴 버튼과 라운드 HUD(위 가운데)를 가리지 않게. **왼쪽 금지 구역**: x < 화면 폭 × 0.4 (Roblox 이동 조이스틱 자리 — REFERENCE 2절 4).
   - 겹침: 버튼 셋 서로 `UiLayout.gapBetween ≥ UiLayout.MIN_TOUCH_GAP`(8). 끄는 중에는 잡은 버튼만 클램프하고, 겹치면 빨간 테두리 + "저장" 비활성(손을 떼도 자동으로 밀어내지 않음 — 예상 밖 이동 방지).
   - 불러온 배치가 지금 화면에서 규칙을 못 지키면(작은 화면 등) 크기 → 위치 순으로 줄이고 옮겨 맞추고, 그래도 안 되면 **기본 배치**로(조용히, 저장값은 그대로).
3. **프리셋** (`TouchLayoutLogic.preset(name, screen)`)
   - `default`: 지금 `UiLayout.touchButtons(w, h)`와 **픽셀까지 같다**(점프 = Roblox 기본 위치, 다이브 = 왼쪽, 잡기 = 위, 85%).
   - `large`: 기본에서 셋 다 ×1.25(클램프 뒤), 묶음 가운데 기준.
   - `compact`: 셋을 오른쪽 아래 모서리로 모은 배치(점프 모서리, 다이브 왼쪽, 잡기 왼쪽 위 대각선 — 엄지가 덜 움직이게).
   - "기본값으로 되돌리기" = `default`로 바꾸고 저장하면 그 묶음 저장값을 지움.
4. **점프 버튼** (`TouchLayoutController`): Roblox 기본 점프 버튼(`PlayerGui.TouchGui.TouchControlFrame.JumpButton`)을 저장된 자리·크기로 옮기고, **PlayerModule이 Position·Size를 바꾸면 그때마다 다시 적용**(속성 변경 신호, 같은 프레임 반복 방지). `default` 배치면 손대지 않는다(지금과 같음).
   - 다이브·잡기 버튼은 지금처럼 점프 버튼 실제 위치를 기준으로 하지 않고 **배치 값**을 쓴다(배치가 `default`면 지금처럼 점프 실제 위치 기준 — 기본 사용자 회귀 없음).
5. **편집 화면** (`TouchLayoutEditor`)
   - 들어가는 곳: 위쪽 바 음소거 버튼 왼쪽 ⚙ 버튼(`SettingsButton`, **터치 컨트롤이 있을 때만** 보임 = `UserInputService.TouchEnabled`이고 `TouchGui`가 있을 때) → 작은 메뉴 "버튼 위치 편집". 다른 설정 항목은 이번에 없음(메뉴 틀만).
   - 화면: 반투명 어두운 덮개 + 버튼 셋의 **편집용 복사본**(아이콘 같은 모양, 끌기 가능). 하나를 누르면 선택(흰 테두리) → 아래 줄 "작게 −" "크게 +"(한 번에 10%), 프리셋 3개, "기본값으로", "취소", "저장".
   - 편집 중에는 **진짜 버튼 입력이 안 나간다**: 다이브·잡기 버튼 숨김, 기본 점프 버튼 숨김(편집 끝나면 원래대로), 덮개가 아래 터치를 막음.
   - **라운드 중에는 못 연다**: 내가 레이서로 배치돼 있는 동안(소개 포함 — 클라이언트가 이미 아는 매치 단계 값) ⚙ 메뉴 항목이 회색 "라운드 중에는 편집할 수 없어요". 로비·대기실·관전 중·대기석에서는 열 수 있다. 편집 중에 라운드 배치가 오면 **취소로 닫힌다**(저장 안 함).
   - "저장": 클라이언트가 그 묶음 배치를 `SaveSettings({ touchLayout = { bucket, layout } })`로 한 번 보냄(누름 사이 1초 안 연타는 마지막만). "기본값으로" 뒤 저장은 `{ touchLayout = { bucket, reset = true } }`.
6. **저장 (프로필 — 결정 기록 D1)**
   - `Types.Settings`: `{ muteLevel: number, touchLayout: { phone: Layout?, tablet: Layout? }? }`. 프로필 버전은 **3 그대로**(새 필드는 선택, 없으면 기본 — `sanitizeSettings`가 이상한 값은 버림).
   - `ProfileSchema.sanitizeSettings`를 **부분 저장**을 받게: 들어온 표에 `muteLevel`·`touchLayout` 중 하나 이상, 있는 필드는 각각 검증하고 **하나라도 틀리면 전체 무시**(지금 음소거 저장은 그대로 동작). `touchLayout` 검증: `bucket`이 `"phone"`·`"tablet"`, `reset == true`이거나 `layout`이 위 모양 — 숫자 전부 유한, `x`·`y` 0~1, `s` 0.04~0.4, `preset`이 4개 중 하나, `v == 1`, 다른 키 없음(키 수 상한). 저장 전에 소수 셋째 자리로 반올림.
   - `DataService.onSaveSettings`: 검증 통과한 필드만 `DataService.update` 안에서 병합(`muteLevel`은 지금처럼, `touchLayout[bucket] = layout` 또는 `nil`). **요청 간격은 필드마다**(`muteLevel`·`touchLayout` 각각 `Config.Data.SettingsMinInterval` 0.5초) — 음소거를 누른 직후 배치 저장이 버려지지 않게.
   - `ProfileSchema.toView`: `settings.touchLayout`을 그대로 보냄 → 클라이언트 `ProfileStore`에서 `TouchLayoutController`가 읽음(첫 프로필이 오기 전은 기본 배치).
   - Studio는 지금처럼 메모리 저장(`persistDataInStudio = false`면 서버를 다시 켜면 사라짐 — 정상).
7. **관전 화살표**: `UiLayout.spectateArrows(w, h, buttons?)`가 지금 배치의 버튼 셋 중 **가장 위 버튼** 위에(여백 12) 놓인다. 버튼이 높아 자리가 없으면 위쪽 금지 띠 바로 아래로(버튼과 안 겹치게 — 겹치면 화살표를 버튼 묶음 왼쪽으로).
8. **PC·게임패드**: 해당 없음 — ⚙ 버튼이 안 보이고 아무것도 바뀌지 않는다. 터치 + 키보드가 같이 있는 기기는 터치 컨트롤이 보이는 동안만.

### 제외
- 이동 조이스틱(썸스틱) 옮기기·왼손잡이 좌우 반전(결정 기록 D4), 버튼 투명도·색, 다른 UI(코인·HUD) 옮기기, 게임패드 버튼 바꾸기(콘솔은 `m5-12`), 기기마다(UserId + 기기 id) 저장(Roblox에 기기 id·기기 저장소 없음).

## 수용 기준
### 순수 로직 (lune 테스트, `tests/touch-layout.spec.luau`)
- [ ] AC1: `TouchLayoutLogic.preset("default", s)`가 화면 4종(844×390, 667×375, 1024×768, 2400×1080, 안전 영역 0)에서 `UiLayout.touchButtons(w, h)`와 셋 다 x·y·size가 같다(회귀 없음).
- [ ] AC2: `toScreen(fromScreen(b, s), s)`가 1px 안으로 같다. 휴대폰 844×390에서 만든 배치를 다른 휴대폰 932×430에 적용하면 각 버튼 가운데가 같은 비율 자리(±2px)이고 크기가 짧은 변 비율로 바뀐다.
- [ ] AC3: `clamp`: 크기 20px → 44 이상(배율 1 기준), 짧은 변 × 0.5 → 0.35로, 화면 밖 → 안쪽(여백 8), 왼쪽 40% 안 → 밖으로, 위쪽 금지 띠 안 → 아래로, 노치 안전 영역(left 44) 안 → 밖으로. 결과는 항상 `UiLayout.inside` true, 셋 서로 `gapBetween ≥ 8`.
- [ ] AC4: 겹치는 배치는 `clamp`가 problem `"overlap"`을 돌려주고(자동으로 밀지 않음), 겹침이 없어질 때만 `nil`. 작은 화면(568×320)에 태블릿용 큰 배치를 넣으면 크기를 줄여 맞추고, 그래도 안 되면 `default`를 돌려준다.
- [ ] AC5: `preset("large")`·`("compact")`가 모든 화면 4종에서 `clamp` 문제 없이 규칙을 지킨다.
- [ ] AC6: `ProfileSchema.sanitizeSettings`: `{ muteLevel = 2 }` 통과(지금 그대로), `{ touchLayout = { bucket = "phone", layout = 정상 } }` 통과, `{ touchLayout = { bucket = "phone", reset = true } }` 통과, 둘 다 있으면 둘 다. 거절: 빈 표, `bucket = "pc"`, NaN·inf·음수·1 초과 x, `s = 0.9`, 알 수 없는 키, 문자열 길이 > 16인 preset, 버튼 하나 빠짐, 중첩 표 크기 상한 초과, `muteLevel` 정상 + `touchLayout` 틀림(전체 무시). 통과한 숫자는 소수 셋째 자리.
- [ ] AC7: 병합(가짜 DataService 또는 순수 병합 함수): 음소거만 저장하면 `touchLayout`이 안 지워지고, 배치만 저장하면 `muteLevel`이 그대로, `reset`은 그 묶음만 지운다. 필드별 요청 간격 — 0.2초 안 같은 필드 두 번째는 버리고, 다른 필드는 받는다.
- [ ] AC8: 옛 프로필(`settings = { muteLevel = 1 }`)과 `touchLayout`이 망가진 프로필을 불러오면 `ProfileLogic`이 버전 3 그대로 `touchLayout`만 버리고(메모) 나머지를 지킨다.
- [ ] AC9: `UiLayout.spectateArrows(w, h, buttons)`: 기본 배치에서 지금 결과와 같고, 버튼을 높이 올린 배치에서도 화살표가 버튼과 안 겹치고 화면 안이다.
- [ ] AC10: 리모트 개수 26 그대로, `Remotes`의 `SaveSettings` 설명이 새 모양. 검증 5단계 통과(rojo build, stylua, selene, lune run tests `0 failed`, luau-lsp).

### Studio 확인 (Test → Device 에뮬레이터, 사용자 확인 필요)
- [ ] AC11: iPhone 가로(작은 화면)에서 편집하지 않으면 버튼 셋이 지금과 똑같다. ⚙ → "버튼 위치 편집"에서 다이브를 끌어 옮기고 크게 하고 저장하면 바로 그 자리·크기로 동작하고 다이브가 된다.
- [ ] AC12: 점프 버튼을 옮겨도 PlayerModule이 원래 자리로 되돌리지 않는다 — 리스폰(리셋)·라운드 시작·화면 회전/크기 바꾸기(에뮬레이터 기기 바꾸기) 뒤에도 유지. **안 되면** 결정 기록 D3의 대안(자체 점프 버튼)으로 바꾸고 다시 확인.
- [ ] AC13: 버튼을 왼쪽 조이스틱 자리·위쪽 바·화면 밖·노치로 끌면 못 들어가고, 두 버튼을 겹치면 빨간 테두리에 저장이 안 눌린다. 44px보다 작아지지 않는다.
- [ ] AC14: 편집 중에는 버튼을 눌러도 다이브·잡기·점프가 나가지 않는다. "취소"는 바꾼 걸 버리고, "기본값으로 → 저장"은 처음 배치로 돌아간다. 프리셋 3개가 바로 보인다.
- [ ] AC15: 라운드에 배치된 동안(소개 포함)에는 편집 메뉴가 회색이고, 로비·관전 중에는 열린다. 편집을 열어 둔 채 라운드가 시작되면 편집이 닫히고 버튼이 정상이다.
- [ ] AC16: 같은 Studio 세션에서 캐릭터 리셋·로비 복귀 뒤에도 배치가 남는다. iPad로 바꾸면 태블릿 배치(따로 저장)가 쓰이고, 휴대폰 기기(다른 크기)로 바꾸면 휴대폰 배치가 비율대로 맞춰진다. (실제 재접속 유지는 C1 퍼블리시 뒤 — `persistDataInStudio`는 커밋 값 false.)
- [ ] AC17: 관전 중 ◀ ▶가 옮긴 버튼 위(또는 옆)에 있고 겹치지 않는다. PC·게임패드에서는 ⚙ 버튼이 안 보이고 아무것도 안 바뀐다.

## 공용 파일 변경
- `src/shared/Types.luau`: `Settings`에 `touchLayout: TouchLayoutSettings?`(+ 그 타입). **이 스펙만 수정.**
- `src/shared/Remotes.luau`: `SaveSettings` 설명 주석 한 줄(`{ muteLevel?, touchLayout? }`). 리모트 추가 없음(26개 그대로).
- `src/client/init.client.luau`: `TouchLayoutController`·`SettingsButton` 등록.
- `Config.luau`·`Attributes.luau`·`default.project.json`·`init.server.luau`·`rokit.toml`: 안 바꿈.

## 사용자 작업 (스펙을 막지 않음)
- AC11~AC17 에뮬레이터 확인, 가능하면 실제 휴대폰에서 한 번(퍼블리시 뒤 재접속 유지).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 요청 · 사용자: 모바일 다이브·잡기 버튼 배치를 플레이어가 바꿀 수 있는 설정 → 메인 세션 제안(끌어 옮기기·크기·화면 비율 저장·기본값으로·간단한 프리셋)에 "진행해" · 사용자
- 2026-10-14 · D1 저장 위치: 프로필 vs 기기 · **프로필(서버 DataStore)**. Roblox 경험에는 기기에 저장하는 클라이언트 API가 없다(REFERENCE 1절 E) → 기기별 저장은 불가능. 대신 "기기마다 화면이 다르다"는 문제를 **비율 좌표 + 휴대폰/태블릿 묶음별 저장**으로 푼다. 서버가 범위·키·길이를 검증하고 필드별 요청 간격을 둔다(클라이언트 값은 믿지 않음 — 배치는 겉모습뿐이라 판정과 무관하지만 프로필 오염 방지) · planner (메인 세션 위임 범위)
- 2026-10-14 · D2 새 리모트를 만들지 · 안 만든다. 기존 `SaveSettings`를 부분 저장으로 넓힘(리모트 수·Remotes 테스트 유지). 프로필 버전도 3 유지(선택 필드) · planner
- 2026-10-14 · D3 기본 점프 버튼 옮기기 · 먼저 **기본 JumpButton을 옮기고 PlayerModule이 바꾸면 다시 적용**(PlayerModule 포크 없이 가장 작은 변경, 공식 문서도 기본 점프 버튼을 기준으로 씀). Studio AC12에서 되돌아가거나 깜빡이면 **자체 점프 버튼**(우리 ImageButton이 `Humanoid.Jump = true`, 누르고 있으면 계속 점프 — 기본과 같은 손맛, 기본 버튼은 숨김)으로 바꾸고 결정 기록에 · planner (developer가 실측 뒤 정함)
- 2026-10-14 · D4 왼손잡이 좌우 반전 · **이번에 안 함**(메인 세션 제안에서 뺌). Roblox 이동 조이스틱이 왼쪽에 고정이라(옮기려면 PlayerModule 통째 수정) 버튼만 왼쪽으로 보내면 조이스틱과 겹쳐 오히려 못 쓴다. 대신 `compact`(엄지 가까이 모음)·`large` 프리셋 · planner (메인 세션 위임 범위)
- 2026-10-14 · D5 라운드 중 편집 · 막는다. 편집 화면이 화면을 덮고 입력을 끄기 때문에 라운드 중에 열면 본인만 손해이고 실수로 열 수도 있다. 로비·대기실·관전·대기석에서만 · planner
- 2026-10-14 · D6 금지 구역 수치 · 왼쪽 40%(조이스틱), 위 20% 또는 위쪽 바 + 8(채팅·메뉴·HUD), 안전 영역 여백 8, 크기 44px~짧은 변 35% — 정확한 썸스틱 크기는 확인 못 해 넉넉하게. **기본값, 사용 뒤 조정** · planner

- 2026-10-14 · D7 (developer) 리모트 수 · main은 m5-31 뒤 RemoteFunction 16 + RemoteEvent 11 = **27개**. 스펙의 "26"은 그 전 기준이라 실제 코드 기준(27 그대로, 새 리모트 없음)으로 맞춤 · 메인 세션 지시
- 2026-10-14 · D8 (developer) 맨 위 모르는 칸 · `SaveSettings`의 **맨 위** 모르는 칸(`coins` 등)은 예전처럼 읽지 않고 버림(m4-01·m4-07 QA 테스트가 고정). AC6의 "알 수 없는 키 거절"은 `touchLayout` 안(변경·배치·버튼 표)에 적용 — 키 수 상한(2·5·3)도 거기 · developer
- 2026-10-14 · D9 (developer) 반올림 위치 · `fromScreen`은 반올림하지 않고(AC2 1px 왕복), 저장 직전 `quantize`(클라이언트)와 서버 `sanitizeLayout`이 소수 셋째 자리로 반올림. 폭 2400px에서는 셋째 자리만으로 ±1px을 못 지켜서(0.0005 × 2400 = 1.2px) 왕복 1px은 반올림 전 값으로 검사, 반올림 뒤는 휴대폰에서 2px 안으로 검사 · developer
- 2026-10-14 · D10 (developer) 편집 잠금 단계 · `Starting`·`RoundIntro`·`RoundActive`이고 살아 있고 통과 전일 때 잠금(`TouchLayoutLogic.editLocked`). `Starting`도 넣음 — 곧 소개가 와서 열자마자 닫히는 일을 막으려고. 결과(`RoundResults`)·우승 화면·통과(대기석)·탈락(관전)은 열림 · developer
- 2026-10-14 · D11 (developer) 잘못된 요청과 간격 · 예전에는 틀린 요청도 간격을 썼는데, 이제는 검증을 통과한 칸만 간격을 씀(칸별). 검증은 키 수 상한 때문에 늘 작게 끝남 · developer
- 2026-10-14 · D12 (developer) 점프 버튼(D3) · 1차 구현은 "기본 JumpButton 옮기고 다시 적용". 자체 점프 버튼은 **만들지 않음** — Studio AC12에서 되돌아가거나 깜빡이면 그때 바꿈(사용자 확인 필요) · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
2026-10-14 developer — 브랜치 `m5-41-touch-button-layout` (main d37a1c4 기준). 검증 5단계 통과(rojo build, stylua --check src tests tools, selene 0/0/0, lune 1942 passed 0 failed, luau-lsp 0).

**바뀐 파일**
- 새 `src/shared/TouchLayoutLogic.luau`(순수): 묶음, 비율↔픽셀, `clamp`/`clampOne`(크기 44px~짧은 변 35%·기본 0.7~1.6배, 안전 영역 여백 8, 왼쪽 40%, 위쪽 띠 max(위쪽 바+8, 높이 20%), 겹침 8px — 문제만 알리고 밀지 않음), `fit`(크기 줄이기 → 안 되면 default), `resolve`, 프리셋 3개, `move`/`resize`, 서버 검증 `sanitizeLayout`/`sanitizeChange`/`sanitizeStored`, `editLocked`, 편집 도구 칸 크기 `editorPanel`/`panelHeight`.
- `src/shared/UiLayout.luau`: `spectateArrows(w, h, buttons?)`(없으면 예전 공식 그대로), `TOUCH_TOP_FORBIDDEN`.
- `src/shared/ProfileSchema.luau`: `sanitizeSettings` 부분 저장(→ `SettingsPatch`), `acceptByInterval`(칸별 간격), `applySettings`(병합), `sanitizeStoredSettings`(불러오기), `toView`가 `touchLayout` 복사(없으면 예전 모양 `{ muteLevel }`).
- `src/shared/ProfileLogic.luau`: 불러오기에서 `touchLayout`만 버리고 메모(버전 3 그대로).
- `src/server/DataService.luau`: `onSaveSettings` = 검증 → 칸별 간격 → `update` 안에서 병합.
- 공용: `Types.luau`(TouchLayout 타입들, `Settings.touchLayout?`, `SettingsPatch`), `Remotes.luau`(SaveSettings 주석 한 줄, 27개 그대로), `init.client.luau`(`TouchLayoutController` — Sfx 다음·DiveController 전, `SettingsButton` — 끝).
- 새 `src/client/input/TouchLayoutController.luau`: 화면 재기(ScreenInsets None 기준 gui + DeviceSafeInsets gui + `GetGuiInset`), 저장값 → 버튼 셋, 점프 버튼 옮기기·되돌리면 다시 적용(`task.defer` 한 번), 편집 중 숨김, 잠금 추적, 저장(바로 적용, 1초 간격, 보낸 값은 프로필로 돌아올 때까지 6초 우선).
- 새 `src/client/ui/TouchLayoutEditor.luau`, 새 `src/client/ui/SettingsButton.luau`.
- `src/client/input/DiveButton.luau`·`GrabButton.luau`: 편집한 배치면 그 자리, 아니면 예전 계산(점프 실제 위치 기준), 편집 중 숨김·입력 무시. `src/client/ui/SpectateScreen.luau`: 화살표가 배치를 따름.
- 테스트 새 `tests/touch-layout.spec.luau`(30개). 기존 테스트 수정 없음.
- 안 겹침 확인: m5-32(스킨·캐릭터 fx·SfxCues)·m5-33~40(맵·maps/init·SfxCues) 파일은 안 건드림. `Config.luau`·`Attributes.luau`·`default.project.json` 안 바꿈.

**Studio 확인 방법** (Test → Device 에뮬레이터, 가로)
1. iPhone(작은 화면)으로 Play: 버튼 셋이 예전과 같은 자리(AC11 앞부분). 위쪽 바 음소거 왼쪽에 ⚙가 보임. PC 화면으로 돌아가면 ⚙ 없음(AC17).
2. ⚙ → "✋ 버튼 위치 편집": 어두운 덮개, 왼쪽 빨간 띠(조이스틱 자리)에 도구 칸. 다이브를 끌어 옮기고 눌러서 "크게 +" → "저장" → 바로 그 자리·크기, 다이브가 됨(AC11).
3. 점프를 옮겨 저장 → 리셋(캐릭터 리셋)·방 만들어 라운드 시작·기기 바꾸기 뒤에도 그 자리인지, 깜빡이지 않는지(AC12). **되돌아가면 알려 주세요**(D3 대안으로 바꿈).
4. 끌어서 왼쪽 조이스틱 자리·위쪽 바·화면 밖으로 못 가는지, 두 버튼을 붙이면 빨간 테두리 + "저장" 회색, "작게 −"를 계속 눌러도 44px 아래로 안 가는지(AC13).
5. 편집 중 복사본을 눌러도 다이브·잡기·점프가 안 나가는지, "취소"는 버리고, "기본값으로 → 저장"은 처음 배치, "크게"·"엄지 가까이"가 바로 보이는지(AC14).
6. 혼자 Studio에서 방 시작(`minPlayersToStart = 1`): 소개·라운드 중 ⚙ 메뉴가 회색 "라운드 중에는 편집할 수 없어요", 편집을 열어 둔 채 시작하면 닫히고 버튼이 정상(AC15). 탈락 뒤 관전 중에는 열림.
7. 리셋·로비 복귀 뒤 배치 유지, iPad로 바꾸면 태블릿 배치(따로), 다른 휴대폰 크기로 바꾸면 비율대로(AC16). 관전 중 ◀ ▶가 옮긴 버튼과 안 겹침(AC17).

**남은 이슈**
- AC11~AC17은 사용자 Studio 확인 필요. 특히 AC12(PlayerModule이 점프 버튼을 되돌리는지)는 실측 전.
- 편집 화면 "기본" 프리셋과 "기본값으로"는 같은 동작(둘 다 저장하면 그 묶음 저장값을 지움) — 스펙 그대로.
- 기본 배치에서 다이브·잡기 위치는 예전처럼 점프 실제 위치 기준이고, 편집 화면 시작값도 그 실제 위치(기기 점프 자리가 금지 구역에 걸치면 처음 손댈 때 규칙에 맞춰 옮겨짐).
