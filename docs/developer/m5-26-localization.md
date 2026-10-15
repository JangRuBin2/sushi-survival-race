# m5-26 현지화 개발 작업 기록 (developer)

## 2026-10-15 — main(8750ee6) 병합 p3 + 새 문구 현지화, in-qa (최신)

**브랜치**: 원격 `m5-26-i18n-p3` (= `m5-26-i18n-p2` 64b8ed8 + `origin/main` 8750ee6 병합). main은 건드리지 않음.

### 끝난 것
- 병합 충돌 13개 파일 해결(스펙 개발 메모 "main 병합 p3"). main 기능(🎫 뽑기, 터치 편집, 맵 3차, 맵 길이) 그대로 + LocText 계약.
- 새 사용자 문구 현지화: 뽑기 화면·뽑기 오류·티켓 토스트/정산, 탈의실 🎫 특, ⚙ 버튼 위치 편집, 맵 3차 6개 이름·규칙·수산시장 간판, 특 스킨 4종·고등어 이름·대사. CSV 새 키 91 + 고침 5 (507행).
- B1(P1) p2에서 고쳐진 것 확인(QA 회귀 테스트 통과).
- 검증 5단계 통과: lune 2343 passed 0 failed.

### 남은 것
- 재QA(B1 재확인 + p3 병합분 + 2단계 AC25·26). 사용자 Studio 확인(스펙 개발 메모 p3 "Studio 확인" + 예전 목록).
- main 병합: QA 통과 뒤 메인 세션이. 그사이 main이 또 움직이면 다시 병합하고 AC4·AC5·AC11(`localization.spec`)이 새 문구를 잡아요 — 실패 목록대로 CSV에 키 추가.
- docs-writer: CLAUDE.md "현지화" 규칙(숫자 + 단위 한 키, `WorldText.mark`, 동적 키 `shop.drawGrade.*` 포함), USER-TODO(CSV 업로드).

### 다음에 할 첫 단계
- QA 리포트가 오면 그 버그부터. `lune run tests`에서 `localization`·`m5-26-qa`·`m5-26-phase2`·`m5-31-*` 확인.

### 막힌 점
- 없음. 결정 기록에 p3 세부 7개(뽑기 등급 동적 키 등) — QA·기획이 보고 아니면 알려 주세요.

## 2026-10-13 — QA 수정(B1~B5) + 2단계 완료, in-qa

**브랜치**: 원격 `m5-26-i18n-p2` (= `m5-26-i18n` + 2단계, origin/main 3ed86cb와 이미 같은 기준 — 병합할 것 없었음)

### 끝난 것
- B1(P1): `RoomService.restoreRoom`이 복귀 티켓의 `nameIsDefault`를 믿지 않음 — 방장이 있으면 방장 DisplayName, 없으면 필터해서 안 바뀐 기본 이름만 유지, 쓴 이름은 항상 필터. 앞 세션의 wip(방장 없으면 돌아온 사람 이름으로 덮음)는 정상 기본 이름 방이 이름을 잃어서 다시 짰어요.
- B2: QA 영어 다듬기 10줄. B3: `Loc.tPlace`(영어만 서수, 폴백 영어도 서수). B4: 늦은 번역기면 PlayerGui의 같은 글씨 다시 쓰기 + `Loc.onChanged`.
- 2단계: 단상(`PodiumLogic` + 속성 `WinnerName`·`WinnerWins`), 와사비 "매워!!"(`WorldText.mark` + `WorldTextController`, 키 `map.soy-swamp.spicy`), 칭호 속성 = 기준 승수 숫자.
- 사용자 규칙(숫자 + 단위 = 한 키) 테스트, AC11을 `src` 전체로(허용 줄 1개: Studio "Studio 매치"), `forceStart` 한국어 → `AdminCommands`.
- 검증 5단계 통과: rojo build · stylua · selene 0/0 · lune 1828 passed 0 failed · luau-lsp 끝 코드 0.
- 스펙 `in-qa`, 개발 메모 "QA 수정"·"2단계", 결정 기록 5줄.

### 남은 것
- 재QA(B1 + 2단계 AC25·AC26 + 전체). 사용자 Studio 확인(QA 체크리스트 + 스펙 개발 메모 "2단계" Studio 확인 1~5).
- docs-writer: CLAUDE.md 규칙(숫자 + 단위 한 키, 서버 월드 글씨는 `WorldText.mark`, Attributes 3개, Title = 숫자), DEV-SETUP, USER-TODO(CSV 업로드).
- 선택: `ProfileView.title`·MatchPhase `mapName`·`rule`(서버가 보내는 한국어, 화면엔 안 씀) 정리.

### 다음에 할 첫 단계
- QA 리포트가 오면 그 버그부터. `lune run tests`에서 `m5-26-qa`·`m5-26-phase2`·`localization` 확인.

### 막힌 점
- 없음. B4는 클라우드 업로드 뒤 느린 번역기에서만 생겨 Studio 재현이 어려워요(순수 테스트 + 코드 읽기).

## 2026-10-13 — 1단계 완료, in-qa

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
