# m5-24 그룹 A 인계 메모 (rotating-belt · hot-plate · skewer-showdown)

## 2026-10-13 — 그룹 A 완료 (렌더 루프 3맵 모두 3회 이상, 검증 5단계 통과)
- **브랜치**: `m5-24-art-a`, `origin/main` c01a38f(m5-23 키트 수정·m5-25 캐릭터·m5-27 컨셉 스킨)까지 머지. 마지막 push는 이 메모 커밋.
- **스펙 상태**: `status:` 줄은 안 건드림(`ready` 그대로 — 머지 담당이 정리). 스펙 "개발 메모" 그룹 A 절도 안 씀(네 그룹이 같은 파일 끝을 고치면 충돌 — 이 메모를 그 절의 원본으로 써 주세요).
- **검증 5단계 (머지 뒤, 이 커밋 기준)**: `rojo build` OK · `stylua --check src tests tools` OK · `selene src` 0 errors 0 warnings · `lune run tests` **1795 passed, 0 failed** · `luau-lsp analyze` 끝 코드 0(에러 0).

### 맵별 결과
| 맵 | 전 → 후 (한 줄) | 렌더 stats (마지막) |
|---|---|---|
| rotating-belt | 허공 위 벨트 → 저녁 회전초밥집 안(마루 바닥 -92, 손님 카운터·손님, 셰프 작업대·진열 케이스, 메뉴판 벽, 해 질 녘 창, 종이등) | decor 1386/1500 · lights 13/24 (shadowed 1) · particles 7/16 · anim 45/80 · tris 103712 · void 전 뷰 0% |
| hot-plate | 갈색 허공에 뜬 철판 탑 + 흰 벽 한 장 → 밤의 철판구이집(무쇠 카운터 상판 -95, 탑 발치 호박색 열기, 손님 5명·접시·찻잔 김, 버터·계란·새우, 헤라·그라인더, 타일 벽 양념 선반, 메뉴판 벽, 파란 밤 거리 창, 종이등·선풍기) | decor 808/1500 · lights 8/24 (shadowed 1) · particles 11/16 · anim 16/80 · tris 53712 · void 전 뷰 0% |
| skewer-showdown | 분홍 허공의 무대·가게 문·셰프 → 축제 광장(돌판 바닥 -106, 무대 밑 숯불 화로 + 석쇠, 노점 6, 등롱 줄 8, 망루, 거리 건물 정면 12, 불꽃놀이 탑, 먼 지붕선) | decor 1294/1500 · lights 13/24 (shadowed 1) · particles 6/16 · anim 30/80 · tris 74588 · void 전 뷰 0% |
- 전/후 PNG: `docs/renders/<mapId>/before-{overview,eye,intro-01,mobile}.png` → `after-{overview,eye,intro-01,mobile}.png` (rotating-belt는 `after-intro-04.png`도). wip-iter3 PNG는 지웠어요.
- **휴대폰 성능 메모 (AC11)**: 가장 무거운 뷰 tris — belt 103.7k / hot-plate 53.7k / skewer 74.6k. 새로 추가한 큰 반투명 판 **0개**(길이 20 이상·투명도 0~1 사이 장식 없음 — 버터 웅덩이 지름 16 하나만 반투명). 그림자 조명 각 1개(좁은 SpotLight). 파티클 Rate 합(DecorSpec 기준) belt 6.3 / hot-plate 21 / skewer 19 (+ hot-plate 코드 Steam 4개 × 3).
- **AC2 렌더러 조명·파티클(코드 Instance.new 포함)**: belt 13 lights·7 particles(Lantern 3·SoyGlint 2 포함), hot-plate 8·11(SteamVent 4 포함, 후드 PointLight 2는 DecorSpec SpotLight로 옮김), skewer 13·6(문 등롱 PointLight 2 포함).

### 반복 기록 (체크리스트 18개)
**rotating-belt — 반복 4 (마지막)** (반복 1~3은 이전 세션, 렌더는 wip-iter3였던 것)
- 1 빈 공중 예(0%) · 2 실루엣 예(셰프·손님·진열 케이스·창) · 3 맨 상자 없음 예(이번 반복에서 가는 `OverheadPost` 6개 → 굵은 옻칠 원기둥 4개, 메뉴판·카운터 상판은 트림 있음) · 4 히어로 색 예(옻칠 빨강 레일·의자·노렌 남색) · 5 shade 예(마루 4 shade, 벽 판) · 6 바닥 가독성 예(eye·mobile에서 벨트 고무·나무 바닥이 장식보다 깨끗) · 7 위험 색 예 · 8 가짜 바닥 없음 예(카운터 상판 2.5, 벽 바깥) · 9 보이는 광원 예(등·노렌 스포트, 그림자 1) · 10 온도 대비 예(호박색 가게 + 파란 창) · 11 밀도 위치 예(출발·병목·결승 노렌) · 12 생동감 예(7·45) · 13 방향 예(eye에서 결승 노렌·셰프) · 14 소개 구도 예(5점, 경로 충돌 없음) · 15 휴대폰 예 · 16 바닥 높이 예(-92 vs -40) · 17 예산 예 · 18 스케일 예.
- 가장 나빴던 뷰: overview — 위에서 가는 검은 봉 6개가 "철사 숲"처럼 보여 싸 보였음 → 굵은 옻칠 봉 둘로 줄임.

**hot-plate — 반복 1** (`build/hp2`)
- 아니오: 13 방향(eye에서 창이 벽 뒤에 묻혀 안 보임 — 창 판이 벽 바깥에 있었음) · 2 실루엣(손님 얼굴 머리카락 공이 얼굴을 덮어 "검은 공"처럼 보임) · 4 히어로 색(열기 주황이 화면에 거의 없음) · 등이 너무 커서 overview 가장자리를 막음.
- 예: 1(0%)·3·5·6·7·8·9·10(어두운 실내 vs 램프)·11·12(11·16)·14·15·16(-95 vs -55)·17·18.
- 가장 나쁜 뷰 intro-01: 머리카락 공이 얼굴 반을 검게 가림, 창이 안 보여 온도 대비가 약함, 열기 없음.
- 고침: 창 판을 벽 안쪽 면으로, 머리카락 공 작게·뒤로, 등 16 → 12 + 자리 양옆 벽 앞으로.

**hot-plate — 반복 2** (`build/hp3`)
- 아니오: 4 히어로 색(아직 열기 주황 거의 없음).
- 예: 나머지 17개(창 밤 파랑 보임, 얼굴 읽힘).
- 고침: 탑 발치 상판에 호박색 열기 번짐 원판 3장(가운데만 Neon, 나머지 불투명 Metal 그라데이션 — 큰 반투명 판 금지). 경고 주황(232,100,24)·빨강과 다른 노란 쪽.

**hot-plate — 반복 3 (마지막)** (`build/hp4`)
- 18개 전부 예. 4 히어로 색: 탑 밑 호박색 열기 + 파란 가스불 + 등빛이 ~10%. 7 위험 색: 장식 열기는 노란-주황(240,120,40/255,168,60), 판정 HotTile은 회색 → 주황 → 빨강 그대로.
- 가장 나쁜 뷰 intro-03(위층 옆): 후드 천장이 화면 위 1/4을 덮음 — 판정 시야와 무관하고 기존 m4-03 구도라 유지.

**skewer-showdown — 반복 1** (`build/ss2`)
- 아니오: 2 실루엣(거리 건물·노점·망루가 **등을 보이고** 서 있음 — 회전 방향 실수) · 1 빈 공중(overview 35%).
- 예: 3·5·6·7·8·9·10(등롱 따뜻함 vs 자주 하늘)·11·12·14·15·16·17·18.
- 고침: `transform` 회전 yaw+180 → yaw(앞면 -Z가 광장 가운데를 봄), 1400 × 1400 먼 땅.

**skewer-showdown — 반복 2** (`build/ss3`)
- 아니오: 1 빈 공중(overview 20% — 먼 땅 너머 하늘).
- 고침: 반경 640에 먼 지붕선·산 실루엣 18장(그림자 없음, 안개 속).
- 재렌더 void 전 뷰 0%. 남은 아니오: 13 방향 보조 — eye에서 건물 정면이 단조로운 갈색 띠.

**skewer-showdown — 반복 3 (마지막)** (`build/ss4`)
- 고침: 건물 정면 색 한 단계 밝게, 처마 밑 작은 등롱 3개씩(빛 없음).
- 18개 전부 예. 13 방향: Final(생존형)이라 "가운데 기둥·꼬치"가 방향 — eye에서 기둥·꼬치·등롱 줄이 바로 보임. 9 그림자: 무대 +Z 바깥 등 기둥의 좁은 SpotLight(70°) 하나.

### 바꾼 파일
- `src/shared/maps/HotPlateArt.luau`: `BUDGET`·`LIGHTING`(프리셋 값 출발, Ambient 더 파랗게·Brightness 1.2), 방·카운터·손님·소품·버너·불티·등·선풍기, 후드 다듬기(bevelBox·트림·리벳·덕트), 램프는 `light = Spot`(하나만 그림자). `addKitchenWall` → `addRoom`(병 3개 `SauceBottle` 이름·Wobble 유지, 위치만 선반으로).
- `src/shared/maps/HotPlate.luau`(아트 부분만): `HOOD_LAMP` PointLight 생성 코드 삭제(DecorSpec.light로), `lighting = Art.LIGHTING`. `CastShadow = false` 줄·SteamVent·Wobble 태그 그대로.
- `src/shared/maps/SkewerShowdownArt.luau`: `BUDGET`·`LIGHTING`, 광장·화로·돌 기단·거리·노점·등롱 줄·망루·불꽃·무대 스포트, 셰프 자리(+Z 72, 광장 위에 섬 — 모든 `Chef*` max.y < -20 유지). 가게 문·`Porch`·`DOOR_Z`·조각·꼬치 음식·손 장식은 그대로.
- `src/shared/maps/SkewerShowdown.luau`(아트 부분만): `lighting = Art.LIGHTING`. `overtime`·`start` 그대로.
- `src/shared/maps/RotatingBeltArt.luau`: `OverheadPost` 6 → 4(굵은 옻칠 원기둥).
- 새 테스트 `tests/m5-24-group-a.spec.luau` (8개): AC2 Extended·700 이상·파티클 2·anim 3, 꼬치 전체 합 예산, AC3 시야 상자, AC4 Art.LIGHTING·로비와 다름, AC5 조각·음식·손에 anim 없음, 배경 바닥 낙하선 -10·200×200 이상, 그림자 조명은 좁은 Spot·고정 파츠, Neon 장식에 경고 빨강 없음.

### 바꾼 아트 수량 단언 (D2/D4 — QA가 diff로 확인)
- `tests/map-art-arena.spec.luau` AC1 철판(~98줄): `count <= DECOR_PART_BUDGET(600)` → `count <= budget(Art.BUDGET).parts` + `checkBudget(specs, tier) == nil`.
- `tests/map-art-arena.spec.luau` AC1 꼬치(~109줄): 합 `<= 600` → `<= budget(SkewerArt.BUDGET).parts` + `checkBudget(all, tier) == nil`.
- `tests/map-art-race.spec.luau` AC1(~120줄, 이전 세션): 같은 방식(belt, 그룹 B soy-swamp도 같은 테스트).
- **공유 테스트(main에 있는 m5-23 QA)** — 머지 충돌을 풀며 좁게 고침. "m5-24 패스를 끝낸 맵만 제외" 규칙:
  - `tests/m5-23-qa.spec.luau` 새 도움 함수 `artModule(id)`(~145줄).
  - 같은 파일 "기존 6개는 프리셋을 씀"(~247줄): 전 `lighting == PRESETS[id]` → `Art.LIGHTING`이 있는 맵은 `lighting == Art.LIGHTING`(정확히 그 표), 없는 맵은 여전히 `== PRESETS[id]`.
  - 같은 파일 "렌더러 통계 = 기존 맵 lune 카운트"(~476줄): 전 belt `{3, 2}`·swamp `{2, 3}` 고정 → `expected(id, codeLights, codeParticles)`: `Art.BUDGET == "Extended"`인 맵은 `countLights/countParticles(Art.decor()) + 코드 수`, 아니면 코드 수 그대로. soy-swamp(그룹 B)도 같은 함수로 자동 처리.
  - 같은 파일 예산 루프(~490줄): main 버전(`artBudgetTier`) 그대로 채택(충돌은 이쪽으로 정리).
  - `tests/m5-23-visual-kit.spec.luau` AC7(~294줄): 전 `lighting == preset` → `Art.LIGHTING`이 있으면 `lighting == Art.LIGHTING`, 없으면 `== preset`.
  - 그룹 B·C·D도 같은 줄을 고칠 거예요 — 위 규칙이 이미 Art 모듈을 읽으므로 그쪽은 **이 줄을 더 고칠 필요가 없게** 해 뒀어요(머지 때 이 버전을 고르면 됨).

### Studio 확인 (AC12~AC15, 사용자)
1. `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }` (확인 뒤 **nil**로 되돌림 — 테스트가 고정).
2. Play(F5) → 방 만들기 → 시작. 라운드마다:
   - AC12: 소개 카메라가 시작되면 1~2초 안에 조명이 바뀌는지 — belt 호박색 저녁, hot-plate 어두운 밤 + 파란 창, skewer 자주-주황 해 질 녘. 로비로 돌아오면 원래 조명.
   - AC13: belt 벨트·병목·결승, hot-plate 타일이 회색 → 주황 → 빨강 → 사라짐(장식 호박색 열기와 구분되는지), 맨 아래층에서 떨어져 탈락, skewer 꼬치 점프·셰프 손·연장전 붕괴(90초 — `DEBUG.overtimeAt`로 당겨 볼 수 있음, 확인 뒤 nil)가 전과 같은지. 무대 그림자 SpotLight로 꼬치 그림자가 무대에 보이는지.
   - AC14: 소개 카메라가 물체를 뚫지 않는지(lune 경로 검사는 3맵 모두 0건), 카메라를 돌려도 빈 하늘이 거의 없는지. hot-plate: 위층에서 줌아웃하면 후드·벽이 가리는지(m4-03 B2와 같은 확인).
   - AC15: Device 에뮬레이터(휴대폰)에서 경고 타일·꼬치·결승이 보이는지, 프레임이 이전보다 눈에 띄게 끊기지 않는지.
3. Future 조명에서 SpotLight 그림자(각 맵 1개)가 너무 진하면 알려 주세요.

### 특이사항
- **공유 테스트 수정**: 위 "공유 테스트" 4곳. 그룹 B~D가 같은 줄을 다르게 고치면 머지 충돌 — Art 모듈을 읽는 이 버전으로 정리하길 권해요.
- **hot-plate 후드 조명 종류 변경**: m4-03의 코드 `PointLight`(Range 40) 2개 → DecorSpec `SpotLight`(아래로 80°, Range 60) 2개, 왼쪽만 `Shadows = true`. 판정 무관이지만 위층 타일 그림자가 아래층에 생겨요 — 경고 색이 가려지면 `shadows`를 끄면 됩니다(m4-03 B4 교훈: 장식 `CastShadow`는 build에서 전부 꺼 둔 상태 그대로).
- **hot-plate 배경 바닥 기준**: "배경 바닥"은 철판 카운터 상판(-95, 낙하선 -55보다 40 아래). 카운터 밖은 방 마루(-185).
- **skewer 셰프 위치 이동**: 무대 바로 밑(z 6) → 화로 뒤 +Z 72, 무대 쪽을 봄(머리띠·눈썹 추가). 모든 `Chef*` 장식 max.y < -20 테스트 그대로 통과. 셰프가 광장 바닥(-106) 위에 서도록 몸통 아래를 나무 카운터로 가렸어요.
- **skewer 무대 기둥 아래 장식 `PillarStem`**: 판정 기둥(바닥 -10)을 화로 석쇠(-36)까지 이어 보이는 장식 원기둥. 판정 기둥은 그대로.
- **불꽃(FireworkStar)·먼 지붕선은 반경 640까지** 퍼져요(아레나 슬롯 간격 2000의 절반 안). 다른 방 아레나와 안 겹쳐요.
- **렌더러 한계**: 렌더러 Neon 번짐이 Studio Bloom과 달라요. 특히 skewer 거리 창(`FacadeWindow` Neon)이 렌더에서 꽤 밝게 번지는데 Studio에서 너무 밝으면 일부를 `SmoothPlastic`으로.
- **rotating-belt의 남은 "아니오" 후보였던 것**(이전 메모의 메뉴판·카운터 상판 맨 상자): 메뉴판은 두께 1.4 판 + 테(트림)라 통과로 봤어요.
- 시도하다 막힌 것: 워크트리 git 안전장치가 `&&`로 이은 git 명령을 막아서 git은 한 줄씩 실행했어요(작업 영향 없음).
- 이 브랜치는 아직 main에 없음 — 머지 뒤 검증 5단계 다시(m4-09 B1 교훈).

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
