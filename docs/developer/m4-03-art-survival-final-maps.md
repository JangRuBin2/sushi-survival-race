# m4-03 art survival/final maps — 개발 작업 기록

## 2026-10-08 — QA 후 수정 (최신)
- **브랜치**: 로컬 `m4-03-art-arena`에 `origin/m4-03-qa`(a9c031c) 병합 후 수정, `origin/m4-03-qa`로 push. 스펙 status는 qa-passed 유지.
- **끝난 것**: B1 툇마루·가게를 8 낮추고 문을 z -46으로 옮김, 가짜 바닥 테스트 3개. B4 고정 장식 CastShadow 끔. B2 주방 벽을 멀리(cz-90), 후드·가게 건물은 Studio 확인으로 결정 기록.
- **검증**: rojo build OK, stylua OK, selene 0/0/0, lune 735 passed / 0 failed (map-art-arena 21개, m4-03-qa 11개).
- **남은 것**: Studio 체크리스트(QA 리포트 1~9). B3·B5(P3)는 손대지 않음.
- **다음에 할 첫 단계**: 메인 세션이 `m4-03-qa`를 main에 병합.
- **막힌 점**: 없음.

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m4-03-art-arena` (origin/main aa4cc72에서 분기). 커밋 65bcb96(코드) + 문서 커밋, push 완료.
- **끝난 것**: 스펙 범위 1~4 전부. 새 `HotPlateArt.luau`, `SkewerShowdownArt.luau`, `tests/map-art-arena.spec.luau`(18개). `HotPlate.luau`/`HotPlateLogic.luau`(색 상수만)/`SkewerShowdown.luau` 아트 반영. 꼬치 넉백 `MoveExempt.mark`. 손으로 짠 IntroCamera로 m3-04 B2 해소(두 맵 모두 IntroCamera 폴더가 있어 자동 경로·내 위치 끝점을 안 씀).
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 582 passed / 0 failed.
- **남은 것**: Studio 확인 AC7~AC13 (사용자), QA.
- **다음에 할 첫 단계**: QA가 m4-03 검증 → 통과 후 메인 세션이 main에 병합.
- **막힌 점**: 없음.
- **메모**:
  - 공용 파일 수정 없음.
  - 꼬치 음식 장식은 Decor/<Skewer>Food 폴더에 있고, start의 Heartbeat에서 꼬치 CFrame 기준 상대 위치로 `workspace:BulkMoveTo`. 판정 계산엔 안 들어가요.
  - 조각 장식(금 선·남색 테두리)은 조각 Model 안이라 경고 깜빡임 때 같이 빨개지고 손이 가져갈 때 같이 사라져요 (의도).
  - 타일 Neon 전환 대비 `CustomPhysicalProperties` 고정, 기둥 재질 변경도 Metal 물성 고정.
  - Roblox는 Ball을 균일 크기로, Cylinder 단면을 원으로 맞추므로 테스트(shapeProblem)로 데이터를 막아 둠 — 다른 맵 아트도 참고.
