# m5-03 foundation — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (push 안 함 — 메인 세션 지시). 커밋 `6c7db78`(맵 inPool·껍데기) · `222e99e`(프로필 v2·카탈로그·판매 기간) · `f53c7c1`(공용 리모트·속성·Config·cue·껍데기 서비스/컨트롤러·PriceCache·코드 목록 로더·관리자 명령 등급) + 문서 커밋.
- **끝난 것**: 스펙 범위 1~16 전부, AC1~AC10 (lune 1133 통과, 검증 5단계 통과). 메인 세션 지시 2개 반영:
  - 공개 저장소 → 실제 코드 목록은 로컬 `src/server/CodeList.luau`(.gitignore), 커밋되는 건 로더 `CodeConfig.luau` + 빈 예시 `CodeList.example.luau`.
  - 사용자 결정: 실서버 테스트 명령 없음 → `LiveTestCommands` 없음. `AdminLogic.canRun`은 실서버에서 Info만, AdminService `AdminCommand` 틀이 Studio 확인 뒤에만 `runCommand`(m5-11이 채움).
- **남은 것**: QA, 사용자 Studio 확인(AC11~13). `BuyWithTokens` 핸들러는 m5-07.
- **다음에 할 첫 단계**: QA가 `docs/specs/m5-03-foundation.md` 수용 기준대로 확인 → main push → 단계 1 worktree.
- **막힌 점**: 없음. (python이 Windows Store 스텁이라 편집은 perl/Edit로 함.)
