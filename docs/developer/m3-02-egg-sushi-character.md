# m3-02 egg sushi character — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m3-02-character` (push함)
- **끝난 것**: `SushiBody`(layout/bounds/build/GROUND_OFFSET), `AppearanceService.applyAppearance`(숨김 + `SushiJoint` Motor6D, 아바타 외형 로딩 끔), `CharacterFxController`(걷기 통통, 넘어짐 버둥 + "@_@" + Knockdown 소리, m3-03 숨김 존중), 테스트 `tests/sushi-body.spec.luau` 7개.
- **검증**: rojo build OK, stylua --check OK, selene 0 errors/0 warnings, lune 222 passed / 0 failed.
- **남은 것**: Studio 확인 AC5~AC10 (사용자). QA.
- **다음에 할 첫 단계**: QA가 스펙 개발 메모의 Studio 확인 방법대로 검증.
- **막힌 점**: 없음. 초밥 Model/관절 이름(`SushiBody`/`SushiJoint`)을 서버·클라이언트 두 곳에 상수로 적음 — 공용 상수로 옮길지는 m3-09 (스펙 결정 기록).
