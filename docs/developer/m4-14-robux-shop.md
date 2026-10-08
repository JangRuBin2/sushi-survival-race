# m4-14 robux shop — 개발 작업 기록

## 2026-10-08 — QA 후 수정 R2~R5, qa-passed 유지 (최신)
- **브랜치**: `main` (커밋 d2be142 코드·테스트 + 문서 커밋). push는 메인 세션이 함.
- **끝난 것**: R2 결제 창이 열린 스킨의 코인 해금 거절(`ShopService.setCoinBlocker` ← `RobuxShopService.prompted`, 취소·Granted·120초에 해제, `ShopLogic` 거절 이유 `PurchasePending`), R3 클라이언트 취소 시 pending 해제, R4 fake + persist 같이 켜면 가짜 결제 끔 + 경고(`ShopLogic.fakeRobuxActive`), R5 Remotes 주석. `Config.Shop.PurchasePromptHold = 120` 추가.
- **테스트**: `tests/m4-14-qa.spec.luau` 가짜 MarketplaceService에 `PromptProductPurchaseFinished` 신호 추가 + 재현 테스트 4개(R2 거절·취소/타임아웃 해제·RecordOnly 경고 유지, R4, R3·R5 소스). `receipt-logic.spec`의 소스 검사를 새 fakeMode 형태로.
- **검증**: rojo build OK, stylua OK, selene 0/0/0, lune 1016 passed / 0 failed, luau-lsp 에러 0.
- **남은 것**: 사용자 C3·Studio 확인(QA 리포트 체크리스트). R1(USER-TODO 개인정보 삭제)은 메인 세션.
- **다음에 할 첫 단계**: docs-writer가 M4 완료 문서 반영. Studio에서 일반 스킨 "R$ 49로 사기" → 창 취소 → 코인 해금이 바로 되는지, 창이 떠 있는 동안 해금이 거절 문구인지.
- **막힌 점**: 없음. 클라이언트 쪽 PromptProductPurchaseFinished가 실제로 취소 때 오는지는 Studio에서 확인 필요.

## 2026-10-08 — 구현 완료, in-qa
- **브랜치**: `main` (커밋 4a03333 순수 로직·공용, e5db97f 서버, 7943c94 클라이언트 + 문서 커밋). push는 메인 세션이 함.
- **끝난 것**: 스펙 범위 1~6, AC1~AC5. m4-13 QA N1(탈락 연출 중 스킨 버튼 숨김)·N3(결제는 grantSkin 결과가 아니라 canPersist + saveNow), m4-12 QA N3(logArenaStats Studio 가드).
  - 순수: `ReceiptLogic` (decide·process·canRequest·message·receipts 목록), `ShopLogic` 로벅스 카드 상태, 프로필 `receipts` 칸.
  - 서버: `RobuxShopService` (ShopService 다음 등록, ProcessReceipt 하나), `PurchaseLog` (`Purchases_v1`).
  - 클라이언트: 로벅스 버튼·실제 가격·획득 안내.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 990 passed / 0 failed (receipt-logic 16개 새로), luau-lsp analyze 에러 0.
- **남은 것**: QA, 사용자 C3(상품 15개 + id), Studio AC6~AC9 (스펙 개발 메모 "Studio 확인 방법" 1~6).
- **다음에 할 첫 단계**: QA가 `tests/receipt-logic.spec.luau`와 `RobuxShopService`의 port(특히 `save`·`profileReady`)를 검토. 사용자가 id를 주면 `Skins.luau` productId에 넣고 `lune run tests`(AC4 겹침 검사).
- **막힌 점**: 없음. Studio가 없어 결제 창·화면은 확인 못 함.
- **메모**
  - ProcessReceipt를 ShopService가 아니라 RobuxShopService에 둔 이유: `tests/m4-13-qa.spec.luau`가 ShopService 소스를 가짜 환경(서비스 4개만)에서 돌려요. ShopService에 require를 더하면 그 테스트가 깨져요.
  - `AlreadyRecorded`·`RecordOnly`도 저장 성공이 필요해요: 앞 시도에서 저장이 실패하면 메모리 프로필엔 스킨이 있어서 `owned`가 true로 보여요.
  - Studio 가짜 결제는 `fakeReceipts[purchaseId]`로 스킨을 찾고(상품 id가 없으니), 메모리 프로필이면 save를 성공으로 봐요. `ServerStorage.ShopDebug.ReplayReceipt`는 fake 모드일 때만 생겨요.
  - 누수 점검(`m4-12-hardening`) 예외에 `PurchaseLog.luau:memory` 추가 (Studio 메모리 기록, 결제당 한 줄).
