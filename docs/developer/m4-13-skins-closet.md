# m4-13 skins closet — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (커밋 71e5f0c 공용 로직·테스트, 014e595 서버, b9f5a6f 클라이언트 + 문서 커밋). push는 메인 세션이 함.
- **끝난 것**: 스펙 범위 1~7 전부.
  - 순수: `Skins`(16종, GDD 9.2 가격, 코인은 일반만 500, `productId` nil), `ShopLogic`(canEquip·canBuyWithCoins·buyWithCoins·grantSkin·message·cardState), `SushiBody` 15종 레이아웃(+`shape`/`rotation`/`effect`), `EliminationCutsceneLogic.SKIN_LINES` ← `Skins.speech`.
  - 서버: `ShopService`(EquipSkin·BuyWithCoins, 잠금 = 라운드 레이서·탈락 연출·우승, 요청 간격 0.3초, `grantSkin` for m4-14), `AppearanceService.setResolver`·`refresh`(프로필 늦게 로드돼도 다시 입힘), `MatchService` 우승자 외형 기억(m4-06 L2 외형).
  - 클라이언트: `ShopController`·`ShopScreen`(ShopGui, UiScale, 탭·카드·회전 미리보기·결과 글씨, compact 2열).
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 952 passed / 0 failed, luau-lsp analyze 에러 0.
- **남은 것**: QA, 사용자 Studio AC6~AC11 (스펙 개발 메모 "Studio 확인 방법" 1~6), 스킨 모양 스크린샷 확인.
- **다음에 할 첫 단계**: QA가 `tests/skins.spec.luau`·`tests/shop-logic.spec.luau`와 Studio 확인 목록으로 검증. m4-14는 `Skins.LIST`의 `productId`를 채우고 `Skins.forProduct` → `ShopService.grantSkin(player, id, true)` → `DataService.saveNow` 순서로, `ShopLogic.ROBUX_ENABLED = true`.
- **막힌 점**: 없음. Studio가 없어 화면·모양은 확인 못 함.
- **메모**
  - 외형 적용 지점은 `AppearanceService.applyAppearance` 하나. ShopService는 `setResolver`·`refresh`만 써요 (서버 파일에 "SushiBody" 글자가 있으면 m3-02 QA 테스트가 실패해요 — 주석 포함).
  - AppearanceService가 DataService를 직접 require하지 않는 이유: m3-02 QA의 가짜 환경 테스트가 AppearanceService만 따로 불러와요.
  - Cylinder는 X축 방향. `rotation = { 0, 0, 90 }`이면 위를 보는 눕힌 원판(오이 단면·문어 빨판). `bounds`는 Rx·Ry·Rz 행렬로 회전한 상자의 축 정렬 외곽을 계산해요.
  - 외곽 ±15%(폭 2.8·높이 4.7·두께 2.28 기준)가 빠듯한 건 용 롤(두께 ×1.10, 높이 ×1.12)과 새우(꼬리). 모양을 고칠 때 `tests/skins.spec.luau` AC2를 돌려 보기.
  - 남은 L2: 단상 칭호·승수는 우승자가 쇼케이스 전에 나가면 없음. 우승 연출 인형도 그 경우 기본 외형.
