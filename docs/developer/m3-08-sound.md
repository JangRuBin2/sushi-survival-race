# m3-08 sound — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m3-08-sound` (push함)
- **끝난 것**: 스펙 범위 1~4 전부. `SfxLibrary`(cue 표 + `musicFor`), `Sfx.play`(2D/3D, 0.05초 같은 cue 제한, 동시 16개, 다 울린 Sound 정리), `Sfx.setMusic`(0.5초 페이드), `Sfx.start`(SoundGroup Sfx 0.7/Music 0.3, RoomUpdated·MatchPhase로 배경음, 모든 GuiButton 클릭음, 내 Passed면 Qualified, `SoundGui` 음소거 3단계 버튼). 테스트 `tests/sfx-library.spec.luau` 5개.
- **검증**: rojo build OK, stylua --check OK, selene 0 errors/0 warnings, lune 220 passed / 0 failed.
- **남은 것**: Studio 확인 AC6~AC10 (사용자). QA. 사용자가 배경음 4곡과 id 없는 효과음 8개를 Creator Store에서 골라 `SfxLibrary.Entries`에 넣기.
- **다음에 할 첫 단계**: QA가 m3-08 검증 → m3-09 통합에서 장애물 cue를 서버 맵에 붙임 (`SfxLibrary.get(cue)`로 id·볼륨 읽기).
- **막힌 점**: 이 PC에 Roblox가 없어 `content\sounds`를 직접 못 봄 → 공개 클라이언트 추적 저장소의 `rbxManifest.txt`로 실제 있는 소리 11개만 사용 (스펙 결정 기록). 공용 파일 변경 없음.
