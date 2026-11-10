# m6-08 공격 — 개발 기록 · 인계 메모

스펙: [`docs/specs/m6-08-attack-and-legend-skins.md`](../specs/m6-08-attack-and-legend-skins.md) · 구조: [`docs/REFERENCE-attack-fx.md`](../REFERENCE-attack-fx.md) · 스킨 쪽 기록: [`m6-08-legend-skins.md`](m6-08-legend-skins.md)

## 인계 메모 (2026-11-10)
- 브랜치 `claude/gracious-curie-tl82em`(push 됨) → main PR. 스킨 4종은 `claude/gracious-curie-tl82em-skins`에서 만들어 이 브랜치에 `--no-ff` 병합(그 브랜치는 지움).
- 끝난 것: 공격(서버·순수 로직·입력·터치 버튼·연출), 전설 스킨 4종, 문서(GDD v0.10·GAME-GUIDE·README·CHANGELOG·DEV-SETUP 3-18·6절·USER-TODO·CLAUDE.md), 클라우드 도구(`tools/cloud/`).
- 남은 것: QA 에이전트 리포트(`docs/qa/m6-08-*.md`)는 아직 없음 — 스펙 상태 `in-qa`. 사용자 Studio 확인(DEV-SETUP 3-18), 상품 4개, 공격 소리.
- 다음에 할 첫 단계: PR 리뷰 반영 → (원하면) qa 에이전트로 스펙 AC 검증 → main 병합 → 병합 뒤 5단계 재실행.
- 막힌 점: 클라우드에서 `selene src`(진짜 Roblox std) 못 돌림 — 근사 std로만 통과(DEV-SETUP 6절).

## 만든 것
| 파일 | 내용 |
|---|---|
| `src/shared/AttackLogic.luau` | 순수: `pickTargets`(반지름·제외·가까운 순·동률 userId), `knockFor`(바깥 수평 + 위, 겹치면 바라보는 방향 → -Z), 북(`canAttack`·`record`·`readyAt`·`isImmune`·`removePlayer`) |
| `src/server/AttackService.luau` | `AttackInput` 검증(인자 없음·간격·레이서·넘어짐) → 대상 → `LinearVelocity` "AttackKnock" 0.12초 + `PlatformStand` 1초 + `MoveExempt` 1.5초 → `AttackReadyAt` → 같은 방에 `AttackFx` |
| `src/shared/AttackFxLogic.luau` | 순수: 스킨 → 스타일 표, 스타일 색·길이, `ringRadius`·`fade`·`helixPoint`·`missilePoint`·`missileTargets` |
| `src/client/fx/AttackFxController.luau` | 연출 그리기(고리·띠·쫓아가는 미사일·폭발 조각), 연출마다 폴더, 동시 6·거리 150 |
| `src/client/input/AttackController.luau` · `AttackButton.luau` | F·L2·터치, 관전·쿨다운 중 안 보냄, 버튼 쿨다운 표시 |
| 공용 파일 | `Config.Attack`, `Remotes`(`AttackInput`·`AttackFx` → 16 + 13), `Attributes.AttackReadyAt`, `Types.AttackFxInfo`·`TouchLayout.attack?`, init 스크립트 2개, `SfxCues`/`SfxLibrary` `Attack` |
| 터치 배치 | `UiLayout.touchButtons().attack`, `TouchLayoutLogic.NAMES` 4개·compact 프리셋·선택 칸 저장·예전 값 호환, 편집 화면 글씨 |
| 테스트 | `tests/m6-08-attack.spec.luau`(19), 리모트 수·속성 수·cue 목록·터치 4버튼에 맞춰 기존 5개 고침, `tests/run-one.luau` |

## 결정 (메인)
- 키 F·L2: 쓰이지 않는 키(E는 다이브·관전, Y는 관전 "로비로", B는 창 닫기).
- 공격자 스킨은 서버가 보내지 않고 클라이언트가 `AppearanceId`로 고름 → 판정 코드에 스킨 개념이 아예 없음(테스트 고정).
- 공격 즉시 판정(예비 동작 없음): 반응이 빠르고 단순. 연출 0.6~0.9초는 판정 뒤에 그림.
- 맞은 사람은 쿨다운 없음(바로 반격 가능), 대신 2초 면역으로 연속 넘어뜨리기 막음.
- 저장 모양 버전을 올리지 않음(v1 + 선택 칸): 올리면 모든 사람의 편집 배치가 사라짐.

## 검증 (병합 뒤, 2026-11-10)
- `rojo build` OK · `stylua --check src tests tools` OK · selene **근사 std** 0 errors / 0 warnings(Roblox API 검사 없음) · `lune run tests` **2499 passed, 0 failed** · `luau-lsp analyze` 끝 코드 0.
- Studio 확인 못 함(클라우드) → DEV-SETUP 3-18.
