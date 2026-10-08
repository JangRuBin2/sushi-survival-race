# m4-05 map-chef-board — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-05-chef-board` (origin/main f33086b 기반, push 완료)
- **끝난 것**: 스펙 범위 1~8 전부.
  - `src/shared/maps/ChefBoardLogic.luau`: 격자 칸 61개, 보호 칸(가운데 3×3), 스폰 24곳, 줄 18개, 칼 주기·경고 시간, 경고 시각 목록, 줄 고르기(남은 칸 가중, 연속 금지), 잘려 나갈 칸, 맞음 판정, 넉백 방향, 기울기 일정·`tiltCFrameParams(t, plan)`.
  - `src/shared/maps/ChefBoardArt.luau`: 칸 색, 칸 칼자국 장식, 손님 얼굴 4개·주방 배경·등, IntroCamera 3점, 시야 상자.
  - `src/shared/maps/ChefBoard.luau`: build(칸·칼·스폰·장식) + start(기울기 적용·밀기·낙하 탈락 Heartbeat, 칼 스레드, 잘린 칸 떨어짐).
  - `tests/map-chef-board.spec.luau` 20개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 539 passed / 0 failed.
- **남은 것**: Studio 확인 AC8~AC13 (사용자), QA.
- **다음에 할 첫 단계**: QA가 스펙 수용 기준대로 검증. 난이도 조정이 오면 `ChefBoardLogic` 맨 위 상수만 바꾸면 됨.
- **막힌 점**: 없음.
- **메모**:
  - 스펙의 "칸 중심이 반지름 36 안"은 69칸이라, 61칸에 맞게 `CENTER_LIMIT = 35`로 정함(결정 기록).
  - `tests/map-sfx.spec.luau` MAP_CUES 표에 ChefBoard를 넣지 않음(다른 스펙 소유 파일). 필요하면 QA가 추가.
