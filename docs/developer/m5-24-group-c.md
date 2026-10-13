# m5-24 그룹 C 작업 기록 (ramen-rapids · giant-jenga · claw-machine-prize)

## 2026-10-13 인계 2 — 세 맵 아트 루프 완료, 검증 5단계 통과 (최신)
- 브랜치 `m5-24-art-c`, `origin/main`(c01a38f, m5-maps-fix-a·b 포함) 병합. 스펙 `status:`는 안 바꿈(`ready` 그대로 — 메인 세션이 그룹 병합 때 정함).
- **검증 5단계 (이 상태로 전부 돌림)**: `rojo build` 통과 · `stylua --check src tests tools` 통과 · `selene src` 0 errors/0 warnings · `lune run tests` **1793 passed, 0 failed** · `luau-lsp analyze` 오류 0(끝 코드 0).

### 바뀐 파일
- `src/shared/maps/RamenRapidsArt.luau` — 반복 3: Atmosphere Density 0.2→0.16·Haze 1→0.6·Color 어둡게, Contrast 0.12·Saturation 0.1, 국물 위 김(Nori) 두 shade, `Art.LIGHTING`에 `:: MapLighting.LightingPreset`(타입 검사).
- `src/shared/maps/GiantJengaArt.luau` — 전면 재작성(장식 44 → 1101). `GiantJenga.luau`는 `lighting = Art.LIGHTING` 한 줄만 추가(블록·칸·build 판정 코드 그대로).
- `src/shared/maps/ClawMachinePrizeArt.luau` — 기계 외관·오락실 추가(장식 18 → 554 + 칸 인형 256). `ClawMachinePrize.luau`는 `lighting = Art.LIGHTING` 한 줄만(칸·집게·overtime 그대로).
- `tests/m5-24-c.spec.luau` (새 파일, 6개): Extended 예산 3맵, `lighting = Art.LIGHTING`·로비와 다른 ClockTime, 칸 인형(tileDecor)에 anim 없음·인형뽑기 Decor는 Pulse만·그림자 조명 파츠 고정, 배경 바닥 ≤ 낙하선 −10, 시야 상자 겹침 없음, 소개 경로가 장식 상자를 안 지나감.
- `docs/renders/{ramen-rapids,giant-jenga,claw-machine-prize}/after-*.png` + `after-stats.txt` (overview·eye·mobile·top·intro-01~04).

### 바꾼 아트 수량 단언 (D2) — 파일·줄·전후
| 파일:줄 | 전 | 후 |
|---|---|---|
| `tests/map-giant-jenga.spec.luau:322~323` | `count(decor) <= DECOR_PART_BUDGET` | `checkBudget(decor, "Extended", { lights = 3 }) == nil` (LampBulb PointLight 3 포함). `LampBulb` 3개 단언(`t.eq(lamps, 3)`)은 그대로 |
| `tests/map-claw-machine-prize.spec.luau:257~262` | `total <= DECOR_PART_BUDGET` (decor + 64칸 tileDecor) | `checkBudget(decor, "Extended", { parts = 칸 장식 수, lights = 1 }) == nil` (NEON PointLight 1 포함) |
| `tests/m5-23-qa.spec.luau:238~245` "기존 6개는 프리셋을 씀" | 6개 모두 `lighting == PRESETS[id]` | `Art.BUDGET == "Extended"`(아트 패스 끝낸 맵)이면 `lighting ~= nil and validate == nil`, 아니면 그대로 `== PRESETS[id]` (AC7과 같은 방식). **A·B·D 그룹도 같은 줄을 고칠 수 있음 — 병합 충돌 주의(같은 내용이면 하나만 남기면 됨)** |
| (이전 인계) `map-ramen-rapids.spec.luau` 318·371, `m5-20-qa.spec.luau` 177, `m5-23-visual-kit.spec.luau` AC7 | 아래 인계 1 참고 | |
- `m5-23-qa` "렌더러 통계 = 기존 맵 lune 카운트"는 main 병합 뒤(맵별 `Art.BUDGET`으로 단계를 읽게 바뀜) **고치지 않아도 통과** — 손대지 않았어요.
- 판정·스폰·시간·태그·로직·연장전·카메라 경로 테스트는 수정 없음.

### 맵별 결과 (전 → 후 한 줄)
- **ramen-rapids** — `before-*.png` → `after-*.png`: 빈 하늘 위 그릇 → 라멘집 카운터·벽·노렌·주방 창구 속 라이몬 그릇, 나루토 섬·계란·면 커튼. decor 205→966, void overview 87%→0%.
- **giant-jenga** — 빈 갈색 판 위 떠 있는 탑(void overview 57%·eye 22%) → 저녁 목공소: 작업대(상판 −56)·공구판·창(차가운 빛)·선반·문·시계·선풍기, 블록 뽑는 셰프 손, 바이스·탁상등·톱·줄자·머그, 톱밥 더미·상자·여분 블록, 탑 그림자 둘레 안전 줄무늬, 그림자 작업등 SpotLight. decor 44→1101, void 전 뷰 0%.
- **claw-machine-prize** — 하늘 속 유리 상자(void overview 89%) → 한밤 오락실: 빨간 기계 몸통·모서리 기둥·머리 간판(자홍·청록 네온)·조작대(조이스틱·버튼·동전)·경품 출구, 옆 오락기 4대, 경품 선반, 카펫·벽 네온, 천장 네온 간판·미러볼. decor 18→554(+칸 인형 256), void 전 뷰 ≤1%.

### 휴대폰 성능 메모 (AC11)
| 맵 | 가장 무거운 뷰 tris(렌더러 전체) | 화면 속 큰 반투명 판 | 그림자 조명 | 파티클 Rate 합 |
|---|---|---|---|---|
| ramen-rapids | 43,744 | m5-20 FogPanel 3(국물 아래, 그대로)·그 밖 새로 없음 | 1 | 장식 26 + 코드 Steam 3×6 = 44 |
| giant-jenga | 89,888 | 0 | 1 (WorkLampBulb Spot) | 11 |
| claw-machine-prize | 76,864 | 유리벽 4 + 천장 1 (m5-19 그대로, 새로 추가 없음 — 오락기 간판도 불투명) | 1 (CeilingLamp Spot) | 11.5 |

### Studio 확인 (사용자, AC12~AC15)
1. `Config.DEBUG.forceMapPlan = { "ramen-rapids", "giant-jenga", "claw-machine-prize" }`, Rojo `serve --port 34884`. **확인 뒤 nil로 되돌리기.**
2. 라운드마다 조명이 1~2초 안에 바뀌는지: 라멘 = 금빛 한낮, 젠가 = 어두운 저녁 목공소 + 창 푸른빛, 인형뽑기 = 한밤 보라 + 네온. 로비로 오면 원래 조명.
3. 젠가: 블록이 뽑히고 칸이 기울 때 장식이 같이 안 움직이고(전부 고정), 탑 그림자(작업등)에 빠진 칸이 읽히는지. 떨어질 때 작업대(−56)에 닿기 전 탈락(−30)하는지.
4. 인형뽑기: 집게가 칸을 들어 올리는 동작·연장전 기울기(상자 전체가 장식과 같이 기움)가 전과 같은지, 기울 때 장식이 어긋나 보이지 않는지(Pulse만 씀). 칸 밖 기계 윗면 크롬 테(−4)를 바닥으로 착각하지 않는지.
5. 소개 카메라 4점이 물체를 뚫지 않는지, 휴대폰 에뮬레이터(480×270 근처)에서 경고 노랑·구멍·가장자리가 보이는지. Future 조명에서 너무 어두우면 각 Art.LIGHTING의 `ExposureCompensation`만 올리면 됨.

### 반복 기록 (체크리스트 18개, 가이드 11절)
#### ramen-rapids 반복 3 (마지막)
- 렌더: decor 966/1500 · lights 7/24(그림자 1) · particles 13/16 · anim 29/80 · tris 43,744 · void 전 뷰 0%.
- 1 예 · 2 예(그릇·나루토·계란·젓가락·노렌) · 3 예 · 4 예(국물 금빛 + 나루토 분홍) · 5 예(김 두 shade로 보강) · 6 예(밥 발판 밝음) · 7 예 · 8 예 · 9 예 · 10 예(주방 창구 따뜻 + 창 차가움) · 11 예 · 12 예 · 13 예 · 14 예 · 15 예 · 16 예(카운터 −90 ≤ −56−10) · 17 예 · 18 예(그릇 스케일, 인계 1 참고).
- 가장 나쁜 뷰였던 overview: 안개가 두꺼워 그릇 밖이 물에 빠진 듯 흐렸음 → Density·Haze를 낮추고 대비를 올려 해결. 노른자는 반구 + 테두리로 잘 읽힘.

#### giant-jenga 반복 1 (BEFORE 렌더 기준)
- 1 아니오(overview 57%·eye 22%·intro 15~24%) · 2 아니오(탑 하나뿐) · 3 아니오(맨 상자 Crate) · 4 아니오(안전 줄무늬 없음) · 5 아니오 · 6 예 · 7 예 · 8 예 · 9 예(LampBulb) · 10 아니오(로비 조명) · 11 아니오(배경이 고르게 흩어짐) · 12 아니오(파티클 0, anim 0) · 13 예(중앙 짙은 받침) · 14 아니오(intro 3점, 하늘) · 15 예 · 16 예 · 17 예 · 18 아니오(상자·줄자가 탑보다 큼).
- 왜 싸 보이나: 하늘에 뜬 탑 + 빈 판, 세계가 없음 / 조명이 로비와 같음 / 움직임 없음.
- 고침: 목공소 방 전체, 작업대 상판, 셰프 손·바이스 등 세트피스, Art.LIGHTING(19시), 그림자 작업등, Dust·Sparkle·Steam, Spin·Sway·Bob, intro 4점.
#### giant-jenga 반복 2
- 렌더: decor 1077 · void 0%. 1 예 · 2 예 · 3 예 · 4 예 · 5 아니오(기대 세운 목재 단색) · 6 예 · 7 예(공구 손잡이 초록·파랑, 블록 상자 빨강 → 골판지색으로) · 8 예 · 9 예 · 10 예 · 11 예 · 12 예 · 13 예 · 14 아니오(intro-02 올려다보기가 손님 얼굴 정면에 막힘) · 15 예 · 16 예 · 17 예 · 18 예.
- 고침: 목재 아래 짙은 띠, intro-02를 왼쪽 아래로 옮겨 손·탑·창을 함께, 창 색 어둡게(Bloom 번짐 줄임), Exposure 0.35. eye 뷰 정면 어두운 벽 → 반복 3.
#### giant-jenga 반복 3 (마지막)
- 렌더: decor 1101/1500 · lights 7/24(그림자 1) · particles 4/16 · anim 5/80 · tris 89,888 · void 전 뷰 0%.
- 18개 전부 예. (11: 탑 둘레·작업대 앞쪽 무리에 몰림, 12: 파티클 3종(Dust·Sparkle·Steam)·anim 5, 13: eye에서 가운데 짙은 받침이 보임, 17: 경고 없음.)
- eye 뷰 정면에 클램프 걸이 + 벽등(따뜻한 Point)을 넣어 빈 벽을 채움. 클램프 턱을 roundedBox → 상자로 줄여 파츠 1321 → 1101.
#### claw-machine-prize 반복 1 (BEFORE)
- 1 아니오(overview 89%·intro 46/39%) · 2 아니오(유리 상자만) · 3 아니오(맨 간판 상자) · 4 아니오 · 5 아니오 · 6 예 · 7 예 · 8 예 · 9 예 · 10 아니오(로비 조명) · 11 아니오 · 12 아니오 · 13 예(가운데) · 14 아니오(하늘) · 15 예 · 16 아니오(배경 바닥 없음) · 17 예 · 18 아니오(기계 몸체가 없음).
- 고침: 기계 몸통(칸 아래 비움, 구덩이 −40)·기둥·머리 간판·조작대·경품 출구, 카펫 −150·벽·오락기·선반·네온 간판, Art.LIGHTING(0시), 천장 램프 Spot(그림자), 유리 틀 트림.
#### claw-machine-prize 반복 2
- 렌더: decor 552 · void 0%. 1 예 · 2 예 · 3 예 · 4 예 · 5 예 · 6 예 · 7 예(빨간 버튼은 조작대만) · 8 예 · 9 예 · 10 예(청록·흰 램프 vs 자홍) · 11 예 · 12 예 · 13 예 · 14 아니오(intro-03이 빈 천장만) · 15 예 · 16 예 · 17 예 · 18 아니오(옆 오락기가 기계 반대쪽을 봄).
- 고침: 오락기 4대가 기계 쪽을 보게, intro-03 아래쪽으로, 뒤(−Z) 간판 추가.
#### claw-machine-prize 반복 3 (마지막)
- 렌더: decor 554/1500 (+칸 인형 256) · lights 11/24(그림자 1) · particles 4/16 · anim 8/80 · tris 76,864 · void 전 뷰 ≤1%.
- 18개 전부 예. top 뷰가 머리 간판에 가려 → 머리를 유리 천장 위 7로 올려 해결. 미러볼이 overview에서 상자를 가려 → 오른쪽 뒤로. 오락기 간판 반투명 0.15 → 불투명(AC11 큰 반투명 판 추가 금지).

### 특이사항
- **인형뽑기 Decor에는 Pulse만**: 연장전이 `ctx.model:PivotTo`로 Decor까지 같이 기울이는데, `MapDecorFxController`의 Spin·Bob·Sway는 처음 본 CFrame을 매 프레임 덮어써서 기운 상자와 어긋나요. 그래서 미러볼도 Spin 없이 반짝이(Sparkle)로. 스펙의 "미러볼 Spin"은 이 이유로 뺐어요(키트 쪽에서 부모 기준 오프셋을 지원하면 다시 가능 — m5-23 담당).
- 인형뽑기 머리 간판의 `Neon` 파츠(build가 PointLight를 붙이는 이름)는 1개 그대로 — 테스트 `lights ≤`와 runtime 조명 수 유지.
- 젠가 스펙 세트피스 "공구판 망치 Sway"는 망치가 여러 파츠라(위상이 달라 따로 흔들림) 앞치마(단일 파츠) Sway로 대신했어요. 걸린 줄자 띠 Bob·벽시계 진자 Sway·선풍기 날 Spin.
- 젠가 블록 모서리 트림(FG)은 **안 넣음**: 블록이 판정 Top 파츠 자식으로 기울고 사라지는데, Decor로 만들면 같이 안 움직이고, 블록 하위로 넣으려면 판정 build hunk를 고쳐야 해서(금지).
- 렌더러 tris는 방 전체 기준이라 휴대폰 실제 부하와 다를 수 있음 — AC15는 Studio 확인 필요.
- 브랜치에 `build.rbxl`·`sourcemap.json`·`build/renders`는 커밋 안 함.

## 2026-10-13 인계 1 (사용자 요청으로 중간 정리) — 이전 기록
- 브랜치: `m5-24-art-c` (worktree `agent-a69742ebe88c113b3`), `origin/main` 591d84e까지 병합됨. Rojo 포트 34884.
- 스펙 상태: `ready` 그대로 (in-dev로 안 바꿈). **검증 미완료 — in-qa로 넘기지 말 것.**

### 끝난 것
- 세 맵 BEFORE 렌더 저장: `docs/renders/<mapId>/before-*.png` + `before-stats.txt` (렌더러 lookAt 버그 수정 전 렌더라 before-intro-* 는 방향이 틀림 — 다시 찍으려면 `git show` 이전 커밋의 Art로 재렌더).
- **ramen-rapids 반복 2회 진행** (`src/shared/maps/RamenRapidsArt.luau`, `RamenRapids.luau`의 `lighting = Art.LIGHTING` 한 줄):
  - 라멘집 환경: 카운터 상판(y -90, 판 8장), 가게 바닥(y -290), 벽 4면(흙벽+기둥+보), 뒤 벽 주방 창구(따뜻한 빛, 육수 냄비·국자·김), 노렌 5장(가운데 흰 원 표식, Sway), 메뉴 패 10개, 붉은 등롱 3개(Point, Sway), 오른쪽 격자창 3개(차가운 Surface 빛 range 16), 왼쪽 그릇 선반, 앞 벽 미닫이 문.
  - 그릇 스케일 소품: 찻잔(김), 양념 쟁반(오른쪽), 교자 접시, 젓가락 통, 옆 손님 그릇(김), 물수건·메뉴 세움판.
  - 히어로: 라이몬 띠(BowlPattern/BowlPatternKey), 그릇 아래 깎임·굽, 나루토 소용돌이 섬(소용돌이 22조각 + Spin 막대), 반숙 계란 반쪽 2개, 젓가락이 든 면 커튼(14가닥 Sway) + 그림자 스폿 등 1개, 테두리 김 판, 렌게.
  - 국물: BrothDepth(불투명), 기름 띠, Sparkle·Bubbles·SteamThick 앵커.
  - **m5-20 QA B2·B5 해결**: FogPanel 3장을 국물 수면 아래(그릇 안, 길이 230/200)로 내림 — 그릇 밖으로 안 나가고, 위에서 볼 때 항상 국물 뒤라 가릴 투명 물체가 없음. 이름·개수·재질·투명도는 m5-20 테스트대로 유지(D3).
  - Art.LIGHTING: 프리셋 복사 후 Density 0.2, Haze 1, Contrast 0.08, Saturation 0.08, SpecularScale 0.8.
  - IntroCamera 4점: ① (56,50,38)→그릇 전체+주방 벽 ② 차슈 클로즈업 ③ 결승 쪽 반전 ④ 출발 뒤 (0,12,14). 모두 판정 경계+40 안.
  - 마지막 렌더 stats: decor 966/1500, lights 7/24 (shadowed 1/2), particles 13/16 (+코드 Steam 3 포함 여부 확인 필요), anim 29/80, tris 43744, void 전 뷰 0%.
- 바꾼 테스트 단언 (D2):
  - `tests/map-ramen-rapids.spec.luau` 318·371줄: `count <= DECOR_PART_BUDGET` → `checkBudget(decor, "Extended") == nil`
  - `tests/m5-20-qa.spec.luau` 177줄: 같은 변경 (ramen budget)
  - `tests/m5-23-visual-kit.spec.luau` AC7: `lighting == preset` → `preset 또는 validate 통과한 자기 Art.LIGHTING` (D4 때문에 필요, 다른 그룹도 같은 줄을 고칠 것 — 병합 충돌 주의)

### 남은 것
- **검증 실패 2건 (main 병합 후 새로 생긴 m5-23-qa 테스트)**: `m5-23-qa.spec.luau` "QA lighting: … 기존 6개는 프리셋을 씀"(ramen이 Art.LIGHTING을 써서) · "QA budget: 렌더러 통계 = 기존 맵 lune 카운트". 둘 다 m5-24 D4/Extended와 충돌 — 그 단언을 AC7과 같은 방식으로 고치거나 m5-23 담당과 맞춰야 함. 나머지 1567 통과, stylua 통과. selene·rojo build·타입 검사는 이번 상태로 **안 돌림**.
- ramen-rapids: 반복 3 이상 + 체크리스트 18개 글 비평 기록, 계란 노른자 모양 확인(마지막 렌더 아직 안 봄), 오버뷰 안개 정도 확인, 양념 쟁반 이동 후 구도 확인, after PNG 저장, 휴대폰 성능 메모, `tests/m5-24-c.spec.luau`(Extended 예산·anim 금지 목록·소개 경로 충돌·FogPanel 그릇 안) 작성.
- giant-jenga: 손 안 댐 (BEFORE만). 블록 스택은 m5-maps-fix-a가 판정 수정 중 — **아트 코드만, 블록 만드는 부분은 같은 hunk 건드리지 말 것**. 소개 점 01(y=355)이 아레나 경계 밖.
- claw-machine-prize: 손 안 댐 (BEFORE만). m5-maps-fix-b가 판정 수정 중 — 칸·집게 스타일 hunk 금지, 칸·인형·집게에 anim 금지.
- 스펙 개발 메모(그룹 C 절) 미작성.

### 다음에 할 첫 단계
1. `git fetch origin && git merge origin/main` → `lune run tools/render-map ramen-rapids --view all` → `build/renders/ramen-rapids/*.png` 전부 보고 반복 3 비평을 이 파일에 적기.
2. m5-23-qa 실패 2건 처리 방법 결정(단언 수정은 D2 범위인지 메인 세션에 확인).

### 막힌 점 / 참고
- Lune `CFrame.lookAt` 버그로 렌더러 intro 뷰가 반대로 찍히던 문제 → main e07e08d에서 고쳐짐 (BEFORE intro 렌더는 그 전 것).
- SurfaceLight range ≤ 16 (kit가 거부함). Spin anim은 amount 0.
- 여러 파츠로 된 장식에 anim을 달면 파츠마다 위상이 달라(phaseOf 위치 기반) 따로 움직임 — 단일 파츠에만 anim.
