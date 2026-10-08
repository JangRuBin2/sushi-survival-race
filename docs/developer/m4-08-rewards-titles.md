# m4-08 rewards-titles — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-08-rewards` (origin/main f33086b 기반), push 완료.
- **끝난 것**: 스펙 범위 1~6 전부. RewardLogic(순수) + RewardService(서버 지급·승수·판 수·칭호 속성) + CoinScreen/CoinController(배지·토스트·정산) + CharacterFxController 칭호 줄 + `tests/reward-logic.spec.luau` 14개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 533 passed / 0 failed.
- **남은 것**: Studio 확인 AC6~AC10 (사용자), AC11은 m4-07 머지 뒤. QA.
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"의 Studio 확인 순서대로 검증.
- **막힌 점**: 없음.
- **메모**:
  - 공용 파일은 건드리지 않음. 정산 한 줄은 `CoinSummaryGui`라는 두 번째 ScreenGui에 둠 (스펙 결정 기록에 적음).
  - 하루 첫 판 판정·기록은 `DataService.update` 안에서 해서 같은 프로필에 두 번 주지 않음. 날짜는 `os.time() // 86400`(UTC).
  - 매치가 끝난 뒤 늦게 온 PlayerResult는 빈 tracker로 계산(Won만 지급), 방 상태를 다시 만들지 않음.
  - 이름표 칭호 줄은 BillboardGui.SizeOffset으로 이름 자리를 유지하게 했는데 방향은 Studio에서 확인 필요.
