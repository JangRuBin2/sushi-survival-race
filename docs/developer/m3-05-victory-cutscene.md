# m3-05 victory cutscene — 개발 작업 기록

## 2026-10-08 — QA 반려 수정, 다시 in-qa (최신)
- **브랜치**: `m3-05-victory` (origin/m3-05-qa 병합 — QA 테스트·리포트, main의 m3-02 등 포함. push함)
- **끝난 것**: B1(박수 카메라를 부두 끝 너머 z -31로), B2(연출 뒤 FOV 복원). B3는 HudController라 m3-09로 넘김(스펙 결정 기록).
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 311 passed / 0 failed (QA B1 재현 테스트 포함).
- **남은 것**: QA 재검증, Studio AC7~AC12 (사용자).
- **다음에 할 첫 단계**: QA가 B1·B2 재확인.
- **막힌 점**: 없음.

## 2026-10-08 — 구현 완료, in-qa
- **브랜치**: `m3-05-victory` (origin/main 08d49fd에서 분기, push함)
- **끝난 것**: 스펙 범위 1~7 전부. `VictoryCutsceneLogic`(순수), `VictoryProps`(회색 박스 장면), `VictoryCutsceneScreen`(큰 글씨), `VictoryCutsceneController`(재생·정리·카메라·효과음), `HudScreen` Victory 분기(배너·순위표를 연출 뒤로). 테스트 `tests/victory-cutscene.spec.luau` 13개.
- **검증**: rojo build OK, stylua --check OK, selene 0 errors/0 warnings, lune 248 passed / 0 failed.
- **남은 것**: Studio 확인 AC7~AC12 (사용자). QA.
- **다음에 할 첫 단계**: QA가 m3-05 검증. m3-02 머지 뒤 인형이 계란초밥으로 나오는지, 박수 때 얼굴이 카메라 쪽인지 확인.
- **막힌 점**: 없음. 공용 파일은 건드리지 않음. 가정 하나 — SushiBody 인형의 앞이 -Z(LookVector). 반대면 `dollPose`의 Clap yaw를 0으로.
