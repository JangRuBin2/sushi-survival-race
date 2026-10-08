# m4-07 data persistence — 개발 작업 기록

## 2026-10-08 — QA 후 수정 (최신)
- **브랜치**: `m4-07-data` → `origin/m4-07-qa`로 push (origin/m4-07-qa + origin/main(m4-08) 병합 위에)
- **끝난 것**: D1(세션 GUID 잠금 + 같은 서버 재접속 대기), D2(해제 뒤 saveNow false), D3(persistent 표시), D4(음소거 재전송), dayNumber 하나로. 새 테스트 `tests/data-service.spec.luau` 5개(가짜 DataStore), profile-logic +2, m4-01-qa 가짜 환경 보강.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 619 passed / 0 failed.
- **남은 것**: 사용자 Studio 확인 AC6~AC10. D5·D6·D7 보류(스펙 결정 기록).
- **다음에 할 첫 단계**: 메인 세션이 m4-07-qa를 main에 병합.
- **막힌 점**: 없음.
## 2026-10-08 — 구현 완료, in-qa
- **브랜치**: `m4-07-data` (origin/main f33086b 기반), push 완료
- **끝난 것**: 스펙 범위 1~7 전부.
  - `DataService`: DataStore(`Config.Data.StoreName`, 키 `u_<UserId>`), UpdateAsync 세션 잠금(대기 5번 → 가져오기), 요청 에러 3번 재시도 → 임시 프로필, 자동 저장(60초, 바뀐 것 + 10분마다 잠금 갱신), 나갈 때·BindToClose(25초) 저장+해제, `saveNow`(세대 번호로 직렬화), 요청 예산 대기, Studio 메모리 모드.
  - `ProfileLogic`(새): migrate, lockDecision, canWrite, dayNumber + claim/commit/release/readLock/deepCopy.
  - `Sfx`: 음소거 저장(마지막 누름 0.5초 뒤, 전송 간격 최소 1초, 같은 값이면 안 보냄), 첫 프로필로 복원(먼저 누른 값 우선).
  - 테스트 `tests/profile-logic.spec.luau` 28개, `tests/lib/FakeSfxEnv.luau`에 가짜 ProfileStore·FireServer.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 547 passed / 0 failed.
- **남은 것**: QA, Studio 확인 AC6~AC10(사용자: 퍼블리시 + API 접근 + `persistDataInStudio = true`).
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"의 Studio 확인 방법대로 검증.
- **막힌 점**: 없음.
- **메모**:
  - 스펙 파일 목록 밖으로 `tests/lib/FakeSfxEnv.luau`를 고침(스펙 결정 기록에 사유). 다른 m4 스펙 중 Sfx를 고치는 것은 없음.
  - 로드가 비동기가 되어 `DataService.get`은 접속 직후 잠깐 nil일 수 있음 → `waitForProfile`/`onLoaded` 사용.
