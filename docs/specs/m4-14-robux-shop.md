status: qa-passed
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
- 2026-10-08 · ProcessReceipt·RequestRobuxPurchase는 `ShopService`가 아니라 새 `RobuxShopService`가 등록 · m4-13 QA 가짜 환경 테스트(`tests/m4-13-qa.spec.luau`)가 ShopService 소스를 그대로 돌려서, 결제 의존성(MarketplaceService·PurchaseLog·BindToClose)을 넣으면 깨짐. 지급은 그대로 `ShopService.grantSkin` · developer
- 2026-10-08 · 프로필에 처리한 PurchaseId 목록 `receipts`(최근 `Config.Shop.ReceiptHistoryMax` = 50개) 추가, VERSION은 1 유지(없는 칸은 빈 목록, 옛 서버는 모르는 칸으로 보존) · 구매 기록과 함께 중복 지급을 두 번 막고, "다시 시도"와 "이미 가진 스킨을 또 삼"을 로그에서 구분 · developer
- 2026-10-08 · `AlreadyRecorded`·`RecordOnly`도 프로필 저장이 성공해야 Granted · 앞선 시도에서 저장이 실패해 메모리에만 스킨이 들어가 있을 수 있음 (그 상태로 Granted면 서버가 꺼질 때 스킨이 사라짐) · developer
- 2026-10-08 · 일반 스킨은 코인 해금 버튼 아래 "R$ 49로 사기" 버튼이 하나 더 · 결정 기록 2번째 줄 · developer
- 2026-10-08 · 결제로 받은 스킨이 라운드·연출 잠금 중이면 보유만 하고 장착은 안 함 (`grantSkin` 규칙 그대로) · developer
- 2026-10-08 · **QA 후 수정** (R2~R5, 커밋 d2be142) · R2: 서버가 플레이어별로 결제 창을 띄운 스킨을 기억(`RobuxShopService.prompted`)하고 그동안 같은 스킨 코인 해금을 "로벅스 결제가 끝날 때까지 기다려 주세요"로 거절 (`ShopService.setCoinBlocker`). 서버 `PromptProductPurchaseFinished` 취소·영수증 Granted·`Config.Shop.PurchasePromptHold`(120초)로 풀림. 그래도 RecordOnly가 되는 경로(다른 서버 등)는 경고 로그 유지. R4: `fakeRobuxInStudio`와 `persistDataInStudio`를 같이 켜면 가짜 결제는 꺼지고 시작 때 경고 (`ShopLogic.fakeRobuxActive`, 서버·클라이언트 공통) → 운영 저장소에 가짜 기록·무료 스킨 없음. R3: 클라이언트가 결제 창 취소 때 `pending`을 지움. R5: Remotes 주석. 재현 테스트는 `tests/m4-14-qa.spec.luau` 끝 4개 · developer

## 개발 메모
### 바뀐 파일
- 새: `src/shared/ReceiptLogic.luau` (decide·process·canRequest·message·영수증 목록), `src/server/RobuxShopService.luau` (RequestRobuxPurchase, ProcessReceipt, Studio 가짜 결제·디버그 훅), `src/server/PurchaseLog.luau` (DataStore `Purchases_v1`, Studio 메모리), `tests/receipt-logic.spec.luau` (16개)
- 공용: `Config.luau` (`Shop.PurchaseRequestCooldown = 1`, `Shop.ReceiptHistoryMax = 50`, `Shop.PurchaseLogStore`, `DEBUG.fakeRobuxInStudio = false`), `Remotes.luau` (`RequestRobuxPurchase`, 리모트 20개)
- `ProfileSchema`/`ProfileLogic` (`receipts` 칸 + 정리), `ShopLogic` (`ROBUX_ENABLED` 삭제 → `robuxOpen`·`robuxPrice`·`robuxButtonText`, `cardState(skin, view, robux?)`), `Skins` (productId 주석), `init.server.luau` (RobuxShopService 등록, ShopService 다음)
- `ShopController`/`ShopScreen`: 로벅스 버튼(레어 이상은 행동 버튼, 일반은 두 번째 버튼), 실제 가격(`GetProductInfoAsync`), 결제 후 "🎉 {스킨} 획득!", m4-13 QA N1(탈락 연출 3초 동안 "🍣 스킨" 버튼 숨김)
- `MatchService`: `DEBUG.logArenaStats`에 Studio 가드 (m4-12 QA N3)
- 테스트 조정: `m4-foundation`(리모트 20개), `shop-logic`·`skins`(상품 id를 채워도 깨지지 않게), `m4-12-hardening`(누수 점검 예외에 Studio 메모리 구매 기록)

### 결제 흐름 (`ReceiptLogic.process`)
| 경우 | 결과 |
|---|---|
| 플레이어가 이 서버에 없음 / 모르는 상품(경고) / 프로필 로드 전 / `canPersist = false`(임시 프로필·잠금 상실) / 서버 종료 중 / 구매 기록 읽기 실패 | NotProcessedYet |
| 이 서버에서 같은 PurchaseId를 처리 중 | NotProcessedYet |
| 기록 없음 + 미보유 → 지급·장착·receipts 추가 → `saveNow` true → 기록 true | PurchaseGranted (하나라도 실패하면 NotProcessedYet, 저장 전엔 기록 안 씀) |
| 기록 없음 + 이미 보유 (다시 시도 / 다른 서버에서 또 삼 → 경고) → 저장 → 기록 | PurchaseGranted |
| 기록 있음 → (없으면 다시 넣고) 저장 | PurchaseGranted |
- Studio + `fakeRobuxInStudio`: 결제 창 없이 같은 흐름, 메모리 프로필이면 메모리 저장을 성공으로 봐요. 실제 서버는 무시.

### 사용자 작업 (USER-TODO C3에 표)
1. Creator Dashboard → 이 게임 → Monetization → Developer Products → Create a Developer Product를 15번: 이름 = 스킨 이름, 가격 = 일반 49 / 레어 99 / 에픽 199 / 전설 399 (표는 `docs/USER-TODO.md` C3).
2. 각 상품의 Product ID를 `src/shared/Skins.luau`의 그 스킨 항목에 `productId = 1234567890,`으로 넣거나 메인 세션에 알려 주기. 겹치면 서버 시작 때 경고, 테스트(AC4)도 실패.
3. 게임 설정 → Security → Enable Studio Access to API Services 켜기 (AC7에서 저장이 필요).

### Studio 확인 방법
1. **AC6** `Config.DEBUG.fakeRobuxInStudio = true` → Play → "🍣 스킨" → 레어 탭 "성게" → "R$ 99" → 결제 창 없이 바로 성게를 입고 카드가 "입는 중", 결과 줄 "🎉 성게 획득!". 서버 Output에 `[Shop] receipt studio-... skin uni -> PurchaseGranted (GrantAndRecord: granted)`. 일반 스킨은 "R$ 49로 사기" 버튼으로 같음. false로 돌리면 "R$ 99 — 곧 열려요"(회색).
2. **AC9** (fake = true, Play 중) Server 쪽 Command Bar: `print(game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("<내 이름>", "eel", "studio-test-1"))` 두 번 → 첫 번째 `PurchaseGranted`(GrantAndRecord), 두 번째도 `PurchaseGranted`(AlreadyRecorded: already recorded), 탈의실의 장어는 하나. Output에 결제마다 `[Shop] receipt` 한 줄.
3. **AC8** 가진 스킨은 로벅스 버튼 없이 "입기"/"입는 중". 상품 id를 넣은 뒤 `fakeRobuxInStudio = false` + `persistDataInStudio = false`(메모리)로 로벅스 버튼 → "저장이 안 되는 상태라 지금은 살 수 없어요". 상품 id가 없는 스킨은 버튼이 회색이라 요청이 안 감 (Command Bar `game.ReplicatedStorage.Remotes.RequestRobuxPurchase:InvokeServer("eel")` → `false 준비 중이에요`).
4. **AC7** (상품 id를 넣고 퍼블리시한 게임, `persistDataInStudio = true`, `fakeRobuxInStudio = false`) 로벅스 버튼 → Roblox 결제 창(Studio 테스트 구매, 청구 없음) → 확인 → 스킨이 들어오고 입혀짐, 가격은 상품 가격. 나갔다 다시 Play해도 남음. Output에 `[Shop] receipt <PurchaseId> ... PurchaseGranted`.
5. **N1** 매치에서 탈락 → 탈락 연출 3초 동안 "🍣 스킨" 버튼이 안 보이고, 그 뒤 관전 화면에서 보임.
6. 휴대폰 크기(에뮬레이터)에서 일반 스킨 선택 시 정보 칸에 버튼 두 개 + 결과 줄이 넘치지 않는지 (compact 배치는 미확인).

### 남은 이슈
- Studio가 없어 화면(두 번째 버튼 배치, 특히 compact)·실제 결제 창은 확인 못 함.
- 결제 때 잠금 중(라운드 레이서)이면 보유만 되고 장착은 안 돼요 — 매치 서버에서 관전 중 구매는 잠금이 아니라 바로 입혀짐.
- 이미 가진 스킨을 다른 서버에서 동시에 또 사면 기록만 남기고 Granted(로벅스는 빠짐). 환불은 운영 판단(경고 로그로 찾기).
- 구매 기록 DataStore(`Purchases_v1`)도 개인정보 삭제 요청 대상: 키는 PurchaseId라 UserId로 찾으려면 키 메타데이터(userIds)로 검색해야 해요 — USER-TODO C4 문구 보강은 docs-writer 몫.
