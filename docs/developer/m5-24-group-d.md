# m5-24 그룹 D 작업 기록 (bouncy-castle-maze · lantern-bridge · cat-cafe-shelves)

## 2026-10-13 인계 2 (클라우드 세션, 3맵 아트 패스 끝 — QA 대기)
- 브랜치 `m5-24-art-d`, `origin/main`(c01a38f, m5-27까지) 머지함(충돌 없음). 스펙 `status:` 줄은 안 건드림(메인 세션이 `in-qa`로).
- **3맵 모두 반복 3회 이상 + after PNG 커밋**: `docs/renders/<mapId>/after-*.png`(overview·eye·mobile·top·intro-01~04) + `after-stats.txt`.
- 새 테스트 `tests/m5-24-group-d.spec.luau`(7개): Extended 예산(build의 Instance.new 조명·파티클 포함), validate, `lighting == Art.LIGHTING`·로비와 다름, 등불 다리 판자 구간에 anim 없음, 소개 경로가 장식 속 안 지남(m4-02 Q1 방식), 배경 바닥 ≤ 낙하선 −10, 이름으로 센 기존 장식 수 유지(Lantern 12·WindowLight 2·Sunbeam 2·CarnivalLamp), 고양이 카페 장식이 선반 위 시야를 안 가림.

### 바꾼 아트 수량 단언 (D2 — QA diff 확인용)
| 파일 | 줄 | 전 | 후 |
|---|---|---|---|
| `tests/map-bouncy-castle-maze.spec.luau` | AC7, 252 근처 | `t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, …)` | `t.eq(Art.BUDGET, "Extended")` + `t.eq(MapKitLogic.checkBudget(decor, "Extended"), nil)` |
| `tests/map-lantern-bridge.spec.luau` | AC10, 195 근처 | `t.ok(MapKitLogic.count(specs) <= MapKitLogic.DECOR_PART_BUDGET, "decor part budget")` | 같은 방식 (Lantern 12개·IntroCamera 4점 단언은 그대로) |
| `tests/map-cat-cafe-shelves.spec.luau` | AC10, 241 근처 | `t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, …)` | 같은 방식 (WindowLight·Sunbeam 단언·IntroCamera 4점 그대로) |
- **공용 테스트(`tests/m5-23-qa.spec.luau`)는 고치지 않았음**: "기존 6개는 프리셋을 씀" 목록에 그룹 D 맵이 없고, "렌더러 통계" 단언은 맵마다 `Art.BUDGET`을 읽어 Extended 기준으로 봐서 머지 뒤에도 통과(1794 passed, 0 failed).
- 소개 카메라 점 좌표만 바뀜(개수 4 그대로): lantern-bridge ③ `(-12,14,-150)` → `(0,15,-172)`, cat-cafe-shelves ② `(CX+18, T1+4, CZ-18)` → `(CX+36, T1+12, CZ-34)`, ③ `(CX+30, T1-4, CZ)` → `(CX+30, T1-5, CZ+46)`(반전 샷). 소개 점 좌표를 고정한 기존 단언은 없음.

### 맵별 결과 (전 → 후, 렌더러 stats)
| 맵 | 장식 | 조명(그림자) | 파티클 | anim | void% 최대 | 가장 무거운 뷰 tris |
|---|---|---|---|---|---|---|
| bouncy-castle-maze | 291 → 1468 | 6 → 7 (1) | 0 → 3 | 0 → 47 | 87% → 4% | 127k |
| lantern-bridge | 102 → 1412 | 12 → 23 (1) | 0 → 9 | 0 → 73 | 97% → 0% | 112k |
| cat-cafe-shelves | 39 → 842 | 2 → 6 (1) | 2 → 4 | 0 → 17 | 78% → 2% | 79k |
- **휴대폰 성능 메모**: 큰 반투명 판 새로 없음(반투명은 작은 것만 — 등롱 물그림자 0.55, 피크닉 병 0.2, 신사 창 0.2). 그림자 조명 맵당 1(좁은 SpotLight). 파티클 Rate 합: bouncy 결승 Confetti 6 + Sparkle 2 + Bubbles 4 ≈ 12, lantern 불꽃 Sparkle 10×3 + 석등 Embers 3×3 + 반딧불 3×3 = 48(전부 배경·가장자리), cat 창 먼지 1.5×2 + 컵 Steam 2 + 진열 Sparkle 2 = 7.
- **bouncy-castle-maze** (반복 4회): 반복 4에서 overview 앞쪽 빈 잔디에 꽃밭 2·피크닉 돗자리 2 무리, 앞쪽 나무 2그루를 카메라 앞에서 옆으로. 전: 회색 박스 미로가 빈 하늘에 떠 있음 → 후: 잔디밭 유원지(대관람차·회전목마·텐트·초밥집) 한가운데 원색 에어 성.
- **lantern-bridge** (반복 4회): 반복 2 = 등불 흰색 → 따뜻한 미색(Bloom에 하얗게 날아가던 것), 강 밝게 + 달빛 반영, 절벽 바위에 지층 띠·이끼 턱, 결승 초롱 2·깃발 2·노렌(높은 표지), 거리 초롱 줄·손님 무리. 반복 3 = 출발 뒤 참배길(돌길·석등 16·초롱 아치 3·소나무). 반복 4 = 절벽 위 기와집 마을 42채(overview의 빈 어두운 땅), 소개 ③ 반전 샷 높이·위치 조정. 마지막에 **입구 도리이 기둥 버그 수정**(원기둥 축이 뒤바뀌어 높이 1.4·지름 16 원판이던 것 → 높이 16 기둥; m5-15 원래 코드의 버그, 소개 경로 검사로 발견). 전: 검은 허공 위 다리 → 후: 여름밤 축제 계곡.
- **cat-cafe-shelves** (반복 4회, 이번 세션 처음 손댐): 반복 1 = 방 키우기(바닥 y −30 = 탈락선 −11 −19, 벽 x ±150·z CZ−60~CZ+150, 높이 130), 마루 3 shade 띠, 허리 몰딩·벽판, 창 2(하늘 판·창살·창턱), 바닥 햇살 무늬, 캣타워 받침(사이잘 기둥 8 + 몸통 + 구멍 집 + 원형 러그), 장식 기둥 3개를 바닥까지 + 사이잘 감김 + 꼭대기 방석, 선반 가장자리 립, 거대 치즈냥(앞발 Sway·꼬리 Sway), 카운터·케이크 4·커피 머신·펜던트 등 3(빛)·메뉴판, 천장 들보·팬(Spin), 창가 화분(잎 Sway)·큰 화분 2, 장난감 쥐 3(Bob)·실뭉치, 바닥 발자국 길, 고양이 바구니 + 잠자는 고양이 3(Pulse), 창 햇살 그림자 SpotLight 1, `Art.LIGHTING`(16시), `lighting = Art.LIGHTING`. 반복 2 = 치즈냥을 타워 쪽으로 돌림, 들보 7 → 3(overview 가림), 소개 ③을 하늘 대신 창 벽을 올려다보는 반전 샷으로. 반복 3 = 카페 테이블 세트 3(의자·컵 Steam·케이크 접시), 서쪽 벽 고양이 액자 4, 벽 선반 마네키네코(팔 Sway), 진열 Sparkle, 들보 2. 반복 4 = 테이블을 overview 카메라 앞에서 치움, 소개 ② 기둥 사이 → 바깥에서. 기존 간판(작은 벽 앞 기둥)은 창 벽 위 고양이 귀 간판으로 옮김. 전: 작은 분홍 상자 속 나무 선반 → 후: 햇살 드는 고양이 카페와 그 한가운데 캣타워.

### 반복 4 (마지막) 체크리스트 — 3맵 공통 판정
| # | bouncy | lantern | cat |
|---|---|---|---|
| 1 빈 공중 ≤10% | 예 (최대 4%) | 예 (0%) | 예 (2%) |
| 2 실루엣 3+ | 예 (성·탑·대관람차·텐트·회전목마) | 예 (도리이·계곡·노점 거리·신사·불꽃) | 예 (캣타워·치즈냥·카운터·창) |
| 3 맨 상자 없음 | 예 (성 받침은 공기 기둥이 덮음) | 예 (절벽 바위 지층 띠·이끼 턱, 마을 집 지붕·들보) — 큰 강 판·땅 판은 배경 평면 | 예 (카운터 roundedBox, 벽은 몰딩·벽판, 테이블 rimDisc) |
| 4 히어로 색 | 예 (원색 4색 + 흰 파이핑) | 예 (등불 주황-빨강 on 남색) | 예 (연분홍·크림 + 치즈 주황) |
| 5 shade 2~3 | 예 | 예 | 예 (마루 띠·벽 2톤·잎 3톤) |
| 6 바닥 가독성 | 예 (체크무늬 밝음) | 예 (판자 밝은 나무, 주변 어두움) | 예 (밝은 선반 + 진한 립) |
| 7 위험 색 | 예 | 예 | 예 (치즈냥은 경고 주황보다 어두운 갈색) |
| 8 가짜 바닥 없음 | 예 (잔디 −56) | 예 (거리 y 14 = 판자보다 14 위, 강 −40) | 예 (마루 −30, 탈락선 −11) |
| 9 보이는 광원·그림자 ≤2 | 예 (1) | 예 (1) | 예 (1, 창 위 램프 파츠) |
| 10 온도 대비·로비와 다름 | 예 (13시 맑은 하늘 + 따뜻한 결승 빛) | 예 (21시 남색 + 주황 등불) | 예 (16시 따뜻한 햇살 + 청록 펜던트 갓·푸른 창) |
| 11 밀도 위치 | 예 | 예 | 예 (타워 주변·창가·카운터 무리) |
| 12 생동감 | 예 (3종, anim 47) | 예 (3종, 73) | 예 (Dust·Steam·Sparkle, 17) |
| 13 방향 | 예 (결승 아치) | 예 (결승 초롱·깃발이 끝에 보임) | 예 (위로 오르는 3단 타워) |
| 14 소개 구도 | 예 | 예 | 예 |
| 15 휴대폰 | 예 | 예 (판자·결승 빛) | 예 |
| 16 배경 바닥 ≤ 낙하선 −10 | 예 (−56 vs −40) | 예 (−40 vs −25) | 예 (−30 vs −11) — 테스트로 고정 |
| 17 예산 | 예 | 예 (조명 23/24 — 여유 1) | 예 |
| 18 스케일 | 예 | 예 | 예 (테이블 75·의자 46·카운터 90 ≈ cm) |
- 남은 약점(아니오는 아님): bouncy eye/mobile은 렌더러 카메라가 출발 벽 뒤라 벽만 보임(Roblox 카메라는 벽 앞으로 당겨짐 — Studio 확인). lantern overview는 밤이라 전체가 어두운 편(의도). cat overview는 천장이 없어 위가 하늘(카메라가 방 밖 위에서 봄 — 게임 카메라·소개 점은 방 안이라 안 보임).

### Studio 확인 (AC12~15)
1. `src/shared/Config.luau`의 `DEBUG.forceMapPlans = { { "bouncy-castle-maze", "cat-cafe-shelves", "claw-machine-prize" }, { "lantern-bridge", "giant-jenga", "tug-of-war-platform" } }` (마지막 라운드는 Final이어야 해서 두 판으로 나눔 — 판마다 다음 플랜).
2. Play(F5) → 방 만들기 → 시작. 라운드마다: 조명이 1~2초에 그 맵 분위기(한낮 / 오후 햇살 / 밤)로 바뀌고 로비로 오면 돌아오는지(AC12).
3. 플레이 감각: 방방 미로 튕김·관문·출구, 등불 다리 흔들림·낙하, 고양이 발·공 넉백이 전과 같은지. 장식(거리·절벽·러그·햇살 무늬)을 바닥으로 착각하는 자리가 없는지(AC13).
4. 소개 카메라가 물체를 뚫지 않는지 — 특히 등불 다리 ③(결승 뒤 낮게)과 고양이 카페 ③(1단 아래 올려다보기)(AC14).
5. 기기 에뮬레이터(휴대폰)에서 등불 다리 판자·결승, 고양이 카페 경고 주황 선반이 보이는지, 끊김(AC15).
6. 확인 뒤 `forceMapPlans = nil` (커밋 기본값, 테스트가 고정).

### 특이사항
- **selene(검증 3단계) 못 돌림**: 이 클라우드 환경에서 `setup.rbxcdn.com`(Roblox API 덤프)이 프록시 정책으로 403 — selene이 roblox std를 못 만듦. 대신 바뀐 4파일만 `std = "luau"`로 따로 돌려 0 errors·0 warnings(미사용 변수 1개 고침). 로컬 PC에서 `selene src` 한 번 확인 필요.
- 도리이 기둥 버그(m5-15부터)는 판정과 무관한 장식 크기 수정.
- lantern-bridge 조명 23/24 — 더 넣을 여유 1개.
- cat-cafe-shelves에서 타워 받침 기둥·몸통·러그는 판정 선반 **아래**(선반 아랫면 −2.2까지)라 바닥처럼 밟히지 않음. 선반 위 시야 상자 검사 테스트 추가.
- `docs/renders/*/before-*.png`는 이전 세션 것 그대로(렌더러 lookAt 수정 뒤 찍은 것).

## 2026-10-13 인계 (wip, 사용자 요청으로 중단)
- 브랜치: `m5-24-art-d` (worktree `agent-adb9fe3b08e5b5131`), `origin/main` 591d84e(키트 수정 e07e08d 포함)까지 머지함. 스펙 상태 `in-dev`.
- **검증 5단계 아직 안 돌림** (wip 커밋). 기존 테스트 중 예산 단언(`<= DECOR_PART_BUDGET` 600)은 깨질 것 — D2대로 `checkBudget(..., "Extended")`로 바꿔야 함:
  `tests/map-bouncy-castle-maze.spec.luau` AC7(208줄 근처), `tests/map-lantern-bridge.spec.luau` AC10(195줄; `Lantern` 이름 12개 단언은 유지됨), `tests/map-cat-cafe-shelves.spec.luau` AC10(241줄).

### 끝난 것
- before 렌더: `docs/renders/<mapId>/before-*.png` 3맵 (렌더러 lookAt 고친 뒤 다시 찍은 것).
- **bouncy-castle-maze** (반복 3회): 잔디밭(GROUND = 낙하선 -40 −16 = -56), 성 받침 + 바깥 공기 기둥(빨강/노랑), 흰 파이핑(벽·칸막이 위), 탑 6개(원뿔 지붕·깃발 Sway), 입구 아치, 결승 아치(그림자 SpotLight 1·Confetti·Sparkle), 송풍기 2(팬 Spin·호스 Pulse), 풍선 다발 3(Bob), 산울타리, 간식 수레, 바람개비, 매표소 + 비눗방울(Bubbles), 대관람차(허브 Spin)·회전목마·서커스 텐트·옆 초밥집·나무·먼 언덕. 램프 기둥을 레인 안 → 성 바깥(x ±28)으로 옮김(이름·개수 그대로). `lighting = Art.LIGHTING`(13시 맑음), `Art.BUDGET = "Extended"`. 소개 점 4개 새로(판정 경계 +40 안).
  - stats: decor 1418/1500, lights 7, shadowed 1, particles 3, anim 47, void 전부 ≤4%. eye/mobile은 렌더러 카메라가 출발 벽 뒤(z +9.5)라 공기 기둥만 보임 — 실제 Roblox 카메라는 벽 앞으로 당겨짐(QA 참고).
  - 주의: m5-maps-fix-a가 z −110(x −20~10)에 출구 벽을 추가 — 그 자리에 장식 없음(확인 필요).
- **lantern-bridge** (반복 1회): 강(WATER_Y = -40, 불투명 반사), 계곡 절벽 바위, 절벽 위 축제 거리 + 노점 10(빛 10), 등불 줄 4(강 위 y 22), 떠내려가는 등롱 14(Bob), 쉼터·출발·결승 바위 받침, 다리 끝 고정 기둥, 석등 불씨(Embers)·쉼터2 그림자 SpotLight, 반딧불, 먼 신사·불꽃·산·달, 도리이 보강. `lighting = Art.LIGHTING`(21시 밤). 판자 위·하위 장식/anim 없음.
  - stats: decor 884, lights 23/24, shadowed 1, particles 9, anim 69, void 0%. **렌더 PNG 아직 안 봄(비평 반복 남음).**

### 남은 것
1. lantern-bridge: `build/renders/lantern-bridge/*.png` 보고 비평 → 고침 2회 이상.
2. cat-cafe-shelves: 아직 손 안 댐. 계획: 방 키우기(바닥 y -30 = 탈락선 -11 −19, 벽 ±170), 캣타워 받침 기둥(사이잘 Fabric 띠), 거대 치즈냥(경고 주황 255,150,60과 다른 갈색 톤), 꼬리 Sway, 잠자는 고양이 Pulse, 창 + 햇살 Spot(그림자), 카운터·케이크 진열장, 천장 팬 Spin, `Art.LIGHTING`(16시). 기존 소개 1번 점이 벽 밖이라 고쳐야 함. (fix-b가 CatCafeShelves.luau 277~346 판정부를 고침 — 아트 부분만.)
3. 새 테스트 `tests/m5-24-group-d.spec.luau`: 3맵 checkBudget Extended, lighting == Art.LIGHTING + MapLighting.validate + 로비와 다름, 소개 경로가 장식 속 안 지남(m4-12 방식), lantern-bridge 판자 구간(|x| ≤ halfWidth+1, y -3~5) 안에 anim 장식 없음.
4. 기존 테스트 예산 단언 3곳 수정(위), 검증 5단계, after PNG 복사(`docs/renders/<mapId>/after-*.png`), 스펙 개발 메모 그룹 D 절, `in-qa`.

### 다음에 할 첫 단계
`git fetch origin && git merge origin/main` → `lune run tools/render-map lantern-bridge --view all` → PNG 비평.

### 막힌 점
- 없음. 렌더러 lookAt 버그는 main(e07e08d)에서 고쳐짐(내 임시 수정은 되돌림).
