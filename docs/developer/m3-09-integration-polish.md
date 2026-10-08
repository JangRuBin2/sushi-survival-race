# m3-09 integration-polish — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (커밋만, push는 메인 세션이 함)
- **끝난 것**: 스펙 범위 1~4 + 메인 세션이 넘긴 QA 항목 1~9. 장애물 소리(`MapSfx`/`MapSfxLogic`, 서버 신호 → 클라이언트 `Sfx` 재생), 맵 4개 소리 호출, `Config.Fx` 튜닝 묶음, Timeout cause + 연출, 결승 우승 발표 3초 지연, 공중 다이브 vy 상한, 다이브 상태 복원, 잡기 규칙(잡는 사람 대상 아님·다이브 해제), 넘어짐 Anchored 제외, 자체 이름표, KeepVisible/NoClickSfx 규칙, 좁은 화면 음소거 아이콘, 긴 효과음 수명, 소개 중 탈락, 우승 개인 글씨 생략, 관전 비추기 시간, 리셋 위치. 자세한 건 스펙 결정 기록·개발 메모.
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 463 passed / 0 failed.
- **남은 것**: QA, 사용자 Studio 확인(스펙 개발 메모 1~11), docs-writer가 DEV-SETUP M3 절에 Studio 목록 반영. 사용자가 `ChopstickWarn`·`HotTileSizzle`·`ChefHandWarn` 등 id 없는 소리를 `SfxLibrary`에 채우기.
- **다음에 할 첫 단계**: QA가 `docs/specs/m3-09-integration-polish.md` 검증.
- **막힌 점**: 없음. 스펙 범위 1(서버가 Sound 생성)과 다르게 서버는 RemoteEvent `MapSfx`로 알리고 클라이언트가 소리를 냄 — 결정 기록에 이유(음소거·pitch) 적음.
