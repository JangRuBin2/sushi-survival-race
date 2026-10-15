# QA — m5-26 다국어(현지화) 재QA (p3: main 병합 뒤)

- 스펙: `docs/specs/m5-26-localization.md`
- 이전 리포트: `docs/qa/m5-26-localization.md` (1차 반려 B1, 2차 재QA 중간 인계)
- 검증 커밋: `0087be5` (`origin/m5-26-i18n-p3` a9c0eb2 + `origin/main` 3f2678c 병합, git 충돌 없음) + QA 테스트 1개 파일
- 결과: **통과 (P0/P1 없음)** — 스펙 상태 `qa-passed`

## 요약
- 이전 P1 B1(복귀 티켓 `nameIsDefault`를 믿고 방 이름 필터를 건너뜀)은 고쳐졌고 회귀 테스트가 있어요(`m5-26-qa` "QA B1 (P1)", `m5-26-phase2` "B1:" 6개, 이번 재QA 2개).
- main 병합(p3) 충돌 해결이 main 기능을 깨지 않았어요. 서버 쪽 변경은 반환 타입 `string` → `LocText`와 오류 문구 키뿐이고 검증·판정 코드는 main과 같아요.
- m5-29·m5-31·m5-32 테스트는 단언을 약하게 하지 않고 `LocTest.ko(...)`로 main 때와 같은 한국어 값을 비교해요. m5-41 테스트는 문구를 보지 않아 바뀐 게 없어요.
- 키 누락 없음: 맵 21개 name·rule, 스킨 41종 이름(+대사), 뽑기 등급 5, 새 화면 문구 모두 CSV에 있어요. src 한국어 리터럴은 허용 목록(Studio 매치 1줄 + 데이터 원문 + 관리자 파일)뿐이에요.
- 새 버그는 P3 관찰 1개뿐이에요(영어에서 뽑기 등급과 상점 등급 이름이 겹침, 아래).

## 자동 검증 (로컬 Windows, 2026-10-15)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공 |
| `stylua --check src tests tools` | 통과 (QA 테스트 추가 뒤 다시 확인) |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests` | QA 테스트 추가 전 **2349 passed, 0 failed** → 추가 뒤 **2357 passed, 0 failed** (끝 코드 0). `localization` 20 · `m5-26-qa` 21 · `m5-26-phase2` 20 · `m5-26-reqa` 8 모두 통과 |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 CSV 읽기·머리줄 | 통과 | `localization.spec` AC1 (508줄 = 머리줄 + 507행), `m5-26-qa` 파일 위생 |
| AC2 키 형식·중복·빈 칸 | 통과 | `localization.spec` AC2, 중복 키 0 (`cut \| uniq -d`로도 확인), en 빈 칸 0 |
| AC3 자리표시자·괄호·Example | 통과 | `localization.spec` AC3 (새 키 `reward.summaryTokensTickets` 등 Example 있음) |
| AC4 코드 키 ↔ CSV | 통과 | `localization.spec` AC4 + `m5-26-qa` 리터럴 보강. 동적 키 `shop.drawGrade.*` 포함 |
| AC5 데이터 동기화 | 통과 | `localization.spec` AC5 — 맵 21×2, 스킨 41(이름·대사), 뽑기 등급 5. 재QA "뽑기 등급"(en = `DRAW_GRADE_INFO.english`), "칭호" |
| AC6 이유 enum → LocText | 통과 | `localization.spec` AC6 + 재QA "뽑기 거절 이유"(DrawLogic 6개, 한국어가 main 때와 같음) |
| AC7 format | 통과 | `localization.spec` AC7 |
| AC8 choose 폴백 | 통과 | `localization.spec` AC8 |
| AC9 languageOf·formatNumber·ordinal | 통과 | `localization.spec` AC9 |
| AC10 isLocText | 통과 | `localization.spec` AC10 |
| AC11 한국어 리터럴 금지 | 통과 | `localization.spec` AC11 (src 전체, 허용 1줄 + 데이터 원문). `DrawScreen`·`TouchLayoutEditor`·`SettingsButton`·`DiveButton`·`GrabButton` 한국어 0. 재QA "맵 21개" — 지은 맵 모델의 TextLabel에 한글 0 |
| AC12 버튼·탭 길이 | 통과 | `localization.spec` AC12 (`input.layout.*.btn` 8개, `shop.draw.btn.*`, `shop.tab.draw` 포함) |
| AC13 조사 규칙 | 통과 | `localization.spec` AC13 ("R$ {price} · 사기") |
| AC14 서비스 오류 키 비교 | 통과 | `m5-26-qa` RoomService 하네스, `ShopService` DrawTicket은 `DrawLogic.message`/`common.err.retry` (코드 읽기 `src/server/ShopService.luau:274-277, 392-399`) |
| AC15 기본 방 이름 | 통과 | `localization.spec` AC15, `m5-26-qa` AC15 |
| AC16 검증 5단계 | 통과 | 위 표 |
| AC17~AC24 | 사용자 확인 필요 | 아래 체크리스트 |
| AC25 (2단계 단상·칭호) | 자동 부분 통과, Studio 확인 필요 | `m5-26-phase2` 단상·칭호, 재QA "칭호" |
| AC26 (2단계 와사비) | 자동 부분 통과, Studio 확인 필요 | `m5-26-phase2` 월드 글씨, 재QA "맵 21개"(키 글씨는 빈 글씨 + LocKey + AutoLocalize false) |

정리: 자동 AC1~AC16 **16개 통과, 실패 0**. AC25·AC26 자동 부분 통과. Studio·실서버 AC17~AC26 **사용자 확인 필요**.

## 이전 버그 상태
- **B1 (P1) 고침 확인**: `src/server/RoomService.luau:695-714`. `filterWith`가 있으면(로비 복귀) 기본 이름은 방장 DisplayName으로 다시 만들거나(방장이 이 서버에 있을 때), 티켓 이름을 필터해서 바뀌면 돌아온 사람 DisplayName으로 바꿔요. 쓴 이름은 항상 필터해요. `nameIsDefault`는 `== true`로만 읽어서 `"yes"` 같은 값은 쓴 이름으로 보고 필터해요(재QA 테스트).
- B2 영어 다듬기·B3 서수·B4 늦은 번역기: 반영 확인(이전 재QA 기록 그대로).
- B5(2단계): 단상·와사비 처리 완료. B6(P3, 월드 BillboardGui는 늦은 번역기 다시 쓰기 대상 아님): 그대로 알려진 한계 — `WorldTextController`는 `Loc.onChanged`로 다시 채우지만 캐릭터 이름표 칭호는 다음 갱신까지 폴백 영어.

## main 병합 확인 (질문 3)
| 영역 | 결과 | 근거 |
|---|---|---|
| Remotes 계약 | 이상 없음 | `git diff origin/main` = 주석만(LocText 계약·DrawTicket `err: LocText?`). 리모트 이름·개수 그대로 |
| RewardLogic 티켓 정산 | 이상 없음 | `matchTicketTotal`·`simulate` 그대로. `summaryText` 4조합·`ticketToastText`의 한국어가 main 때 모양과 같음(재QA "정산 줄") |
| ShopLogic 🎫 특 탭·drawHint | 이상 없음 | 탭 순서·`draw = true`·`visibleSkins` 그대로, 글씨만 키. `m5-31-draw-logic`·`m5-32` 기대값 그대로 `LocTest.ko`로 비교 |
| ShopService DrawTicket | 이상 없음 | 요청 간격·잠금·저장 가능·`DataService.update` 한 번 그대로, 반환 타입만 LocText |
| DrawScreen | 이상 없음 | 확률 = `DrawLogic.grades`/`displayPercents`(빈 등급만 LocText), 오류는 `Loc.text(err)`, 글씨는 Kit(AutoLocalize false) |
| TouchLayoutEditor·SettingsButton | 이상 없음 | 글씨만 `Loc.t`로 바뀜, 잠금·저장·겹침 로직 그대로. 직접 만든 TextButton은 `AutoLocalize = false` |
| 테스트 단언 | 약해지지 않음 | m5-29(2줄)·m5-31(10여 줄)·m5-32(4줄) 모두 같은 한국어 값을 `LocTest.ko`로 비교. m5-31 ShopScreen 소스 고정 줄은 새 배지 코드로 바뀜(같은 의도) |
| 서버 파일 | 이상 없음 | `DataService`는 main과 같음. `RewardService`는 칭호 숫자 1줄, `AdminCommands`는 forceStart 문구 이동뿐 |
| `Types`·`Attributes` | 이상 없음 | main 쪽 추가(TouchLayout·drawTickets·DrawGrade 등) 모두 있음. 빠진 줄은 m5-26이 의도한 `name` → `name + nameIsDefault`, `Title` 설명 변경뿐 |

## developer 판단 7개 (질문 6)
1. **`shop.drawGrade.<Grade>` 동적 키** — 맞음. 스펙 2절 "동적 키는 정해진 모양만, `Loc` 도우미만" 규칙을 따름(`LocalizeLogic.drawGradeKey`·`Loc.drawGradeName`, `DYNAMIC_KEY_PATTERNS`). 영역 `shop` 재사용도 2절 영역 목록 안. 스펙 2절 목록에 한 줄 추가 필요(planner/docs-writer).
2. **"R$ {price} · 사기"** — 맞음. 스펙 6절이 바로 이 예를 듦. 탈의실과 같은 키를 써서 일관됨.
3. **강제 줄바꿈 제거** — 받아들임. CSV 칸 안 줄바꿈을 피하고 `TextWrapped`에 맡김. AC17(한국어 그대로)에서 줄이 바뀌는 위치만 달라질 수 있어 Studio 확인 항목에 넣음.
4. **"(Legendary)" 괄호는 한국어 넓은 화면만** — 맞음. m5-31 스펙 UI 11이 휴대폰에서 영어 괄호를 빼라고 했고, 영어 화면에서는 "Legendary (Legendary)"가 되므로 빼는 게 맞음.
5. **DrawTicket 오류 LocText** — 맞음. 스펙 5절 리모트 계약과 같은 모양. 서버는 클라이언트 문자열을 판단에 쓰지 않음.
6. **수산시장 간판 `WorldText.mark`, 밥솥 타이머 AutoLocalize false** — 맞음. 2단계 결정(서버 월드 글씨 = 키 속성) 그대로. 재QA 테스트가 맵 21개 전부의 월드 글씨를 확인.
7. **정산 줄 조합별 키** — 맞음. 사용자 규칙 "숫자 + 단위 = 한 키"(결정 기록 2026-10-13)를 따름.

## 버그
### [P3] B7 영어에서 뽑기 등급 이름과 상점 등급 이름이 같은 말이 됨 (관찰)
- 재현: Locale English → 탈의실. 상점 등급 탭 "Rare"·"Epic"·"Legendary"와 🎫 특 카드 배지 "🎫 Rare"·"🎫 Epic"(뽑기 등급).
- 기대: CLAUDE.md "뽑기 등급(일반·고급·희귀·영웅·전설)은 상점 등급과 다른 말이다" — 한국어는 레어/희귀, 에픽/영웅으로 구분돼요.
- 실제: 영어는 `Skins.DRAW_GRADE_INFO.english`(m5-31 데이터)를 그대로 써서 Common·Rare·Epic·Legendary가 상점 등급과 같은 단어예요. 🎫 아이콘이 붙고 특 스킨은 상점 등급 탭에 안 나와서 실제 혼동은 작아요. 고등어는 상점 전설 = 뽑기 전설이라 문제 없음.
- 위치: `src/shared/Localization/Strings.csv:331-335`, `src/shared/Skins.luau:114-118`
- 제안(선택, 기획 결정): 그대로 두거나, 영어도 구분하려면 planner가 뽑기 등급 영어 이름을 정해서 `english`와 CSV `en`을 같이 바꿈(재QA 테스트가 둘이 같은지 확인함).

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자 검증 그대로: p3에서 바뀐 서버 파일(`ShopService`·`RewardService`·`AdminCommands`)은 반환 타입·문구 키만 바뀜. `DrawTicket`은 여전히 인자를 받지 않고 요청 간격·잠금·저장 가능을 서버가 봄.
- [x] 서버 판단이 클라이언트 문자열에 의존하지 않음: 서버에 `isLocText` 사용 없음(`m5-26-qa` 정적 검사), `Attributes.LocKey`·`Title`은 서버가 달고 클라이언트가 글씨로만 씀. `Title`은 숫자(기준 승수)이고 권한·보상 판단에 안 씀.
- [x] 판정(통과·탈락·순위·코인·뽑기 결과)은 서버에만 있음 — 이 스펙은 판정 코드를 바꾸지 않음.
- [x] 맵 상태·Cleanup: 맵 파일 변경은 `FishMarket` 간판·`SoySwampHazards` 글씨(`WorldText.mark`)·`RiceCooker` AutoLocalize 1줄뿐, 상태·정리와 무관.
- [x] 방 이름 필터: B1 고침 확인.

## 사용자 Studio 확인 체크리스트
준비: Studio **Test** 탭 → **Player Emulator** 켜기 → Locale 고르기 → Play. 휴대폰은 Test → **Device** 에뮬레이터.
이전 리포트(`docs/qa/m5-26-localization.md`) 체크리스트 1~9와 스펙 개발 메모 "2단계" Studio 확인 1~5는 그대로 유효해요. p3에서 더 볼 것:

1. **🎫 뽑기 화면 영어** — `Config.DEBUG.unlockAllSkinsInStudio = false`(커밋 전 `true`로 되돌리기), 🛠 명령 `tickets 30`. Locale English → 탈의실 "🎫 Draw 30" → 제목 "Skin Draw", "Your Draw Tickets ×30", 버튼 "🎫 Start Draw >", 확률표 "Odds by Grade" 등급 5줄(이름만, 괄호 영어 없음)·퍼센트, ⓘ 상세 "… : 5.05% each"·"Duplicate: +20 🍚"·반올림 안내. 뽑으면 "Drumroll…" → "👑 You Got a Skin!" 또는 "Already owned → +80 🍚". 0장이면 "Win a match to get a 🎫 draw ticket". **한글이 하나도 없어야** 해요(스킨 이름 포함).
2. **뽑기 화면 한국어** — 기본 Locale에서 넓은 화면 확률표가 "전설 (Legendary)" 모양, 부제·안내·말풍선 글씨가 예전과 같은지(강제 줄바꿈 대신 자동 줄바꿈이라 줄 나뉘는 위치만 다를 수 있음).
3. **휴대폰 넘침 (AC22 + p3)** — English + Device 가로 667×375·844×390:
   - 뽑기 화면 탭 3개 "🎫 Draw / 📊 Odds / 📦 Skins", 📊 탭의 등급 5줄과 "Coming Soon"(빈 등급이 있을 때), 아래 안내 "Only the winner gets a draw ticket! (Skins are given by the odds)"가 칸 밖으로 잘리지 않는지. ⓘ 상세의 긴 줄(반올림 안내 "Odds are rounded, so the total may be slightly off from 100%.")이 스크롤 안에서 줄바꿈되는지.
   - ⚙ 메뉴 "✋ Edit Button Layout" → 편집 화면 버튼 8개("Smaller −", "Bigger +", "Default", "Large", "Near Thumb", "Reset", "Cancel", "Save")가 칸 안에 들어가는지, 위쪽 안내 "Drag buttons to move them. Tap one, then change its size."와 겹침 경고 "Buttons overlap. Move them apart to save."가 잘리지 않는지, 조이스틱 자리 "Move joystick area", 버튼 이름 "⬆ Jump"·Dive·Grab.
   - 라운드 중 ⚙ 메뉴 "Can't edit during a round"가 메뉴 폭(240) 안에 들어가는지.
4. **탈의실 🎫 특** — English: 탭 "🎫 Special", 특 카드 배지 "🎫 Rare" 등, 안 가진 카드 버튼 "🎫 From Draws", 고등어 상세 "Legendary · 🎫 Also in Legendary draws", Studio 전부 입기 켠 상태 버튼 "Wear (Studio)". (B7: 상점 등급 탭 "Rare"와 같은 단어인 게 거슬리는지 같이 봐 주세요.)
5. **우승 정산·토스트** — English로 혼자 한 판 우승: 토스트 "+1 🎫 Winner Draw Ticket", 정산 줄 "This match: +… 🍚 🎫 +1 (Total: …)". 🛠 `tickets 99`(가득) 뒤 우승 → "🎫 Draw tickets are full (99)". 한국어에서는 "이번 판 +… 🍚 🎫 +1 (총 …)", "+1 🎫 우승 뽑기권".
6. **새 맵 6개 소개** — `forceMapPlan`으로 dish-sink·space-conveyor·rice-cooker·fish-market·tea-garden·onsen-claw를 English로 열어 라운드 소개 이름·규칙이 영어인지(예: "Fish Market", "Hot Spring Claw Machine"). 수산시장 간판이 "FISH MARKET"(한국어 "수산시장"), 밥솥 숫자 타이머가 그대로 보이는지. 끝나면 `forceMapPlan = nil`.

## 추가한 테스트
- `tests/m5-26-reqa.spec.luau` (8개, 모두 통과)
  - B1 경계: `nameIsDefault = "yes"`는 쓴 이름으로 보고 필터 / 방장이 다른 서버에 있는 조작된 기본 이름은 돌아온 사람 이름
  - 칭호: `Config.Titles` ↔ `titleWinsFor` ↔ `title.w*` (원문·영어)
  - 뽑기 등급 동적 키: Source = `displayName`, en = `english`, 고등어 안내 한국어
  - DrawLogic 거절 이유 6개 → `shop.drawErr.*`, 한국어 = main 때 글자 그대로, 빈 등급·반올림 안내·결과 줄(천 단위 쉼표)
  - 정산 줄 4조합 + 0 값: 한국어 = main 때 모양, 영어 깨끗, 티켓 토스트
  - 뽑기 확률 상세(RichText)에 들어가는 이름·줄에 `<`·`>`·`&` 없음
  - 렌더러 환경에서 맵 21개를 실제로 지어 TextLabel에 한글 없음, 키 글씨는 CSV 키 + 빈 글씨 + AutoLocalize false, 키 없는 글씨도 AutoLocalize false

## 인계 메모 (최신)
- **브랜치**: worktree `agent-a217e185a26e97558`, 브랜치 `m5-26-i18n-p3` → `origin/m5-26-i18n-p3`에 push (main 3f2678c까지 병합됨).
- **끝난 것**: m5-26 재QA 전부 — 최신 main 병합(충돌 없음), 5단계 검증, AC1~AC16 확인, B1 고침 확인, p3 병합 검토, developer 판단 7개 검토, 재QA 테스트 8개, 이 리포트. 스펙 `qa-passed`.
- **남은 것**: (1) 메인 세션이 `m5-26-i18n-p3`를 main에 병합하고 5단계 다시 돌리기(그사이 main이 움직였으면 `localization.spec` AC4·AC5·AC11이 새 문구를 잡음). (2) 사용자 Studio 체크리스트(이 리포트 1~6 + 이전 리포트 1~9 + 스펙 "2단계" 1~5). (3) docs-writer: CLAUDE.md 현지화 규칙, DEV-SETUP, USER-TODO(CSV 업로드), 스펙 2절 동적 키 목록에 `shop.drawGrade.<Grade>`. (4) 선택: B7(P3) 기획 결정.
- **다음에 할 첫 단계**: main 병합 뒤 `lune run tests`의 `localization`·`m5-26-*` 결과 확인.
- **막힌 점**: 없음. Studio·실서버(AC17~AC26)는 사용자 확인 필요.
