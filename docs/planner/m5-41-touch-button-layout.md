# planner 작업 기록 — m5-41 모바일 터치 버튼 위치 편집

## 2026-10-14 (최신)
- **브랜치**: main 체크아웃(맵 스펙은 c97d11a로 커밋됨). docs만.
- **끝난 것**: `docs/specs/m5-41-touch-button-layout.md`(ready), `docs/REFERENCE-touch-button-layout.md`(조사), GDD §6 한 줄 + 변경 이력, USER-TODO B3 한 줄.
- **주요 결정**: 저장 = 프로필(Roblox에 기기 저장소 없음) + 비율 좌표 + 휴대폰/태블릿 묶음. 새 리모트 없이 `SaveSettings` 부분 저장, 프로필 v3 유지. 점프 = 기본 JumpButton을 옮기고 PlayerModule이 바꾸면 다시 적용(안 되면 자체 점프 버튼). 왼손잡이 반전 제외(조이스틱 왼쪽 고정). 라운드 중 편집 불가.
- **남은 것**: developer 구현(worktree `m5-touch-layout`, 포트 34902). 공용 파일 담당 = 이 스펙(Types·Remotes 주석·init.client).
- **다음 첫 단계**: 메인 세션 커밋 → `m5-26`(현지화)이 개발 중이 아닌지 확인 후 developer에게.
- **막힌 점**: m5-26과 Types·Remotes·init.client가 겹침 — 동시 개발 금지.
- **사용자 질문**: 없음(필수 아님).
