# m3-01 foundation — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (커밋함, push는 메인 세션이 함)
- **끝난 것**: 스펙 범위 1~9 전부. 공용 파일(Config·Remotes·Types·default.project.json), Attributes·SfxCues·CameraPriority, CameraDirector 실제 구현, SpectateController를 CameraDirector로 전환 + 탈락 대상 3초 비추기, RoundService 맵 속성·cause/position·`activeRoomOf`, 껍데기(SushiBody, AppearanceService, GrabService, Sfx, fx 4개, input 2개)와 init 등록. 테스트 `tests/camera-priority.spec.luau` 6개.
- **검증**: rojo build OK, stylua --check OK, selene 0 errors/0 warnings, lune 215 passed / 0 failed.
- **남은 것**: Studio 확인 AC5~AC9 (사용자). QA.
- **다음에 할 첫 단계**: QA가 m3-01 검증 → 통과 후 m3-02~08 worktree 생성.
- **막힌 점**: 없음. 질문 하나를 스펙 결정 기록에 남김 — 시간 종료·통과 인원 다 참으로 탈락한 사람은 `cause = nil`이라 m3-03 탈락 연출이 안 나옴 (원하면 m3-09에서 cause 추가).
