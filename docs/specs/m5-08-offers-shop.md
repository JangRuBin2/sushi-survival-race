status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-08 — 특별 상품: 스타터 팩·세트·연출 팩·VIP 패스 (🎁 상점)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1(능력치 판매 금지, 뽑기 없음, 코인 로벅스 판매 없음), §9.3(그 밖의 상품 — 가격 재검토 대상), §9.5(스킨 = 개발자 상품, 영구 혜택 = 게임 패스, ProcessReceipt 저장 성공 뒤 지급), §13(결제했는데 안 들어옴/두 번 들어감)
- 레퍼런스: [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) 8.1·8.4·8.6절, 3·4·7절
- 담당 개발 worktree: `m5-offers` (Rojo 포트 34876)
- 공용 파일 수정 담당: 없음 (리모트 `RequestOfferPurchase`·`EquipFx`, 속성 `Vip`·`EliminationFx`·`VictoryFx`, 프로필 `ownedFx`·`equippedFx`·`boughtOffers`, `DataService.setViewExtra`, `FxCatalog`, `PriceCache`, `DEBUG.fakeVipInStudio`, 껍데기 등록은 m5-03)
- 의존: **m5-03 머지 후 시작**. 연출의 실제 모습은 m5-09(병렬) — 이 스펙은 소유·장착·속성까지.
- **이 스펙이 고치는 파일**: 새 `src/shared/Offers.luau`, 새 `src/shared/OfferLogic.luau`, `src/server/OfferService.luau`(껍데기 채우기), `src/shared/ReceiptLogic.luau`, `src/server/RobuxShopService.luau`, `src/server/PurchaseLog.luau`(기록 모양), 새 `src/client/ui/OfferScreen.luau`, `src/client/ui/OfferController.luau`(껍데기 채우기), `src/client/ui/ChatTagController.luau`(껍데기 채우기), `src/client/fx/CharacterFxController.luau`(이름표 👑만), 테스트 `tests/receipt-logic.spec.luau`(추가), 새 `tests/offer-logic.spec.luau`

## 목표
로비의 **"🎁 상점"**에서 스킨 말고도 살 수 있는 것: 처음 하는 사람을 위한 **스타터 팩**, 에픽·전설 **세트 할인**, 내가 먹힐 때·우승할 때 모습을 바꾸는 **연출 팩**, 겉모습만 주는 **VIP 패스**. 전부 겉모습뿐이고(Pay-to-Win 없음), 이미 가진 것을 또 사게 하지 않는다.

## 상품표 (기본값, 사용자 수정 가능 — `Offers.luau`)
| offer id | 이름 | 종류 | 가격 R$ | 주는 것 | 조건 |
|---|---|---|---|---|---|
| `starter-pack` | 스타터 팩 | 개발자 상품 | **79** | 스킨 연어·참치·새우 + 장어 ("따로 사면 R$ 146") | **계정당 1번**, 4종을 **하나도 안 가졌을 때만** 보임 |
| `epic-set` | 에픽 세트 | 개발자 상품 | **249** | 무지개 롤·불꽃 연어·아보카도 캘리포니아롤 ("따로 297") | 계정당 1번, 3종을 하나도 안 가졌을 때만 |
| `legendary-set` | 전설 세트 | 개발자 상품 | **499** | 황금 참치 뱃살·다이아 성게·용 롤 ("따로 597") | 계정당 1번, 3종을 하나도 안 가졌을 때만 |
| `fx-cat-customer` | 탈락 연출: 고양이 손님 | 개발자 상품 | **59** | 연출 `cat-customer` (내가 먹힐 때 손님이 고양이) | 안 가졌을 때만 |
| `fx-fireworks` | 우승 연출: 불꽃놀이 | 개발자 상품 | **99** | 연출 `fireworks` (내가 우승할 때 불꽃놀이) | 안 가졌을 때만 |
| `vip` | VIP 패스 | **게임 패스** | **149** | VIP 전용 스킨 "금박 계란초밥" + 이름표 앞 👑 + 채팅 "[VIP]" 태그. **코인 배수 없음** | 패스가 없을 때만 |

- `Offers.luau` 모양:
  ```lua
  export type Kind = "Bundle" | "Fx" | "Pass"
  export type Offer = { id: string, displayName: string, kind: Kind, robux: number,
      productId: number?, gamePassId: number?, skins: { string }?, fx: { string }?,
      perks: { string }?, -- 화면 글씨 (VIP)
      order: number }
  Offers.LIST, Offers.get(id), Offers.forProduct(productId), Offers.forPass(passId), Offers.validate(list)
  ```
  validate: id·order 겹침 없음, 상품 id 겹침 없음(스킨 상품 id와도), Bundle은 스킨 2개 이상·전부 `Skins.get` 있음·시즌/VIP 전용 스킨 아님, Fx는 `FxCatalog` id, Pass는 `gamePassId` 칸(nil 허용, 사용자가 채움)·스킨은 `vipOnly`만, 가격 양의 정수.
- 상품 id·패스 id는 사용자가 만들어 채워요(아래 사용자 작업). nil이면 버튼이 "곧 열려요"(비활성), Studio 가짜 결제(`fakeRobuxInStudio`)·가짜 VIP(`fakeVipInStudio`)면 켜져요 — 스킨과 같은 규칙.

## 범위
- 포함:
  1. **판매 가능 판단** (순수 `OfferLogic`):
     ```lua
     OfferLogic.visible(offer, view): boolean          -- 화면에 카드를 보일지 (위 표의 조건)
     OfferLogic.canRequest(offerId, view, opts): (boolean, Reason?)
       -- Reason: "Unknown" | "AlreadyBought" | "OwnsSome" | "AlreadyOwned" | "AlreadyVip" | "NotForSale" | "CannotSave" | "NoProfile" | "TooFast"
     OfferLogic.grantsFor(offer, owned): { skins: { string }, fx: { string } }  -- 아직 없는 것만
     OfferLogic.message(reason): string               -- "이미 샀어요", "이미 가진 스킨이 있어서 따로 사야 해요" 등
     OfferLogic.valueText(offer): string?             -- "따로 사면 R$ 146" (스킨 카탈로그 가격 합)
     ```
  2. **결제 처리 일반화** (`ReceiptLogic`, `RobuxShopService`): 지금 "상품 → 스킨 하나"인 영수증 흐름을 **"상품 → 대상(스킨 하나 또는 상품 묶음)"**으로 넓혀요. 원칙은 그대로: 저장이 실제로 성공 → 구매 기록 성공 → `PurchaseGranted`, 아니면 `NotProcessedYet`. 같은 PurchaseId는 기록 + 프로필 receipts로 한 번만.
     - `Port.skinFor()` → `Port.targetFor(): Target?` (`{ kind = "Skin", id }` | `{ kind = "Offer", id }`), `owns(target)`: 스킨이면 보유, 상품이면 `boughtOffers[id]`(Bundle) 또는 `ownedFx`(Fx) 확인, `grant(target, equip)`: Offer면 `grantsFor`의 스킨·연출을 넣고 Bundle은 `boughtOffers[id] = 시각`.
     - 자동 장착: 스킨 하나는 지금처럼 장착, **묶음은 장착하지 않음**(탈의실 안내 Notice "탈의실에서 새 스킨을 입어 보세요"), **연출은 장착**(그 칸에).
     - 묶음을 샀는데 그 사이 일부를 코인으로 해금해서 가진 경우(창을 연 뒤 해금): 남은 것만 지급하고 Output에 warn(환불은 운영 판단 — m4-14 RecordOnly와 같은 처리).
     - `PurchaseLog` 기록: `{ userId, productId, skinId?, offerId?, at }`(기존 기록 읽기 그대로 호환).
     - 결제 창 열기: `RequestOfferPurchase(offerId)` → `OfferLogic.canRequest` → 간격 `Config.Shop.PurchaseRequestCooldown` → 개발자 상품이면 `PromptProductPurchase`(창을 연 동안 그 묶음 스킨의 코인 해금을 막는 것은 하지 않음 — 위 warn 처리로 충분, 결정 기록 D5), 게임 패스면 `PromptGamePassPurchase`.
  3. **VIP 게임 패스** (`OfferService`):
     - 접속할 때(그리고 `PromptGamePassPurchaseFinished`에서 산 경우) `MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)`를 pcall(실패하면 5초 뒤 한 번 더, 그래도 실패면 이번 접속은 VIP 아님 + warn). Studio + `DEBUG.fakeVipInStudio`면 VIP.
     - VIP면: Player 속성 `Vip = true`, `DataService.setViewExtra(player, { vip = true })`, 프로필이 로드되면 `vip-gold-tamago`가 없을 때 지급(장착은 안 함, 저장 요청). 한 번 받은 스킨은 패스가 없어져도 남아요.
     - `RequestOfferPurchase("vip")`: 이미 VIP면 `AlreadyVip`, 패스 id 없으면 `NotForSale`(가짜 VIP 모드 제외).
  4. **연출 장착** (`EquipFx(slot, fxId?)`, OfferService): 요청 간격(`Config.Shop.RequestCooldown`) → slot이 `"Elimination"`/`"Victory"` → fxId가 nil·""면 벗기, 아니면 `FxCatalog`에 있고 그 slot이고 **가진 것** → 잠금(`ShopService.isLocked` — 라운드·연출 중 거절) → `profile.equippedFx[slot]` 저장 + Player 속성 `EliminationFx`/`VictoryFx`(없으면 속성 제거). 접속·프로필 로드 때도 속성을 프로필대로 달아요.
  5. **이름표·채팅 태그**:
     - `CharacterFxController`: 이름표 이름 앞에 Player 속성 `Vip`이면 "👑 "(칭호 줄은 그대로).
     - `ChatTagController`: `TextChatService.OnIncomingMessage`에서 보낸 사람의 `Vip` 속성이면 `PrefixText`에 금색 "[VIP] "(기존 접두어 앞). `TextChatService.ChatVersion`이 `TextChatService`가 아니면 아무것도 안 함.
  6. **"🎁 상점" 화면** (`OfferScreen`/`OfferController`, 자기 ScreenGui `OfferGui`, `UiScaleController.attach`):
     - 열기 버튼 "🎁 상점": 왼쪽 위 "🍣 스킨" 버튼 바로 아래(오프셋 12, 60, 크기 110 × 44). **로비·방 대기실에서만** 보임(매치 중·관전 중 숨김 — 결제는 판 사이에만).
     - 창: 카드 목록(보이는 상품만, `order` 순) — 이름, 주는 것(스킨 이름들 / 연출 설명 / VIP 혜택 3줄), `valueText`, 가격 버튼 "R$ 79로 사기"(가격은 `PriceCache.product`/`PriceCache.pass`, 없으면 카탈로그), 결과 한 줄. 산 상품 카드는 "산 상품" 회색으로 아래(묶음·VIP) 또는 사라짐(조건이 안 맞는 묶음).
     - **"내 연출"** 칸: 가진 연출마다 "입기 / 입는 중 · 벗기" 버튼(칸마다 하나만). 가진 연출이 없으면 숨김.
     - 휴대폰(compact): 카드 1열 스크롤, 터치 44px 이상. 탈의실과 같은 `RoomUiKit` 색·모양.
     - 코인으로 사는 길은 없어요(로벅스만 — 코인 경제는 스킨 해금 전용, 결정 기록 D4).
- 제외:
  - 연출의 실제 모습(m5-09), 연출 미리보기 재생.
  - 지역 가격 켜기(대시보드 — 사용자 결정, 코드는 `PriceCache`로 준비만), 가격 A/B 테스트.
  - VIP 로비 좌석·VIP 서버, 선물하기(gifting), 구독.

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1: `Offers.validate(Offers.LIST)` 통과(6개). 같은 상품 id가 스킨과 겹치면·묶음에 VIP 전용 스킨이 있으면·Fx id가 카탈로그에 없으면 각각 잡힌다.
- [ ] AC2: `OfferLogic.visible`: 스타터 팩은 4종 중 하나라도 가졌거나 `boughtOffers["starter-pack"]`이면 false, 아무것도 없으면 true. 에픽 세트도 같은 규칙. 연출 팩은 그 연출이 없을 때만, VIP는 `view.vip == false`일 때만.
- [ ] AC3: `OfferLogic.canRequest`가 위 Reason을 경우마다 돌려준다(이미 산 묶음 `AlreadyBought`, 일부 보유 `OwnsSome`, 가진 연출 `AlreadyOwned`, VIP `AlreadyVip`, 상품 id 없음 `NotForSale`(가짜 모드면 통과), 저장 불가 `CannotSave`).
- [ ] AC4: `valueText(starter-pack) == "따로 사면 R$ 146"`, 에픽 세트 297, 전설 세트 597.
- [ ] AC5: `ReceiptLogic.process` (가짜 port): 스타터 팩 영수증 → 스킨 4개 + `boughtOffers` 기록 + 저장 + 기록 → Granted, 장착은 바뀌지 않음. 같은 PurchaseId 두 번째는 AlreadyRecorded(중복 지급 없음). 저장 실패면 NotProcessedYet이고 기록 안 씀. 연출 영수증 → `ownedFx` + `equippedFx` 그 칸 장착. **기존 스킨 영수증 테스트 전부 그대로 통과**.
- [ ] AC6: 묶음 영수증이 왔는데 그 사이 1개를 이미 가졌으면 나머지 3개만 지급하고 Granted(note에 "already owned" 포함).
- [ ] AC7: 검증 5단계 통과.

### Studio 확인 (사용자 확인 필요 — `fakeRobuxInStudio = true`, VIP는 `fakeVipInStudio = true`, **확인 뒤 false**)
- [ ] AC8: 새 프로필로 로비에 들어가면 "🍣 스킨" 아래 "🎁 상점" 버튼, 열면 스타터 팩·에픽 세트·전설 세트·연출 2개·VIP 카드와 "따로 사면 R$ 146".
- [ ] AC9: 스타터 팩을 (가짜) 사면 탈의실에 4종이 생기고 입고 있던 스킨은 그대로, "탈의실에서 새 스킨을 입어 보세요" 안내. 상점에서 스타터 팩이 사라지고 다시 살 수 없다. 재접속해도(저장 켠 경우) 그대로.
- [ ] AC10: 연어를 코인으로 먼저 해금한 새 프로필에서는 스타터 팩이 안 보인다.
- [ ] AC11: 고양이 손님을 사면 "내 연출"에 "입는 중", 벗기·입기가 되고 라운드 중에는 거절된다. Player 속성 `EliminationFx`가 바뀐다(Explorer).
- [ ] AC12: `fakeVipInStudio = true`로 들어가면 이름표에 👑, 채팅에 [VIP], 탈의실에 금박 계란초밥이 보유로 생기고(장착 안 됨) VIP 카드가 없다. 2명 테스트에서 상대 화면에도 👑·[VIP]가 보인다.
- [ ] AC13: 매치 중(대기석·관전 포함)에는 "🎁 상점" 버튼이 안 보인다.
- [ ] AC14: 휴대폰 에뮬레이터에서 카드가 1열로 스크롤되고 버튼이 겹치지 않는다. "🍣 스킨"·"🎁 상점" 버튼이 다른 로비 UI와 안 겹친다.
- [ ] AC15 (실서버, 사용자 작업 뒤): 상품 5개·패스 1개 id를 넣고 퍼블리시하면 실제 결제 창이 뜨고 지급된다.

## 공용 파일 변경
- 없음 (필요해지면 결정 기록에 적고 사용자에게 알림)

## 사용자 작업
- **개발자 상품 5개** 만들기 (USER-TODO C3에 추가) → id를 `src/shared/Offers.luau`의 `productId`에:
  | offer id | 상품 이름 | 가격 R$ |
  |---|---|---|
  | starter-pack | 스타터 팩 | 79 |
  | epic-set | 에픽 세트 | 249 |
  | legendary-set | 전설 세트 | 499 |
  | fx-cat-customer | 탈락 연출: 고양이 손님 | 59 |
  | fx-fireworks | 우승 연출: 불꽃놀이 | 99 |
- **게임 패스 1개** "VIP 패스" R$ 149 → id를 `Offers.luau`의 `gamePassId`에.
- 가격·구성 확인 (특히 VIP 149·코인 배수 없음, 스타터 팩 조건). 지역 가격(Managed Pricing)을 켤지 — 켜려면 대시보드에서(REFERENCE 8.4).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 VIP에 코인 배수를 넣을지 · **넣지 않음**(겉모습 3가지: 전용 스킨·👑·채팅 태그). 코인 배수는 "코인을 로벅스로 파는 것"과 같은 효과라 사용자가 확정한 "코인 R$ 판매 안 함"(GDD 9.1)과 어긋남. Arsenal이 1.5배 VIP를 겉모습 VIP로 바꾼 사례. 가격은 혜택이 가벼워 249 → **149**(가이드 "편의 49~149" 위 끝, VIP 묶음 199~499보다 아래). 근거: Arsenal VIP(교체 전후)·Epic Minigames VIP 499(코인 포함 많은 혜택) — REFERENCE 8.1. **사용자 결정 필요(기본값으로 진행)**: 코인 1.5배를 넣고 199~249로 할지 · planner
- 2026-10-08 · D2 묶음을 게임 패스로 할지 · **개발자 상품**. 문서는 "한 번만 = 패스"를 권하지만, 패스는 웹 상점에서도 팔려서 "그 안의 스킨을 하나도 안 가졌을 때만" 조건을 못 걸고, 스킨 소유가 이미 프로필(DataStore)에 있음. 한 번만은 `boughtOffers` + 구매 기록으로 지킴. VIP만 패스(조건 없는 영구 혜택, 지역 가격 자동). 근거: REFERENCE 8.4 공식 문서 · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D3 가격 · 스타터 79(Rivals 59·Epic Minigames 99 사이), 세트 약 16% 할인(249/499), 탈락 연출 59(레어 스킨 가격 — 자주 보이는 작은 코스메틱), 우승 연출 99(에픽 가격). 근거: REFERENCE 7.4·8.1·8.6 · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D4 연출을 코인으로 · 팔지 않음(로벅스만). 코인은 일반·레어 스킨 해금 전용으로 단순하게(GDD 9.4). 나중에 원하면 탈락 연출 900코인 같은 길을 추가할 수 있음 · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D5 묶음 결제 창 중 코인 해금 · 스킨 결제처럼 막지 않음(묶음은 여러 스킨이라 막으면 탈의실이 복잡). 대신 영수증 때 가진 것을 빼고 지급 + warn. 실제로 일어날 확률이 낮음(결제 창은 수 초) · planner
- 2026-10-08 · D6 상점을 언제 보일지 · 로비·방 대기실에서만(탈의실은 관전·대기석에서도 열리지만, 결제는 판 사이에만 — 라운드 집중 방해 줄이기) · **기본값, 사용자 수정 가능** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
