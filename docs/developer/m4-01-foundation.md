# m4-01 foundation — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (커밋 c880407, 2f6cb83, 0daea60 + 문서 커밋. push는 메인 세션이 함)
- **끝난 것**: 스펙 범위 1~17 전부.
  - 공용 파일: Config(Places·Teleport·Data·Rewards·Titles·Ui·MovementGuard·DEBUG.persistDataInStudio), Remotes(ProfileUpdated·RewardGranted·SaveSettings, 총 16개), Types, Attributes(Title·MoveExemptUntil), maps/init(새 stub 2개), default.project.json(MapArt·LandscapeSensor), init.server/init.client 등록 순서.
  - 새 모듈: ProfileSchema, PlaceRole, MoveExempt, MapKitLogic, MapKit, MatchEvents, DataService(메모리), ProfileStore, PlaceService.role, 맵 stub RamenRapids·ChefBoard, 껍데기 6개.
  - 기존 수정: MatchService 훅, EliminationService fireResult, RoundService setPassValidator·MoveExempt·마지막 땅 위치, CharacterUtil toLobby MoveExempt, RoundLogic 결승 묶음 리셋 규칙(m2-07 I1).
  - 테스트 `tests/m4-foundation.spec.luau` 26개, camera-priority Attributes 개수 갱신.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 519 passed / 0 failed.
- **남은 것**: Studio 확인 AC9~AC14 (사용자). QA.
- **다음에 할 첫 단계**: QA가 m4-01 검증 → 통과 후 main push, m4-02~m4-10 worktree 생성.
- **막힌 점**: 없음.
- **메모**:
  - stylua 2.5.2가 긴 함수 타입 인자를 두 모양으로 번갈아 포맷해서 `--check`가 안 맞았음 → `MatchEvents.RoundStartHandler` 타입 별칭으로 피함. 다른 스펙도 긴 함수 타입 인자는 별칭으로.
  - 빈 폴더 유지는 `assets/map-art/README.md` (Rojo가 .md 무시, 빌드 확인).
  - 결승 묶음이 전부 리셋이면 이제 `round.ended = true`로 바로 끝남 (예전엔 이 경로가 없었음).
