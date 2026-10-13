# m5-24 그룹 A 인계 메모 (rotating-belt · hot-plate · skewer-showdown)

## 2026-10-13 — 중간 인계 (사용자 요청으로 에이전트 정리, 작업 중단)
- **브랜치**: `m5-24-art-a` (worktree `agent-a633ece04ab35ae6d`), `origin/main` 591d84e까지 머지됨 (m5-23 키트 수정 e07e08d 포함).
- **스펙 상태**: `docs/specs/m5-24-map-art-pass-v2.md`는 아직 `ready` 그대로 (그룹 4개가 같은 줄을 고치면 충돌 — 머지 담당이 정리). 개발 메모 그룹 A 절은 아직 안 씀.
- **검증 (마지막 실행)**: `lune run tests` 1569 passed / 0 failed. `rojo build`·`stylua --check`·`selene`·`luau-lsp`는 이번 인계 시점에 **안 돌림**(stylua는 포맷 적용만 함).

### 끝난 것
- **before 렌더** (renderer lookAt 수정 뒤 기준): `docs/renders/{rotating-belt,hot-plate,skewer-showdown}/before-{overview,eye,intro-01,mobile}.png`.
- **rotating-belt — 반복 3회 렌더, 체크리스트 대부분 예** (`RotatingBeltArt.luau`, `RotatingBelt.luau` 아트 부분):
  - `Art.BUDGET = "Extended"`, `Art.LIGHTING`(프리셋 초안을 옮겨 다듬음: 안개 0.24, 덜 주황), `lighting = Art.LIGHTING`.
  - 가게 환경: 마루 바닥 y -92(낙하선 -40보다 52 아래), 천장 y 200 + 대들보, 옆 벽(회벽·판벽·기둥) + 창 3개씩(해 질 녘 Neon 하늘·건물 실루엣·불빛 창), 끝 벽(메뉴판 줄·노렌 출입구·초롱·술병 선반), 손님 카운터(장식 레인 + 지름 8 색 접시 줄 — 접시 색 = 가격), 손님 5명(머리카락 덮개·귀·코·몸·팔·젓가락), 셰프 작업대(진열 케이스 — 유리 판 없음, 참치·연어·새우, 거대 셰프, 마네키네코 팔 Sway, 회전 진열대 Spin, 밥통 김), 머리 위 레일 + 종이등, 마루 테이블 6개, 코스 받침 기둥·바닥 아래 옻칠 띠.
  - 결승 노렌 위 그림자 SpotLight 1 (`FinishSpotLamp`).
  - **m5-20 QA B1 수정**: `FaceEyeShine`(태그 없는 흰 점) 삭제, 눈에 reflectance 0.35. 새 손님 눈 `GuestEye`도 `EyeBlink` 태그.
  - 유지: `Lantern` 3·`SoyGlint` 2·`FaceEye` 6, Noren/GateBeam 높이, 소개 카메라 5점 좌표 그대로.
  - 렌더 통계 (it3): decor 1388/1500 · lights 13/24 (shadowed 1/2) · particles 7/16 · anim 45/80 · tris 103528 · void 전 뷰 0%.
  - 최신 렌더: `docs/renders/rotating-belt/wip-iter3-{overview,eye,intro-01,intro-04,mobile}.png`.
- **바꾼 아트 수량 단언 (D2/D4, QA가 diff로 확인)**:
  - `tests/map-art-race.spec.luau` AC1: `count <= DECOR_PART_BUDGET` → `budget(entry.art.BUDGET or "Standard").parts` + `checkBudget(specs, tier) == nil`. (그룹 B soy-swamp도 같은 테스트 — 머지 때 충돌 가능)
  - `tests/m5-23-visual-kit.spec.luau` AC7 (~294줄): `Maps.get(id).lighting == preset` → lighting이 있고 `MapLighting.validate` 통과 (Art.LIGHTING 허용, D4).
  - `tests/m5-23-qa.spec.luau` (~227줄): "기존 6개는 PRESETS" → PRESETS 또는 Art.LIGHTING(검사 통과).
  - `tests/m5-23-qa.spec.luau` (~448줄): rotating-belt 렌더러 조명/파티클 `{3, 2}` → `{countLights(decor)+3, countParticles(decor)+2}`; 모든 맵 Standard 조명·파티클 예산 → 그 맵 `Art.BUDGET` 단계 예산.
  - 다른 그룹도 이 줄들을 고칠 가능성이 높아요 — 머지 때 한쪽으로 정리.

### 남은 것
- rotating-belt: 반복 3 비평을 글로(체크리스트 18개) 이 메모에 쓰기, 남은 "아니오" 후보 — 메뉴판·카운터 상판 외 맨 상자 점검, mobile 뷰 확인, 레일 기둥(가는 선) 정리. 최종 `after-*.png` 복사.
- **hot-plate, skewer-showdown: 시작 안 함** (before 렌더만). 계획:
  - hot-plate: 바닥(철판 카운터 상판) y ≤ -65(낙하선 -55), 손님 얼굴(y -80)은 테이블에서 솟게 위치 조정 가능, 후드 램프 SpotLight 그림자, 헤라·그라인더 Spin·버터 Bubbles·Embers. 주의: `buildArt`의 `CastShadow = false` 줄 유지(테스트), 가짜 바닥 테스트(층 윗면 -4~+2 높이·가장자리 16 안의 넓은 장식 금지), 시야 상자, 카메라 경로 테스트(m4-12-hardening).
  - skewer-showdown: 낙하선 -20 → 바닥 ≤ -30. 무대 아래 숯불 화로, 축제 거리 건물 정면 링, 등롱·망루 실루엣. 셰프(`Chef*` max.y < -20) 위치는 옮겨도 됨. 조각·꼬치 음식에 `anim` 금지. 가게 문(`DOOR_Z`, Porch ≤ -6) 규칙 유지.
- 두 맵 모두 `Art.BUDGET`/`Art.LIGHTING`(MapLighting.PRESETS 값 복사 출발) + `lighting = Art.LIGHTING`, map-art-arena AC1 예산 단언 수정(D2).
- 검증 5단계 전부, 스펙 개발 메모 그룹 A 절, 상태 변경.

### 다음에 할 첫 단계
1. `git fetch origin && git merge origin/main` → `lune run tests`.
2. `lune run tools/render-map hot-plate --view all --out build/it1` 하고 PNG를 보며 hot-plate 환경부터.

### 막힌 점
- 없음. (렌더러 lookAt 버그는 main e07e08d에서 고쳐짐 — 내 로컬 수정은 버림.)
- 도움 스크립트: `build/tmp/count.luau <ArtModule>` (이름별 파츠 수, build/는 커밋 안 됨).
