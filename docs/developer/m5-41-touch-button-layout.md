# developer 작업 기록 — m5-41 모바일 터치 버튼 위치·크기 편집

## 2026-10-14 (최신) — 구현 끝, in-qa
- **브랜치**: `m5-41-touch-button-layout` (main d37a1c4 기준, push됨). main 병합 안 함.
- **끝난 것**: 스펙 AC1~AC10 (순수 로직·서버 검증·병합·불러오기·관전 화살표·리모트 수) + 클라이언트(배치 컨트롤러·편집 화면·⚙ 버튼·다이브/잡기/관전 연동). 검증 5단계 통과 — rojo build, `stylua --check src tests tools`, selene 0/0/0, `lune run tests` **1942 passed, 0 failed**(새 `tests/touch-layout.spec.luau` 30개), luau-lsp 0.
- **남은 것**: QA, 사용자 Studio 확인 AC11~AC17. AC12에서 기본 점프 버튼이 되돌아가거나 깜빡이면 스펙 D3 대안(자체 점프 버튼: 우리 ImageButton이 `Humanoid.Jump`, 기본 버튼 숨김)으로 바꿔야 함 — 손댈 곳은 `TouchLayoutController.applyJump`/`attachJump`.
- **다음에 할 첫 단계**: QA 리포트(`docs/qa/m5-41-touch-button-layout.md`)가 오면 그 버그부터. 없으면 사용자 AC12 결과 기다림.
- **막힌 점**: 없음. 스펙의 "리모트 26개"는 m5-31 이후 27개라 실제 기준으로 맞춤(결정 기록 D7). 결정 D8~D12는 스펙 "결정 기록".

### Studio 확인 방법 (요약 — 자세한 건 스펙 "개발 메모")
1. Test → Device 에뮬레이터에서 iPhone 가로로 Play. 편집 전 버튼 셋이 예전 자리, 위쪽 바 음소거 왼쪽에 ⚙.
2. ⚙ → "✋ 버튼 위치 편집" → 다이브 끌기·"크게 +"·저장 → 그 자리에서 다이브가 되는지.
3. 점프를 옮겨 저장 → 리셋·라운드 시작·기기 바꾸기 뒤 유지되는지(AC12).
4. 금지 구역(왼쪽 40%·위쪽 띠·화면 밖·노치)·겹침 빨간 테두리·저장 회색·44px 하한.
5. 편집 중 입력 안 나감, 취소·기본값으로·프리셋, 라운드 중 메뉴 회색·자동 닫힘, iPad 따로 저장, 관전 ◀ ▶.
6. PC 화면에서는 ⚙ 없음.

### 파일
- 새: `src/shared/TouchLayoutLogic.luau`, `src/client/input/TouchLayoutController.luau`, `src/client/ui/TouchLayoutEditor.luau`, `src/client/ui/SettingsButton.luau`, `tests/touch-layout.spec.luau`
- 수정: `src/shared/UiLayout.luau`, `src/shared/ProfileSchema.luau`, `src/shared/ProfileLogic.luau`, `src/server/DataService.luau`, `src/client/input/DiveButton.luau`, `src/client/input/GrabButton.luau`, `src/client/ui/SpectateScreen.luau`
- 공용(이 스펙 담당): `src/shared/Types.luau`, `src/shared/Remotes.luau`(주석만), `src/client/init.client.luau`

## 2026-10-14 — 1단계
- 순수 로직(TouchLayoutLogic)·부분 저장·칸별 간격·관전 화살표 + 테스트, wip 커밋 5c0aa5c.
