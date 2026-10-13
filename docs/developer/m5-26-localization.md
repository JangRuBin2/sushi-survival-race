# m5-26 현지화 개발 작업 기록 (developer)

## 2026-10-13 — 1단계 완료, in-qa (최신)

**브랜치**: worktree 브랜치 → 원격 `m5-26-i18n` (main c65266a = m5-25 머지까지 병합함)

### 끝난 것
- 1단계 전부: `Strings.csv` 397행(ko 원문 + 영어), `LocalizeLogic`(순수), 클라이언트 `Loc`, 서버 `ServerLoc`(Kick만), 서버 메시지 LocText(방·플레이스·탈의실·상점·결제·코드), Notice kind 항상, 기본 방 이름 `nameIsDefault`(서버 이동·다른 서버 목록 포함), 클라이언트 UI 전부(관리자 제외) `Loc` 경유, `RoomUiKit` AutoLocalize false 기본.
- 2단계 일부: `CharacterFxController` 칭호(`Loc.titleFromName`)·이름표 AutoLocalize false (m5-25 머지 뒤라 메인 세션이 허락).
- 테스트: `tests/localization.spec.luau` 20개(AC1~AC13, AC14 일부, AC15), 기존 테스트 문구 비교를 `LocTest.ko`·키 비교로.
- 검증 5단계 통과: rojo build · stylua · selene 0/0 · lune 1787 passed 0 failed · luau-lsp 끝 코드 0.
- 스펙 "결정 기록"(메인 세션 기본값 + 구현 세부)과 "개발 메모"(바뀐 파일·Studio 확인 방법) 작성.

### 남은 것
- QA (AC17~AC24는 사용자 Studio·실서버 확인).
- 2단계: 로비 우승자 단상(`LobbyService`/`LobbyLayout` SurfaceGui → 서버는 속성, `LobbyFxController`가 Loc으로; `Attributes.luau` 추가 필요), 간장 늪 "매워!!"(`SoySwampHazards`) 처리 방식 결정.
- docs-writer: CLAUDE.md 규칙, DEV-SETUP(Player Emulator·AC17~AC23), USER-TODO(CSV 업로드, 자동 번역 켜기, AC24).

### 다음에 할 첫 단계
- QA 리포트가 오면 그 버그부터. 2단계를 하면 `LobbyService.setLabels` 쪽부터 읽기.

### 문구를 고칠 때
- `src/shared/Localization/Strings.csv`를 직접 고쳐요(키는 바꾸지 않기). 새 문구는 행 추가 + 코드에서 `Loc.t("키")`(서버·순수 로직은 `LocalizeLogic.text("키")`). `lune run tests`의 localization.spec이 빠진 키·안 쓰는 키·데이터 원문 불일치·자리표시자·버튼 길이·조사 규칙을 잡아요.
- 새 맵·스킨·상품·시즌은 CSV에 `map.<id>.name|rule` 같은 행도 같이 (안 하면 AC5 테스트 실패).

### 막힌 점
- 없음. Roblox에서 확인 못 한 것(플레이스 표·클라우드 표 우선순위, 자동 번역의 자리표시자 보존 등)은 설계가 폴백으로 덮어요 — AC20·21·24로 사용자 확인.
