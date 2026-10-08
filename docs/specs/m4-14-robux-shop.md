status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-14 — 로벅스 스킨 구매 (개발자 상품 · ProcessReceipt · 구매 기록)

- 마일스톤: M4 (**맨 마지막 스펙** — CLAUDE.md "스킨·상점·로벅스 결제는 가장 마지막")
- GDD 근거: `docs/GDD.md` §9.1(로벅스로 바로 구매, 능력치 판매 없음, 유료 뽑기 없음), §9.2(가격), §9.5(개발자 상품, DataStore, ProcessReceipt는 저장 성공 뒤에만 완료), §13("결제했는데 스킨이 안 들어옴" → 저장 성공 후에만 완료, 구매 기록 별도 저장)
- 담당 개발 worktree: `main` (**순차, m4-13 다음**)
- 공용 파일 수정 담당: **이 스펙** (m4-13 다음 차례)
- 의존: m4-13 병합 (`Skins.luau`, `ShopService`, `ShopScreen`), m4-07 `DataService.saveNow`·`canPersist`
- **이 스펙이 고치는 파일**: `src/server/ShopService.luau`, `src/client/ui/ShopScreen.luau`, `src/client/ui/ShopController.luau`, `src/shared/Skins.luau`(`productId` 칸 채우는 자리), 공용 파일(`Remotes.luau`, `Config.luau`), 새 파일 `src/shared/ReceiptLogic.luau`, `src/server/PurchaseLog.luau`, `tests/receipt-logic.spec.luau`

## 목표
레어·에픽·전설 스킨(그리고 일반 스킨도 원하면)을 로벅스로 바로 산다. 결제가 끝나면 스킨이 즉시 들어오고 입혀지며, 서버가 꺼지거나 저장이 실패해도 **결제했는데 스킨이 없는 일은 없다**(Roblox가 다시 시도하게 둠). 같은 결제가 두 번 처리돼도 한 번만 반영된다.

## 범위
- 포함:
  1. **상품**: 계란초밥을 뺀 스킨마다 개발자 상품 1개(15개, 사용자가 만듦), id를 `Skins.luau`의 `productId`에. `productId`가 nil인 스킨의 로벅스 버튼은 "곧 열려요"(비활성) 그대로.
  2. **구매 요청** `RequestRobuxPurchase(skinId)` (RemoteFunction, 서버 검증): 스킨이 있고 `productId`가 있고 미보유이고 `DataService.canPersist(player)`가 true(Studio 대체 모드 제외)여야 한다. 통과하면 서버가 `MarketplaceService:PromptProductPurchase(player, productId)`. 요청 간격 1초. 거절 이유: "이미 있어요", "저장이 안 되는 상태라 지금은 살 수 없어요", "준비 중이에요".
  3. **`ProcessReceipt`** (서버에 단 하나, `ShopService`가 등록):
     1. `PlayerId`로 서버 안 플레이어를 찾는다 → 없으면 `NotProcessedYet`.
     2. `ProductId` → 스킨. 모르는 상품이면 경고 로그 + `NotProcessedYet`.
     3. 프로필이 로드되지 않았거나 `canPersist = false`면 `NotProcessedYet`.
     4. 구매 기록 저장소(`PurchaseLog`, DataStore `Purchases_v1`, 키 = `PurchaseId`)에 이미 있으면 → 프로필에 그 스킨이 있는지 확인(없으면 넣고 저장) → `PurchaseGranted`.
     5. 없으면: 프로필에 스킨 추가 + 자동 장착 → `DataService.saveNow(player)` **성공해야** → `PurchaseLog`에 `{ userId, productId, skinId, at }` 기록 → 성공하면 `PurchaseGranted`. 중간 어느 단계든 실패하면 `NotProcessedYet`(Roblox가 나중에 다시 부름 — 4단계 덕에 두 번 들어가지 않음).
     6. 이미 보유한 스킨의 영수증이 오면(다른 서버에서 동시에 산 경우 등): 기록만 남기고 `PurchaseGranted` + 경고 로그(환불은 사용자 운영 판단).
     - 판단 순서는 순수 함수 `ReceiptLogic.decide(state) -> "NotProcessedYet" | "GrantAndRecord" | "AlreadyRecorded" | "RecordOnly"`로 분리해 테스트.
  4. **화면** (`ShopScreen`): 로벅스 가격 버튼 "R$ 99"(가격은 카탈로그 값, 가능하면 `MarketplaceService:GetProductInfo`의 실제 가격으로 바꿔 표시). 누르면 요청 → Roblox 결제 창. 결제가 끝나 `ProfileUpdated`로 보유가 바뀌면 카드가 "입는 중"으로 바뀌고 "🎉 {스킨} 획득!" 한 줄.
  5. **Studio 대체**: `Config.DEBUG.fakeRobuxInStudio = false`(새). Studio이고 true면 `productId`가 nil이어도 로벅스 버튼이 활성화되고, 누르면 결제 창 없이 위 3번 흐름을 가짜 영수증(PurchaseId = `"studio-" .. 시각`)으로 그대로 탄다(저장은 메모리 모드면 메모리). 실제 서버에서는 무시.
  6. **원칙 확인**: 판매하는 것은 겉모습(스킨)뿐이다. 속도·히트박스·판정에 영향 주는 상품 없음, 랜덤 상품 없음(GDD 9.1). 탈락·우승 연출 팩, VIP 게임 패스, 스타터 번들은 M5.
- 제외:
  - 게임 패스(VIP), 연출 팩, 번들, 시즌 스킨, 선물하기, 환불 처리 도구
  - 로벅스 인게임 소비 아이템(`docs/proposals/robux-gameplay.md` — 사용자 승인 전, 범위 밖)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/receipt-logic.spec.luau`)
- [ ] AC1: `decide`: 플레이어 없음 → NotProcessedYet, 모르는 상품 → NotProcessedYet, 프로필 없음/`canPersist = false` → NotProcessedYet, 기록 있음 → AlreadyRecorded, 기록 없음 + 미보유 → GrantAndRecord, 기록 없음 + 이미 보유 → RecordOnly.
- [ ] AC2: (가짜 저장소로) GrantAndRecord에서 `saveNow`가 실패하면 결과는 NotProcessedYet이고 기록이 남지 않는다. 같은 PurchaseId로 다시 부르면 저장 성공 시 스킨이 **한 번만** 들어가고 PurchaseGranted.
- [ ] AC3: 기록 저장이 실패하면 NotProcessedYet이고, 다시 부르면(프로필엔 이미 있음) RecordOnly → PurchaseGranted, 스킨 중복 없음.
- [ ] AC4: `productId`가 겹치는 스킨이 없다(nil 제외).
- [ ] AC5: 검증 명령 5개 통과.

### Studio 확인
- [ ] AC6: `fakeRobuxInStudio = true`로 "성게"(R$ 99)를 사면 결제 창 없이 바로 성게를 입고 카드가 "입는 중"이 된다. false로 돌리면 "곧 열려요".
- [ ] AC7: (사용자가 상품을 만들고 id를 넣은 뒤, 퍼블리시된 게임을 Studio에서) 로벅스 버튼을 누르면 Roblox 결제 창이 뜨고(Studio 테스트 구매는 실제 청구 없음) 확인하면 스킨이 들어오며, 나갔다 들어와도 남는다.
- [ ] AC8: 이미 가진 스킨은 로벅스 버튼이 없다(입기만). 저장 안 되는 상태(Studio 메모리 모드, `fakeRobuxInStudio = false`)에서 요청하면 거절 문구.
- [ ] AC9: 서버 Output에 `[Shop] receipt …` 로그가 결제마다 한 줄 있고, 같은 영수증이 두 번 처리돼도 스킨이 하나다(Studio에서 가짜 영수증 같은 id로 두 번 — 개발 메모의 명령).

## 공용 파일 변경
- `shared/Remotes.luau`: RemoteFunction `RequestRobuxPurchase`
- `shared/Config.luau`: `DEBUG.fakeRobuxInStudio = false`, `Shop.PurchaseRequestCooldown = 1`

## 사용자 작업
1. Creator Dashboard → 게임 → Monetization → Developer Products에서 **스킨 상품 15개**를 만든다(계란초밥은 무료라 제외. 이름 = 스킨 이름, 가격 = m4-13 표, 아이콘은 스킨 미리보기 스크린샷이면 충분).
2. 상품 id 15개를 메인 세션에 알려 주거나 `Skins.luau`의 `productId`에 넣는다.
3. AC7 확인 (Studio 테스트 구매).
4. 공개 전환 (m4-12 체크리스트 10번).

## 결정 기록
- 2026-10-08 · 구매 기록 별도 저장소(`Purchases_v1`, 키 = PurchaseId) + 프로필 저장 성공 뒤 기록 → 둘 다 성공해야 Granted · GDD 9.5·13 · planner
- 2026-10-08 · 일반 스킨도 로벅스 49로 살 수 있게(GDD 9.2 "49 R$ 또는 500 코인") · planner
- 2026-10-08 · 산 스킨은 바로 입힘 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · VIP 패스·연출 팩·번들은 M5 · M4 완료 기준 "스킨 상점(로벅스+코인)"만 채움 · **기본값으로 진행, 사용자 수정 가능** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
