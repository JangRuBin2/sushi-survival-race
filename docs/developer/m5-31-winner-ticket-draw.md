# m5-31 우승자 뽑기 티켓 — 개발 작업 기록

## 2026-10-14 — 구현 끝, `in-qa`
- 브랜치: `m5-31-winner-ticket-draw` (main 7a30de7에서 시작, origin/main 2차 스펙까지 병합 — 문서만 바뀜, 충돌 없음)
- 끝난 것
  - 2차 사용자 결정(꽝 없는 등급별 확률, `drawGrade`, 빈 등급 비율 나누기, 샘플 UI) 반영. 1차(10%/꽝) 코드는 wip 커밋에만 남고 지금 코드에는 없음.
  - `DrawLogic`(grades·roll·displayPercents·perSkinPercent·featured), `ShopService` `DrawTicket`, `RewardService` 우승 뽑기권, 프로필 v3, Studio 전부 입기, 관리자 `tickets`, 뽑기 화면 `ui/DrawScreen.luau`, 탈의실 🎫 특 탭·배지.
  - 테스트 `tests/m5-31-draw-logic.spec.luau` 25개 + 기존 테스트 기대값 갱신(목록은 스펙 개발 메모).
  - 검증 5단계 통과: rojo build, stylua, selene 0/0, lune 1888 passed / 0 failed, luau-lsp 끝 코드 0.
- 남은 것: QA, Studio 확인(스펙 개발 메모 "Studio 확인 방법" 1~6), 뽑기 소리 id(사용자).
- 다음에 할 첫 단계: QA 리포트(`docs/qa/m5-31-winner-ticket-draw.md`) 읽고 P0/P1 수정.
- 막힌 점: 없음. 뽑기 화면 모양은 렌더러로 볼 수 없어 Studio 확인이 필요.

### Studio 확인 요약
1. 커밋 값(`unlockAllSkinsInStudio = true`)으로 Play → 모든 카드 "입기 (Studio)".
2. `unlockAllSkinsInStudio = false` → 🛠 패널 "🎫 티켓 +10" → 탈의실 "🎫 뽑기" → 샘플(`docs/귀여운 초밥 스킨 뽑기 UI.png`)과 비교, 확률표 전설 준비 중 / 5.0 / 15.2 / 30.3 / 49.5.
3. 뽑기 → 🛎️ 들썩 → "👑 스킨 획득!" 또는 "이미 가진 스킨이에요 → 🍚 +N", Output `[Draw]`.
4. 혼자 우승 → "+1 🎫 우승 뽑기권", 99장이면 "가득 찼어요".
5. 휴대폰 에뮬레이터에서 탭 3개(뽑기·확률·목록).

## 2026-10-14 — 1차 구현 (wip, 폐기)
- 1차 스펙(스킨 10% / 꽝 90%)으로 만든 것을 wip 커밋으로 push한 뒤, 사용자 변경으로 등급별 확률로 바꿈.
