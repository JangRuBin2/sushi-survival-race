# QA — m5-31 우승자 뽑기 티켓 (🎫 무료 등급별 뽑기 · 특 스킨 9종 · Studio 전부 입기)

- 스펙: `docs/specs/m5-31-winner-ticket-draw.md`
- 검증 커밋: `a5bc3f2` (브랜치 `m5-31-winner-ticket-draw`, main `ab91c52`까지 병합됨) + QA 테스트 `tests/m5-31-qa.spec.luau`
- 결과: **반려 → `in-dev`** (P2 1건 — 휴대폰 뽑기 화면 버튼 여러 개가 44px보다 작아 AC24를 못 지킴. P0/P1 없음, P3 2건)
  - 이번 QA는 "P0~P2면 반려"로 요청받아 그 기준을 따랐다(WORKFLOW 기본은 P0/P1). 서버 판정·확률·경제 쪽(AC1~AC16)은 모두 통과했고, 고칠 곳은 클라이언트 `DrawScreen.luau` 배치뿐이다.

## 자동 검증 (2026-10-14, Windows 로컬, worktree `agent-a6786423e039151fb`)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 (`Built project to build.rbxl`) |
| `stylua --check src tests tools` | 통과 (끝 코드 0) |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | **1906 passed, 0 failed** (개발 1888 + QA 18) |
| `luau-lsp analyze … --flag:LuauSolverV2=true src` | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 (테스트 이름 / 파일:줄 / 사용자 확인 필요) |
|---|---|---|
| AC1 카탈로그·validate | 통과 | `m5-31-draw-logic` "AC1: 특 9종…", "AC1: DRAW_IDS(9) = …", "AC1: validate가 잡는 것 / 가짜 고등어…"; QA "QA 롤: 뽑기 풀 = DRAW_IDS 정확히" |
| AC2 무료 아님 | 통과 | "AC2: isFree는 계란초밥만…"; QA "QA 판매 금지: 특 스킨은 묶음·VIP 패스·로벅스 결제로 못 주고…" (가짜 묶음·패스에 특 스킨을 넣으면 `Offers.validate`가 거절, 9종 모두 `ReceiptLogic.canRequest` → `NotRobux`) |
| AC3 프로필 v3 | 통과 | "AC3: VERSION 3…"; QA "QA migrate v2 → v3: drawTickets 경계" (99 유지, 100→99, inf·−1·2.5·문자열·true → 0 + 노트, nil → 0 노트 없음, 다른 값 보존). 특 스킨 장착 미보유 → `tamago`는 기존 `ProfileLogic.luau:174-179`가 `isFree` 변경으로 처리 |
| AC4 등급 확률·빈 등급 | 통과 | "AC4: 실제 카탈로그…", "AC4: 가짜 카탈로그…"; QA "QA 표시: 빈 등급 조합 31가지" (모든 조합에서 chance 합 1) |
| AC5 표시 = 판정 | 통과 | "AC5: displayPercents…", "AC5: perSkinPercent…"; QA 빈 등급 31조합에서 표시 합 정확히 100.0·각 ±0.1, 스킨별 % × 수 ≈ 등급 %, "QA 화면 = 서버" (화면 소스에 퍼센트 상수·`GradeWeights` 없음, `DrawLogic.grades()`·`displayPercents(grades)`·`perSkinPercent(grades)`만, 서버는 같은 기본 카탈로그로 `roll`) |
| AC6 롤 경계 | 통과 | "AC6: 누적 경계…", "AC6: NextInteger(1, n)대로…"; QA "QA 롤: 정확한 누적값은 다음 등급(`<`)…" (0 → 영웅, 누적값 정확히 → 다음 등급, 1.0·NaN → 일반, 음수 → 영웅), "NextNumber·NextInteger 한 번씩, NextInteger(1, 등급 스킨 수)", "NextInteger가 범위 밖이어도 그 등급 안으로" |
| AC7 분포 | 통과 | "AC7: 고정 시드 100,000번…" |
| AC8 적용 | 통과 | "AC8: apply…", "AC8: canDraw…"; QA "roll이 Skin이었는데 그 사이 보유가 생기면 Duplicate + 그 등급 코인", "티켓 NaN·음수·0.5·문자열·nil이면 NoTickets" |
| AC9 대표 스킨 | 통과 | "AC9: featured…"; QA "QA featured: 연어 → 연어알 → 성게 → 문어 → 참치 순" |
| AC10 지급 | 통과 | "AC10: Won만 1장…", "AC10: simulate…"; QA "QA 지급: 우승은 이벤트 기간과 상관없이 정확히 TicketsPerWin…" (이벤트 밖·할로윈·크리스마스, 통과·탈락·결승 패배 0장), "QA 티켓: drawTickets를 바꾸는 곳은…", "QA 지급: RewardService는 우승 티켓을 코인과 같은 update에서…" |
| AC11 Studio 전부 입기 | 통과 | "AC11: unlockAllActive…"; QA "QA 서버: Studio 전부 입기는 서버 설정(IsStudio·DEBUG)만, EquipSkin은 ownedSkins를 안 바꿔요". 커밋 값 `true` 고정 (`m5-03-qa`) |
| AC12 관리자 `tickets` | 통과 | "AC12: tickets StudioOnly…" (−99~99, 100·1.5·"3"·NaN 거절, PersistOn·실서버 거절, AdminService에 DrawLogic·DataService 없음) |
| AC13 리모트·타입·설정 | 통과 | "AC13: RemoteFunction 16·RemoteEvent 11…", `m5-03-foundation` 합계 27 |
| AC14 탈의실 로직 | 통과 | "AC14: '🎫 특' 탭…", "AC14: 안 가진 특 스킨 'Draw'…" |
| AC15 기존 테스트 | 통과 | diff 검토(아래 "기존 테스트 변경 검토") — 바뀐 것은 무료·보유·이름·탭 수·버전·리모트 수 기대값뿐, 모양·관절·파츠 상한(70)·렌더 검사는 그대로 |
| AC16 검증 5단계 | 통과 | 위 표 |
| AC17 현지화 | 해당 없음 | main에 `src/shared/Localization/Strings.csv` 없음 (개발 메모와 같음) |
| AC18 티켓 받기 | 사용자 확인 필요 | 체크리스트 2 |
| AC19 뽑기 화면 | 사용자 확인 필요 | 체크리스트 3 (확률표 값은 lune으로 확인함) |
| AC20 뽑기 결과 | 사용자 확인 필요 | 체크리스트 4 (B2 같이 보기) |
| AC21 보유 목록·상세 | 사용자 확인 필요 | 체크리스트 5 |
| AC22 잠금 | 사용자 확인 필요 | 체크리스트 6 (서버 `isLocked` 거절은 코드로 확인) |
| AC23 Studio 전부 입기 | 사용자 확인 필요 | 체크리스트 1·7 |
| AC24 휴대폰 | **실패 예상 (코드 계산)** | B1 — Studio 에뮬레이터로 최종 확인 필요 |

- lune으로 확인한 수용 기준: AC1~AC16 **16개 통과**, AC17 해당 없음, AC18~AC23 사용자 확인 필요, AC24 실패 예상(B1).

## 버그

### [P2] B1 휴대폰(짧은 변 ≤ 500px)에서 뽑기 화면 버튼 여러 개가 44px보다 작다 (AC24)
- 재현 (코드 계산 — Studio에서 확인할 것):
  1. Studio Device 에뮬레이터 iPhone 가로(예 844×390) → 탈의실 → "🎫 뽑기".
  2. 📦 목록 탭에서 카드를 눌러 상세의 "입기"·표정 썸네일, 🎫 뽑기 탭의 "뽑기 시작하기", 📊 확률 탭의 ⓘ, ⓘ 창의 ✕, 결과 창의 "확인"·"입기" 높이를 본다 (Explorer에서 `AbsoluteSize`).
- 기대: 스펙 UI 11·AC24 "모든 버튼 44px 이상" (`Config.Ui.MinTouchSize = 44`, 다른 화면은 `UiLayout.touchSize`로 Offset 크기를 정함 — `ShopScreen.luau:613`).
- 실제: `DrawScreen.setLayout`은 닫기 ✕와 탭 줄만 `touchSize`로 맞추고, 나머지는 부모 비율(Scale) 크기이거나 고정 44 Offset이다. 844×390 기준(UIScale = clamp(390/720, 0.6, 1.25) = 0.6, 창 374px, 탭 줄 아래 내용 약 320px)으로 계산하면:
  | 버튼 | 크기 정의 | 실제 높이(약) |
  |---|---|---|
  | 상세 "입기" | 상세판(내용 × 0.45) × 0.12 | **17px** |
  | 표정 썸네일 4칸 | 상세판 × 0.2 | **29px** |
  | ⓘ, ⓘ 창 ✕ | `fromOffset(44, 44)` × UIScale 0.6 | **26px** |
  | 결과 "확인"·"입기" | 결과 창(창 × 0.9) × 0.11 | **37px** |
  | "🎫 뽑기 시작하기" | 단상 칸(내용 × 0.84) × 0.14 | **38px** |
  - UIScale이 Scale 크기에도 곱해진다면 더 작아진다. 어느 쪽이든 44px 아래.
  - 큰 화면(PC)은 문제 없음(1366×768에서 상세 "입기" 약 32px — 마우스라 AC 대상 아님).
- 위치: `src/client/ui/DrawScreen.luau:367-372`(ⓘ), `:501-516`(표정 썸네일), `:525-530`(상세 입기), `:577-581`(ⓘ 창 ✕), `:741-753`(결과 확인·입기), `:327-332`(뽑기 시작하기), `:1208-1243`(`setLayout` compact 분기가 위 버튼들을 건드리지 않음)
- 고치는 방향(제안): `setLayout`에서 위 버튼들의 높이를 `UiLayout.touchSize(44, m)` Offset으로(가로는 Scale 유지 가능), 상세판은 휴대폰에서 스펙대로 겹치는 창으로 키우거나 상세판 높이를 늘린다. 고친 뒤 순수 계산 테스트(예: compact 지표에서 버튼 높이 ≥ `px(44, scale)`)를 두면 좋다.

### [P3] B2 결과 연출(두근두근) 중에 배경의 보유 목록·단상이 결과보다 먼저 바뀔 수 있다
- 재현: `unlockAllSkinsInStudio = false`, 티켓 여러 장 → "뽑기 시작하기" → 1.2초 두근두근 동안 결과 창 바깥(왼쪽 아래 "보유 스킨 목록 n/9", 카드 🔒, 단상 대표 스킨)을 본다.
- 기대: 결과는 결과 창에서 처음 알게 된다(등급을 색으로 먼저 알려 주는 연출).
- 실제(코드): 서버는 바로 답하고 `DataService.update`가 `ProfileUpdated`를 보내므로, 클라이언트가 `SUSPENSE_TIME`을 기다리는 사이 `ShopController` `render` → `drawScreen:render` → `paint`가 돌아 카드 잠금이 풀리고 n/9가 늘고 대표 스킨이 바뀐다. 결과 막은 `BackgroundTransparency = 0.25`이고 결과 창(가로 62%)이 목록 판 왼쪽을 다 덮지 못한다.
- 위치: `src/client/ui/ShopController.luau:101-111`, `src/client/ui/DrawScreen.luau:1108-1113`(busy 중에도 paint), `:611-619`
- 영향: 판정·보상과 무관한 연출 문제. 고치려면 busy 동안 `render`가 상태만 저장하고 `reveal` 뒤에 paint.

### [P3] B3 휴대폰 배치가 스펙 UI 11과 다르고 결정 기록에 없다
- 스펙: 왼쪽 열을 위쪽 한 줄로 접고, 상세는 겹치는 창. 구현: 탭 3개("🎫 뽑기 / 📊 확률 / 📦 목록"), 상세는 목록 아래 반쪽(`DrawScreen.luau:1236-1239`). 개발 메모 "Studio 확인 방법" 5에는 적혀 있지만 "결정 기록 (개발)"에는 없다.
- 탭 방식 자체는 겹침이 없어 괜찮아 보인다. 사용자가 Studio에서 보고 정하면 결정 기록에 남긴다(B1을 고칠 때 상세를 겹치는 창으로 바꾸면 같이 해결).

## 서버 판정 · 보안 체크
- [x] 클라이언트 인자 검증: `DrawTicket` 핸들러는 `function(player: Player)`로 인자를 받지 않고 `pcall(onDraw, player)`만 부른다(`ShopService.luau` `init`). 요청 간격 `Config.Draw.RequestCooldown`은 프로필 확인보다 먼저, 상점 간격과 따로(`lastDrawAt`, 나갈 때 정리). 관리자 `tickets`는 `AdminLogic.parse`(정수 −99~99) + `canRun`(StudioOnly, PersistOn 거절). QA 테스트 "QA 서버: onDraw는 클라이언트 인자·속성을 쓰지 않고…"
- [x] 판정은 서버만: 등급·스킨 결정은 서버 `Random` 하나 + 순수 `DrawLogic.roll`, 티켓 −1과 보상은 `DataService.update` 한 번 안에서 `canDraw`를 다시 본 뒤 `apply`. 클라이언트는 받은 `DrawResult`만 그린다(`DrawScreen.reveal`이 `result.kind/skinId/grade/coins`만 사용, 확률표는 같은 `DrawLogic.grades()`로 그림 — 판정에 쓰지 않음).
- [x] 클라이언트 Attribute로 권한 판단 없음: `onDraw`·`onEquip`에 `GetAttribute` 없음(QA 테스트). Studio 전부 입기는 서버 `RunService:IsStudio()`·`Config.DEBUG`만, 화면에는 `ProfileView.studioUnlockAll`(표시용). `ownedSkins`에 쓰는 곳은 `apply`뿐이고 `onEquip`은 쓰지 않음.
- [x] 티켓을 얻는 길: `drawTickets`를 바꾸는 곳은 `RewardService`(Won)·`AdminCommands`(StudioOnly)·`DrawLogic`·`ProfileLogic`(migrate)·`ProfileSchema.new`뿐(QA 테스트가 `src` 전체를 훑음). 상품·코드·결제 모듈에 `drawTickets` 없음, 코드 표에 `tickets`를 적어도 `CodeLogic.validateConfig`가 버림, 특 스킨은 묶음·VIP 패스에 넣을 수 없음.
- [x] Remotes 개수: RemoteFunction 16 + RemoteEvent 11 = 27 (`m5-03-foundation`, `m5-31-draw-logic` AC13).
- [x] 맵 상태 `ctx`: 해당 없음(맵 변경 없음).
- [x] 정리: `lastDrawAt`는 `PlayerRemoving`에서 지움. 클라이언트 `RenderStepped` 연결은 화면을 닫을 때 끊음(`stopSpin`).
- 참고(버그 아님): `onDraw`의 `canSave = DataService.canPersist(player) or RunService:IsStudio()` — Studio에서 저장을 켰는데 세션 잠금을 못 얻은 임시 프로필도 뽑을 수 있지만, 그 프로필은 저장되지 않아 결과가 남지 않는다. 실서버 임시 프로필은 `CannotSave`로 거절.

## 기존 테스트 변경 검토 (AC15, `git diff ab91c52 a5bc3f2 -- tests/`)
- `m5-27-concept-skin`·`m5-28-concept-skins`·`m5-29-concept-skins-2`: 바뀐 곳은 카탈로그 이름("(특)", "(테스트)"·"콘셉트" 없음 확인을 **추가**), `drawGrade` 확인 추가, 보유 규칙(`isFree` false, 미보유 `NotOwned`, 코인 `NotForCoins`, 로벅스 `NotRobux`, 보유하면 장착·`Locked`), 카드 글씨, migrate 기대값(미보유 → tamago, 보유 → 유지), validate 오류 문구 하나. 몸 레이아웃·발바닥·관절·표정·파츠 상한(`BUDGET = 70`)·겹침·렌더 검사 줄은 diff에 없음 → **약화 없음**.
- `m5-28-qa`·`m5-29-qa`: "전체 탭에만" → "전체·🎫 특 탭에만", 다른 등급 탭에 없음 검사는 유지. migrate 확인은 보유/미보유 두 경우로 늘어남.
- `skins.spec`: 이름 표만. `shop-logic`·`m5-07-qa`: 탭 수 +1과 `draw` 탭 위치 확인 추가. `m4-foundation`·`m5-03-*`·`m4-07-data-qa`: VERSION 3, 미래 버전 4, 리모트 27(+ 16/11 분리 확인 추가), DEBUG 기본값 `unlockAllSkinsInStudio = true` 추가. `reward-logic`: Won 묶음에 `tickets = 1`. `admin-logic`: info 줄 🎫, `tickets` 등급. `camera-priority`: SfxCues 2개. `m4-14-qa`·`m5-08-qa`: 가짜 모듈 표에 DrawLogic.
- 기대값을 구현에 맞춰 느슨하게 바꾼 곳은 찾지 못했다.

## DrawScreen 코드 리뷰 (샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png`과 비교)
- 구성: 나무 간판 "👑 스킨 뽑기"(기울임·그라데이션·테두리), 보유 뽑기권 상자 ×N, "1등만…" 안내, 가운데 단상 + 대표 스킨 인형(회전·숨쉬기) + "○○ 획득 가능!" 말풍선, 노란 "🎫 뽑기 시작하기 >", 오른쪽 "스킨 등급별 확률 ⓘ" 5줄(등급색, 전설 줄 진하게, 빈 등급 회색 "준비 중") + 안내, ✕, 아래 남색 띠의 보유 목록 n/총수 격자 + 상세(등급 배지·이름·대사·큰 인형·표정 4칸·입기). 샘플 구성을 모두 따름. 단상은 2D 둥근 Frame(개발 결정 기록에 있음).
- 결과: 서버 `DrawResult`만 사용(`reveal`), 결과 전 최소 1.2초 두근두근(돔 들썩임), 등급색 빛·빛줄기(영웅·전설은 빛줄기 전부·빛 더 크게), 새 스킨이면 "입기"(자동 장착 없음), 중복이면 "이미 가진 스킨이에요 → 🍚 +N"·입기 없음. 연타: 클라이언트 `drawing`·`busy` 두 겹 + 서버 1초 간격 + update 안 재확인.
- 휴대폰: 탭 3개로 나눔(B3), 확률표 영어 괄호 뺌, 목록 3열, 결과 창 넓힘. 버튼 크기는 B1.
- 숨김: 탈의실 버튼이 숨으면 뽑기 화면도 닫음(`ShopController.luau` 135-140), 서버도 `isLocked`로 거절.

## 사용자 Studio 확인 체크리스트
준비: worktree를 Rojo로 연결(`rojo serve`, 포트는 worktree마다 다름), `Config.DEBUG.minPlayersToStart = 1`.

1. **Studio 전부 입기 (AC23)** — 커밋 값 그대로 Play.
   - 서버 Output에 `[ShopService] Studio: all skins can be worn without owning them (not saved, m5-31)` 한 줄.
   - 🍣 스킨 → 탈의실 모든 카드(판매·시즌·VIP·🎫 특)가 "입기 (Studio)". 하나 입으면 내 캐릭터가 바뀜.
   - Test 탭 "Clients and Servers"로 플레이어 2명 → 다른 창에서도 바뀐 모습이 보이는지.
   - 🎫 뽑기 화면의 "보유 스킨 목록"이 **0/9**인지(저장된 보유가 늘지 않음).
2. **티켓 받기 (AC18)** — `Config.DEBUG.unlockAllSkinsInStudio = false`로 바꾸고 Play.
   - 혼자 방을 만들어 한 판 끝까지(우승) → 토스트 "+1 🎫 우승 뽑기권", 우승 정산 줄 "이번 판 +… 🍚 🎫 +1 (총 …)", 🍣 스킨 버튼에 빨간 배지 "1".
   - 🛠 → 명령 탭 "+98" → 배지 99 → 다시 우승 → 토스트 "🎫 뽑기권이 가득 찼어요 (99장)", 99 그대로.
3. **뽑기 화면 (AC19)** — 🛠 명령 탭 "0으로" → "+10" 세 번(30장) → 탈의실 머리줄 "🎫 뽑기 30".
   - 샘플 그림과 나란히: 왼쪽 위 나무 간판 "스킨 뽑기", "보유 중인 뽑기권 ×30", "1등만…" 안내, 가운데 연어초밥 (특) 인형이 돌고 "연어초밥 (특) 획득 가능!", 노란 "🎫 뽑기 시작하기 >", 오른쪽 확률표 **전설 준비 중(회색) / 영웅 5.0% / 희귀 15.2% / 고급 30.3% / 일반 49.5%**, 오른쪽 위 ✕.
   - ⓘ → 스킨별 "각 5.05%"(연어·성게·문어·연어알), "각 10.10%"(유부·장어·참치), "각 24.75%"(새우·계란), "중복이면 🍚 +20/40/80/150/300", 맨 아래 반올림 안내.
4. **뽑기 결과 (AC20)** — "뽑기 시작하기".
   - 약 1.2초 뚜껑 접시가 들썩 → 등급색 빛 → "👑 스킨 획득!" + 인형 + "이름 [등급]" + "입기"·"확인".
   - "입기" → 바로 입힘("○○ 입었어요!"). 보유 목록 n/9가 1 늘고 단상 대표 스킨이 바뀜(아직 없는 가장 높은 등급).
   - **B2 같이 보기**: 두근두근 동안 결과 창 바깥의 n/9·카드 🔒가 먼저 바뀌는지.
   - 여러 번 뽑아 중복이 나올 때 "이미 가진 스킨이에요 → 🍚 +N"(일반 20 / 고급 40 / 희귀 80 / 영웅 150), 코인 배지가 N 늘고 "입기" 없음.
   - 버튼을 빠르게 여러 번 눌러도 티켓이 한 장씩만 줄어드는지. 서버 Output에 뽑을 때마다 `[Draw] 이름(UserId) -> skin …` 또는 `-> duplicate … +N …` 한 줄. 꽝은 한 번도 안 나와야 함.
   - 티켓 0장 → 버튼 회색 + "우승하면 🎫 뽑기권을 받아요".
5. **보유 목록·상세 (AC21)** — 가진 카드는 인형·이름·등급 배지, 안 가진 카드는 어두운 실루엣 + 🔒 "아직 없어요", 입는 중은 금색 테두리. 카드를 누르면 상세(등급 배지·이름·대사·큰 인형·표정 4칸 — 누르면 큰 인형 표정이 바뀜·"입기"/"입는 중"/"🎫 뽑기로 얻기").
6. **잠금 (AC22)** — 뽑기 화면을 연 채 방에서 판을 시작 → 카운트다운·소개 때 탈의실과 같이 닫히는지. 달리는 중·탈락 연출·우승 연출 중에도 못 여는지. (서버 쪽 거절은 달리는 중 Client 창 명령 바에서 `game.ReplicatedStorage.Remotes.DrawTicket:InvokeServer()`를 불러 서버 Output `[Draw] … -> rejected Locked`와 티켓 수 그대로인지로 확인. Remotes 폴더 위치가 다르면 Explorer에서 `DrawTicket`을 찾아 그 경로로.)
7. **저장 켠 Studio** — `persistDataInStudio = true`(실제 DataStore를 쓰므로 테스트 계정으로만) → 서버 경고 `unlockAllSkinsInStudio is off because persistDataInStudio is on (m5-31)` 한 줄, 카드가 "입기 (Studio)"가 아님. 🛠 `tickets`는 "저장을 켠 Studio에서는 쓸 수 없어요". 확인 뒤 `false`로 되돌림.
8. **휴대폰 (AC24, B1)** — Device 에뮬레이터 iPhone 가로 등(짧은 변 ≤ 500).
   - 탭 "🎫 뽑기 / 📊 확률 / 📦 목록"이 겹치지 않고, 확률표 5줄이 "전설 / 영웅 …"(영어 괄호 없음)로 잘리지 않는지.
   - Explorer에서 `PlayerGui.DrawGui` 아래 버튼들의 `AbsoluteSize.Y`: "입기"·표정 썸네일·ⓘ·ⓘ 창 ✕·결과 "확인"/"입기"·"뽑기 시작하기"가 44 이상인지 (QA 계산으로는 17~38px — B1).

## 추가한 테스트
- `tests/m5-31-qa.spec.luau` (18개):
  - 롤: 정확한 누적값 경계(`<`)·0·1.0·NaN·음수, rng 호출 횟수와 `NextInteger(1, n)`, 범위 밖 `NextInteger` 잘림, 뽑기 풀 = `DRAW_IDS`(계란초밥·VIP 없음)·kind는 Skin/Duplicate만
  - 적용: roll 뒤 보유가 생기면 Duplicate + 등급 코인, `canDraw` 잘못된 티켓 값, `addTickets` nil·NaN·음수·상한·빼기
  - migrate v2 → v3 경계값과 다른 값 보존
  - 표시: 빈 등급 31조합 chance 합 1·표시 합 100.0, 스킨별 %, 화면 = 서버(소스)
  - 서버 원칙: onDraw 인자·속성 없음, update 안 재확인, 간격 먼저, 전부 입기는 서버 설정만·`ownedSkins` 안 바꿈, 티켓을 바꾸는 파일 목록, RewardService 같은 update·ticketsFull
  - 대표 스킨 순서, 판매 금지(묶음·패스·결제·코드), 이벤트 기간 우승 1장·통과/탈락/결승 패배 0장

## 인계 메모
- 브랜치: `m5-31-winner-ticket-draw` (worktree `.claude/worktrees/agent-a6786423e039151fb`). main 병합은 하지 않았음.
- 끝난 것: 검증 5단계(1906 passed, 0 failed), AC1~AC16 lune 확인, 서버·보안 리뷰, 기존 테스트 diff 리뷰, DrawScreen 리뷰, QA 테스트 18개, 이 리포트, 스펙 상태 `in-dev`.
- 남은 것: developer가 B1(휴대폰 버튼 44px) 고치기 — 필요하면 B2·B3도. 그 뒤 재QA(B1 계산 다시 + Studio 체크리스트 8), 사용자 Studio 확인 1~8, 뽑기 소리 id(사용자).
- 다음에 할 첫 단계: developer가 `src/client/ui/DrawScreen.luau` `setLayout`에서 B1 표의 버튼 높이를 `UiLayout.touchSize(44, m)` Offset으로 바꾸고 상세판을 휴대폰에서 키움(또는 겹치는 창).
- 막힌 점: 없음. 휴대폰 실제 픽셀은 Studio 에뮬레이터로 최종 확인해야 함(렌더러 없음).
