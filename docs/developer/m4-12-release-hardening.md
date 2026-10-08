# m4-12 release hardening — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (5c1308c 위 커밋 98eadcb, 04e0fe6, ce9f470 + forceMapPlans·문서 커밋). push는 메인 세션이 함.
- **끝난 것**
  - 타입 검사(m2-07 I2): `luau-lsp` 1.70.1을 rokit에 고정, Roblox 정의 파일을 `types/`에 커밋, 새 검사기(`LuauSolverV2`)로 `src/` 에러 72 → 0 (타입 표기만, 동작 같음). 명령은 스펙 개발 메모 / `types/README.md`.
  - P3: m3-09 B3(약한 키), m3-07 G1·G4(`GrabInputLogic` + `GrabController`), m4-02 Q1·Q2, m4-03 B3, m4-05 C2·C3, m4-07 D5.
  - 연속 매치: `Config.DEBUG.logArenaStats`, `Config.DEBUG.forceMapPlans`(매치마다 다음 강제 플랜), `RoundService.debugHookCount`, 테스트(순수 10판 시뮬레이션·모듈 전역 표 정리 점검).
  - 출시 체크리스트: 스펙 개발 메모에 USER-TODO 칸 대응표 + 개인정보 삭제 절차.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 911 passed / 0 failed, luau-lsp analyze 끝 코드 0 (에러 0).
- **보류**: m3-09 B4, m4-05 C1(판정 수치), m4-03 B5, m4-06 L2(m4-13), m4-07 D6, m4-08 B4(Studio 확인) — 스펙 결정 기록에 사유.
- **남은 것**: QA. 사용자 Studio AC4~AC7(스펙 개발 메모 "Studio 확인" 1~6). docs-writer: 검증 5단계를 WORKFLOW·CLAUDE.md·에이전트 정의에, "도구를 못 받으면 타입 검사 못 함을 보고" 규칙, DEV-SETUP 3-9 체크리스트.
- **다음에 할 첫 단계**: QA가 `tests/m4-12-hardening.spec.luau`와 타입 검사 명령을 돌려 확인. 사용자 AC4 숫자를 받으면 스펙 개발 메모에 기록.
- **막힌 점**: 없음. Studio가 없어 AC6(다이브 지름길)은 확인 못 함.
- **메모**
  - 옛 검사기(기본값)는 140건을 냄: `pcall` 반환값 개수, `Instance ~= nil` 비교, `{UICorner, UIPadding}` 자식 배열 같은 올바른 코드. 새 검사기를 쓰기로 함. VS Code 확장은 `luau-lsp.fflags.enableNewSolver = true`.
  - 새 검사기에서 자주 나오는 패턴과 해결: `table.insert(list, { … 리터럴 … })` → 타입을 붙인 지역 변수로 넣기, `table.create(n)` → `:: { T }` 캐스트, `table.sort` 비교 함수 인자 타입 표기, 메서드 호출 결과(`…CFrame`)를 인자로 넘길 때 괄호, 다른 모양 표 배열을 받는 함수는 `{ read [number]: { read field: T } }`.
