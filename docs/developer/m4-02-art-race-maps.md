# m4-02 art-race-maps — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-02-art-race` (origin/main aa4cc72에서 분기, push 완료)
- **끝난 것**: 스펙 범위 1~4 전부.
  - 새 순수 모듈 `RotatingBeltArt`, `SoySwampArt` (COLORS · decor · introCamera · courseVolume).
  - 회전 벨트 태그 전환(M1 B10): `Chopstick.taggedIn`/`stationsIn`, 벨트 구역 `Conveyor` 태그. `Hazards`·`Conveyors` 폴더는 정리용으로만 남음.
  - `MoveExempt.mark`: 벨트 밀기(0.5초 간격), 젓가락 잡기/놓기, 간장 감속 켜기/끄기, 와사비 튕김, 날치알 넘어짐.
  - 판정 파츠는 Color/Material/Reflectance만 바꾸고 물리는 `CustomPhysicalProperties`로 M3 재질 그대로.
  - 테스트 `tests/map-art-race.spec.luau` 14개.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 578 passed / 0 failed.
- **남은 것**: Studio 확인 AC7~AC13 (사용자), QA.
- **다음에 할 첫 단계**: QA가 스펙 AC1~AC6 검증, 사용자 Studio 확인 (스펙 "개발 메모"의 순서).
- **막힌 점**: 없음.
- **메모**:
  - `courseVolume()`은 스펙의 `{ min, max }` 하나 대신 구간별 상자 목록 (결정 기록).
  - 회전 벨트 스폰 13~24번이 출발 바닥 뒤 허공에 있음 (기존 버그, 결정 기록에 보고만 함).
  - 젓가락 끝 `Tip`은 젓가락에 WeldConstraint로 붙여 트윈을 따라감 — Studio에서 눈으로 확인 필요.
  - `SoySwampLayout.luau`는 손대지 않음.
