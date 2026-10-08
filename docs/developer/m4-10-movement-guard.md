# m4-10 movement guard — 개발 작업 기록

## 2026-10-08 — QA 반려 수정, in-qa (최신)
- **브랜치**: 로컬 `m4-10-guard`에 `origin/m4-10-qa`(main 0314eb8 포함) 병합 후 수정 → `origin/m4-10-qa`에 push.
- **끝난 것**: B1(면제 중 상한 130/200 studs/s, 통과 순간 재검사도 적용), B2(RoundService 배치 알림·placedRoomOf, 기준점 = 스폰, Track 없으면 통과 거부), B3(StallGrace 0.5), B5(RevertSettle 0.5초 안 위반은 세지 않음).
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 826 passed / 0 failed.
- **남은 것**: QA 재검증, Studio AC6~AC9. 연속 밀기 표시를 뺄지 기획/QA 판단(결정 기록) — 빼면 벨트 위 속도 조작도 잡힘.
- **다음에 할 첫 단계**: QA가 m4-10-qa 브랜치로 재검증.
- **막힌 점**: 없음.

## 2026-10-08 — 구현 완료, in-qa
- **브랜치**: `m4-10-guard` (origin/main aa4cc72 기반). push 완료.
- **끝난 것**: 스펙 범위 1~5 전부. `MovementGuardLogic`(check/advance/allowPass/strikeLog), `MovementGuardService`(Heartbeat 샘플링, 되돌리기, 3회 경고, pass validator + 통과 순간 재검사), 테스트 26개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 590 passed / 0 failed.
- **남은 것**: Studio AC6~AC9 (사용자). QA. **병합은 맵 스펙(m4-02~05) 다음, 마지막에.** AC6는 그 `main`을 이 브랜치에 merge한 뒤.
- **다음에 할 첫 단계**: QA가 스펙 개발 메모의 Studio 확인 방법대로 검증. 병합 전 `git merge origin/main` 후 4개 검증 명령 다시.
- **막힌 점**: 없음.
- **메모**:
  - 공용 파일은 안 건드림. 복제 멈춤 대응 상수(MaxGap·StillDistance·StallGrace)는 `MovementGuardLogic`에 둠.
  - 지금 main 코드 기준 모든 정상 이동(다이브·와사비·꼬치 넉백·벨트·손 들어 올리기)은 `MoveExempt` 표시 없이도 기준 안 — 표시가 필요한 건 서버의 순간 위치 이동(스폰·toLobby, 이미 표시)과 새 맵의 큰 밀기.
  - 위험: 캐릭터끼리 물리 fling은 표시 불가 → AC9에서 확인.