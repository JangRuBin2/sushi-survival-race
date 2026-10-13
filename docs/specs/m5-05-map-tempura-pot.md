status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-05 — 새 Survival 맵: 튀김 냄비 탈출 (`tempura-pot`)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.2 Survival 맵(최대 60초, 목표 인원만 남으면 끝, **시간이 끝나면 버틴 사람 전원 통과**), §5.3 "튀김 기름 점프 (Survival, 튀는 기름 방울 피하기)", §5.2 점수(Survival = 높이), §11.4
- 레퍼런스: [`docs/REFERENCE-m5-maps.md`](../REFERENCE-m5-maps.md) 1·2.2절
- 참고 코드: `HotPlate.luau`(층 구조·아래층 기회), `ChefBoard.luau`(경고 뒤 넉백·Survival 판정), `SoySwampHazards.luau`(넉백 + `MoveExempt`), `RamenRapidsLogic.crossingPath`(발판 경로 탐색 테스트 방식)
- 담당 개발 worktree: `m5-tempura` (Rojo 포트 34873)
- 공용 파일 수정 담당: 없음 (id·이름·규칙 문구·등록·`OilSplash` cue는 m5-03)
- 의존: **m5-03 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/maps/TempuraPot.luau`(껍데기 덮어쓰기, 끝나면 `inPool = false` 줄 삭제), 새 파일 `src/shared/maps/TempuraPotLayout.luau`, `TempuraPotLogic.luau`, `TempuraPotArt.luau`, `tests/map-tempura-pot.spec.luau`

## 목표
거대한 튀김 냄비 속, 기름이 점점 차오른다. 둥둥 뜬 새우튀김·고구마튀김·깻잎튀김 발판을 밟고 **위로 올라가야** 산다. 기름에 닿으면 바삭하게 튀겨져 탈락. 위로 갈수록 자리가 좁고, 기름이 튀어 사람을 밀어낸다. 철판(계속 움직이기)·도마(칼 줄 읽기)와 달리 **"올라가서 자리 지키기"** Survival.

## 규칙 (수치는 전부 기본값, Layout·Logic 상수)
### 무대
- 냄비: 안쪽 반지름 **36**, 바닥 y = −10(origin 기준), 벽 높이 y = 40까지(매끄럽고 오를 수 없음, 충돌 있음). 맨 위 발판(30) + 점프(약 6.4) < 40이고 맨 위 발판에서 벽까지 수평 6 이상이라 테두리에 올라갈 수 없어요.
- **튀김 바구니**(출발 판): 반지름 20 원판, 윗면 y = 3. `Spawns` 24개(서로 3 이상).
- **튀김 발판** (태그 `TempuraRaft`, 고정 — 움직이지 않음): 층 높이(윗면) **7, 11, 15, 19, 23, 27, 31** (4 studs 간격, 점프로 오를 수 있음). 모양 3종: 새우튀김(12 × 5 길쭉), 고구마튀김(지름 8 원판), 깻잎튀김(10 × 8 판).
  | 층 윗면 | 발판 수 | 크기 |
  |---|---|---|
  | 7, 11, 15, 19 | 각 4~5개 | 섞어서 |
  | 23 | 2개 | 지름 7 고구마 (또는 같은 넓이) |
  | 27 | 2개 | 지름 6 |
  | 31 (꼭대기) | 1개 | 지름 5 |
- **경로 약속**: 바구니에서 꼭대기까지 **서로 다른 시작 발판으로 출발하는 길이 3개 이상**, 한 발판에서 다음 층 발판으로 수직 4 · 수평 틈(가장자리 사이) ≤ 5. 같은 층 안 발판끼리 틈 ≤ 6 (옆으로 옮겨 다닐 수 있게).

### 기름 (태그 `HotOil`, 판정은 숫자로)
- 기름 높이 `Logic.oilHeight(t)`: 0~6초는 y = 0, 그 뒤 **초당 0.4**로 올라 **22**에서 멈춤 (60초에 21.6).
  - 바구니(3)는 13.5초, 7층은 23.5초, 11층은 33.5초, 15층은 43.5초, 19층은 53.5초에 잠겨요. **23·27·31층은 60초까지 안전**.
- **탈락**: 발 높이(HumanoidRootPart Y − 3)가 기름 높이보다 낮으면 `ctx.eliminate`("튀겨짐"). 서버가 0.1초마다 확인. 냄비 바닥 밑(−15)으로 빠져도 탈락(안전망).
- 기름 표면 파츠(반투명 금색, 충돌 없음)는 `oilHeight`를 따라 올라가요 — 보여 주기만.
- 잠긴 발판은 그대로 두되(기름 아래로 보임) 위에 서 있으면 탈락이에요.

### 튀는 기름 (태그 `OilSplash`, 서버가 만듦)
| 시각 | 간격 |
|---|---|
| 0 ~ 10초 | 없음 |
| 10 ~ 30초 | 3초 |
| 30 ~ 45초 | 2초 |
| 45 ~ 60초 | 1.5초 |
- 매번 **기름 위에 서 있는 레이서 한 명**(무작위)의 발밑 발판 윗면에 반경 **5** 주황 원 경고 **1.2초** → 기름이 솟구치며 원 안 레이서를 원 중심에서 **바깥으로 수평 35 + 위로 25**, 넘어짐 1초, `MoveExempt.mark` 1.5초. 같은 사람 0.5초 쿨다운. 효과음 `OilSplash`, 기름 방울 파티클.
- 고른 사람이 경고 중에 움직여도 원은 그 자리(피할 수 있음).

### 끝
- Survival 공통 규칙 그대로: 남은 인원 ≤ 목표 인원이면 즉시 끝, **60초가 끝나면 버틴 사람 전원 통과**. 시간 제한 `Config.TimeLimit.Survival`.
- 탈락 연출은 Survival 낙하 = 손님 입(`Mouth`, 지금 규칙).

### 아트 (**[`docs/REFERENCE-map-art-direction.md`](../REFERENCE-map-art-direction.md) 필수**, 도구 m5-23 비주얼 키트 + 렌더러, 예산 **Extended: 장식 파츠 1500·파티클 16·조명 24(그림자 2)·움직임 80**, `Art.BUDGET = "Extended"`)
- 아트 작업은 m5-23이 `main`에 머지된 뒤 `git merge main`으로 받아서 한다(판정·로직은 먼저 해도 됨).
- 기본 요소(유지, 예산 숫자는 위 Extended로): 검은 무쇠 냄비(안쪽 반사), 금색 기름 표면(Glass, 투명도 0.3) + 보글보글 거품 파티클 2, 김 파티클 2, 튀김 발판은 노릇한 튀김옷 색 + 바삭한 돌기(장식, 충돌 없음), 냄비 위로 거대한 긴 젓가락(장식, 높이 50 이상, 충돌 없음), 냄비 밖 주방 배경. `IntroCamera` 4점(냄비 전체 → 꼭대기 발판 → 출발 바구니). (아래 디렉션이 우선)
- **아트 디렉션 — "밤의 주방, 불 위의 무쇠 튀김 냄비"**
  - 히어로 색: **튀김 금빛**(`PALETTE.TempuraGold`, 기름 표면 Glass + 튀김옷 `Plastic`/`Sand` 노릇한 3 shade). 60 = 검은 무쇠·어두운 주방 벽(청회색), 30 = 금빛 기름·튀김 발판, 10 = 뜨거운 주황-빨강(튀는 기름 경고·불꽃) + 차가운 파란 창빛.
  - 조명(`lighting` 프리셋): ClockTime 21 밤, 낮은 청색 Ambient(약 40,48,70), Atmosphere Density 0.35 따뜻한 연기빛 Haze 1.5, Bloom 0.6, ColorCorrection 대비 0.12. **빛의 주인공은 기름**: 기름 표면 파츠(올라가는 보여주기용)에 그림자 없는 주황 PointLight 2~3개를 붙여 기름이 차오를수록 빛도 올라온다. 그림자 조명: 레인지 후드 램프에서 냄비 안쪽을 비추는 좁은 SpotLight 1개(발판 그림자가 아래층에 떨어져 층이 읽히게). 냄비 밖 창문에서 들어오는 파란 SurfaceLight 1개(온도 대비).
  - 히어로 세트피스: ① 위에서 냄비로 들어오는 거대한 긴 조리 젓가락(높이 50+, 캡슐 모양) ② 냄비 아래 가스레인지 — 파란 Neon 불꽃 고리 + 무쇠 삼발이(냄비 테두리 너머로 보이게) ③ 레인지 후드 + 램프 ④ 냄비 옆 카운터 위 다 튀긴 튀김 탑이 놓인 기름종이 접시 + 튀김 망(아미) ⑤ 뒤쪽 타일 벽에 걸린 국자·뜰채·냄비 뚜껑 무리.
  - 층: FG = 냄비 테두리 립(두꺼운 무쇠 림, `ring`), 발판 옆면·아래쪽 바삭한 돌기(밟는 윗면은 깨끗하게 — 가이드 9절), MG = 젓가락·후드·튀김 접시, BG = **카운터 상판(냄비 바닥 아래, 낙하·안전망 −15보다 10 이상 아래)**, 타일 벽·창문(밤하늘·달), 선반 실루엣.
  - 파티클: 기름 거품 `OilBubbles` 2, 김 `Steam`/`SteamThick` 2, 가스 불꽃 위 `Embers`, 튀는 기름(게임플레이 기존).
  - 움직임(`anim`): 조리 젓가락 느린 Sway, 걸린 국자·뜰채 Sway, 기름 표면 반짝임 원판 Pulse, 창밖 달 옆 구름 Bob.
  - 발판 가독성: 층이 높을수록 튀김옷 색을 한 shade씩 밝게 해 "위가 안전"이 읽히게, 잠긴 발판은 기름 아래로 어둡게 보인다(기존 규칙).
  - `IntroCamera` 4~5점: 냄비 밖 카운터 높이에서 불꽃 + 냄비 넓은 샷 → 꼭대기 발판 → 꼭대기에서 바구니를 내려다보는 반전 샷 → 출발 바구니.

## 범위
- 포함: 위 규칙, 순수 로직 분리, 아트, IntroCamera, `inPool = false` 줄 삭제.
- 제외: 움직이는(떠다니는) 발판 — 캐릭터가 같이 안 움직이는 문제(m4-04 결정 기록), 기름에 빠졌다 다시 나오기, 새 소리 외 효과.

## 수용 기준
### 순수 로직 (lune 테스트, `tests/map-tempura-pot.spec.luau`)
- [ ] AC1: `MapTypes.validate` 통과(Survival), 스폰 24개가 바구니 위에서 서로 3 이상.
- [ ] AC2: `Logic.oilHeight`: 0·6초 → 0, 16초 → 4, 60초 → 21.6, 100초 → 22. 줄어들지 않는다(0~100초 0.1초 간격 단조 증가).
- [ ] AC3: `Logic.isFried(footY, oilY)`: 발 < 기름이면 true, 같거나 높으면 false.
- [ ] AC4: 경로: 발판 그래프(수직 ≤ 4.5 이고 수평 틈 ≤ 5면 위로 이어짐)에서 바구니 → 꼭대기(31) 경로가 있고, **시작 발판(7층)이 서로 다른 경로가 3개 이상**이다. 같은 층 안 발판끼리 틈 ≤ 6으로 모두 이어진다.
- [ ] AC5: 안전: 23·27·31층 윗면이 `oilHeight(60)`보다 1 이상 높다. 꼭대기 발판 가장자리에서 냄비 벽까지 수평 6 이상, 벽 높이 − 꼭대기 윗면 > 7.
- [ ] AC6: 넓이: 23·27·31층 윗면 넓이 합이 160 이하(기본 배치 약 153 = 2 × 지름 7 + 2 × 지름 6 + 지름 5, 약 8~10명 — 너무 넓으면 아무도 안 떨어짐, 결정 기록 D2).
- [ ] AC7: `Logic.splashInterval(t)`: 9.9 → nil, 10 → 3, 30 → 2, 45 → 1.5. `Logic.splashKnockback(dx, dz)`가 바깥 방향 수평 35·위 25, 반경 5 밖이면 nil.
- [ ] AC8: 장식 `MapKitLogic.validate` 통과, 600개 이하, `inPool` 없음 또는 true.
- [ ] AC9: 검증 5단계 통과 + 기존 `maps` 테스트 통과.

### Studio 확인 (`forceMapPlan = { "rotating-belt", "tempura-pot", "skewer-showdown" }`, **확인 뒤 nil**)
- [ ] AC10: 출발 6초 뒤부터 기름이 눈에 보이게 차오르고, 바구니에 계속 서 있으면 약 13초에 탈락(손님 입 연출)한다.
- [ ] AC11: 혼자 바구니에서 꼭대기(31층)까지 점프로 올라갈 수 있다(세 갈래 길 중 아무거나). 발판 위에서 미끄러져 저절로 떨어지지 않는다.
- [ ] AC12: 10초부터 내 발밑에 주황 원이 뜨고 1.2초 뒤 기름이 솟아 밀려 넘어진다. 원 밖으로 피하면 안 맞는다. 아래층으로 떨어져도 그 층이 아직 안 잠겼으면 계속할 수 있다.
- [ ] AC13: 60초까지 23층 이상에 있던 사람은 전원 통과한다. 4명 이상 판에서 목표 인원만 남으면 그 자리에서 끝난다.
- [ ] AC14: 냄비 벽·테두리·젓가락 장식에 올라가 버틸 수 없다. 이동 감시 로그가 튀는 기름 넉백 때문에 생기지 않는다.
- [ ] AC15: 재미 확인(사용자): 4~8명이 했을 때 60초 안에 목표 인원 근처까지 줄어드는지, 처음 하는 사람도 "위로 가야 한다"를 바로 아는지. 수치는 Layout 상수만 고친다.

### 아트 품질 (m5-23 렌더러, 2026-10-13 추가)
- [ ] AC16: 렌더 미리보기(`lune run tools/render-map tempura-pot --view all`) → 아트 가이드 11절 체크리스트 비평(글로) → 고침을 **3회 이상 반복**했고, 마지막 반복에서 체크리스트 18개가 전부 "예"다. 반복 기록은 `docs/developer/m5-05-*.md`, 전/후 PNG는 `docs/renders/tempura-pot/`에 있고 **최종 PNG 경로가 개발 메모에** 있다. 예산은 `MapKitLogic.checkBudget(Art.decor(), "Extended")` 테스트로 확인한다(AC8의 "600개 이하"는 Extended 1500으로 읽는다). 맵에 `lighting` 프리셋이 있고 `MapTypes.validate`를 통과한다.
- [ ] AC17 (Studio): 라운드가 시작되면 밤 주방 조명으로 바뀌고, 기름이 차오를 때 주황 빛도 같이 올라오며, 휴대폰 에뮬레이터에서 튀는 기름 경고 원과 층 구분이 보인다.

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- AC15 체감, `OilSplash` 소리 id(USER-TODO A2). (선택) `assets/map-art/tempura-pot.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 규칙 방향 · GDD 5.3 "튀김 기름 점프(튀는 기름 방울 피하기)"에 **차오르는 기름 + 위로 올라가기**를 더함. 지금 Survival 2개가 다 평평한 바닥이라 "올라가기"가 빈자리이고, 로블록스 아이들에게 차오르는 용암·물은 익숙한 장르. Survival 점수가 높이라 규칙과도 맞음. 근거: Fall Guys Slime Climb·Roll Off(차오르는 슬라임), Roblox The Floor Is LAVA!(방문 32억)·Flood Escape 2 — REFERENCE-m5-maps 1·2.2. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 꼭대기 넓이 · Survival은 시간이 끝나면 버틴 사람 전원 통과라서 안전 구역이 넓으면 탈락이 안 생김 → 안전한 세 층(23·27·31) 넓이 합 160 이하(약 8~10명), 튀는 기름이 계속 사람을 노려 자리싸움이 생기게. 잡기(GDD 6)도 자리싸움에 쓰임. **기본값, 플레이테스트 후 조정** · planner
- 2026-10-13 · D4 (developer, 해석 — 확인 부탁) AC4 "수직 ≤ 4.5"를 **높이 차 0~4.5(같은 층 옆으로 건너기 포함, 내려가기 제외)**로 읽어 경로 그래프를 만듦. 층마다 나선이 60° 돌아서 위층으로 바로 올라가는 자리는 각 층의 한쪽 끝에 있고, 나머지 발판에서는 옆 발판(틈 2.5)으로 건너가야 해요. 바로 11층으로 올라갈 수 있는 7층 발판은 3개(세 갈래, 테스트로 고정). 위·두 층 위 발판과는 위에서 볼 때 겹치지 않게(머리 닿음 방지) 했어요. · developer
  - → 2026-10-13 **확정: 지금 나선 배치 그대로** · 사용자
- 2026-10-13 · D5 (developer, 스펙 빈칸 채움) 튀는 기름 대상 = 마지막 0.1초 확인에서 발밑 레이캐스트(4.5)가 발판/바구니에 닿은 레이서 중 그 발판 윗면 > 기름인 사람. 원 안 판정은 수평 반경 5 + 발 높이가 그 윗면 −1 ~ +6. 0.5초 쿨다운은 "같은 사람이 다시 맞는 간격". 넉백은 PlatformStand 1초 + LinearVelocity 0.15초(SoySwampHazards 방식). 바구니도 태그 `TempuraRaft`(RaftKey "Basket")를 달아 같은 방식으로 찾음. · developer
  - → 2026-10-13 **확정: 해석 그대로** (바구니도 튀는 기름 대상 — 바구니에 머무르면 안 되는 게 의도) · 메인 세션 (사용자가 맵 판단 위임)
- 2026-10-08 · D3 기름 속도 · 0.4 studs/s(4초에 한 층), 6초 여유. 점프 한 번에 한 층(4)을 오르니 기름보다 빠르게 오를 수 있지만 꾸물거리면 잠김. 근거: 우리 점프 높이 약 6.4(점프력 50)·Survival 60초 — 계산값. **기본값, 플레이테스트 후 조정** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### PHASE A (게임플레이) — 2026-10-13, 브랜치 `m5-05-tempura`
- 상태: **in-dev 유지** — 게임플레이·판정·테스트는 끝, 아트(PHASE B, m5-23 새 비주얼 키트 위)가 남음.
- 바뀐 파일
  - `src/shared/maps/TempuraPotLayout.luau`(새): 냄비·바구니·발판 7층(17+5개) 나선 배치, 스폰 24(동심원 4·8·12).
  - `src/shared/maps/TempuraPotLogic.luau`(새): `oilHeight`, `isFried`, `splashInterval`, `splashKnockback`, `pickSplashTarget`, 발판 기하(`gap`·`isOnRaft`·`wallClearance`·`area`), 경로(`canClimb`·`climbGraph`·`pathFrom`·`startsReachingTop`·`tierConnected`).
  - `src/shared/maps/TempuraPotArt.luau`(새): 판정 파츠 기본 색, 장식 자리표시(거대한 젓가락 2), `introCamera` 4점.
  - `src/shared/maps/TempuraPot.luau`(덮어씀): 냄비 벽 32조각·바닥, 바구니·발판(태그 `TempuraRaft`), 기름 표면(태그 `HotOil`, Glass 0.3, 충돌 없음), 0.1초마다 기름 높이·튀김/낙하 탈락·서 있는 발판 기록, 10초부터 튀는 기름(태그 `OilSplash` 경고 원 1.2초 깜빡임 → 파티클 + `OilSplash` 소리 + 넉백). **`inPool = false` 삭제 → 랜덤 풀 합류.**
  - `tests/map-tempura-pot.spec.luau`(새, 24개): AC1~AC8 + 무대·발판 표·겹침·gap 기하.
  - 맵 개수 고정 테스트 갱신: `tests/maps.spec.luau`(풀 13), `tests/m4-foundation.spec.luau`(Survival 5), `tests/m5-03-foundation.spec.luau`(껍데기 목록에서 제거, infos 13), `tests/m4-12-hardening.spec.luau`(강제 플랜 9번째에 tempura-pot).
  - `docs/USER-TODO.md` A2에 `OilSplash` 소리.
- Studio 확인: `Config.DEBUG.forceMapPlan = { "rotating-belt", "tempura-pot", "skewer-showdown" }`(확인 뒤 nil) → 1라운드 통과 → 냄비. AC10(6초 뒤 기름 상승, 바구니에 계속 서 있으면 약 13.5초에 탈락), AC11(혼자 꼭대기까지 — 7층 오른쪽 끝 세 발판 중 하나에서 바깥 새우튀김으로, 층마다 옆으로 건너 나선을 따라), AC12(10초부터 발밑 주황 원 → 1.2초 뒤 넉백, 원 밖이면 안 맞음), AC13, AC14(벽·젓가락에 못 올라감, 이동 감시 `[MoveGuard]` 로그가 넉백 때 안 생김).
- 알려진 것: `src/shared/maps/init.luau`의 주석 "(inPool = false)"가 낡음 — 공용 파일이라 안 고침(다음 공용 파일 담당이 지우면 됨). 장식은 자리표시뿐(PHASE B).

### PHASE B (아트) — 2026-10-13, 브랜치 `m5-05-tempura` → **in-qa**
- 바뀐 파일: `src/shared/maps/TempuraPotArt.luau`(Extended 예산 장식 1479·`LIGHTING` 밤 21시 프리셋·`raftColor` 층별 밝기·`OIL_GLOWS`·IntroCamera 4점), `src/shared/maps/TempuraPot.luau`(아트 부착만: 기름 따라 올라가는 `OilFollowers` 폴더 — 짙은 기름 층·주황 PointLight 3·김 2, 기름 표면 거품 2, 벽 Reflectance, `lighting`), `tests/map-tempura-pot.spec.luau`(AC8·AC16), `tests/m5-23-qa.spec.luau`(조명·파티클 검사를 맵 예산 단계 기준으로), `tests/m5-03-qa.spec.luau`(껍데기 검사에서 tempura-pot 제외).
- 세트피스: 무쇠 림·귀 손잡이·튀김 온도계, 가스레인지(파란 불꽃 고리 Pulse, 삼발이, 옆 화구 2 — 김 나는 냄비·불티), 긴 조리 젓가락(Sway), 레인지 후드 + 램프 3(가운데 그림자 Spot), 오른쪽 카운터 튀김 접시·튀김 망·반죽 그릇, 왼쪽 카운터 통·도마·기댄 뚜껑, 창문(밤하늘·달·구름 Bob·파란 SurfaceLight), 찬장 + 걸이 레일(국자·뜰채·집게·팬 Sway), 냉장고·선반, 노렌 출입구, 펜던트 등 2, 나무 바닥(−108). 발판: 튀김옷 돌기·새우 꼬리·고구마 껍질·깻잎(전부 윗면보다 낮음, 충돌 없음).
- **최종 PNG**: `docs/renders/tempura-pot/after-overview.png`, `after-eye.png`, `after-intro-01.png`, `after-intro-02.png`, `after-intro-04.png`, `after-top.png`, `after-mobile.png` (+ `after-stats.txt`, 전: `before-*.png`). 반복 4회 비평: `docs/developer/m5-05-map-tempura-pot.md`.
- 예산 (렌더러 통계): decor 1479/1500, lights 14/24 (shadowed 1/2), particles 6/16, anim 53/80, void 0% (모든 뷰).
- Studio 확인 AC17: `forceMapPlan = { "rotating-belt", "tempura-pot", "skewer-showdown" }` → 소개가 시작되면 밤 주방 조명(어두운 청색 + 주황 기름빛)으로 바뀌는지, 기름이 오를 때 주황 빛과 김이 같이 올라오는지, 휴대폰 에뮬레이터에서 경고 원과 층 구분이 보이는지. 너무 어두우면 `Art.LIGHTING`의 Brightness·ExposureCompensation만 올린다.
