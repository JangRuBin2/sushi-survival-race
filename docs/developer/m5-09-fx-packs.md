# m5-09 연출 팩 비주얼 — 개발 작업 기록

## 2026-10-13 — 구현 완료, in-qa
- **브랜치**: 로컬 `m5-09-fx` (worktree `.claude/worktrees/agent-a0966d167e64b6517`), push 대상 `origin/m5-09-fx`. 시작 전에 `origin/main`을 병합함(m5-23 `tools/render` 포함).
- **끝난 것**: 스펙 범위 전체. 순수 로직(AC1~AC4) + 고양이 손님 소품 3종 + 불꽃놀이 소품·컨트롤러. 자세한 파일 목록·Studio 확인 방법은 스펙 "개발 메모".
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 1272 passed / 0 failed, luau-lsp exit 0.
- **모습 다듬기**: `tools/render`(Shims로 `src/client/fx/*Props` 실행)로 PNG를 그려 확인. 고쳐진 것: 처음 고양이 얼굴은 윗턱 판이 눈을 가려서 "ω" 주둥이 공 2개 + 아래턱 위주 벌림으로 바꿈. 큰 앞발 팔이 본인 카메라를 막아서 거의 수직으로 바꿈(기본 셰프 손보다 덜 가림). 불꽃을 먼 하늘에 띄우면 화면 맨 위에 작게 잘려서 인형 뒤 바다 위 낮은 곳으로 옮김(스펙 결정 기록 D4, 확인 필요).
  - 미리보기 스크립트는 지웠어요. 다시 만들려면: `Shims.root("src/client")` + `Shims.require(client.fx.CutsceneProps)`, VictoryProps는 `Shims.globals.game`을 `ReplicatedStorage → { Shared = Shims.root("src/shared") }`로 감싸야 불러와져요. 파티클 버스트는 렌더러가 못 그려서 직접 불티 경로(속도/Drag·가속)를 계산해 Neon 상자로 찍었어요.
- **남은 것**: QA, Studio 확인(AC6~AC10), D4~D7 확인(planner·사용자).
- **다음에 할 첫 단계**: QA가 스펙 "개발 메모"의 Studio 확인 방법대로 `SetAttribute`로 속성을 손으로 달고 Race·Survival·Final·우승을 한 번씩 확인.
- **막힌 점**: 없음. m5-08(속성 달기)과는 파일이 겹치지 않음 — 이 브랜치는 속성을 읽기만 해요.
- **참고**: 진행 중에 받은 "m5-03 QA B2·B3(BuyWithTokens 핸들러, OffSale 카드)" 메시지는 m5-07 담당 내용이라 이 스펙에서는 손대지 않았어요(`ShopLogic.luau`는 이 스펙의 파일 목록 밖).
