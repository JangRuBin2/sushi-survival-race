# m4-06 lobby-art-podium — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-06-lobby` (origin/main aa4cc72 기반), push 완료.
- **끝난 것**: 스펙 범위 1~5 전부.
  - `src/shared/LobbyLayout.luau`(새, 순수 데이터): 건물·장식 DecorSpec, 빛 8, 타원 레일과 `plateAt`, 단상, `WINNER_ATTRS`, 비울 영역, 조명 표.
  - `src/server/LobbyService.luau`: init 조명, start 로비 생성(Match 역할이면 생략), 단상 이름표 + 폴더 속성.
  - `src/client/fx/LobbyFxController.luau`: 접시 로컬 회전(`BulkMoveTo`, 서버 시각 기준), 단상 인형 세우기.
  - `tests/lobby-layout.spec.luau` 11개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 575 passed / 0 failed.
- **남은 것**: Studio 확인 AC6~AC11 (사용자, 스펙 "개발 메모" 순서). QA.
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"대로 검증.
- **막힌 점**: 없음.
- **메모**:
  - 단상 인형을 서버에서 만들면 `tests/m3-02-qa.spec.luau`의 "서버에서 SushiBody는 AppearanceService뿐" 불변식이 깨져서, 인형은 클라이언트가 만든다 (스펙 결정 기록). 서버 소스에는 "SushiBody"라는 글자도 쓰면 안 된다(주석 포함, 테스트가 문자열 검색).
  - 접시는 서버가 `plateAt(i, 0)` 자리에 멈춰 두고, 클라이언트가 같은 기준으로 상대 CFrame을 계산한다. 접시 파츠를 바꾸면 양쪽이 자동으로 맞는다.
  - 방 안쪽 벽면 ±88: "반지름 128"을 수평 거리로 지키려고 (모서리 127.3).
