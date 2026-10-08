# m4-04 map-ramen-rapids — 개발 작업 기록

## 2026-10-08 — QA P2 R1·R2 수정 (최신)
- **브랜치**: `m4-04-ramen` (origin/m4-04-qa 06ae17c 병합), push 대상 `origin/m4-04-qa`
- **끝난 것**: R1 급류 끝 넓은 착지판 `LandingRaft` + 토핑 재배치, R2 급류 앞 밀기 20(소용돌이 안 14). 테스트 `QA R1`·`QA R2` 추가.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 626 passed / 0 failed.
- **남은 것**: Studio 확인 AC8~AC13 (사용자). 스펙 status는 qa-passed 유지.
- **다음에 할 첫 단계**: main 병합.
- **막힌 점**: 없음.

## 2026-10-08 — 구현 완료, in-qa
- **브랜치**: `m4-04-ramen` (origin/main f33086b 기반, push 완료)
- **끝난 것**: 스펙 범위 1~6 전부.
  - `RamenRapids.luau` stub 덮어씀 (구간 A~E, 태그 Broth·Chashu·NoodleSweeper, 장식·김·IntroCamera·attachStudioArt).
  - 새 `RamenRapidsLayout`(치수), `RamenRapidsLogic`(차슈 높이·막대 각도/맞음·밀기·낙하선·진행도·건너는 길 탐색), `RamenRapidsArt`(장식 161개, 김 3, IntroCamera 4, 시야 상자 5).
  - 테스트 `tests/map-ramen-rapids.spec.luau` 16개.
  - 공용 파일 수정 없음.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 535 passed / 0 failed.
- **남은 것**: Studio 확인 AC8~AC13 (사용자), QA.
- **다음에 할 첫 단계**: QA가 `docs/specs/m4-04-map-ramen-rapids.md` "개발 메모"의 Studio 확인 방법대로 검증.
- **막힌 점**: 없음.
- **메모 (결정 기록에도 있음)**:
  - 잠긴 차슈는 CanCollide를 꺼서 위에 있던 사람이 빠짐.
  - 젓가락 막대 = 두께 2.5, 바닥 위 중심 1.5, 한쪽 팔(길이 = 반지름). 맞음 판정은 `SkewerShowdownLogic.isHit` 재사용.
  - 출발 → 결승 낙하 약 30 (스펙 "약 40"). `BROTH_Y`로 조정.
  - 급류 밀기는 회전 벨트 방식(목표보다 느릴 때만 가속). 체감이 약하면 `LinearVelocity` 방식이나 `BROTH_PUSH_SPEED` 상향 검토.
