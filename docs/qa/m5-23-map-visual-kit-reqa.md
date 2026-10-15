# QA (재QA) — m5-23 맵 비주얼 키트 + 미리보기 렌더러

- 스펙: `docs/specs/m5-23-map-visual-kit.md`
- 이전 리포트: `docs/qa/m5-23-map-visual-kit.md` (B1 P1로 반려, B2 P2, B3~B6 P3)
- 검증 커밋: main `8750ee6` (맵 21개 — m5-24 아트 패스, m5-33~39 새 맵 6개, m5-40 L1·L2 포함), 브랜치 `m5-23-reqa`
- 결과: **통과** — B1~B6 모두 고쳐졌고 회귀 테스트가 있다. 새 P0/P1/P2 없음. 스펙 `qa-passed`. Studio 확인(AC14~AC18)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 (끝 코드 0) |
| `stylua --check src tests tools` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **2288 passed, 0 failed** (재QA 추가 `m5-23-reqa.spec.luau` 6개 포함. 추가 전 2282/0) |
| `luau-lsp analyze …` (타입 검사) | 통과 (끝 코드 0, 경고는 LSP 클라이언트 감시 등록 안내뿐) |
| `lune run tools/render-map all --view all --quality fast` | **21개 맵 전부 성공**, 끝 코드 0, PNG 177장 + stats.txt 21개, 3분 53초. 맵 하나 7~19초 |
| 같은 명령 2회(`--out build/renders2`) | **177장 PNG의 md5가 모두 같음**(결정적) |
| `render-map hot-plate --view overview --studio-art` | 통과. 단 `assets/map-art/`에 `.rbxm`이 아직 하나도 없어(README만) 실제 파일을 붙이는 경로는 못 돌림 |

## 이전 버그 재확인
| 버그 | 상태 | 고친 곳 | 회귀 테스트 |
|---|---|---|---|
| B1 [P1] Surface range 상한 16 | 고쳐짐 | `MapKitLogic.luau:82-83`(`LIGHT_MAX_RANGE` 60·`SURFACE_LIGHT_MAX_RANGE` 16), `:276-277` 종류별 검사, `tools/render/Scene.luau:586-592` 렌더러 자르기 | `m5-23-visual-kit` "QA B1"(16 통과·16.01 거절·Point/Spot 60). 재QA 추가: 풀 전체 DecorSpec Surface ≤ 16, `Scene.addModel`이 Range 40인 SurfaceLight를 16으로 자름, 올바른 목록 + Surface 17 하나 → 장식 0개 |
| B2 [P2] 소개 첫 컷 로비 조명 | 고쳐짐 | `MapLightingController.luau:100-133` `measure`가 IntroCamera 파츠를 크기 0 점으로 넣음 | `m5-23-qa` "QA arenas: 스폰 24개·eye·소개 경유점" — `KNOWN_INTRO_OUTSIDE = {}`, `Maps.allInfos()`를 돌므로 **21개 맵 소개 점 전부** 아레나 안 |
| B3 [P3] 효과 중복 | 고쳐짐 | `MapLightingController.luau:38-56`(`localCreated`), `:188-198` `Lighting.ChildAdded`에서 같은 클래스가 오면 자기 것 Destroy 후 다시 apply | 재QA 추가 "reQA B3 소스" (소스 확인 — 실제 복제 순서는 Studio만) |
| B4 [P3] `AnimSpec.amount` 필수 | 고쳐짐 | `MapDecorAnimLogic.luau:14` `amount: number?` | `m5-23-visual-kit` "QA B4", 재QA `buildDecor`에 amount 없는 Spin 포함 |
| B5 [P3] 가짜 RunService 이벤트 | 고쳐짐 | `tools/render/Shims.luau:170-175` Heartbeat 등 5개, `:198-210` 없는 멤버는 `[render] RunService.X is not available …` | `m5-23-visual-kit` "렌더러 shim: 가짜 RunService 이벤트는 연결만, 없는 멤버는 이름을 찍고 실패" |
| B6 [P3] 작은 것들 | 고쳐짐 | `MapKitShapes.luau:145-147` radius ≤ 0 → 상자 하나, `MapKitLogic.luau:359-375` extra `shadowedLights`, `MapLighting.luau:74-76` 로비 기본값 = 플레이스 값 | `m5-23-visual-kit` "QA B6". CornerWedge 방향은 여전히 Studio 확인(체크리스트 5) |
| (개발 추가) Lune `CFrame.lookAt` 우회 | 확인 | `Shims.luau:215-231` | `m5-23-visual-kit` lookAt 5방향 + introCamera. 21개 맵 intro PNG를 몇 장 직접 봄(onsen-claw intro-01 — 중앙 무대를 정면으로, space-conveyor eye — 코스 앞) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | 기존 테스트 전부 통과(2288/0). 재QA "reQA pool: 모든 맵 Art.decor()가 validate 통과" — **21개 맵 모두** Art 모듈이 있고 validate nil. 상수 600·8·12는 `m5-23-visual-kit` AC1 |
| AC2 | 통과 | `m5-23-visual-kit` AC2·B1, `m5-23-qa` "QA extras" 2개. 재QA로 잘못된 shape·particle·anim.period·Surface range를 **올바른 목록 끝에 하나만** 넣어도 거절 |
| AC3 | 통과 | `m5-23-visual-kit` AC3, `m5-23-qa` budget 3개. 재QA: 렌더러 환경에서 지은 21개 맵의 **실제 인스턴스 수**(Decor 파츠·조명·그림자 조명·파티클·움직임 태그)가 각 맵 `Art.BUDGET` 단계 안 |
| AC4 | 통과 | `m5-23-visual-kit` AC4, `m5-23-qa` 파티클 프리셋(지금 15종 — SoapFoam·Stardust·TeaLeaves가 m5-33에서 늘었고 모두 통과) |
| AC5 | 통과 | `m5-23-visual-kit` AC5·transform, `m5-23-qa` shapes |
| AC6 | 통과 | `m5-23-visual-kit` AC6, `m5-23-qa` anim |
| AC7 | 통과 | `m5-23-visual-kit` AC7, `m5-23-qa` lighting 6개(풀 21개 맵 lighting validate 포함) |
| AC8 | 통과 | `m5-23-visual-kit` AC8, `m5-23-qa` pickArena 2개 + 실제 21개 맵 슬롯 1·2 아레나 상자 2개 |
| AC9 | 통과 | `m5-23-visual-kit` AC9 3개 + 위 전체 렌더 2회 md5 같음 |
| AC10 | 통과 | 위 자동 검증 표 |
| AC11 | 통과 | `render-map all --view all` 21개 맵 모두 intro-NN·overview·eye·top·mobile + stats.txt. "그 맵만 실패" 경로: 실제로 실패하는 맵은 없음. 코드(`tools/render-map.luau:311-316` build pcall, `:409-418` 계속 돌고 끝에 끝 코드 1)와 B5 shim 테스트로 확인. 재QA "render-map 명령": 모르는 맵 → 끝 코드 1 + `unknown map` |
| AC12 | 통과 | QA가 PNG를 봄: onsen-claw intro-01(원형 무대·인형뽑기 기계·등롱 빛), space-conveyor eye(네온 코스·인형 3개·링 게이트). 기존 3장은 이전 QA에서 확인 |
| AC13 | 통과 | `m5-23-qa` "렌더러 통계 = 기존 맵 lune 카운트"(rotating-belt·soy-swamp + 풀 전체 예산). stats 형식은 재QA가 실제 명령으로 정규식 확인 |
| AC14~AC18 | 사용자 확인 필요 | 아래 체크리스트 (이전 리포트와 같고 B1·B2 확인 항목만 바꿈) |

통계: 자동 확인 AC 13개 모두 통과, Studio 확인 5개는 사용자 확인 필요.

### stats.txt 형식 (실측)
```
[render] dish-sink decor=1300/1500 lights=9/24 (shadowed 2/2) particles=15/16 anim=36/80 tris=107388 void=intro-01:0%,…,top:12% time=14.3s
[render]   Race · budget Extended · parts 1423 (judgment 123, decor 1300, hidden 0) · beams 0 · lighting map preset
[render]   bounds all 1132x514x1314 · play area 43x19x445 · out build/renders/dish-sink/
```
첫 줄은 스펙 A의 통계 한 줄과 같은 모양(21개 파일 모두 같은 정규식에 맞음). 2·3줄은 개발이 보탠 상세.

## 버그
새 P0/P1/P2 없음.

### [P3] N1 예산 여유가 거의 없는 맵 (위험 메모, 버그 아님)
- 실측(fast 렌더 stats): `tempura-pot` decor 1495/1500, `rotating-belt` 1492/1500, `bouncy-castle-maze` 1479/1500, `lantern-bridge` 1468/1500·**lights 24/24**, `dish-sink`·`space-conveyor`·`onsen-claw`·`dessert-fridge` shadowed 2/2, `dessert-fridge`·`dish-sink` particles 15/16.
- 영향: 지금은 모두 예산 안(테스트 통과). 다만 m5-40 L3 이후 맵 길이 작업이나 아트 다듬기에서 장식을 몇 개만 더해도 맵 테스트가 깨진다. 넘으면 `MapKit.buildDecor`는 경고만 하고 짓지만(`MapKit.luau:144-147`), 맵 테스트(`checkBudget`)가 막는다 — 정상 동작.
- 권장: 위 맵을 늘릴 때는 같은 개수만큼 장식을 빼거나 합칠 것. 개발 조치 필요 없음.

### [P3] N2 `tests/m5-23-qa.spec.luau` 제목·주석의 "15개"
- 테스트 본문은 `Maps.allInfos()`를 돌아 이미 21개를 검사하지만 제목·주석은 "실제 맵 15개". 판정에는 영향 없음. 다음에 이 파일을 손볼 때 "풀 전체"로 바꾸면 됨(QA 파일, src 아님).

### 참고 (버그 아님)
- `--studio-art`는 `assets/map-art/*.rbxm`가 없어 실제 파일 경로를 못 돌렸다. 사용자가 첫 `.rbxm`을 넣으면 `lune run tools/render-map <id> --studio-art`로 한 번 확인.
- 렌더러 shim은 새 맵이 쓰는 인스턴스(LinearVelocity 13곳·VectorForce·SurfaceGui·BillboardGui·TextLabel·WeldConstraint·Attachment)를 `@lune/roblox`의 진짜 인스턴스로 만든다. 대부분 `start`에서 만들어 build 단계에서는 안 타지만, 재QA 테스트가 이 클래스들이 섞인 모델을 `Scene.addModel`에 넣어 오류 없이 파츠·조명만 세는 것을 확인했다. SurfaceGui·BillboardGui 글자는 렌더러가 안 그린다(DEV-SETUP 2-1에 이미 적힌 한계).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 이번 스펙은 새 리모트 없음. `MapLightingController`·`MapDecorFxController`는 리모트를 안 씀(`m5-23-qa` 소스 테스트).
- [x] 판정은 서버에만 — 조명·장식 움직임은 클라이언트 표시 전용, 움직이는 장식은 `Decor`(충돌·쿼리·터치 없음). B3 수정도 클라이언트 Lighting 자식만 다룸.
- [x] 맵 상태가 `ctx`에 — 키트는 build 단계 데이터만.
- [x] 정리 — 아레나 Model은 라운드 cleanup이 지움, 컨트롤러는 `Parent == nil`/`InstanceRemoved`로 표에서 뺌. B3의 `ChildAdded` 연결은 `start`에서 한 번(누수 없음). `localCreated`는 클래스 4개 상한의 고정 크기 표.

## 사용자 Studio 확인 체크리스트
(`docs/DEV-SETUP.md` 3-11 순서)
1. **Future 조명 (AC14)**: Rojo Connect → Explorer `Lighting` → `Technology = Future`, `LightingStyle = Realistic`, `PrioritizeLightingQuality` 켬. Play → 로비가 너무 어둡거나 하얗게 날아가지 않는지, 회전 접시·우승자 단상 아래 그림자.
2. **맵별 조명 (AC15)**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }` → 혼자 Play. 소개 시작 1~2초 안에 부드럽게 바뀌는지, 로비로 오면 돌아오는지, 번쩍임 없는지. 이어서 `{ "rotating-belt", "giant-jenga", "skewer-showdown" }`로 한 번 — **giant-jenga 소개 첫 컷부터 맵 조명**이면 B2 수정 확인.
3. **방 2개 (AC16)**: Test → Clients and Servers 2명, 서로 다른 방 → 각 화면이 자기 맵 조명, 관전으로 다른 방을 보면 그 방 조명.
4. **움직이는 장식 (AC17)**: 지금은 맵마다 anim 장식이 많다(예: ikura-bombs 71개). 아무 맵에서 회전·흔들림이 보이는지, 서버 창(Server)에서는 안 움직이는지, 두 클라이언트가 같은 위상인지, Output에 경고가 없는지.
5. **CornerWedge 방향**: `CornerWedgePart`를 회전 0으로 넣어 꼭대기가 로컬 (+X, 위, −Z) 귀퉁이인지. 다르면 developer에게(`Scene.luau` `cornerWedge`, `MapKitShapes.CORNER_YAW`).
6. **휴대폰 성능 (AC18)**: 예산을 가장 많이 쓰는 맵(tempura-pot·rotating-belt·lantern-bridge·dish-sink) 소개·달리기 중 30fps 이상.
7. **Surface 조명 (B1)**: Surface 조명이 있는 장식(예: 간판·창문)이 렌더 PNG와 Studio에서 비슷한 넓이로 비추는지.
8. **로비 효과 중복 (B3)**: Play 직후 Explorer `Lighting` 아래 `Atmosphere`·`ColorCorrectionEffect`·`BloomEffect`가 클래스마다 하나씩인지(클라이언트 창에서).

## 추가한 테스트
- `tests/m5-23-reqa.spec.luau` (6개)
  - `reQA pool: 모든 맵 Art.decor()가 validate 통과` — 21개 맵, Surface range ≤ 16, `checkBudget(decor, Art.BUDGET)`
  - `reQA pool: 렌더러 환경에서 지은 모든 맵` — 진짜 build, Decor 파츠 수 ≥ DecorSpec 수(장식 건너뛰기 감지), 실제 인스턴스 5종이 예산 단계 안
  - `reQA buildDecor: 올바른 장식 + 틀린 것 하나 → 아무것도 안 만듦` — Surface 17·없는 프리셋·period 0.4·shape Cone
  - `reQA Scene: 새 맵 인스턴스가 섞여도 오류 없이` — LinearVelocity·VectorForce·WeldConstraint·SurfaceGui·TextLabel·BillboardGui·Attachment + SurfaceLight Range 40 → 16
  - `reQA render-map 명령` — `process.exec("lune", …)`로 hot-plate top 160×90을 그려 stats.txt 정규식, 모르는 맵은 끝 코드 1 (출력 `build/reqa-render-test`, 끝나고 지움)
  - `reQA B3 소스` — `Lighting.ChildAdded`·`mine:Destroy()`·`localCreated`

## 인계 메모 (2026-10-15, QA)
- 브랜치: `m5-23-reqa` (origin/main `8750ee6`에서 시작), push 완료.
- 끝난 것: 검증 5단계, `render-map all --view all` 21개 맵 2회(결정적), B1~B6 재확인, 재QA 테스트 6개, 이 리포트, 스펙 상태 `qa-passed`.
- 남은 것: main 병합(메인 세션), 사용자 Studio 체크리스트 1~8(AC14~AC18). N2는 다음에 QA 파일을 손볼 때.
- 다음 첫 단계: 메인 세션이 `m5-23-reqa`를 main에 병합하고 병합 뒤 `lune run tests` 다시 확인. docs-writer는 CLAUDE.md "현재 상태"의 m5-23 줄을 `qa-passed`로.
- 막힌 점: 없음. `--studio-art`는 `.rbxm`이 생기면 한 번 확인.
