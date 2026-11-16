# m6-14 C 터치 조작 버튼 (보일 때 · 아이콘) — 개발 작업 기록

## 2026-11-16 — C1·C2 구현 끝 (메인 세션 A·B와 병렬)
- 브랜치: `claude/m6-14-touch-buttons` (`claude/lobby-mobile-ux`의 스펙 커밋에서 땀). push 함, PR 안 엶. `LobbyScreen`·`CreateRoomDialog`·`Strings.csv`·공용 파일은 손대지 않음.
- 스펙 상태는 메인 세션이 정함(A·B·C 한 스펙). 스펙 6절 "개발 메모 — C"에 바뀐 파일·결정을 적음. Studio 확인 `docs/DEV-SETUP.md` **3-22**.

### 끝난 것
- C1: `Shared.RaceActionLogic`(순수 리듀서 + 판단) + `input/RaceActionState`(감시) → `GrabButton`·`AttackButton` 표시 = `placementOk AND canUse`. 다이브는 그대로.
- C2: SVG 4개 → PNG 256(`tools/icons/export-icons.js`), 시트 `docs/renders/icons/touch-icons-sheet.png`, `Shared.IconAssets`(빈 id = 글씨 폴백), `Shared.TouchButtonFaceLogic` + `input/TouchButtonFace`(접시색 원 + 나무 테두리, 아이콘, 쿨다운 덮개 + 초).
- 테스트 `tests/m6-14-touch-buttons.spec.luau` 16개. 기존 `m5-41-qa`의 소스 검사("if editing then release()")에 맞게 GrabButton.place에 그 줄을 그대로 둠.

### 아이콘 렌더 비평 (시트를 직접 보고 고친 순서)
1. v1: 모두 너무 작음(버튼 안에서 가늘다). 다이브는 약 캡슐처럼 보임, 잡기는 펜 두 자루(초밥이 안 보임), 공격은 해·꽃·조타륜처럼 보임. 시트 쿨다운 예시에 "undefined" 글씨(도구 버그).
2. v2: 선 12 → 14, 모양을 키움. 다이브 = 네모난 밥 + 넘치는 계란 + 김 띠 + 눈 둘 + 팔 → 초밥으로 읽힘. 잡기는 막대가 초밥을 가려 지퍼처럼 보임. 공격은 바퀴살(꼬리 선)이 생겨 조타륜.
3. v3: 다이브 팔 하나로(두 팔은 작은 크기에서 포크처럼). 공격 = 큰 노란 "펑" 별 + 끊긴 고리 + 틈으로 나가는 밥알(각도 −90° 보정). 잡기는 초밥을 막대와 평행하게 끼웠더니 빨래집게처럼 보임.
4. v4: 잡기 = 뒤 젓가락 → 초밥 → 앞 젓가락(집어 올리는 모양) + 들어 올림 표시, 막대 끝이 캔버스 밖에서 잘리지 않게 줄임. 48·44px에서 넷 다 구분됨.
- 남은 약점: 공격은 48px에서 조금 복잡(별 + 고리 + 밥알 5). 실제 휴대폰에서 사용자 확인 필요(3-22 B5).

### 검증 (클라우드 세션)
- `rojo build` 통과 · `stylua --check src tests tools` 통과 · selene **근사 std**(`cd tools/cloud && selene --config selene.toml ../../src`, Roblox API 검사 없음 — `selene src`는 프록시 때문에 API 덤프를 못 받음) 0 errors 0 warnings · `lune run tests` **2655 passed, 0 failed** · luau-lsp 타입 검사 끝 코드 0.
- 처음 전체 실행에서 기존 테스트 2개가 깨져서 고침: `m5-41-qa`(GrabButton.place의 "if editing then release()" 소스 검사 → 그 줄 유지), `m4-12-hardening`(모듈 전역 `{ [K]: V }` 표 누수 검사 → `TouchButtonFace`의 고정 TONES 표를 캐스트 선언으로).

### 다음에 할 첫 단계
- 사용자가 PNG를 올려 `IconAssets.IDS`를 채우면 휴대폰에서 3-22 확인. 메인 세션 브랜치와 병합 뒤 검증 다시.

### 막힌 점
- 없음. DEV-SETUP 번호는 3-20(UI 개선)·3-21(메인 세션 로비)·3-22(이것)로 맞춤.
