# m5-08 offers shop — 개발 작업 기록

## 2026-10-08 — 착수 직후 중단 (wip, 최신)
- **브랜치**: `m5-08-offers` (origin/main c4ca608 기반). 스펙 status `in-dev`.
- **끝난 것**: 관련 코드·테스트 읽기와 설계만. **코드 변경 없음.** 검증은 돌리지 않음 (바뀐 코드가 없음).
- **남은 것**: 스펙 범위 1~6 전부 (Offers, OfferLogic, ReceiptLogic 일반화, RobuxShopService, PurchaseLog 기록 모양, OfferService, OfferScreen/Controller, ChatTagController, 이름표 👑, 테스트 2개).
- **다음에 할 첫 단계**: `src/shared/Offers.luau` + `src/shared/OfferLogic.luau` + `tests/offer-logic.spec.luau` 작성 (아래 설계대로).
- **막힌 점**: 없음. 아래 제약 두 가지는 꼭 지킬 것.

### 꼭 지킬 제약 (QA 테스트 하네스 `tests/m4-14-qa.spec.luau`, 수정 금지 파일)
1. 하네스는 `ReceiptLogic`을 의존성 `{ Skins, Seasons }`만으로 불러요 → **ReceiptLogic은 Offers/OfferLogic/FxCatalog를 require하면 안 됨.** 결제 처리는 대상(Target)에 대해 일반적으로 두고 상품별 처리는 port가 함.
2. 하네스는 `RobuxShopService`를 shared `AdminLogic, Attributes, Config, ProfileLogic, ProfileSchema, ReceiptLogic, Remotes, Seasons, ShopLogic, Skins, Types` + server `DataService, PurchaseLog, ShopService, AppearanceService, MatchEvents, RoundService`로만 불러요 → **RobuxShopService는 Offers/OfferLogic/OfferService를 require하면 안 됨.** OfferService가 `RobuxShopService.setOfferPort(...)`로 등록하는 방식 (ShopService.setCoinBlocker와 같은 패턴).
3. 기존 port(`skinFor`, `owns(skinId)`, `grant(skinId, equip)`)를 쓰는 테스트(receipt-logic, m4-14-qa)는 그대로 통과해야 해요 → ReceiptLogic.process는 `port.targetFor`가 있으면 Target 방식, 없으면 `skinFor`를 `{kind="Skin", id}`로 감싸고 owns/grant에 skinId를 넘기는 호환 경로.

### 설계
- `ReceiptLogic`: `Target = { kind: "Skin" | "Offer", id: string }`. Port에 `targetFor?`, 선택 `ownedParts?(target) -> {string}`(묶음 일부 보유 → note "already owned: …"). Outcome에 `target` 추가, `skinId`는 Skin일 때만. Record = `{ userId, productId, skinId?, offerId?, at }`. 원칙은 그대로: saveNow 성공 → writeRecord 성공 → PurchaseGranted, 나머지 NotProcessedYet. RobuxShopService 로그 줄은 스킨이면 지금 형식 `skin <id>` 유지, 상품이면 `offer <id>`. warn 조건은 `target == nil` 또는 note에 "already owned".
- `OfferLogic` (순수, Offers·Skins·FxCatalog require): view는 목록(ProfileView)·맵(Profile) 둘 다 받게 `has(collection, id)` 헬퍼 (`c[id]`가 nil/false가 아니거나 `table.find(c, id)`), tamago는 항상 보유. `visible`, `canRequest(offerId, view?, {canSave, fake, fakeVip?})`(순서: Unknown → NoProfile → AlreadyBought/OwnsSome/AlreadyOwned/AlreadyVip → fake면 통과 → id nil이면 NotForSale → Bundle/Fx는 canSave 아니면 CannotSave), `grantsFor`, `applyGrant(profile, offer, equip, now)`(스킨·연출 추가, Bundle이면 boughtOffers[id]=now, Fx+equip이면 equippedFx[slot]), `message`, `valueText`(Bundle 스킨 robux 합 → "따로 사면 R$ 146"), `contentLines(offer)`(카드 글씨).
- `Offers`: 스펙 표 6개 + 선택 칸 `blurb`. `validate(list, skins?)`: 스킨 목록을 두 번째 인자로 받아 상품 id가 스킨과 겹치는지 테스트할 수 있게.
- 가격 확인: 연어·참치·새우 29 + 장어 59 = 146, 에픽 99×3 = 297, 전설 199×3 = 597 (Skins.luau 기준 맞음). 에픽 = rainbow-roll, aburi-salmon, california-roll / 전설 = golden-otoro, diamond-uni, dragon-roll.
- `OfferService`: init에서 Offers.validate, `RobuxShopService.setOfferPort({ targetFor(productId), owns, ownedParts, grant })`(grant = `DataService.update` 안에서 `OfferLogic.applyGrant` → 끝나면 Player 속성 EliminationFx/VictoryFx 갱신), 리모트 RequestOfferPurchase(간격 PurchaseRequestCooldown → canRequest → 가짜면 `RobuxShopService.fakeReceipt(player, target)`, 상품이면 PromptProductPurchase, 패스면 PromptGamePassPurchase), EquipFx(RequestCooldown → slot·fx·보유·ShopService.isLocked → 저장 + 속성). VIP: PlayerAdded에서 UserOwnsGamePassAsync pcall(실패 → 5초 뒤 한 번 더 → 실패면 warn), Studio+fakeVipInStudio면 VIP, PromptGamePassPurchaseFinished(구매 시 재확인). VIP면 속성 Vip, setViewExtra({vip=true}), 프로필 로드 때 vip-gold-tamago 지급(장착 안 함, canPersist면 saveNow).
- 클라이언트: OfferScreen(ShopScreen/RoomUiKit 모양, ScreenGui `OfferGui`, 버튼 (12,60) 110×44, 1열 카드 스크롤 + "내 연출"), OfferController(로비·방 대기실에서만 보임: room이 없거나 state ~= "InMatch", 매치 서버면 숨김; PriceCache.product/pass; 묶음이 boughtOffers에 들어오면 "탈의실에서 새 스킨을 입어 보세요"), ChatTagController(TextChatService.OnIncomingMessage, ChatVersion 확인, Vip 속성이면 금색 "[VIP] "), CharacterFxController 이름표에 Vip 속성이면 "👑 ".
