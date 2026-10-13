# m5-24 그룹 B 작업 기록 (soy-swamp · chef-board · tug-of-war-platform)

## 2026-10-13 인계 (최신) — 그룹 B 세 맵 아트 루프 끝, `in-qa` 직전
- **브랜치**: `m5-24-art-b`, origin/main(c01a38f)까지 머지됨. Rojo 포트 34883. 스펙 `status:` 줄은 **안 바꿈**(메인 세션이 그룹 병합 때 정함).
- **검증 5단계 (마지막 커밋 기준)**: rojo build OK · `stylua --check src tests tools` OK · `selene src` 0/0/0 · `lune run tests` **1794 passed, 0 failed** · luau-lsp analyze 끝 코드 0.
  - selene: 이 클라우드 환경은 selene이 Roblox API dump를 받을 때 TLS(rustls)가 프록시 인증서를 거절해 `roblox.yml`을 못 만듦. curl로 API dump를 받고, selene 0.31 소스를 로컬 빌드(dump를 파일에서 읽게 고침)해 `~/.cache/selene/roblox.yml`을 만들어서 돌림 — 저장소 파일은 안 건드림. 결과는 정상 selene과 같음(같은 API dump).
- **결과 (맵별 stats, Extended)**
  | 맵 | 장식 | 조명(그림자) | 파티클 | 움직임 | tris | void% (최대) |
  |---|---|---|---|---|---|---|
  | soy-swamp | 966 | 8 (1) — 코드 HillRice 2 포함 | 9 — 코드 거품 3 포함 | 34 | 87,428 | 0% |
  | chef-board | 778 (칸 장식 포함) | 5 (1) — 코드 LampBulb 3 포함 | 6 (상시 5 + 칼 불꽃 one-shot) | 11 | 50,428 | 0% |
  | tug-of-war-platform | 411 (발판 하위 포함) | 3 (1) — 코드 Lantern 2 포함 | 4 | 11 | 26,320 | 6% (overview) |
- **전/후 PNG**: `docs/renders/<mapId>/before-{overview,eye,intro-01}.png` → `after-*.png` (+ `after-stats.txt`). soy-swamp의 임시 `wip-*.png`는 지움.
  - soy-swamp: 반복 3에서 쓰러진 병을 바깥·뒤로 옮겨 eye 뷰 왼쪽을 덜 가림, 판정 유리벽 색만 조금 어둡게.
  - chef-board: 회색 하늘에 뜬 도마 + 반투명 벽 → 청회색 타일 주방(작업대·창·허브·연어 상자·칼꽂이·숫돌·화구·밥통·개수대·선반), 도마 받침 기둥.
  - tug-of-war-platform: 빈 공중(overview void 93%) → 해 질 녘 가게 마당(돌바닥·뒷벽·뒷문·기와·담장·감나무·장독대·가로대 작업등), 발판 테두리 트림·놋쇠 저울 접시.
- **휴대폰 성능 메모 (AC11)**: 큰 반투명 판 **새로 추가 없음**(기존 안개 패널만 — soy 4·chef 4를 방 벽 바깥으로 옮김, tug은 0).
  - soy-swamp: 가장 무거운 뷰 tris 87k(장면 전체), 그림자 조명 1, 장식 파티클 Rate 합 20 + 코드 거품 3.
  - chef-board: tris 50k, 그림자 조명 1, 파티클 Rate 합 22(창 Dust 6×2·연어 Sparkle 3·개수대 Steam 3·냄비 Steam 4) + 칼 불꽃 one-shot.
  - tug-of-war-platform: tris 26k, 그림자 조명 1, 파티클 Rate 합 10.

### 바꾼 아트 수량 단언 (D2 — QA가 diff로 확인)
이전 세션 4개(아래 "이전 인계" 절)에 더해 이번 세션:
1. `tests/m5-23-qa.spec.luau` ≈465줄 (main 머지 충돌 해결): main 쪽 "맵마다 `Art.BUDGET` 단계로 조명·파티클 검사" 구조를 그대로 받고, soy-swamp 고정 수만 `{2,3}` → `{8,9}`. main의 `artBudgetTier`가 Extended 맵을 Art.BUDGET으로 읽어서 **"모든 맵 Extended 한도" 완화는 없앰**(이전 세션 수정 4번의 뒷부분은 main 방식으로 대체). "기존 6개는 프리셋을 씀" 단언은 이전 세션 수정(=lighting validate)이 그대로 유지됨 — 이번엔 충돌·추가 수정 없음.
2. `tests/map-chef-board.spec.luau` ≈305줄 AC6: `total <= DECOR_PART_BUDGET(600)` → `Art.BUDGET == "Extended"` + `checkBudget(decor + 칸 장식, Art.BUDGET, Art.CODE_EXTRAS) == nil`. 바로 위 `validate` 두 줄·`#cellDecor > 61`은 그대로.
3. `tests/m4-05-qa.spec.luau` ≈200줄: `total <= DECOR_PART_BUDGET` → `total <= MapKitLogic.budget(Art.BUDGET).parts`.
- **안 바꾼 것**: 손님 얼굴 높이(-30~-60, 이름 `Customer*`)·LampBulb 3·FogPanel 3~4·`SpotLight` 글자 없음·PointLight 1곳·소개 카메라 마지막 점·카메라 경로가 안개 패널 안 뚫음·줄다리기 AC7(`#deck + #still + 1 <= 600`, 411+1이라 그대로 통과)·m4-12 hardening 경로 검사 — 전부 수정 없이 통과.
- 새 테스트 `tests/m5-24-group-b.spec.luau` (7개): AC2(Extended·checkBudget+CODE_EXTRAS·파티클 2종·anim 3+·그림자 조명에 anim 없음), AC3(도마 시야 상자·받침 기둥이 보호 칸 안·작업대 낙하선 10 아래 / 줄다리기 고정 장식이 발판 회전 공간(반지름 37, |z|≤12) 밖 / 호수 낙하선 10 아래), AC4(lighting == Art.LIGHTING, validate, 로비와 다름), AC5(도마 칸·발판 하위 장식에 anim·light 없음), m5-20 이름 개수.

### 바꾼 파일
- `SoySwampArt.luau` (반복 3: 쓰러진 병 위치·크기, `COLORS.wall` 색만), `SoySwamp.luau`(이전 세션: lighting 한 줄).
- `ChefBoardArt.luau` (BUDGET·LIGHTING·CODE_EXTRAS, 세계 전체, 칸 `EdgeTrim`, 손님 어깨 `DinerShoulders`, 안개 패널 ±312(ROOM+12)로 이동), `ChefBoard.luau` (lighting 한 줄 + MapLighting require 제거 — 판정·build 로직 그대로).
- `TugOfWarPlatformArt.luau` (전면), `TugOfWarPlatform.luau` (아트 부착 코드: 고정 장식 `p.CastShadow = false` 강제 한 줄 삭제 → 스펙 castShadow 규칙대로, `lighting = Art.LIGHTING` 한 줄 추가). start/overtime/판정 파츠 그대로.

### 렌더 비평 — chef-board
**반복 1** (첫 세계: 190 방, 작업대, 창, 연어, 칼꽂이, 개수대, 냄비 걸이, 선반, 작업등)
1 빈 공중: 아니오 — overview 20%(렌더러 overview 카메라가 190 방 벽 밖에 섬) → 방 300으로.
2 실루엣: 예(칼·창·연어·등). 3 맨 상자: 아니오 — 연어가 Ball(가장 짧은 변 지름)이라 작은 공 → 캡슐·빗각 판으로. 4 히어로 색: 예(꿀색 도마 + 연어 주황). 5 shade: 예. 6 바닥 가독성: 예(도마가 가장 밝음). 7 위험 색: 아니오 — 등 갓·병·수도 손잡이·행주 줄이 옻칠 빨강(칼 경고 줄과 같은 계열) → 남색·금·주황으로. 8 가짜 바닥: 예. 9 광원: 예(그림자 1). 10 온도: 예(차가운 창 vs 따뜻한 등). 11 밀도: 아니오 — 도마 주변 외 비어 보임. 12 생동감: 예. 13 방향: 예(Survival — 가운데). 14 소개: 예. 15 휴대폰: 예. 16 바닥 높이: 예(-70). 17 예산: 예. 18 스케일: 예(작업대 90 아래·칼 80·병 20~34).
가장 나쁜 뷰 overview: 방 밖에서 벽만 보임 / 도마가 공중 판처럼 / 소품이 없는 큰 회색 면.
**반복 2** (방 300·천장 높임, 연어 재구성, 손님 어깨 캡슐, 화구·밥통·소스병·종지 추가, 냄비 걸이 +X로 옮김, 칸 옆면 트림, 들보)
1 예(0%). 3 예. 7 아니오 — 등 갓 빨강·병 하나 빨강 남음. 8 예(매트 판은 작업대 위 0.15 — 낙하선 40 아래라 바닥으로 오해 없음). 11 아니오 — 작업대 큰 면이 한 색 → 고무 매트 3장. 14 아니오 — 소스병 무리가 intro-03 오른쪽 아래를 가림 → 도마 뒤(-Z) 창 쪽으로. 나머지 예.
가장 나쁜 뷰 intro-03: 앞 소스병이 화면 1/6을 막음 / 빨간 등 갓이 칼 경고와 같은 색 / 작업대 단색.
**반복 3** (등 갓 남색+금 테, 빨강 장식 전부 제거, 매트 3장, 소스병 이동, 스테인리스 한 단계 어둡게)
1~18 전부 예. void 전 뷰 0%. 남은 아쉬움(통과 기준 밖): 렌더러 근사라 Neon 창빛이 강하게 번짐 — Studio에서 Bloom 확인.

### 렌더 비평 — tug-of-war-platform
**반복 1** (전면 새 세계 — 마당·뒷벽·뒷문·담장·감나무·장독대·돌절구 받침·가로대 작업등·발판 트림·저울 접시)
1 빈 공중: 예(overview 6%, intro-01 3%, 전엔 93%). 2 실루엣: 예(가로대·감나무·장독·뒷문). 3 맨 상자: 예(벽은 기둥·인방, 담장 판자 3 shade+기둥+기와). 4 히어로 색: 예(놋쇠·감 주황·등빛). 5 shade: 예. 6 바닥 가독성: 아니오 — 마당 돌바닥이 따뜻한 갈색이라 발판 나무와 비슷 → 회색으로. 7 위험 색: 예(빨강은 리본·금줄 고추 작은 점뿐). 8 가짜 바닥: 아니오 — 금 원판(PanRimLip)이 접시를 덮어 발판 위 "떠 있는 판"으로 보임 → 다음 반복. 9 광원: 예. 10 온도: 아니오 — 전부 주황, 그늘 청색 없음 → Ambient 청색. 11 밀도: 예. 12 예. 13 예(가운데 받침·양 끝 접시). 14 예. 15 예. 16 예(-40, 낙하선 -25). 17 예. 18 예(장독 14~30, 감 6).
가장 나쁜 뷰 overview: 화면이 한 색(주황-갈색) / 담장 덮개가 마당 위를 가로질러 떠 있음(±X 담장 기와 Wedge 크기 축 실수) / 흙 자국이 커서 얼룩.
**반복 2** (Ambient·OutdoorAmbient 청색, 마당 회색, 흙 자국 작게, 담장 덮개 크기 축 고침, 소개 1번 점 조정)
6 예. 10 예. 8 아니오(PanRimLip 그대로). 나머지 예.
**반복 3** (PanRimLip를 꽉 찬 원판 → 얇은 `ring` 테두리로, 마당 먼지 상자를 발판 회전 공간 밖으로)
1~18 전부 예. intro-04/eye에서 도자기 접시 + 금 테두리로 "저울 접시"가 읽히고 밟는 나무면과 구분됨.

### 렌더 비평 — soy-swamp 반복 3
(반복 1~2는 이전 세션, 아래 "이전 인계" 메모)
1 예(전 뷰 0%). 2 예(와사비 산·쓰러진 병·강판·날치알 언덕·결승 문). 3 예. 4 예(와사비 연두). 5 예. 6 예 — 유리벽은 판정이라 투명도 그대로, `COLORS.wall`만 한 단계 어둡게. 7 예(빨강은 병 띠·뚜껑, 경고 계열 아님). 8 예. 9 예(그림자 1). 10 예(창빛 vs 등). 11 예. 12 예. 13 예(결승 문·등). 14 예 — 반복 2에서 eye 왼쪽 아래를 많이 가리던 쓰러진 병을 (−88,−36,−66)→(−112,−38,−84), 길이 60→54로. 15 예. 16 예(-50). 17 예. 18 예.

### Studio 확인 방법 (사용자, AC12~AC15)
1. `Config.DEBUG.forceMapPlan = { "soy-swamp", "chef-board", "tug-of-war-platform" }` (Studio만, **확인 뒤 nil로 되돌리기**), `rojo serve --port 34883`, Studio에서 Play.
2. 라운드마다: 소개 카메라가 벽·장식을 뚫지 않는지, 조명이 1~2초 안에 맵 분위기(간장 오후 / 아침 주방 / 해 질 녘 마당)로 바뀌고 로비로 오면 돌아오는지.
3. chef-board: 칼 경고 줄(빨강)이 장식과 헷갈리지 않는지, 잘린 칸 구멍 아래로 받침 기둥이 "칸"처럼 보이지 않는지, 작업등 그림자(칼)가 도마에 떨어지는지.
4. tug-of-war-platform: 발판이 기울 때 테두리 트림·저울 접시·동아줄이 같이 기울고 떨어져 보이는 장식이 없는지, **연장전**(`overtimeAt`로 당겨 볼 수 있음)에서 발판이 90°까지 돌 때 가로대 기둥·받침대에 겹쳐 보이지 않는지, 마당에 발판 그림자가 읽히는지.
5. 휴대폰 에뮬레이터: 경고·구멍·발판 끝이 보이는지, 실제 휴대폰에서 끊김이 전보다 심하지 않은지.

### 특이사항
- **selene 우회**: 위 "검증" 줄 참고. 다른 클라우드 세션도 같은 문제를 겪으면 같은 방법(로컬 빌드로 `~/.cache/selene/roblox.yml` 생성, 6시간 캐시 + `last_selene_version` 0.32.0으로 맞춤)으로 돌릴 수 있음.
- **m5-maps-fix-b**: 이전 메모의 "줄다리기 판정 수정 브랜치" 내용은 이미 origin/main에 들어와 있었음(TugOfWarPlatform*·테스트 diff 없음) → 기다리지 않고 진행.
- **결정 D5(아직 스펙 결정 기록에 안 적음 — 공용이 아닌 스펙 문서라 메인 세션/planner가 확인)**: chef-board·soy-swamp의 m5-20 안개 패널은 지우지 않고 방 벽 바깥으로만 옮김(soy ±680, chef ±312). 안에서 보면 안 보이고, 이름 개수·투명도·색·카메라 경로 테스트는 그대로.
- **줄다리기 `p.CastShadow = false` 삭제**: 아트 부착 코드라 허용 범위로 판단. 장식마다 `MapKitLogic.resolveCastShadow`(작은 소품 그림자 끔)가 적용됨. 판정 파츠·overtime은 안 건드림.
- **m5-23-qa 공용 테스트**: main이 이미 맵별 `Art.BUDGET`로 예산을 읽게 바뀌어 있어서, 그룹 B는 soy-swamp 고정 수 한 줄만 남김. 그룹 A/C/D가 같은 줄 근처(조명/파티클 고정 수 `rotating-belt {3,2}`)를 고치면 머지 때 충돌 가능 — 각 맵 한 줄씩이라 손으로 합치면 됨.
- **렌더러 한계**: overview 카메라는 플레이 영역의 3배 상자를 기준으로 멀리 서서, 작은 방(반경 < 250)이면 벽 밖에서 찍힘 → chef-board 방을 300으로 키운 이유. Studio 플레이 카메라에는 영향 없음.
- **위험**: 줄다리기 고정 장식은 테스트로 발판 회전 공간(반지름 37) 밖임을 확인하지만, 캐릭터가 발판 끝에서 튕겨 나갈 때 가로대 기둥(x ±46)은 장식이라 충돌이 없음 — 시각적으로 "부딪힐 것 같은" 느낌만 있을 수 있음(판정 영향 없음).
- 스펙 개발 메모의 그룹 B 절은 이 파일을 가리키는 짧은 요약만 넣음.

## 2026-10-13 이전 인계 — 세션 종료 요청으로 중단 (soy-swamp 반복 1~2)
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
