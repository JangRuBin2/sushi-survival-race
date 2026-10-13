# m5-24 그룹 B 작업 기록 (soy-swamp · chef-board · tug-of-war-platform)

## 2026-10-13 인계 (최신) — 세션 종료 요청으로 중단
- **브랜치**: `m5-24-art-b` (worktree `agent-ae87e21a6eaacf25a`), origin/main 591d84e까지 머지됨. Rojo 포트 34883.
- **검증 상태**: `lune run tests` 1569 통과 / 0 실패 (마지막 커밋 기준). rojo build·stylua·selene·luau-lsp는 **이번 세션에서 아직 안 돌림** — 이어받으면 5단계 먼저.
- 스펙 상태: `in-dev`.

### 끝난 것
- **soy-swamp 반복 1~2 완료** (렌더 → 비평 → 고침). `SoySwampArt.luau` 전면 재작성, `SoySwamp.luau`는 `lighting = Art.LIGHTING` 한 줄만(+ MapLighting require 제거).
  - 세계: 코스 아래 나무 게타(판+다리 4) → 간장 호수(윗면 y -50 = 낙하선 -40보다 10 아래) → 도자기 접시 테두리 → 어두운 나무 카운터 → 회반죽·타일 방 벽(±640) + 창문 2 + 병 선반 + 먼 병 실루엣.
  - 히어로: ① 와사비 산(층층 언덕을 bevelBox로 + 호수에서 솟은 Pebble 덩어리, 정상 Sparkle) ② 쓰러져 간장을 쏟는 병(줄기·물결·Bubbles) + 선 병(호수에 세움) ③ 젓가락 3쌍·연근 3·떠 있는 김(Bob)·파(Sway) ④ 강판 절벽(기운 금속 판·이빨·손잡이) ⑤ 결승 쪽 날치알 언덕(일부 Pulse). 결승 문(기둥·가로대·노렌 Sway·등 2), 들보에 매단 등 3(빛), 산 위 주방 펜던트 등(그림자 SpotLight 1).
  - 기존 이름 개수 유지: HillRice 2, SoyBubble 3, FogPanel 4, Lantern(있음), WasabiBump(패드 위 0.5 이하).
  - 안개 패널: 지우지 않고 방 벽 바깥(±680)으로 옮김 → 화면이 뿌옇지 않음, 분위기는 Art.LIGHTING Atmosphere(Density 0.32, Haze 1.3). **결정 기록에 D5로 적어야 함(아직 안 적음)**.
  - 소개 카메라: 기존 4점 그대로, 3번 반전 샷만 (0,36,-86)→(0,12,-96)으로 앞으로 기울임 (m5-20 QA B3 해결, m5-20-qa AC12 그대로 통과).
  - stats: decor 966/1500, lights 8/24 (그림자 1/2) — 코드 HillRice 2 포함, particles 9/16 (코드 거품 3 포함), anim 34/80, tris 87428, void% 전 뷰 0%.
- 바꾼 아트 수량 단언 (D2, QA가 diff 확인):
  1. `tests/map-art-race.spec.luau` AC1 (≈120줄): `count <= DECOR_PART_BUDGET` → `checkBudget(specs, entry.art.BUDGET)` (BUDGET 없는 맵은 Standard 그대로).
  2. `tests/m5-23-visual-kit.spec.luau` AC7 (≈294줄): `Maps.get(id).lighting == preset` → lighting이 있고 validate 통과 (스펙이 Art.LIGHTING으로 옮기라고 해서).
  3. `tests/m5-23-qa.spec.luau` ≈227줄: 같은 lighting 동일성 단언 → validate 통과로.
  4. `tests/m5-23-qa.spec.luau` ≈450줄: soy-swamp 조명/파티클 `{2,3}` → `{8,9}`, 모든 맵 Standard 조명·파티클 → Extended 한도.
- 렌더 PNG 저장: `docs/renders/{soy-swamp,chef-board,tug-of-war-platform}/before-{overview,eye,intro-01}.png` (렌더러 lookAt 고친 뒤 원래 코드로 찍은 진짜 전), `docs/renders/soy-swamp/wip-*.png` (현재 상태 — after 아님).

### soy-swamp 비평 메모 (반복 2 기준, 남은 것)
- 판정 유리벽(투명 0.6, 밝은 색)이 eye 뷰를 뿌옇게 함 — 판정 파츠라 투명도는 안 건드림. COLORS.wall을 조금 어둡게 할지 검토만.
- 쓰러진 병이 eye 뷰 왼쪽 아래를 꽤 차지 (히어로로 읽히긴 함). 반복 3에서 크기·각도 다시 보기.
- 체크리스트 18개 글 비평(반복 1~3)을 이 파일에 아직 안 씀 → 반복 3 렌더 후 작성, after PNG 복사.
- `tests/m5-24-group-b.spec.luau` (AC2~AC5: Extended checkBudget+CODE_EXTRAS, courseVolume 비겹침, lighting validate·로비와 다름, 움직이는 판정 장식에 anim 없음) 아직 안 만듦.

### 남은 것 (맵별)
- **chef-board**: 시작 전. 계획: 도마 받침 기둥(가운데 3×3 아래, 반지름 ≤ 11 — 잘린 칸이 통과해 보이지 않게), 스테인리스 작업대(윗면 -70 유지, 손님 얼굴 -44 아래로 몸통 추가 — 이름 "Customer"로 시작하면 안 됨: 테스트가 -30~-60 범위 확인), 4면 청회색 타일 벽 ±150~200 + -Z 벽 큰 창(Dust), 칼꽂이·숫돌, 반쯤 손질된 연어 필레(작업대 위, 비늘 Sparkle), 개수대 Steam·물방울 Bob, 허브 화분·국자 Sway, 칸 가장자리 트림은 `cellDecor`(칸 자식 — anim 금지). 그림자 SpotLight는 창 쪽 작업등(도마에서 60 안). **주의**: `ChefBoard.luau` 소스에 "SpotLight" 글자·두 번째 `Instance.new("PointLight")` 금지(m4-05-qa), LampBulb 3개 유지, FogPanel 3~4 유지, 마지막 소개 점 높이 10~25·도마 밖·가운데를 봄. 예산 단언 `map-chef-board.spec` ≈305줄, `m4-05-qa` ≈200줄은 Extended로 바꿔야 함.
- **tug-of-war-platform**: 시작 전. 다른 개발자가 `m5-maps-fix-b`에서 판정(TugOfWarPlatform.luau/Logic)을 고치는 중 → **아트 부착 코드·Art 파일만** 고치고, 그 브랜치 머지 뒤 origin/main 다시 머지. 발판 하위 장식 anim 금지.
- 공통: 개발 메모(스펙 그룹 B 절), 결정 기록 D5(안개 패널 이동), 휴대폰 성능 메모, 검증 5단계, `in-qa`.

### 다음에 할 첫 단계
1. `git fetch origin && git merge origin/main` → 검증 5단계 돌려 지금 상태 확인.
2. `lune run tools/render-map soy-swamp --view all` → 반복 3 비평을 이 파일에 쓰고 after PNG 복사.
3. chef-board 시작 (위 계획).

### 막힌 점
- 없음. (렌더러 lookAt 버그는 main e07e08d에서 고쳐짐 — 그 전 intro PNG는 거꾸로였음.)
