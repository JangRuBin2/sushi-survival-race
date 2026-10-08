# m3-04 라운드 소개 플라이스루 — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m3-04-intro` (origin/main 08d49fd 기반, push함)
- **끝난 것**: 스펙 범위 1~6. `IntroCameraLogic`(autoPath/sample/ease, 숫자 표), `IntroController`(대상 판정·맵 찾기 1초·IntroCamera 폴더 또는 자동 경로·비행 80%/복귀 20%·RoundActive에 release·"출발!"+Sfx Go), `IntroScreen`("출발!" 팝), 테스트 `tests/intro-camera.spec.luau` 10개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 245 passed / 0 failed.
- **남은 것**: Studio 확인 AC6~AC11 (사용자), QA.
- **다음에 할 첫 단계**: QA가 `docs/specs/m3-04-round-intro-flythrough.md` 개발 메모대로 검증.
- **막힌 점**: 없음. 공용 파일 변경 요청 없음.
