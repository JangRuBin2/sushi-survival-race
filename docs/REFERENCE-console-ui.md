# REFERENCE — 콘솔(게임패드) UI

- 작성: planner, **2026-10-08** (출처 확인 날짜 = 2026-10-08)
- 목적: `docs/specs/m5-12-console-ui.md`의 근거. 표기: **[원문]** = WebFetch로 원문 확인, **[검색]** = 검색 요약만.
- 참고용이다. 결정은 스펙 결정 기록에 있다.

## 1. Roblox 공식 콘솔 가이드라인 (Creator Docs, 2026-06-11 갱신)

| 구분 | 내용 | 근거 |
|---|---|---|
| 필수 | 콘솔용 게임은 **콘텐츠 성숙도 정보**(경험 설문)를 꼭 제공 | [원문] console-guidelines |
| 필수(권장 문구지만 "어떻게 꾸미든" 강조) | "채팅을 어떻게 꾸미든 **콘솔에서는 채팅 창을 끄세요**" | [원문] |
| 권장 | 10피트 UI: 상대 크기·상대 위치(퍼센트), `UISizeConstraint`, `GuiService.ViewportDisplaySize` 고려 | [원문] |
| 권장 | **TV 안전 영역** 안에 중요한 UI | [원문] |
| 권장 | 방향 4개 + 선택 + 뒤로만으로 **모든 UI에 닿을 수 있게**. Roblox가 방향 선택·가상 커서를 기본 제공하지만 화면 구성이 독특하면 직접 내비게이션을 짜라 | [원문] |
| 권장 | 핵심 행동은 **몇 번만 눌러서** 닿게 | [원문] |
| 권장 | 기기에 맞는 **버튼 아이콘** 표시 (`InputActionLabel` 또는 `UserInputService`) | [원문] |
| 권장 | 진동은 아껴서 | [원문] |
| 권장 | 한 화면에 다 넣기보다 **화면을 들어갔다 나오는** 구성이 흔하고 빠름 | [원문] |
| 시장 | Xbox·PlayStation 이용자 2억 명 이상 | [검색] 같은 문서 요약 |

## 2. 지금 우리 상태 (코드 확인)
- 조작은 게임패드 대응됨: 점프 A(Roblox 기본), 다이브 `ButtonX`(`DiveController`), 잡기 `ButtonR2`(`GrabController`). GDD 6 표.
- UI는 마우스·터치 기준. `GuiService.SelectedObject`·`Selectable`·`NextSelection*`을 쓰는 코드가 없음(`LobbyScreen`에 `Selectable = false` 한 곳). 관전 대상 바꾸기는 Q/E·◀▶ 버튼뿐.
- 출시 체크리스트(USER-TODO C4)는 "콘솔 끔 (콘솔 UI는 M5)".

## 3. 우리 기본값 (m5-12)
- **게임패드가 마지막 입력일 때만** 콘솔 모드(PC에 패드를 꽂아도 같음). 마우스·터치를 쓰면 지금 그대로.
- 창이 열리면 첫 버튼을 자동 선택, **B = 닫기/뒤로**, 방향키로 모든 버튼에 닿음. 관전은 **LB/RB**로 대상 바꾸기.
- 10피트 화면(`GuiService:IsTenFootInterface()`)에서만 채팅 창 끔 + 안전 영역 여백 5%.
- 버튼 옆에 패드 글자 힌트("Ⓑ 닫기" 등) — Roblox `InputActionLabel` 대신 글자(간단, 지금 UI 키트로 충분, 추정).

## 4. 출처
- Roblox Creator Docs, Console guidelines — https://create.roblox.com/docs/en-us/production/publishing/console-guidelines.md (원문, 2026-06-11 갱신 표기)
- Roblox Creator Docs, Gamepad input — https://create.roblox.com/docs/input/gamepad (원문: 입력 종류 감지·버튼 배치·진동·컨트롤러 에뮬레이션. UI 내비게이션 세부 API는 이 문서에 없음)

## 5. 확인 못 함
- PlayStation 출시용 추가 요건(성숙도 등급 제한 등) — 이 문서에 없음.
- `GuiService.AutoSelectGuiEnabled` 등 UI 선택 API의 공식 문서 문장 — 이번에 원문을 못 찾음. API 이름은 Roblox 엔진 API 기준(개발 때 Studio 자동 완성으로 확인).
