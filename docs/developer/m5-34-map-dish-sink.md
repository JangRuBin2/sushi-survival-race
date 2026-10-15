# m5-34 dish-sink (깨끗하게! 설거지통) — 개발 작업 기록

## 2026-10-15 — 구현 완료, in-qa
- **브랜치**: `m5-map-sink` (origin/main b2769b8 = m5-33 기반 위). Rojo 포트 34892 (Studio 확인 때만).
- **끝난 것**: 스펙 범위 전부 — `DishSink.luau`(껍데기 덮어씀, `inPool` 줄 삭제), `DishSinkLayout.luau`·`DishSinkLogic.luau`(새), `DishSinkArt.luau`(껍데기 덮어씀), `tests/map-dish-sink.spec.luau`(21개), 렌더 전/후 `docs/renders/dish-sink/`.
- **검증 5단계 통과** (2026-10-15): rojo build OK, `stylua --check src tests tools` OK, selene 0 errors/0 warnings, `lune run tests` **2025 passed, 0 failed**(main 2004 + 21), luau-lsp analyze 끝 코드 0 (처음 `table.insert(rel, CFrame:ToObjectSpace(...))` 오버로드 오류 → 괄호로 한 값만).
- **공용 파일 변경 없음** (Config·Remotes·maps/init·SfxCues·MapFxPresets 등 그대로).
- **남은 것**: QA, 사용자 Studio AC13~AC18(아래 스펙 개발 메모 체크리스트), 실측 시간(AC16).
- **다음 첫 단계**: QA가 `lune run tests`와 스펙 수용 기준 확인. Studio에서 `forceMapPlan = { "dish-sink", "hot-plate", "skewer-showdown" }`.
- **막힌 점**: 없음. 스펙 수치와 다르게 한 곳 2개는 결정 기록 D5·D6.

## 구현 메모
- 접시는 고정 Cylinder(`SinkPlate` 태그). 서버가 `Logic.plateAt`으로 접시 위인지 보고 `Logic.platePush` 목표 속도 쪽으로 `AssemblyLinearVelocity`를 가속(가속 24 = RotatingBelt). `MoveExempt` 없음.
- 회전 느낌: 접시 밑 `PlateSpin` 막대 2개(접시 중심에 있는 고정 장식, 양 끝만 테 밖으로 보임)에 `Spin` anim(B 5초, E 4초). 시계 방향 접시(dir 1)는 막대를 X로 180° 뒤집어 Spin 방향을 반대로 — 무늬가 미는 방향으로 돈다.
- 수세미: `Sponges/SpongeN` Model 안 장식 파츠(`Art.spongeSpecs`, `MapKit.buildDecor`라 충돌·쿼리·터치 없음). 몸통에 `SinkSponge` 태그 + `SpongeIndex`, `SoapFoam` 파티클(Rate 0, 맞을 때 Emit 12). 서버가 매 Heartbeat `workspace:BulkMoveTo`로 묶어 옮김. 맞음은 숫자 판정(`Logic.spongeHit`), 넉백 `LinearVelocity` 0.12초 + `PlatformStand` 0.8초 + `MoveExempt.mark(character, 1.2)`, 쿨다운 0.6초, cue `SpongeSquish`.
- 수세미 이동은 끝에서 1.5초 멈추고 2.5초 동안 코사인으로 부드럽게 이동(멈춘 시각엔 항상 양 끝 — 테스트).
- 런타임 파티클 = 장식 9 + 수세미 거품 6 = 15 (Extended 16 안, 테스트가 `extra.particles`로 셈).

## 렌더 반복 (아트 가이드 12절)
렌더: `lune run tools/render-map dish-sink --view all` (반복 중간은 `--quality fast`). 전: `docs/renders/dish-sink/before-*.png`(m5-33 껍데기), 후: `after-*.png` + `after-stats.txt`.

### 반복 1 (첫 아트)
stats: decor 1158, lights 9 (shadow 2), particles 15, anim 34, void overview 41% · eye 0% · intro 0~1%.
체크리스트: 1 아니오(overview 41%) · 2 아니오(overview에 벽만 보임) · 3 예 · 4 예 · 5 예 · 6 예 · 7 아니오(수도꼭지 손잡이 빨강) · 8 예 · 9 예 · 10 예 · 11 예 · 12 예 · 13 예 · 14 아니오(intro-02·03에 코스가 안 보임, intro-01이 수도꼭지 관에 막힘) · 15 예 · 16 예 · 17 예 · 18 예.
가장 나쁜 뷰: intro-03 — "왜 싸 보이나": ① 조리대 몸통 상자 하나가 개수대 안까지 채워 코스가 통째로 묻혔다(버그) ② 그래서 빈 스테인리스 홈만 보인다 ③ 위험물·접시가 하나도 안 보여 무슨 맵인지 모른다.
고칠 것: 조리대 몸통을 개수대 아래 통짜 + 둘레 4조각으로, 왼쪽 위 벽 제거, 뒤·오른쪽 벽·바닥을 넓고 높게, 손잡이 파랑·흰색, intro-01 위치.

### 반복 2
stats: decor 1161, void overview 4% · 나머지 0~1%.
체크리스트: 1 예 · 2 예(접시 탑·창문·개수대 홈) · 3 예 · 4 예 · 5 예 · 6 예(물 청록을 진하게, 스테인리스 한 단계 어둡게, Contrast 0.15) · 7 예 · 8 예 · 9 예 · 10 예 · 11 아니오(조리대가 넓고 텅 빔 — 소품이 개수대 앞쪽에만) · 12 예 · 13 예 · 14 아니오(intro-04 카메라가 건조대 접시 속, 세운 접시가 흰 벽처럼 겹침) · 15 예 · 16 예 · 17 예 · 18 예.
가장 나쁜 뷰: overview — ① 조리대 300 폭이 비어 있다 ② 바닥·벽·조리대가 다 같은 밝은 회청색 ③ 히어로가 작다.
고칠 것: 조리대 폭 줄이기(±124), 조리대 소품 무리(들통·도마·소쿠리·그릇 탑·철사 바구니·양념통), 바닥 따뜻한 베이지 타일, 건조대 접시를 칸마다 세워(면이 진행 방향) 기울이기, intro-04 가운데로.

### 반복 3
stats: decor 1276, void 0~4%.
체크리스트: 1 예 · 2 예 · 3 아니오(행주 26×14·고무장갑 손바닥이 맨 상자) · 4 예 · 5 예 · 6 예 · 7 아니오(방울토마토 빨강, 결승 기둥 머리가 수세미 노랑) · 8 예 · 9 예 · 10 예 · 11 예 · 12 예 · 13 예 · 14 예 · 15 예 · 16 예 · 17 예 · 18 예.
가장 나쁜 뷰: intro-01 — ① 앞쪽 고무장갑이 판 하나 ② 토마토 빨강이 위험물처럼 튐 ③ 그 밖엔 깊이·전경이 좋다.
고칠 것: 행주에 같은 중심·같은 anim 줄무늬(트림, 같이 흔들림), 손바닥 roundedBox, 토마토 → 삶은 달걀, 기둥 머리 나무색.

### 반복 4 (최종, high 품질)
stats: `decor=1300/1500 lights=9/24 (shadowed 2/2) particles=15/16 anim=36/80 tris=107388 void=intro-01:0%,intro-02:0%,intro-03:1%,intro-04:0%,intro-05:0%,overview:4%,eye:0%,mobile:0%`.
체크리스트 18개 전부 **예**:
1 void ≤ 4% · 2 overview에 개수대 홈·접시 탑·들통·창문, 실루엣으로 "개수대" · 3 큰 장식은 트림·림·roundedBox·bevel(벽은 타일 띠·말린 테두리, 조리대는 크롬 모서리) · 4 수세미 노랑·연두가 eye·intro-03에서 바로 보임(약 5~10%) · 5 스테인리스 STEEL·STEEL_DARK light/base/dark, 타일 2 shade · 6 밟는 접시(흰)·칸막이(밝은 스테인리스)가 청록 물·회색 벽보다 밝음 · 7 위험 = 수세미만 진한 노랑·연두, 장식 수세미는 채도 낮게, 빨강 장식 없음(세제통 주황은 스펙 지정 10%, 조리대 위 코스 밖) · 8 접시 테·트림은 윗면보다 0.1~0.15 아래 립, 조리대는 코스보다 4~14 높음, 거품은 5 아래 · 9 창문(Neon 판)·램프 전구·결승 전구·물빛 원판에만 빛, 그림자 2(창문 햇살 Spot, 램프 Spot) · 10 창문 따뜻한 햇살 + 결승 전구 ↔ 차가운 스테인리스·물, ClockTime 10.5 (로비 14) · 11 출발(세제·장갑·솔·거품), 위험물(수세미·접시 테·거품), 결승(건조대·간판·반짝이)에 몰림, 무리 배치 · 12 파티클 5종(Bubbles·SeaSpray·Sparkle·SoapFoam + 수세미 Emit), anim 36 · 13 eye에서 끝 창문 빛과 접시 줄이 방향을 보여 줌 · 14 intro 5장 모두 주제 하나(①수도꼭지 너머 전체 ②도는 접시 ③칸막이 위 수세미 반전 ④건조대 결승 ⑤출발), 뚫는 물체 없음 · 15 mobile에서 접시 테·틈·수세미 보임 · 16 개수대 바닥 -24 ≤ 모든 낙하선 -10 (테스트), 주방 바닥 -76 · 17 예산 안, 경고 없음 · 18 앞접시 20·큰 접시 26·컵 9~10·수도꼭지 74·들통 46·수세미 9×7×6·세제통 24·도마 34×52.
전/후 한 줄 비교: 전 = 회색 판 하나와 노란 선(빈 하늘 90%), 후 = 햇살 드는 업소용 2칸 스테인리스 개수대 속 파란 테 접시·수세미·건조대 결승.

### 시트 비교 (위 왼쪽 칸 "깨끗하게! 설거지통 레이스" ↔ after-overview·after-intro-01)
| 항목 | 있음/없음 | 메모 |
|---|---|---|
| 수도꼭지 | 있음 | 크롬 구스넥 + 물줄기·물방울, intro-01 앞쪽 |
| 스펀지(수세미) | 있음 | 노랑 몸통 + 연두 면, 칸막이 위를 가로질러 왕복 |
| 파란 테 접시 | 있음 | 지름 20·26, 파란 립 + 회전 무늬 |
| 거품 | 있음 | 물 위 거품 무리·비눗방울(Bob)·SoapFoam 파티클 |
| 건조대 FINISH | 있음 | 세워 둔 깨끗한 접시 줄 + 나무 "FINISH" 간판 |
색 분위기: 시트처럼 밝은 하늘·청록 물과 스테인리스, 노랑 스펀지가 강조색. 시트보다 접시 무늬가 단순하고 배경 창가가 덜 화려하다(근사 렌더러 기준).

### 휴대폰 성능 메모 (AC12)
가장 무거운 뷰(전체) tris 약 107k, 큰 반투명 판 2장(설거지물 — 칸마다 1장, 그 밖 없음, 테스트로 고정), 그림자 조명 2, 파티클 Rate 합 약 30/초(장식 9개: 거품 2×4, 물방울 3×2, 물보라 4, 반짝이 4×2 + 수세미는 Emit만).
