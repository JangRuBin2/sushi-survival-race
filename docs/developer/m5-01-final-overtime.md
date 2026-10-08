# m5-01 결승 연장전 — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)

**브랜치**: `m5-01-overtime` (origin/main b1ef1d2에서 시작, push 완료)

### 끝난 것
- 스펙 범위 1~8 전부 구현: `RoundLogic.schedule/clockPhase`, RoundService 연장전 루프(결승만, 훅 한 번, 안전 상한), `RoundProgress.overtime/collapseAt`, `MapTypes.overtime`(Final 필수, validate), 꼬치 쇼다운 연장전(손 중단·가속·바깥 줄부터 붕괴), HUD 배너·빨간 타이머, `Overtime` 효과음(무음)·배경음 1.1배(`Sfx.setMusicSpeed`), `Config.Final`·`DEBUG.overtimeAt = nil`.
- 테스트 AC1~AC9 추가. 검증 5단계 통과: lune 1032 passed / 0 failed, luau-lsp 오류 없음.
- 공용 파일은 스펙 담당분(Config, Types, MapTypes)만 수정. Remotes·Attributes·init 스크립트·ShopService(m5-02 담당)는 안 건드림.

### 남은 것
- QA (`docs/qa/m5-01-final-overtime.md`), Studio 확인 AC11~17 (사용자).
- `Overtime` 효과음 id 고르기 (USER-TODO A2 제안 — docs-writer).

### 다음에 할 첫 단계
- QA 반려가 오면 `docs/qa/m5-01-final-overtime.md`의 버그부터. 없으면 할 일 없음.

### 막힌 점 / 메모
- 줄 간격은 AC9를 지키느라 2.5초가 아니라 약 2.71초 (스펙 개발 메모).
- `camera-priority.spec.luau`의 고정 cue 목록에 `Overtime`을 추가했어요 (새 cue를 넣으면 깨지는 테스트).
- 연장전 상태는 `SkewerShowdown`의 `roundStates[ctx]` (ctx 키, ctx.cleanup이 지움) — 여러 방 동시 진행 안전.
