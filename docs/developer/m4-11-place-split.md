# m4-11 place split — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `main` (커밋 178758f 코드 + 문서 커밋. push는 메인 세션이 함)
- **끝난 것**: 스펙 범위 1~7 전부.
  - 순수 로직: `PlacePayload`(manifest·matchHint·returnTicket·joinTicket·matchResult 만들기/검증, `arrivalReady`, `pickRestoreHost`), `RoomDirectoryLogic`(merge·cleanRemote·pickQuickJoin·키 파싱), `RoomLogic.addLateMember`·`key`, `PlaceRole.resolve` 흉내 인자.
  - 서버: `PlaceBackend`(real/fake), `PlaceService`(Lobby·Match 흐름, 텔레포트 재시도·묶음 재전송, 텔레포트 전 `DataService.saveNow`), `RoomDirectory`(SortedMap 방 목록·코드), `RoomService` 훅·복원 API, `MatchService.finish`.
  - 클라이언트: `LobbyController` 매치 서버 안내·🌐 표시·`Notice`.
  - 공용 파일: Types·Config·Remotes(`Notice`)·Attributes(`PlaceRole`). `default.project.json`·`maps/init` 변경 없음.
  - m4-06 QA L3(로비 역할 단상) 해결, m4-01 QA B2(크래시 경로 우승자) 수정, B3 계약 주석.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 863 passed / 0 failed.
- **남은 것**: QA, Studio AC7·AC8, 사용자 작업(Match 플레이스 생성·PlaceId 2개) 뒤 실제 서버 AC9~AC13.
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"의 Studio 확인 방법대로 검증. PlaceId를 받으면 `Config.Places`에 넣고 두 플레이스 퍼블리시.
- **막힌 점**: 없음 (실제 텔레포트·MemoryStore는 퍼블리시된 서버에서만 확인 가능).
- **메모**:
  - 신뢰 경계: 매치 서버는 `MatchManifest[PrivateServerId]`만 믿고 TeleportData 힌트는 읽지 않음. 로비 복귀는 `MatchResult[roomKey]`(매치 서버가 씀)를 티켓보다 우선. 참가 티켓은 JoinRoom/JoinByCode와 같은 검증(공개 방 id 또는 코드).
  - 데이터: 텔레포트 직전 `saveNow`(최대 5초), 잠금 해제는 PlayerRemoving의 기존 unload. 도착 서버는 기존 LoadRetries(5×2초) 대기.
  - stylua: 함수 인자 안에 긴 테이블 리터럴을 넣으면 포맷이 번갈아 바뀜 → 변수로 빼서 피함 (`tests/place-split.spec.luau` AC1 24명 케이스).
  - 디렉터리 쓰기는 5초마다(방 수만큼) + 방이 출발·닫힐 때 바로 지움. 요청 예산이 문제되면 `DirectoryRefresh`를 늘릴 것.
