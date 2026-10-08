# m3-06 dive — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m3-06-dive` (origin에 push)
- **끝난 것**: 스펙 범위 1~7 전부. `src/shared/DiveLogic.luau`(순수), `src/client/input/DiveController.luau`, `src/client/input/DiveButton.luau`, `tests/dive.spec.luau`(14개). 공용 파일 수정 없음.
- **검증**: rojo build OK, stylua --check OK, selene 0 errors / 0 warnings, lune 229 passed / 0 failed.
- **남은 것**: Studio 확인 AC7~AC15 (사용자), QA.
- **다음에 할 첫 단계**: QA가 스펙 수용 기준대로 검증. Studio에서 엎드린 자세·착지 판정 체감이 어색하면 `DiveController.luau`의 `PRONE_PITCH`·`isGrounded`부터 본다.
- **막힌 점**: 없음. 스펙에 없던 판단 3개를 결정 기록에 남김 (관전 판정에 Scriptable 카메라 포함, Flying 동안 수평 속도 유지, 기울인 동안 넘어짐 상태 끄기).
