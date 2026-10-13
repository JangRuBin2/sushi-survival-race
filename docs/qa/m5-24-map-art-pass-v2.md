# QA — m5-24 기존 맵 12개 아트 패스 v2

- 스펙: `docs/specs/m5-24-map-art-pass-v2.md`
- 검증 브랜치·커밋: `m5-24-merge` @ `e70d6cb` (= `origin/main` 481eea0 + 그룹 A→B→C→D `--no-ff` 병합 + 병합 메모)
- 결과: **통과 (P0/P1 없음)** → 스펙 `qa-passed`. P2 2건·P3 2건과 planner 질문 1건은 아래에 적었어요. Studio 확인(AC12~15)은 사용자 차례예요.

## 자동 검증 (병합 결과 + QA 테스트 추가 뒤, 이 세션에서 직접 돌림)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests tools` | OK (끝 코드 0) |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests` | **1823 passed, 0 failed** (병합 상태 1815 + QA 새 테스트 8) |
| `luau-lsp analyze … --flag:LuauSolverV2=true src` | 끝 코드 0 |
| `lune run tools/render-map all --view mobile --quality fast` | 15맵 모두 렌더됨. 12맵은 Extended 예산 안이고 mobile void 0% |
| `lune run tools/render-map <12맵> --view all --quality fast --size 480x270` | void 최대: tug overview 6%, bouncy intro-03 5%. 나머지 0~4% (AC10 ≤ 10%) |

## 판정 불변 확인 방법 (AC1, 최우선)
`main`(481eea0)과 `m5-24-merge`의 `src`를 각각 따로 풀고, 렌더러 가짜 환경(`tools/render/Shims`)에서 12맵을 같은 origin에 실제로 `build`했어요. 그다음 **Decor·IntroCamera 밖의 모든 파츠**를 한 줄씩 덤프해 비교했어요(경로·클래스·크기·CFrame 12성분·CanCollide/CanTouch/CanQuery·Anchored·투명도·태그·속성). 결과는 다음과 같아요.
- **10맵은 바이트까지 같았어요**: rotating-belt, hot-plate, skewer-showdown, soy-swamp, ramen-rapids, giant-jenga, claw-machine-prize, bouncy-castle-maze, lantern-bridge, cat-cafe-shelves.
- **chef-board**: 지워진 줄은 0줄이고, 칸(Cell) 하위에 `EdgeTrim` 36개가 더해졌어요. 모두 `cc=false ct=false cq=false`이고 태그·속성이 없어요. 칸 장식(`Art.cellDecor`)이라 칸과 같이 기울고 떨어지는 것도 의도대로예요.
- **tug-of-war-platform**: `PlatformGroup/Weights`(발판과 같이 기우는 장식 폴더) 아래 장식만 6개 바뀌고 82개 더해졌어요(PanRimLip 원판 → 고리, ScalePan·사슬·DeckTrim·RopeKnot 등). 모두 `cc/ct/cq=false`예요. `Platform` 파츠와 태그는 그대로예요.
- 판정 파츠(충돌·터치·쿼리 중 하나라도 켜졌거나 Spawns)의 지문(개수·크기 합·위치 합·충돌 수·태그 수)도 main과 12맵 모두 정확히 같아요. 이 비교를 `tests/m5-24-qa.spec.luau`에 고정했어요.
- 메인 모듈 diff도 확인했어요. `lighting = Art.LIGHTING` 한 줄, `MapLighting` require 삭제, hot-plate 후드 PointLight 코드 → `HotPlateArt` DecorSpec Spot, rotating-belt `GUEST_EYE`에 EyeBlink 태그, tug `p.CastShadow = false` 삭제뿐이에요. 모두 장식 부착 코드이고 `start`/`overtime`/`cleanup`·Layout·Logic 파일은 하나도 바뀌지 않았어요(`git diff origin/main -- src`는 맵·Art 24개 파일뿐).
  - **tug `CastShadow = false` 삭제**: `buildStaticArt`의 Decor 폴더 장식에만 해당해요(`MapKit.buildDecor(Art.decor(), flatPivot, decorFolder)` 반복문 안). 그림자 계산만 달라지고 판정과는 무관해요.
  - **lantern 도리이 기둥 수정**: `LanternBridgeArt` 장식 스펙만 바뀌었고, 판정 지문은 같아요. 기본 카메라→머리 선이 도리이 기둥을 지나던 스폰이 9곳에서 0곳으로 줄었어요(개선).
  - **결승 3맵의 연장전 훅**(`SkewerShowdown`·`TugOfWarPlatform`·`ClawMachinePrize`의 `overtime`): diff 0줄이에요. 기존 연장전 테스트(m5-01·m5-18·m5-19 QA)도 수정 없이 통과해요.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 판정 불변 | 통과 | 위 덤프 비교, `m5-24-qa` "판정 지문", 기존 판정·스폰·시간·태그·로직·카메라 경로 테스트가 수정 없이 통과. 바뀐 단언은 D2 범위뿐(아래 "테스트 약화 검토") |
| AC2 Extended 예산 | 통과 | 그룹 테스트 4개(`m5-24-group-a/b/d`, `m5-24-c`) + 렌더 stats: decor 411~1468/1500, lights 3~23/24, shadowed 맵당 1, particles 3~13/16, anim 5~73/80 |
| AC3 courseVolume·validate | 통과 | 그룹 테스트 + `map-*` 기존 테스트. 실제 build 결과에서 Decor 파츠 12맵 전부 `CanCollide/CanTouch/CanQuery = false` (`m5-24-qa` AC13) |
| AC4 lighting | 통과 | `m5-23-qa`(Art.LIGHTING이 있으면 정확히 그 표인지) + 그룹 AC4 테스트(validate, 로비와 다름) |
| AC5 움직이는 판정과 같이 움직이는 장식에 anim 없음 | 통과 | 실제 build에서 Anim·Wobble·EyeBlink 태그 파츠가 전부 맨 위 `Decor/` 하위이고 꼬치 `*Food` 폴더에는 없음. 인형뽑기 Decor는 Pulse만(연장전에 모델 전체가 기울어서) — `m5-24-qa` 고정 |
| AC6 검증 5단계 | 통과 | 위 표 |
| AC7 before PNG | 통과 | 12맵 모두 `before-overview/eye/intro-01` 있음 |
| AC8 반복 3회·체크리스트 18 | 통과 (문서 확인) | `docs/developer/m5-24-group-{a,b,c,d}.md` 반복별 비평. 렌더 비평 내용 자체는 QA가 다시 하지 않음 |
| AC9 after PNG | 통과 | 12맵 모두 `after-*` 있음, 몇 장을 직접 봄(아래) |
| AC10 void ≤ 10% | 통과 | 위 표 (최대 6%) |
| AC11 휴대폰 메모·큰 반투명 판 추가 없음 | 통과 | 큰 반투명 장식 판(두 변 ≥ 40) 수가 main 이하: soy 4→4, chef 4→4, ramen 3→0(크기 축소, 아래 B4), claw 1→1. `m5-24-qa` 고정 |
| AC12 조명 전환 | 사용자 확인 필요 | Studio 체크리스트 |
| AC13 플레이 감각 | 자동 부분 통과 / 사용자 확인 필요 | 판정 바이트 동일 + 장식 충돌 없음. 체감은 Studio |
| AC14 소개 카메라 | **부분 실패 (P2 B1)** + 사용자 확인 필요 | 실제 IntroCamera 경로 vs 불투명 파츠: giant-jenga가 판정 블록을 뚫음 |
| AC15 휴대폰 | 사용자 확인 필요 | tris 최대 127k(bouncy), 그림자 조명 맵당 1 |

자동으로 볼 수 있는 기준 11개(AC1~AC11) 통과, AC14 자동 부분에서 P2 1건. AC12~15는 사용자 확인이 필요해요.

## 버그 (심각도순)

### [P2] B1 giant-jenga 소개 카메라가 블록탑 앞줄을 뚫고 지나가요 (m5-24에서 새로 생김)
- 재현: `lune run tests` → `m5-24-qa` "QA AC14"가 `KNOWN_INTRO_BUG`로 이 상태를 고정해요. 또는 `IntroCameraLogic.sample`로 실제 `IntroCamera` 점 4개를 따라가면 t ≈ 0.57~0.69에서 `Column_-1_2/Blocks/Block3`, `Column_0_2/Block2·3`, `Column_1_2/Block1·2`, `Column_2_2/Block1`, `Column_2_2` 윗면 안을 지나요.
- 기대: 소개 카메라가 물체를 뚫지 않아요(AC14, 가이드 체크리스트).
- 실제: 새 경유점 ②`(-62, -30, 30)`(탑 아래 작업대 높이)에서 ③`(edge+14, 6, edge*0.6)`로 가는 직선이 탑의 +Z 앞줄(j = 2) 블록 속을 대각선으로 지나가요. 소개 장면 중 약 0.5초 동안 화면이 나무 블록 안쪽으로 가득 차요. main은 `(0,55,0)` → ③라 문제가 없었어요. `m5-24-c` AC14 테스트는 **장식 상자만** 검사해서 판정 블록을 놓쳤어요.
- 위치: `src/shared/maps/GiantJengaArt.luau:1240-1243` (`Art.introCamera`).
- 제안(개발): ②를 탑 바깥 옆으로 옮기거나(예: x -62 → z를 탑 +Z 앞줄 바깥 `edge + 10` 이상으로), ②와 ③ 사이에 탑을 돌아가는 점을 하나 더 넣어요. 고친 뒤 `m5-24-qa`의 `KNOWN_INTRO_BUG`에서 `giant-jenga`를 지워요(테스트가 알려 줘요). Art 파일만 고치면 돼요.

### [P2] B2 claw-machine-prize 연장전에 오락실 전체(장식 554개)가 상자와 같이 35° 기울어요
- 재현: 결승 연장전(`Config.DEBUG.overtimeAt`으로 앞당김) → `ClawMachinePrize.overtime`이 `ctx.model:PivotTo(...)`로 모델 전체를 격자 중심 기준으로 최대 35° 돌려요(`src/shared/maps/ClawMachinePrize.luau:571`, 판정 코드라 이번 패스에서 바뀌지 않음).
- 기대: 상자(기계)가 기울고 세계(오락실 바닥·벽·옆 오락기)는 그대로 있어서 "기계가 넘어간다"로 읽혀야 해요.
- 실제: m5-24에서 기계 밖 오락실(카펫 239×259 두 장, 높이 170 오락기, 벽 판자 522 길이, 네온 줄 등)을 전부 `Decor` 폴더(=같은 Model)에 넣어서 방 전체가 같이 돌아요. 가짜 환경에서 35°로 돌려 보면 낙하선(-25)보다 한참 아래(-150)에 있던 카펫 한쪽 끝이 origin 위 +14~+26까지 올라오고, 오락기 윗면은 +100 이상이 돼요. 충돌은 없어서 판정·낙하에는 영향이 없어요. 다만 ① 세계가 배처럼 기우는 연출이 되고 ② 연장전 동안 매 Heartbeat `PivotTo`가 옮기는 모델 인스턴스가 대략 370 → 900개로 늘어요(가짜 환경 덤프 기준 근사, 서버·복제 비용). 그룹 C는 이것을 알고 Decor에 Pulse만 썼어요(`ClawMachinePrizeArt.luau:18-20`). 연출이 맞는지는 판단하지 않았어요.
- 위치: `src/shared/maps/ClawMachinePrizeArt.luau`(오락실 BG 장식), `ClawMachinePrize.luau:145`(전부 `MapKit.decorFolder(model)`에 부착).
- 제안: planner 결정이 필요해요. (a) 의도한 연출로 받아들이거나, (b) build의 아트 부착 코드에서 방 장식만 기울지 않는 별도 Model(예: `model` 밖, 같은 cleanup)에 붙여요. (b)는 아레나 상자 측정·정리와 엮여서 키트(m5-23) 쪽 결정이 필요해요. Studio 체크리스트 5-c에서 사용자가 보고 정해요.

### [P3] B3 bouncy-castle-maze 렌더러 eye/mobile 뷰가 공기 기둥으로 꽉 차요 (렌더러 한계, Studio 확인)
- 실제: `after-eye.png`·`after-mobile.png`가 빨강·노랑 `AirTube`만 보여요. 렌더러 eye 카메라는 1번 스폰 뒤 12(z +9.5)라 불투명 출발 벽(`StartWall`, z 0~0.5) 바깥, 새 공기 기둥 줄(z ≈ +2) 속에 있어요. main에서도 같은 카메라가 분홍 출발 벽만 봤어요(before-eye).
- 판단: 실제 Roblox 카메라는 쿼리되는 판정 벽 앞으로 당겨지고(장식은 CanQuery=false라 무시), 기둥은 벽 뒤라 보이지 않아요. 그래서 버그가 아니라 렌더러 한계로 봐요(그룹 D 인계 메모와 같은 결론). 다만 렌더러로는 이 맵의 플레이어 시점 가독성을 확인할 수 없어서 Studio 체크리스트에 넣었어요.
- 참고: 기본 카메라→머리 선이 출발 벽을 지나는 스폰은 main과 같은 18곳(벽 앞으로 당겨짐), 공기 기둥을 지나는 스폰 18곳은 새로 생겼어요(카메라가 벽 앞으로 오면 기둥은 뒤라 안 보여요).

### [P3] B4 ramen-rapids m5-20 안개 패널을 국물 아래로 내렸어요 — 스펙 결정 기록에 없음
- 실제: `RamenRapidsArt.addFogPanels`가 높이 200 → 6, y 40 → `BROTH_Y - 5`로 바뀌어 국물 수면 아래 얇은 띠가 됐어요(개수 3·Glass·투명도 0.88·색은 m5-20 테스트대로 유지). 그룹 C 인계 메모에는 "m5-20 QA B2·B5 해결"로 적혀 있지만, 스펙 결정 기록에는 그룹 B의 D5(soy ±680, chef ±312로 방 밖 이동)만 있어요.
- 판단: D3("지우지 않고, 새로 추가하지 않고, 분위기는 lighting")의 글자는 지켰어요. 하지만 soy·chef·ramen 세 맵 모두 안개 패널이 사실상 보이지 않는 자리로 옮겨져 "되돌리지 않는다"(m5-20)의 뜻과 어긋날 수 있어요. 큰 반투명 판이 늘지 않았으니 성능·가독성 위험은 없어요.
- 제안(planner 질문 Q1): D5를 "세 맵 모두 m5-20 안개 패널은 이름·개수·재질만 유지하고 보이지 않는 자리로 옮겨도 된다(분위기는 Art.LIGHTING)"로 넓혀 확정할지, 아니면 m5-20 안개 패널을 실제로 지우는 후속 스펙을 만들지 정해요. 스펙 결정 기록에 ramen 항목을 더해요.

### 참고 (버그 아님)
- hot-plate eye/mobile 왼쪽 1/3을 가리는 큰 어두운 판은 `before-eye.png`에도 있었어요(m5-24 회귀 아님). Studio 기본 카메라로 한 번 확인해요(체크리스트 2-b).
- 여유가 작은 맵: lantern-bridge 조명 23/24·anim 73/80, bouncy decor 1468/1500. 다음 아트 추가 때 넘을 수 있어요(병합 메모와 같음).
- 판정 바닥 높이 근처(스폰 y -4 ~ +3)의 넓은 불투명 장식 중 판정 바닥이 받치지 않는 것: rotating-belt `Counter`·`CounterApron`(벽 바로 바깥 카운터, 유리 벽 높이 6이라 못 넘어감, main에도 Counter 있음), `NetaCaseBase`(+13), soy `WasabiRidge`(벽 높이 48 바깥 +11), ramen `StartPier`(main에도 있음), 나머지는 80 이상 떨어져 있어요. 모두 충돌이 없고 판정 벽 바깥이라 "바닥으로 착각해 떨어지는 자리"(AC13)는 Studio에서 rotating-belt 카운터 쪽만 한 번 보면 돼요(체크리스트 1-c).

## 테스트 약화 검토 (D2)
`git diff origin/main HEAD -- tests`에서 지워진 `t.ok`/`t.eq` 줄 18개를 하나씩 봤어요.
- 예산 단언 13개(`m4-05-qa` AC6, `m5-20-qa` ramen, `map-art-arena` AC1 ×2, `map-art-race` AC1, `map-bouncy-castle-maze` AC7, `map-cat-cafe-shelves` AC10, `map-chef-board` AC6, `map-claw-machine-prize`, `map-giant-jenga` AC8, `map-lantern-bridge` AC10, `map-ramen-rapids` 318·371): `count <= 600` → `checkBudget(..., "Extended"/Art.BUDGET) == nil`(+ 필요한 곳은 코드 조명·파티클·칸 장식 extra)로 바뀌었어요. 파츠 상한만 1500으로 올랐고 조명·그림자·파티클·anim 상한 검사가 **새로 더해졌어요**(더 엄격한 부분 포함). D2 (a) 범위예요. `map-giant-jenga`의 `{ lights = 3 }` extra는 실제 코드 조명(LampBulb 1개)보다 보수적이에요.
- 조명 단언 3개(`m5-23-qa` "기존 6개는 프리셋", `m5-23-visual-kit` AC7): `== PRESETS[id]` → Art.LIGHTING이 있으면 `== Art.LIGHTING`(정확히 같은 표), 없으면 프리셋. D4가 요구한 변경이고 느슨해지지 않았어요(병합 때 B·C의 약한 버전은 버리고 A의 엄격한 버전을 택함).
- 렌더러 수 단언 2개(`m5-23-qa` rotating-belt `{3,2}`, soy-swamp `{2,3}`): 고정값 → `countLights/countParticles(Art.decor()) + 코드 수`. "렌더러 통계 = 실제 인스턴스 수"라는 뜻은 그대로예요.
- 이름으로 센 기존 장식 개수(Lantern·HillRice·LampBulb·FogPanel·Kombu 20·SesameSeed 등), 소개 카메라 마지막 점 조건, 카메라 경로 충돌(m4-02-qa·m4-12-hardening·m5-20-qa 안개 패널) 단언은 **한 줄도 바뀌지 않았어요**. 판정·스폰·시간·태그·로직 테스트 파일은 diff가 없어요.
- 결론: D2 밖의 약화 없음.

## 렌더 확인 (근사 렌더러 — 최종 판단은 Studio)
- 커밋된 after: rotating-belt overview(저녁 회전초밥집, 손님·창밖 거리), hot-plate overview·eye(밤 철판구이 방), skewer overview(축제 노점 원형 광장), soy overview(거대 간장 접시·와사비 산), tug overview(가게 마당·감나무·장독대), claw overview(네온 오락실), lantern overview(밤 계곡 마을), cat overview(분홍 카페), jenga intro-02, bouncy eye·top을 직접 봤어요. 모두 "작은 초밥, 거대한 주방·가게" 세계가 보이고 빈 공중이 거의 없어요.
- 새로 렌더한 mobile 15맵(`build/renders/*/mobile.png`, 커밋 안 함): 경고 색 칸(hot-plate 주황 칸, chef 노란 경고 줄), 결승·벨트(rotating-belt), 꼬치 무대·꼬치(skewer), 발판·저울 접시(tug), 인형 더미(claw), 다리·등불(lantern), 선반(cat)이 작은 화면에서도 보여요. soy·ramen은 반투명 판정 벽(0.6) 너머가 뿌옇고(main도 같음), bouncy는 B3대로 렌더러로 판단 못 해요.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 이 스펙은 리모트를 추가·변경하지 않음(공용 파일 diff 없음)
- [x] 통과·탈락·순위 판정이 서버에만 — 판정 코드 diff 없음
- [x] 맵 상태가 `ctx`에 — `start`/`overtime` diff 없음
- [x] 정리(Cleanup) — 새 연결·스레드 없음. 장식은 Model 하위라 Model과 같이 사라짐. hot-plate는 `Instance.new("PointLight")` 코드를 빼고 DecorSpec으로 옮김

## 사용자 Studio 확인 체크리스트 (AC12~15, 12맵 통합)
준비: `src/shared/Config.luau`의 `DEBUG`에서 아래 플랜을 하나씩 넣고 `rojo serve` → Studio Play(혼자, `minPlayersToStart = 1`). 마지막 라운드는 항상 Final이어야 해요. **확인이 끝나면 `forceMapPlan = nil`, `forceMapPlans = nil`, `overtimeAt = nil`로 되돌려요(테스트가 커밋 값을 고정해요).**
- 한 번에 돌리기(혼자 = 3라운드라 플랜은 맵 3개씩): `forceMapPlans = { { "rotating-belt", "hot-plate", "skewer-showdown" }, { "soy-swamp", "chef-board", "tug-of-war-platform" }, { "ramen-rapids", "giant-jenga", "claw-machine-prize" }, { "bouncy-castle-maze", "cat-cafe-shelves", "skewer-showdown" }, { "lantern-bridge", "giant-jenga", "tug-of-war-platform" } }` → 매치마다 다음 플랜이에요(5판).
- 혼자일 때 Race 라운드는 결승선을 넘으면 통과예요. 결승은 혼자면 바로 끝나서, 결승 맵의 맵 모습·소개만 볼 수 있어요(연장전은 아래 5).

1. **조명 (AC12)** — 라운드가 바뀔 때마다 1~2초 안에 그 맵 분위기로 부드럽게 바뀌는지, 로비로 돌아오면 로비 조명으로 돌아오는지.
   - a. 회전 벨트 = 해 질 녘 호박색, 철판 = 밤 청색 + 주황 열기, 꼬치 = 자주-주황 노을, 간장 늪 = 흐린 갈색-올리브, 도마 = 아침 청회색, 줄다리기 = 노을 주황, 라멘 = 한낮 금빛, 젠가 = 저녁 작업등, 인형뽑기 = 한밤 보라 네온, 방방 = 맑은 한낮, 등불 다리 = 여름밤 남색, 고양이 카페 = 오후 햇살.
2. **소개 카메라 (AC14)** — 라운드 소개 동안 카메라가 벽·블록·장식을 뚫는 순간이 있는지, 빈 하늘·로비 바닥이 보이는지.
   - a. **젠가(B1)**: 두 번째 컷(탑 아래 작업대 높이)에서 세 번째 컷으로 갈 때 화면이 나무 블록 안으로 잠깐 차는지. 차면 B1 확인.
   - b. **철판**: 플레이어 기본 카메라 왼쪽에 큰 어두운 판이 화면을 가리는지(렌더러 before/after 둘 다 가림 — 실제 카메라가 당겨지면 괜찮을 수 있음).
   - c. 등불 다리: 입구 도리이가 이제 서 있는 기둥으로 보이는지(D 수정).
3. **플레이 감각 (AC13)** — 전과 같은지만 봐요(판정은 바이트 단위로 같아요).
   - a. 회전 벨트: 젓가락·벨트 속도, 결승 통과. 벽 바로 바깥 카운터(c)를 바닥으로 착각해 뛰어내리고 싶어지지 않는지.
   - b. 철판: 밟은 칸이 사라지는 박자, 층 낙하. 간장 늪: 와사비 튕김, 간장 웅덩이. 라멘: 급류·차슈·나루토. 방방: 튕김 높이, 칸막이 못 넘음.
   - c. 도마: 칼 줄 경고·내려치기, 잘린 칸이 떨어질 때 가장자리 트림(EdgeTrim)이 칸과 같이 떨어지는지.
   - d. 젠가: 블록이 빠지고 칸이 기울 때 장식(손·작업대)이 같이 움직이지 않는지, 떨어지면 작업대에 닿기 전에 탈락하는지.
   - e. 고양이 카페: 고양이 발·장난감 공, 선반 가장자리.
   - f. 장식(풍선·바위·카운터·화분 등)에 몸이 부딪히거나 올라설 수 있는 곳이 없는지 — 모두 통과돼야 해요.
4. **휴대폰 (AC15)** — Studio 기기 에뮬레이터(작은 휴대폰)로 3·4번을 다시 봐요.
   - a. 경고 색(철판 칸, 도마 칼 줄, 인형뽑기 집게 목표 칸, 꼬치), 구멍, 결승선이 작은 화면에서 보이는지.
   - b. **방방 미로(B3)**: 출발 때 플레이어 시점에서 앞이 보이는지(렌더러로는 확인 못 함).
   - c. 가능하면 실제 휴대폰(비공개 테스트)에서 bouncy(tris 127k)·rotating-belt(104k)·lantern(112k, 조명 23)이 전보다 눈에 띄게 끊기지 않는지.
5. **결승 3맵 연장전** — `Config.DEBUG.overtimeAt = 5`(Studio 전용), 2인 테스트(Studio "Test → Clients and Servers" 2명)로 결승까지 가요.
   - a. 꼬치: 연장전에 무대가 바깥 줄부터 사라지고, 노점·등롱 장식이 서 있을 자리를 주지 않는지.
   - b. 줄다리기: 발판이 기울 때 저울 접시·트림·밧줄 장식이 발판과 같이 기울고(어긋나지 않고), 연장전 끝에 발판과 함께 사라져 설 곳이 없는지.
   - c. **인형뽑기(B2)**: 상자가 기울 때 오락실 바닥·벽·옆 오락기까지 같이 기우는 모습이 괜찮은지, 기울 때 끊김이 있는지. 결과를 알려 주면 planner가 B2 방향을 정해요.
   - 확인 뒤 `overtimeAt = nil`.

## 추가한 테스트
- `tests/m5-24-qa.spec.luau` (8개, 렌더러 가짜 환경에서 12맵을 실제로 지어서 확인)
  - 판정 지문(개수·크기 합·origin 기준 위치 합·충돌 수·태그 수)이 main(481eea0) 값과 같음
  - 판정 Model 하위 새 장식(도마 칸 `EdgeTrim`, 줄다리기 `Weights`)이 충돌·터치·쿼리 꺼짐
  - Decor 폴더 모든 파츠 충돌·터치·쿼리 꺼짐(12맵)
  - Anim·Wobble·EyeBlink 파츠는 전부 `Decor/` 하위, 꼬치 `*Food`에는 없음
  - 인형뽑기 Decor anim은 Pulse만
  - 실제 인스턴스 조명 범위(Surface ≤ 16, Point·Spot ≤ 60), 그림자 조명 1~2이고 고정된 Decor 파츠에만
  - 큰 반투명 장식 판 수가 main 이하
  - 실제 IntroCamera 경로가 불투명 파츠(판정 포함)를 지나지 않음 — 알려진 예외: soy·ramen 반투명 StartWall(main과 같음), **giant-jenga B1**(`KNOWN_INTRO_BUG`, 고치면 지우라고 테스트가 알려 줌)

## 인계 메모
- **브랜치**: `m5-24-merge` (main에는 push 안 함). 이 QA 커밋 = 리포트 + `tests/m5-24-qa.spec.luau` + 스펙 `status: qa-passed`.
- **끝난 것**: 12맵 AC1~AC11 자동 확인, 판정 덤프 비교(main 대비), 테스트 약화 검토, mobile·all 뷰 렌더 확인, 검증 5단계(1823 passed, 0 failed).
- **남은 것**:
  1. 개발: B1(젠가 소개 경유점 ② 이동, `GiantJengaArt.luau`만) → `KNOWN_INTRO_BUG` 항목 삭제.
  2. planner: Q1(B4·D5 안개 패널 처리 확정, 스펙 결정 기록에 ramen 추가), B2(인형뽑기 연장전에 방 전체가 기우는 것 받아들일지).
  3. 사용자: 위 Studio 체크리스트(AC12~15).
  4. 메인 세션: `m5-24-merge` → `main` 병합 뒤 검증 5단계를 다시 돌려요(m4-09 B1 교훈). `CLAUDE.md` "현재 상태"의 m5-24 줄을 갱신해요(QA는 안 고침).
- **다음 첫 단계**: `m5-24-merge`를 main에 병합할지 메인 세션이 정해요. B1·B2·B4는 병합을 막지 않아요(P2/P3).
- **막힌 점**: 없음. 렌더러는 근사라 bouncy 플레이어 시점·인형뽑기 연장전 모습은 Studio에서만 판단돼요.
