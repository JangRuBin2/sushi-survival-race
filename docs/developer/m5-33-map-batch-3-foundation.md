# m5-33 map batch 3 foundation — 개발 작업 기록

## 2026-10-15 — 구현 완료, in-qa
- **브랜치**: `main` (스펙 지정 "main 순차, 단계 0"). 코드 커밋 `55e578c` + 문서 커밋. **push 안 함** — 메인 세션이 판단(지시).
- **끝난 것**: 스펙 범위 1~6, 8 전부. 범위 7(현지화 CSV)은 m5-26이 main에 없어 할 일 없음(결정 기록 D5). AC1~AC8 통과, AC9·AC10은 사용자 Studio 확인.
  - 새 맵 껍데기 6개 + `<Map>Art.luau` 껍데기 6개, `maps/init.luau` 등록(`allInfos` 21, `infos` 15).
  - cue 14개(무음), 파티클 프리셋 3개.
  - 풀 개수 테스트 "목록 기준": `tests/lib/Batch3.luau` 한 곳 + 기존 테스트 8곳(표는 스펙 개발 메모).
  - `tests/m5-33-batch3.spec.luau` 7개. 전체 1999 passed, 0 failed(이전 1992).
  - 껍데기를 풀에 넣는 시뮬레이션(2개, 6개 전부)으로 공용 테스트가 안 깨지는 것 확인 후 되돌림.
- **검증 5단계**: 모두 통과 (rojo build, stylua --check src tests tools, selene 0/0, lune 1999/0, luau-lsp exit 0).
- **결정**: D6 — 새 Race 껍데기는 바닥 뒤 가장자리를 z = +20으로(m5-13 패턴은 스폰 4번째 줄이 바닥 밖이었음, 기존 맵은 손대지 않음).
- **남은 것**: QA(m5-33), 사용자 Studio AC9·AC10. 그 뒤 main push → m5-34~39 worktree 생성.
- **다음 첫 단계**: QA가 스펙 수용 기준대로 확인. 맵 스펙 담당은 자기 `<Map>.luau`·`<Map>Art.luau`를 덮어쓰고, 끝나면 `inPool = false` 줄만 지운다 — 공용 테스트·`init.luau`·SfxCues·SfxLibrary·MapFxPresets는 고치지 않는다.
- **참고(맵 스펙에게)**: `tests/m5-33-batch3.spec.luau` AC5는 실제 맵에도 적용된다 — 스폰 24개가 충돌 파츠 윗면 바로 위(0~6)이고 서로 3 이상, Race는 `FinishLine`(이름 그대로, 자손 어디든)이 스폰보다 −Z. AC1의 displayName·rule도 확정값으로 고정.
- **막힌 점**: 없음.
