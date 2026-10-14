status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-31 — 우승자 뽑기 티켓 (🎫 무료 뽑기 · 특 스킨 9종 · Studio 전부 입기)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1 (원칙 — v0.7에서 "무료 뽑기" 규칙 추가), §9.2 (특 스킨 9종), §9.4 (꽝 위로 코인), §9.6 (새 절 "우승자 뽑기 티켓"), §10 (탈의실), §11.5 (프로필 v3), §11.7 (관리자 `tickets`, Studio 전부 입기)
- 조사: [`docs/REFERENCE-winner-ticket-draw.md`](../REFERENCE-winner-ticket-draw.md), [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) §5
- 담당 개발 worktree: 브랜치 `m5-31-winner-ticket-draw` — **m5-29(QA 중)와 m5-30(콘셉트 토핑 퀄리티)이 main에 병합된 뒤 그 main에서 시작**. 두 작업이 `Skins.luau`·`SushiBody.luau`·`tests/m5-27~29-*.spec.luau`를 같이 건드리기 때문(병합 충돌·테스트 기대값 충돌을 피함).
- 공용 파일 수정 담당: **이 스펙의 developer 한 명** (`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`). 이 작업 중에는 다른 에이전트가 이 세 파일을 고치지 않는다. `Attributes`·`maps/*`·`default.project.json`·init 스크립트·`rokit.toml`은 안 건드린다(서비스가 새로 생기면 init에 넣어야 하는데, 이 스펙은 **새 서비스를 만들지 않고** `ShopService` 안에 둔다 — 아래 "구조").

## 목표
결승에서 1등(`Won`)을 하면 🎫 티켓 1장을 받고, 탈의실에서 티켓으로 뽑기를 한다. 10%는 콘셉트 몸 스킨 "○○ (특)" 9종 중 아직 없는 하나, 90%는 꽝(위로 🍚 +20). 특 스킨은 **뽑기로만** 얻는 "자랑할 만한" 스킨이 된다. 개발자는 Studio에서 저장 없이 모든 스킨을 입어 볼 수 있다.

## 범위
- 포함
  1. **특 스킨 9종으로 바꾸기**: 콘셉트 스킨 9종(`concept-salmon`·`tuna`·`shrimp`·`tamago`·`ikura`·`unagi`·`uni`·`tako`·`inari`)을 무료 실험 스킨에서 **뽑기 전용**으로. 이름 변경(아래 표), `Skins.isFree`는 계란초밥만 true, 저장 `ownedSkins`에 들어가는 진짜 보유가 된다. 모양·대사·order는 그대로.
  2. **티켓 지급**: `RewardService`가 `Won`(부전승 포함)에서 티켓 +1. 이벤트·VIP 배수 없음. 상한 99.
  3. **뽑기**: RemoteFunction `DrawTicket` 하나. 서버 RNG, 판단은 순수 `DrawLogic`, 지급은 `DataService.update` 한 번(티켓 −1 + 보상).
  4. **탈의실 UI**: 🎫 뽑기 패널(티켓 수·확률 표·뽑기 버튼·결과 연출), "🎫 특" 탭, 미보유 특 스킨 카드 "🎫 뽑기로 얻기", 🍣 스킨 버튼에 티켓 수 배지.
  5. **Studio 전부 입기**: `Config.DEBUG.unlockAllSkinsInStudio`(커밋 기본 `true`).
  6. **관리자 명령 `tickets <n>`** (StudioOnly 등급).
  7. 프로필 v3(`drawTickets`), 마이그레이션.
  8. 기존 m5-27/28/29 테스트 중 "무료·모두 보유·이름 (테스트)"를 고정한 기대값을 새 규칙에 맞게 바꾸기.
  9. m5-26 현지화가 main에 있으면 문자열 키(AC17).
- 제외
  - 티켓을 Robux·코인·이벤트 재화·코드·특별 상품·VIP로 주거나 파는 것 (**금지**, GDD 9.1 v0.7)
  - 천장(몇 번 꽝이면 보장) — 열린 질문 1
  - 한 번에 여러 장 뽑기(10연차) — 한 번에 1장만
  - 스킨 교환·거래, 특 스킨 판매
  - 특 스킨 모양 변경(m5-30 몫), 새 특 스킨 추가
  - 뽑기 소리 id(사용자가 고름 — `SfxCues`에 이름만, 무음)

## 정한 값 (기본값, 플레이테스트 후 조정 — `Config.Draw`)
| 키 | 값 | 뜻 | 근거 |
|---|---|---|---|
| `TicketsPerWin` | 1 | 우승 1번에 티켓 | 사용자 결정 1 |
| `MaxTickets` | 99 | 가질 수 있는 최대 장수. 가득이면 우승해도 안 늘어남(토스트로 알림) | REFERENCE-winner-ticket-draw §3 |
| `SkinChance` | 0.10 | 스킨 당첨 확률 | 사용자 결정 1 |
| `ConsolationCoins` | 20 | 꽝 위로 🍚 | 사용자 결정 1 |
| `DuplicateCoins` | 100 | 9종을 다 가진 뒤 스킨 당첨분 대신 🍚 | 사용자 제안, REFERENCE §3 |
| `RequestCooldown` | 1 | `DrawTicket` 요청 간격(초) | 결과 연출(약 1.5초)보다 짧게, 연타 방지 |

### 특 스킨 이름 (사용자 결정 3 — "콘셉트"·"(테스트)" 빼고 "(특)")
| id | 지금 이름 | 새 이름 | en (AC17) | 같은 음식 판매·기본 스킨 |
|---|---|---|---|---|
| `concept-salmon` | 콘셉트 연어초밥 (테스트) | **연어초밥 (특)** | Salmon Sushi (Special) | 연어 |
| `concept-tuna` | 콘셉트 참치초밥 (테스트) | **참치초밥 (특)** | Tuna Sushi (Special) | 참치 |
| `concept-shrimp` | 콘셉트 새우초밥 (테스트) | **새우초밥 (특)** | Shrimp Sushi (Special) | 새우 |
| `concept-tamago` | 콘셉트 계란초밥 (테스트) | **계란초밥 (특)** | Tamago Sushi (Special) | 계란초밥(기본) |
| `concept-ikura` | 콘셉트 연어알 군함 (테스트) | **연어알 군함 (특)** | Salmon Roe Gunkan (Special) | 연어알 군함 |
| `concept-unagi` | 콘셉트 장어초밥 (테스트) | **장어초밥 (특)** | Eel Sushi (Special) | 장어 |
| `concept-uni` | 콘셉트 성게 군함 (테스트) | **성게 군함 (특)** | Sea Urchin Gunkan (Special) | 성게 |
| `concept-tako` | 콘셉트 문어초밥 (테스트) | **문어초밥 (특)** | Octopus Sushi (Special) | 문어 |
| `concept-inari` | 콘셉트 유부초밥 (테스트) | **유부초밥 (특)** | Inari Sushi (Special) | 유부 |

- id는 바꾸지 않는다(저장·렌더 도구·테스트가 id를 씀).
- 판매 스킨 "연어알 군함"과 "연어알 군함 (특)"처럼 앞부분이 같아도 "(특)"과 카드 표시(🎫 특 배지)로 구분한다.

## 구조 (개발 안내 — 바꿔도 되지만 결정 기록에 남긴다)
- **카탈로그** `shared/Skins.luau`
  - 9종에 `draw = true`(얻는 길 = 뽑기). `experimental = true`는 **몸 모양 예외 표시로 남긴다**(`SushiBody.EXPERIMENTAL`의 파츠 상한 — m5-30이 70으로 올림). 주석의 "무료 테스트" 설명은 "뽑기 전용 특 스킨"으로 고친다.
  - `Skins.DRAW_IDS`(명시 목록, 9종). `draw = true`는 이 목록에 있는 id만, 뽑기 스킨은 `robux`·`coins`·`tokens`·`season`·`vipOnly`·`productId`가 모두 nil(validate가 잡음). 지금은 `DRAW_IDS` = `EXPERIMENTAL_IDS`(테스트로 고정).
  - 내부 `tier`는 `"Basic"` 그대로 둔다(등급별 효과·외곽 표를 건드리지 않게). 화면에서는 등급 대신 **"🎫 특"** 표시(카드 테두리 색은 새 상수 `Skins.DRAW_INFO = { displayName = "특", color = … }`, 금빛/주황 계열 — developer가 정함).
  - `Skins.isFree(id)` = 계란초밥만 true. `Skins.isDraw(id)` 추가.
  - validate: 기본 스킨이 아닌 Basic 등급은 `draw = true`인 것만 허용(지금 규칙 "only the default skin is Basic"의 예외를 experimental → draw로 옮김). "얻는 길 정확히 하나" 규칙에서 draw를 하나의 길로 센다.
- **순수 로직** `shared/DrawLogic.luau` (Roblox API 없음)
  - `DrawLogic.pool(ownedSkins) -> { string }`: `Skins.LIST` 중 `draw = true`이고 안 가진 id, **order 순**(결정적).
  - `DrawLogic.odds(ownedSkins) -> { { kind, skinId?, chance, coins? } }`: 남은 수 N > 0이면 스킨마다 `SkinChance / N` + 꽝 `1 − SkinChance`; N = 0이면 "대체 🍚 DuplicateCoins" `SkinChance` + 꽝. chance 합 = 1(부동소수 오차 1e-9 안).
  - `DrawLogic.canDraw(wallet, locked, canSave) -> (ok, reason?)`: 이유 `NoTickets` / `Locked` / `CannotSave`.
  - `DrawLogic.roll(ownedSkins, rng) -> DrawOutcome`: `rng:NextNumber()` 한 번 → `< SkinChance`면 N > 0일 때 `rng:NextInteger(1, N)`로 pool에서 하나(kind `"Skin"`), N = 0이면 kind `"Duplicate"`(coins = DuplicateCoins); 아니면 kind `"Consolation"`(coins = ConsolationCoins). rng는 `NextNumber`·`NextInteger`가 있는 표를 받는다(테스트는 가짜 rng·고정 시드).
  - `DrawLogic.apply(wallet, outcome) -> DrawResult`: 티켓 −1, 스킨이면 `ownedSkins[id] = true`(장착은 안 바꿈), 코인이면 `coins += n`. `DataService.update` 안에서 부른다.
  - `DrawLogic.addTickets(current, n) -> (newValue, added)`: 0 ~ MaxTickets로 자름(우승 지급·관리자 명령이 같이 씀).
  - `DrawLogic.oddsText(odds) -> { string }`: 화면 확률 줄(아래 UI). 퍼센트는 소수 1자리, 스킨별 줄은 "각 1.1%"처럼 묶어서.
- **서버** `ShopService`에 `DrawTicket` 핸들러를 더한다(새 서비스 파일을 만들지 않아 init 스크립트를 안 건드림). 순서: 요청 간격(`Config.Draw.RequestCooldown`, 기존 `Config.Shop.RequestCooldown`과 **따로** 센다) → 프로필 로드됨 → `ShopService.isLocked` → `canPersist`(실서버 임시 프로필이면 `CannotSave`, Studio 메모리 모드는 허용) → `DataService.update` 한 번 안에서 다시 `canDraw` 확인 + `roll`(서버 `Random.new()` 하나를 서비스가 들고 있음) + `apply` → `ProfileUpdated`. 반환 `(true, nil, DrawResult)` / `(false, reason)`. 서버 Output 로그 한 줄: `[Draw] 이름(UserId) -> skin concept-uni (left 7, tickets 3)` / `-> consolation +20 (tickets 2)` / `-> duplicate +100 (tickets 0)` / `-> rejected NoTickets`.
  - 클라이언트가 보낸 인자는 받지 않는다(있어도 무시). 확률·결과는 서버만 정한다.
  - `saveNow`는 부르지 않는다(무료 보상 — 평소 자동 저장·나갈 때 저장). 개발 메모에 이유를 남긴다.
- **지급** `RewardService`/`RewardLogic`: `onResult`의 `Won` 묶음에 `tickets = Config.Draw.TicketsPerWin`. 지급은 기존 코인 지급과 **같은 `DataService.update`** 안에서 `DrawLogic.addTickets`. 가득이면 added = 0 → `RewardGrant.tickets = 0`, `ticketsFull = true`. 이벤트 기간·VIP여도 1장.
- **Studio 전부 입기**: 서버에서 `unlockAll = RunService:IsStudio() and Config.DEBUG.unlockAllSkinsInStudio and not Config.DEBUG.persistDataInStudio` (순수 함수 `ShopLogic.unlockAllActive(isStudio, flag, persist)` — `fakeRobuxActive`와 같은 모양). 켜져 있으면 `EquipSkin`이 카탈로그의 모든 스킨(시즌·VIP·특 포함)을 보유 확인 없이 받고, 장착 resolver(`equippedOf`)도 보유를 보지 않는다. **`ownedSkins`에는 아무것도 넣지 않는다.** 뽑기 후보·구매 판단은 저장된 `ownedSkins`만 본다(그래서 Studio에서도 뽑기·코인 해금 흐름을 시험할 수 있다). 클라이언트에는 `ProfileView.studioUnlockAll`로 알려 카드에 "입기 (Studio)"를 보여 준다. 실서버에서는 플래그가 무엇이든 꺼짐. `persistDataInStudio = true`면 꺼지고 서버 시작 때 경고 한 줄.

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1 (카탈로그): 9종의 이름이 위 표 "새 이름"과 같고 "(테스트)"·"콘셉트"가 없다. 9종 모두 `draw = true`, 가격·얻는 다른 길 없음, id·order·대사·`experimental`은 그대로. `Skins.DRAW_IDS`(9) = `Skins.EXPERIMENTAL_IDS` = `SushiBody.EXPERIMENTAL`의 id(정확한 목록 비교). `Skins.validate` 통과. 목록 밖 id에 `draw`를 달거나, 뽑기 스킨에 `robux`·`coins`·`tokens`·`season`·`vipOnly`·`productId` 중 하나라도 붙이면 validate가 잡는다.
- [ ] AC2 (무료 아님): `Skins.isFree`는 계란초밥만 true, 특 스킨 9종은 false. 새 프로필(`ProfileSchema.new`)에서 특 스킨 `ShopLogic.canEquip` → `NotOwned`, `canBuyWithCoins`·`ReceiptLogic`의 로벅스 지급 판단·`BuyWithTokens` 판단은 모두 거절(이유는 기존 "팔지 않음" 계열). `ownedSkins[id] = true`가 있으면 장착 가능.
- [ ] AC3 (마이그레이션 v3): `ProfileSchema.VERSION = 3`, 새 프로필 `drawTickets = 0`. v2 프로필(`drawTickets` 없음) → 0으로 이전, 다른 값 손실 없음. `drawTickets`가 음수·소수·NaN·문자열이면 0(노트 남김), 99 초과면 99. v2 프로필에서 `equippedSkin`이 특 스킨이고 `ownedSkins`에 없으면 `tamago`로 바뀐다(노트). `ownedSkins`에 특 스킨이 있으면 장착값 유지. `toView`에 `drawTickets` 포함.
- [ ] AC4 (풀·확률): `DrawLogic.pool`은 안 가진 특 스킨만 order 순. `odds`의 chance 합 = 1(±1e-9), 남은 N종이면 스킨 각 `0.10 / N`, 꽝 0.90. 9종 다 가지면 `Duplicate` 0.10 + 꽝 0.90. 계란초밥·판매 스킨은 풀에 절대 없다.
- [ ] AC5 (뽑기 판정, 가짜 rng): `NextNumber`가 0.0999 → 스킨, 0.10 → 꽝(경계는 `< SkinChance`). 스킨일 때 `NextInteger(1, N)`의 값대로 pool의 그 스킨. 남은 게 0이면 `Duplicate`(코인 100). 꽝이면 코인 20.
- [ ] AC6 (분포, 고정 시드): `Random.new(시드)` 같은 결정적 rng로 100,000번 `roll`(빈 보유) → 스킨 비율 0.10 ± 0.005, 9종 각각 1/9 ± 0.01(스킨 당첨 안에서). 이미 가진 스킨은 한 번도 안 나온다(보유 4종으로 따로 확인).
- [ ] AC7 (적용): `apply`는 티켓을 정확히 1 줄이고, 스킨이면 `ownedSkins`에 넣고 `equippedSkin`은 안 바꾸고 코인 그대로, 꽝·대체면 코인만 +20/+100. `canDraw`는 티켓 0이면 `NoTickets`, 잠금이면 `Locked`, 저장 불가면 `CannotSave`이고 이때 `apply`는 불리지 않는다(지갑 변화 0).
- [ ] AC8 (지급): `RewardLogic.onResult(…, "Won")` 묶음에 `tickets = 1`(이벤트 기간 `now`로 불러도 1). `Passed`·`Eliminated`·결승 출발·하루 첫 판에는 티켓 없음. `DrawLogic.addTickets(98, 1)` → 99, `addTickets(99, 1)` → 99와 added 0. `RewardLogic.simulate` 같은 기존 시뮬레이션에 우승자 티켓 합계가 보인다(기존 코인 결과 불변).
- [ ] AC9 (Studio 전부 입기): `ShopLogic.unlockAllActive(isStudio, flag, persist)`는 `(true, true, false)`만 true. 켜진 상태의 `canEquip`은 모르는 id만 거절(`UnknownSkin`)하고, 잠금이면 여전히 `Locked`. 켜져 있어도 `DrawLogic.pool`·`canBuyWithCoins` 결과는 저장된 `ownedSkins`로만 정해진다. `Config.DEBUG.unlockAllSkinsInStudio`의 **커밋 값은 `true`**(테스트로 고정, 다른 DEBUG 기본값 테스트와 같은 곳).
- [ ] AC10 (관리자 명령): `AdminLogic.commandTier("tickets") = "StudioOnly"`. 인자는 정수 −99 ~ 99(벗어나거나 정수가 아니면 `BadArgs`), 결과는 0 ~ 99로 자름. `persistDataInStudio = true`면 거절, 실서버 거절(기존 StudioOnly 규칙 그대로). `AdminService` 소스에 `DrawLogic`·`DataService`가 없다(경제 명령은 `AdminCommands`).
- [ ] AC11 (리모트·타입): `Remotes`의 RemoteFunction 16개(+`DrawTicket`), RemoteEvent 11개 그대로 — 리모트 개수 테스트 갱신. `Types.ProfileView`에 `drawTickets: number`, `studioUnlockAll: boolean`, `Types.RewardGrant`에 `tickets: number?`·`ticketsFull: boolean?`, `Types.DrawResult = { kind: "Skin" | "Consolation" | "Duplicate", skinId: string?, coins: number, ticketsLeft: number, skinsLeft: number }`.
- [ ] AC12 (탈의실 로직): `ShopLogic.tabs`에 "🎫 특" 탭(전체 다음), 이 탭은 특 스킨 9종을 order 순(가진 것·안 가진 것 모두). 특 스킨은 "기본" 탭에서 빠진다(기본 탭 = 계란초밥만). "전체" 탭에는 그대로 있다(시즌 한정처럼 숨기지 않음). 안 가진 특 스킨 `cardState`는 새 상태 `"Draw"`이고 `cardButtonText` = "🎫 뽑기로 얻기", 로벅스·코인 버튼 없음. `studioUnlockAll = true`인 view에서는 안 가진 스킨도 "입기 (Studio)".
- [ ] AC13 (기존 테스트): m5-27·28·29(그리고 m5-30) 테스트에서 "무료·새 프로필에서 입기·`AlreadyOwned`·이름 '(테스트)'"를 고정한 기대값을 새 규칙(위 AC1·AC2)으로 **바꾼다**. 모양·관절·파츠 상한·렌더 관련 검사는 약화 없이 그대로 통과. 바꾼 테스트 목록을 개발 메모에 적는다.
- [ ] AC14: 검증 5단계 통과(rojo build, stylua, selene, `lune run tests` "N passed, 0 failed", luau-lsp 끝 코드 0). 돌리지 못한 단계는 보고에 그대로 적는다.

### Studio 확인
- [ ] AC15 (티켓 받기): `minPlayersToStart = 1`로 혼자 한 판 끝까지 → 우승 토스트와 함께 "+1 🎫 우승 뽑기 티켓", 순위표 "이번 판"에 🎫 +1, 🍣 스킨 버튼에 빨간 배지 "1". 관리자 `tickets 98` 뒤 우승 → 99, 한 번 더 우승 → "🎫 티켓이 가득 찼어요 (99장)" 토스트, 99 그대로.
- [ ] AC16 (뽑기): `unlockAllSkinsInStudio = false`로 바꾸고 `tickets 30` → 탈의실 "🎫 뽑기" 패널: "🎫 30장", 확률 줄("스킨 10% — 아직 없는 9종 중 하나(각 1.1%)", "꽝 90% — 🍚 +20"), "뽑기 (🎫 1장)" 버튼. 누르면 약 1.5초 결과 연출(접시 뚜껑이 들썩 → 열림) 뒤
  - 꽝: "꽝! 🍚 +20" + 코인 배지가 20 늘고 티켓 1 줄어듦.
  - 당첨: 새 스킨 3D 미리보기 + "🎉 연어알 군함 (특) 획득!" + "입기" 버튼(누르면 바로 입힘), 카드가 "입기"로 바뀌고 확률 줄의 남은 종 수가 하나 준다.
  - 연출 중 버튼은 눌리지 않고, 연타해도 요청 간격에 걸려 티켓이 두 장 빠지지 않는다. 티켓 0이면 버튼 꺼짐 + "우승하면 🎫 티켓을 받아요".
  - 서버 Output에 `[Draw]` 로그 한 줄씩.
- [ ] AC17 (현지화 — 조건부): 개발 시작 때 main에 m5-26(`src/shared/Localization/Strings.csv`)이 있으면 특 스킨 9종 이름 키(위 표 en), 뽑기 UI·토스트·거절 문구 키를 넣고 m5-26 테스트가 통과한다. 없으면 "해당 없음"으로 개발 메모에 남기고 문구는 코드 상수로.
- [ ] AC18 (잠금): 라운드 소개·달리는 중·탈락/우승 연출 중에는 뽑기 패널이 탈의실과 같이 숨고, 리모트를 직접 불러도 `Locked`로 거절(티켓 그대로).
- [ ] AC19 (Studio 전부 입기): 기본 커밋 값(`true`)으로 새 Studio 세션 → 탈의실 모든 카드(판매·시즌·VIP·특)가 "입기 (Studio)"이고 입으면 내 캐릭터가 바뀐다. 다른 테스트 플레이어(Clients and Servers)에게도 그 모습으로 보인다. 관리자 `info`나 프로필 보기로 `ownedSkins`가 늘지 않았다. `persistDataInStudio = true`로 바꾸면 꺼지고 서버 Output 경고 한 줄.
- [ ] AC20 (휴대폰): Device 에뮬레이터(짧은 변 500px 이하)에서 뽑기 패널·결과 연출·확률 줄이 잘리지 않고 버튼 44px 이상.

## 공용 파일 변경 (담당: 이 스펙 developer)
- `shared/Config.luau`: `Config.Draw = { TicketsPerWin = 1, MaxTickets = 99, SkinChance = 0.10, ConsolationCoins = 20, DuplicateCoins = 100, RequestCooldown = 1 }`. `Config.DEBUG.unlockAllSkinsInStudio = true` (주석: Studio 전용, `persistDataInStudio`와 같이 켜면 꺼짐, 저장에 안 남음 — **커밋 값 true**).
- `shared/Remotes.luau`: RemoteFunction `DrawTicket()` → `(ok, err?, result: DrawResult?)` 추가, 머리 주석 갱신. RemoteEvent 변화 없음.
- `shared/Types.luau`: `ProfileView.drawTickets`, `ProfileView.studioUnlockAll`, `RewardGrant.tickets?`·`ticketsFull?`, `DrawResult` 타입 (AC11).
- 공용 아님(이 스펙이 고침): `Skins`, `ShopLogic`, `ProfileSchema`(VERSION 3, `drawTickets`, `ViewExtra.unlockAll`), `ProfileLogic`(KNOWN_FIELDS·migrate), `RewardLogic`, `RewardService`, `ShopService`, `DataService`(view extra), `AdminLogic`, `AdminCommands`, 새 `DrawLogic`, 클라이언트 `ShopController`·탈의실 UI·새 뽑기 패널·`CoinController`(토스트), `SfxCues`(`DrawReveal`·`DrawWin`, 무음).
- 없음: `Attributes`, `maps/*`, `default.project.json`, init 스크립트, `rokit.toml`.

## 문서 반영 (docs-writer 몫, 이 스펙이 `qa-passed`된 뒤)
- `CLAUDE.md` "스킨 · 상점 규칙": "능력치 판매·뽑기 없음" → "**유료 뽑기 없음.** 무료 뽑기(🎫 우승자 티켓, m5-31)만 — 티켓은 우승으로만 얻고 Robux·코인·이벤트 재화·코드·상품으로 팔거나 주지 않는다, 확률은 뽑기 화면에 공개, 스킨은 겉모습만". 카탈로그 설명 "31종" + 특 스킨 9종(뽑기 전용, `draw = true`) 줄. 판단은 순수 `DrawLogic`, 지급은 `ShopService`의 `DrawTicket`이 `DataService.update` 한 번.
- `CLAUDE.md` 디버그 기본값 목록에 `unlockAllSkinsInStudio = true` 추가, 관리자 명령 StudioOnly에 `tickets` 추가, Remotes 개수(RemoteFunction 16 + RemoteEvent 11 = 27), 프로필 v3, 현재 상태(GDD v0.7, m5-31).
- `docs/DEV-SETUP.md`: 디버그 설정 표에 `unlockAllSkinsInStudio`(구매·뽑기 흐름 확인 때만 false), 3-10에 뽑기 확인 절(AC15~AC20).
- `docs/CHANGELOG.md`: M5 m5-31 줄.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 우승 보상으로 뽑기를 넣을지 · **우승자 뽑기 티켓**: 1등 우승(`Won`)하면 🎫 티켓 1장. 티켓으로 뽑기 → **스킨 10%**, **꽝 90%(위로 밥알 코인 +20)**. "얻기 꽤 어려운 스킨" · 사용자
- 2026-10-14 · 뽑기 풀 · **콘셉트 몸 스킨 9종 전부**(concept-salmon·tuna·shrimp·tamago·ikura·unagi·uni·tako·inari). 지금은 실험 스킨이라 모두가 무료로 갖지만 이제 **뽑기로만** 얻는다(무료 아님, 판매 아님) · 사용자
- 2026-10-14 · 이름 · "콘셉트 ○○ (테스트)" → "(테스트)"를 빼고 "(특)"을 붙인다. 사용자 제안대로 "콘셉트"도 빼서 "장어초밥 (특)", "연어알 군함 (특)" 식 — 기존 판매 스킨과는 (특)으로 구분 (위 이름 표) · 사용자
- 2026-10-14 · 테스트 환경 · **Studio에서는 모든 스킨을 장착 가능**(보유 안 해도), 저장(`ownedSkins`)에는 안 남김. `Config.DEBUG.unlockAllSkinsInStudio`(서버는 `RunService:IsStudio()`일 때만, `persistDataInStudio = true`면 꺼짐 — `fakeRobuxInStudio`와 같은 규칙), 커밋 기본값 true · 사용자
- 2026-10-14 · GDD 9.1 "유료 랜덤 뽑기 없음"과의 관계 · 유료 뽑기 금지는 그대로, **무료 뽑기만** 허용하는 규칙을 더함: 티켓은 플레이(우승)로만 얻고 Robux·코인으로 팔지 않는다, 확률은 뽑기 화면에 공개, 스킨은 겉모습만. Roblox 문서상 Robux·게임 재화 지불이 없는 행동 보상은 유료 랜덤 아이템이 아니어서 확률 공개 의무·지역 제한(`ArePaidRandomItemsRestricted`) 대상이 아님 — 근거: Roblox Paid random items·Content maturity 문서 [원문], REFERENCE-winner-ticket-draw §1 · 사용자 결정 + 기획 확인
- 2026-10-14 · 티켓이 "가치 있는 아이템을 건 운 게임"(Roblox 도박 정의)으로 읽히지 않게 · 티켓은 뽑기 말고 쓸 곳 없음, 코인으로 사거나 바꿀 수 없음, 거래 없음, 뽑기는 늘 무언가를 줌 · 기획 — 근거: Content maturity 도박 정의 [원문], REFERENCE §1
- 2026-10-14 · 이미 가진 스킨 · 후보에서 빼고 남은 것 중 균등, 9종 다 가지면 스킨 당첨분 = 🍚 +100 · 사용자 제안 채택 — 근거: TDS 골든 상자 "겹치지 않음", MM2·Rivals 플레이 재화 상자 (REFERENCE §2)
- 2026-10-14 · 티켓 상한 · 99장, 가득이면 우승해도 안 늘고 토스트로 알림 · 기획 기본값 — 근거: REFERENCE §3 (1장/우승이라 거의 안 닿음, 화면 두 자리)
- 2026-10-14 · 프로필 · v3로 올리고 `drawTickets` 추가. 옛 서버가 v3를 읽으면 "미래 버전 — 저장 안 함" 보호가 이미 있음(ProfileLogic). 특 스킨을 입고 있었지만 보유가 없는 프로필은 migrate가 계란초밥으로(지금 공개 전이라 실제 플레이어 손실 없음) · 기획
- 2026-10-14 · 내부 등급 · `tier = "Basic"` 유지 + 화면 표시만 "🎫 특"(새 등급을 만들면 등급별 효과·외곽 표와 m5-21 테스트를 다 건드림) · 기획 기본값 (개발이 새 등급이 낫다고 보면 결정 기록에 남기고 바꿔도 됨)
- 2026-10-14 · 당첨 스킨 자동 장착 · 하지 않음 — 결과 화면 "입기" 버튼(코인 해금과 다름: 뽑기는 고르지 않은 결과라 원치 않는 옷이 입혀지지 않게) · 기획 기본값
- 2026-10-14 · 서비스 위치 · 새 서비스 파일 없이 `ShopService`에 `DrawTicket` (init 스크립트 공용 파일 변경 피함) · 기획
- 2026-10-14 · 관리자 명령 · `tickets <n>` 추가, **StudioOnly**(코인·재화와 같은 경제 명령 등급, 저장 켠 Studio·실서버 거절 — 사용자 결정 2026-10-08·10-13의 규칙을 따름) · 기획
- 2026-10-14 · 저장 시점 · 뽑기 뒤 `saveNow` 안 함(무료 보상, 결제가 아님). 서버가 저장 전에 죽으면 티켓·보상이 같이 되돌아가 손해·이득 없음 · 기획
- **열린 질문 (사용자)**
  1. **천장(보장)**을 둘지: 지금은 매번 10% 그대로(사용자 결정). 연속 꽝이 길게 나올 수 있다(10장 연속 꽝 확률 약 35%, 20장 약 12%). 추천: 우선 없이 내고, 플레이테스트에서 "너무 안 나온다"는 반응이 있으면 "20장 연속 꽝이면 다음은 당첨" 같은 천장을 m5 후속으로. (천장 사례는 비교 게임에서 확인 못 함)
  2. 판 인원이 적은 방(4명 비공개 방)에서 친구끼리 우승을 몰아주는 티켓 파밍: 지금은 막지 않음(코인 우승 보상과 같은 조건). 추천: 그대로 두고 플레이테스트 뒤 필요하면 "5명 이상 판에서만 티켓" 같은 조건.
  3. Roblox 성숙도·준수 설문(Maturity & Compliance)에서 "유료 랜덤 아이템"을 "없음"으로 답하면 되는지 — 문서상 그렇다. 퍼블리시 때 사용자가 확인(USER-TODO).

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
