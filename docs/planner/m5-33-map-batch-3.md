# planner 작업 기록 — m5-33~m5-40 맵 3차 배치 + 맵 길이 늘리기

## 2026-10-14 (최신)
- **브랜치**: 이 세션 체크아웃의 현재 브랜치(시작 때 `m5-32-fresh-mackerel`로 표시됨 — 메인 세션이 `main`에 커밋할지 확인). docs만 바꿈, 코드 없음.
- **끝난 것**
  - 사용자 콘셉트 시트 `docs/스시 서바이벌 레이스 신규 맵 6종.png`를 직접 보고 스펙 7개 작성(전부 `ready`): `m5-33`(기반, main 순차, 공용 `maps/init.luau` + cue 14 + 파티클 3 + 풀 개수 테스트를 목록 기준으로), `m5-34` dish-sink, `m5-35` space-conveyor, `m5-36` rice-cooker, `m5-37` fish-market, `m5-38` tea-garden, `m5-39` onsen-claw.
  - 사용자 추가 요청("맵들이 전반적으로 좀 짧다")으로 측정 → `m5-40-map-length-pass.md`(ready) + 새 Race 2개 길이(445·470 studs), 새 Survival 2개 `timeLimit = 75` 반영.
  - `docs/REFERENCE-map-batch-3.md`(사례·겹침 분석·풀 균형·길이), GDD 변경 이력 + §5.3 "3차 배치" 표·길이 메모, USER-TODO A1(한 판 시간 Q1·배치 3 기본값)·A2(소리 14개)·B3.
- **남은 것**: 개발(developer) — m5-33 먼저 main, 그 뒤 m5-34~39 worktree 병렬(포트 34892~34897), m5-40은 m5-33 뒤 4그룹(34898~34901).
- **다음 첫 단계**: 메인 세션이 커밋·push → developer에게 m5-33.
- **막힌 점 / 주의**
  - m5-32가 `SfxCues`·`SfxLibrary`에 `FishFlop`·`FishSplash`를 넣음 → m5-33은 m5-32 머지 뒤 시작(아니면 파일 끝 별도 묶음).
  - m5-26(현지화)이 먼저 들어가면 m5-33이 새 6개 맵 CSV 줄을 한 번에 넣음.
  - m5-40: 장식이 1500 가까운 맵(belt 1386·bouncy 1468·lantern 1412)은 새 구간 장식 재분배 필요 — 안 되면 메인 세션이 예산 단계 결정.
- **사용자 답을 기다리는 질문**: m5-40 Q1 한 판 전체 시간 목표(4~5분 유지 추천 / 5~6분). 나머지 맵 판단은 메인 세션 위임으로 결정 기록에 적음.
