# QA — m5-23 맵 비주얼 키트 + 미리보기 렌더러

- 스펙: `docs/specs/m5-23-map-visual-kit.md`
- 검증 커밋: `3b20944`·`7714541` (main `1ddf47e`에 병합한 상태로 검증)
- 결과: **반려 (P1 1건)** — 스펙 `in-dev`. 고칠 것은 두세 줄이다(아래 B1). 나머지 기능(조명 전환·예산·모양 헬퍼·움직임·렌더러)은 통과.
  - P1 판정 근거: 메인 세션 지시("지금 이 키트로 일하는 아트 에이전트 7명에게 해가 되는 API 버그는 P1"). B1은 게임을 깨지 않지만, 렌더러를 보고 조명을 맞추는 아트 에이전트가 Studio와 다른 결과를 믿게 만든다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 (Lune으로 build.rbxl을 열어 `Lighting.Technology = Future`, `LightingStyle = Realistic`, `PrioritizeLightingQuality = true` 확인) |
| `stylua --check src tests tools` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — **1441 passed, 0 failed** (97개 파일, QA 추가 `m5-23-qa.spec.luau` 22개 포함) |
| `luau-lsp analyze …` (타입 검사) | 통과 (끝 코드 0) |
| `lune run tools/render-map hot-plate --quality fast` | 통과 (5.9초, PNG 8장 + stats.txt). 두 번 돌린 PNG 바이트 같음 |
| `lune run tools/render-map all --quality fast` (2회) | 15개 맵 전부 성공, PNG 109장. **두 번 돌린 109장 모두 바이트가 같다**(결정적). stats.txt는 `time=`만 다름 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m5-23-visual-kit` AC1, 기존 테스트 파일 수정 없이 전부 통과 |
| AC2 | 통과 (B1 제외) | `m5-23-visual-kit` AC2 + QA `QA extras: 추가 경계값 거절`(25개)·`경계값 통과`(11개). 단 Surface 조명 range 상한이 Roblox와 다름 → B1 |
| AC3 | 통과 | 개발 테스트 + `QA budget: 단계별 정확한 경계`, `extra로 Instance.new 조명·파티클·파츠도 같이 세요` |
| AC4 | 통과 | 개발 테스트 + `QA MapKit: 모든 파티클 프리셋이 진짜 ParticleEmitter로`(키프레임 0·1 끝, 진짜 `@lune/roblox` NumberSequence·ColorSequence로 생성) |
| AC5 | 통과 | 개발 테스트 + `QA shapes: 회전한 roundedBox·bevelBox·capsule 경계, ring 최소 3분할, scatter 영역 안` |
| AC6 | 통과 | 개발 테스트 + `QA anim: 큰 서버 시각에서도 주기, 위상 0~1, 축별 성분만` |
| AC7 | 통과 | 개발 테스트 + `QA lighting:` 6개(잘못된 입력 29종 거절, 경계값 통과, MapTypes가 맵 id와 함께 거절, 풀 전체 통과, resolve·lerp가 PRESETS·LOBBY를 안 바꿈, t clamp·시계 거꾸로) |
| AC8 | 통과 | 개발 테스트 + `QA pickArena:` 2개(여유 경계 정확히, 아래쪽 150, 사라진 아레나, 겹칠 때 현재 유지, 경계를 오가도 한 번만 바뀜) |
| AC9 | 통과 | 개발 테스트(픽셀 수·z-버퍼·PNG CRC·같은 바이트) + 위 전체 렌더 2회 바이트 비교 |
| AC10 | 통과 | 위 자동 검증 표 |
| AC11 | 통과 | `render-map all` 15개 모두 intro-NN(IntroCamera 있는 맵)·overview·eye·top·mobile·stats.txt. 껍데기 3개(ikura-bombs·tempura-pot·dessert-fridge)는 IntroCamera가 없어 intro 없음(회색 박스 허용 범위). shim에 없는 API를 쓰는 맵이 없어 "그 맵만 실패" 경로는 실제로 타지 않음(코드로 확인 `tools/render-map.luau` build pcall) — B5 참고 |
| AC12 | 통과 | QA가 PNG를 직접 봄: `rotating-belt/overview`(벨트 두 줄·카운터·손님 얼굴·결승 문), `skewer-showdown/intro-02`(팔각 무대·꼬치·빨간 등롱 빛·해질녘 안개), `hot-plate/overview`(철판 3층·기둥·후드) |
| AC13 | 통과 | `QA budget: 렌더러 통계 = 기존 맵 lune 카운트` (렌더러 환경에서 실제로 지은 모델: rotating-belt 조명 3·파티클 2, soy-swamp 2·3, 15개 맵 모두 Standard 예산 안). 렌더 stats 줄도 같은 값 |
| AC14 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC15 | 사용자 확인 필요 (+ B2) | 체크리스트 2. 코드상 전환은 맞지만 giant-jenga 소개 첫 컷은 로비 조명으로 시작한다(B2) |
| AC16 | 사용자 확인 필요 | 체크리스트 3. 코드·테스트로는 확인: 실제 맵 15개를 슬롯 1·2에 지어 아레나 상자를 컨트롤러와 같은 방식으로 재면 슬롯끼리 안 겹치고 로비는 어느 아레나에도 안 걸림(`QA arenas:` 2개) |
| AC17 | 사용자 확인 필요 | 체크리스트 4 (아직 `anim`을 쓰는 맵이 없음 — 테스트용 장식을 잠깐 넣어야 함) |
| AC18 | 사용자 확인 필요 | 체크리스트 6 |

통계: 자동으로 확인한 AC 13개 중 12개 통과, 1개(AC2) B1로 부분 통과. Studio 확인 5개(AC14~18)는 사용자 확인 필요.

## 버그

### [P1] B1 Surface 조명 range를 0~60까지 받는데 Roblox `SurfaceLight.Range` 상한은 16 — 렌더러가 Studio보다 훨씬 넓게 비춘다
- 재현: `light = { kind = "Surface", color = …, brightness = 2, range = 40 }`인 장식 → `MapKitLogic.validate` 통과(검사 상한이 종류와 상관없이 60) → `MapKit.makeLight`가 `SurfaceLight.Range = 40` → 렌더러(`Scene.luau`)는 그 값을 그대로 읽어 40 studs까지 밝힌다.
- 기대: 검사가 Surface는 0~16으로 거절(이유 문자열)하고, 렌더러도 Studio처럼 16에서 자른다. (PointLight·SpotLight 상한 60은 맞음.)
- 실제: Roblox는 SurfaceLight.Range를 16으로 자르므로 Studio에서는 빛이 렌더보다 훨씬 좁다. 아트 에이전트가 렌더 PNG로 간판·창문·등 빛을 맞추면 Studio에서 어둡게 나온다.
- 위치: `src/shared/maps/MapKitLogic.luau:273`, `tools/render/Scene.luau:586-588`
- 고치는 법:
  1. `MapKitLogic.validateExtras`에서 range 검사를 종류별로: `local maxRange = if light.kind == "Surface" then 16 else 60` → `"light.range must be 0~{maxRange}"`. (`MapKitLogic.SURFACE_LIGHT_MAX_RANGE = 16` 상수로 두면 테스트가 쓰기 좋다.)
  2. `Scene.luau` 조명 수집에서 `range = math.min(range, if kind == "Surface" then 16 else 60)` (맵 코드가 `Instance.new`로 붙인 조명도 같은 값이 되게).
  3. 테스트: Surface range 16 통과·16.01 거절, Point range 60 통과.
- 아트 에이전트에게 지금 바로 할 말: **Surface 조명 range는 16 이하로**. 고쳐지기 전에 넣은 값이 16을 넘으면 고친 뒤 validate가 장식 목록 전체를 건너뛴다(`MapKit.buildDecor`는 목록에 하나라도 틀리면 아무것도 안 만듦).

### [P2] B2 소개 카메라 경유점이 아레나 상자 밖이면 소개 첫 컷이 로비 조명 (giant-jenga 01)
- 재현: 렌더러 환경에서 실제 맵을 슬롯 1에 지어 `MapLightingController.measure`와 같은 방식(판정 파츠만, `Decor`·`IntroCamera` 제외)으로 상자를 재고 `IntroCamera` 점마다 `pickArena`. giant-jenga `01`은 (2000, 355, 0), 상자 위 끝 y ≈ 306.9 + 여유 40 = 346.9 → 밖(nil). 나머지 14개 맵의 소개 점은 모두 안.
- 기대: AC15 "라운드 소개가 시작될 때 1~2초 안에 그 맵 분위기" — 소개 첫 컷부터 맵 조명.
- 실제: 소개 첫 경유점에서는 로비 조명, 카메라가 상자 + 40 안으로 들어온 뒤에야 1.2초 섞기 시작. 아트 패스(m5-24·m5-04~06)에서 소개 경로를 넓게 잡거나 높이 띄우면 같은 일이 더 생긴다.
- 위치: `src/client/fx/MapLightingController.luau:97-127` (`measure`가 107줄에서 `IntroCamera`를 뺌)
- 고치는 법: `measure`에서 `IntroCamera` 폴더의 파츠는 크기 없이 **점으로** 상자에 넣는다(Decor는 지금처럼 빼도 됨). 고치면 `tests/m5-23-qa.spec.luau`의 `KNOWN_INTRO_OUTSIDE` 표를 비운다(그 테스트가 "이제 안이니 지우라"고 실패해서 알려 준다).

### [P3] B3 서버가 만든 효과보다 컨트롤러가 먼저 돌면 Atmosphere·Bloom이 두 개가 될 수 있음
- 재현(이론): 클라이언트 `MapLightingController.start` → `apply(LOBBY)` → `effect("Atmosphere", "LobbyAtmosphere")`가 아직 복제 안 된 서버 효과를 못 찾고 새로 만든다 → 뒤에 서버 `LobbyAtmosphere`가 복제되면 같은 클래스가 둘.
- 기대: 효과는 클래스마다 하나(스펙 C "두 개가 겹치지 않게").
- 실제: 컨트롤러는 Remotes를 기다린 뒤 시작해서 보통은 Lighting 자식이 먼저 와 있다. 실제로 드물 것. 생기면 Atmosphere는 어느 쪽이 쓰일지 정해지지 않고 Bloom은 겹쳐 더 밝다.
- 위치: `src/client/fx/MapLightingController.luau:40-53`
- 고치는 법(선택): 만들기 전에 `Lighting:WaitForChild("LobbyAtmosphere", 5)` 같은 짧은 대기, 또는 `Lighting.ChildAdded`에서 같은 클래스 두 번째를 지운다.

### [P3] B4 `AnimSpec.amount`가 타입에서 필수 — Spin에 amount를 안 쓰면 strict 타입 검사 오류 가능
- 검사(`MapDecorAnimLogic.validate`)와 `MapKit.buildDecor`(`anim.amount or 0`)는 Spin의 amount 없음을 허용하지만 타입은 `amount: number`.
- 위치: `src/shared/maps/MapDecorAnimLogic.luau:15`
- 고치는 법: `amount: number?` (Spin 외에는 validate가 이미 숫자를 요구). 그전에는 아트 에이전트가 `amount = 0`을 쓰면 된다.

### [P3] B5 렌더러 shim의 가짜 `RunService`에 이벤트가 없어, build에서 이벤트를 연결하면 API 이름 없이 실패
- 스펙 A: "RunService 이벤트는 연결만 받고 안 부름", "shim에 없는 API는 이름을 찍고 실패". 가짜 `RunService`는 `IsServer/IsClient/IsStudio/IsRunning`만 있어 `RunService.Heartbeat:Connect`가 `attempt to index nil with 'Connect'`로 실패(어떤 API인지 안 나옴). 지금 맵은 build에서 이벤트를 안 써서 영향 없음.
- 위치: `tools/render/Shims.luau:145-158`
- 고치는 법: `Heartbeat`·`Stepped`·`RenderStepped`를 `{ Connect = function() return { Disconnect = function() end } end }`로, 가짜 서비스 테이블에 `__index` 메타메서드로 `"[render] RunService.<이름> is not available"` 에러.

### [P3] B6 작은 것들
- `checkBudget`의 `extra`에 그림자 조명 수가 없다(`Instance.new`로 붙인 `Shadows = true` 조명은 예산 검사에서 안 셈). 렌더러 stats는 셈. `src/shared/maps/MapKitLogic.luau:351-381`.
- `MapKitShapes.roundedBox(..., { radius = 0 })`(모서리 없음 의도)이면 원기둥·공 크기가 0 → validate 실패 → `buildDecor`가 **맵 장식 전체**를 건너뜀. radius ≤ 0이면 그냥 상자 하나를 돌려주면 안전. `src/shared/maps/MapKitShapes.luau:145`.
- 플레이스 파일의 Lighting은 `EnvironmentDiffuseScale/SpecularScale = 0`, `ShadowSoftness = 0.5`인데 클라이언트 `LOBBY`는 `MapLighting.DEFAULTS`(0.5·0.5·0.2)를 쓴다 — 서버(`LobbyService.applyLighting`)가 이 값들을 안 맞춰서 접속 직후 컨트롤러가 돌 때 한 번 살짝 바뀐다. 의도된 값이면 `LobbyService.applyLighting`에도 같은 값을 넣길 권함.
- CornerWedge 꼭대기 방향(로컬 +X·위·-Z)은 가정 — 렌더러(`Scene.luau:270-280`)와 `MapKitShapes.CORNER_YAW`가 같은 가정이라 서로는 맞음(QA가 회전 계산으로 네 귀퉁이가 안쪽을 향하는 것 확인). **Studio에서 한 번 확인 필요**(체크리스트 5).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이번 스펙은 새 리모트가 없다. 두 클라이언트 컨트롤러는 리모트·`FireServer`를 쓰지 않는다(QA 소스 테스트).
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 조명·장식 움직임은 클라이언트 표시 전용. 움직이는 장식은 `Decor`(충돌·쿼리·터치 없음)에만 붙고 서버 CFrame은 안 바뀜. `RoundService` 변경은 태그 한 줄(MapId 속성 뒤, Workspace에 넣기 전 — QA 소스 테스트).
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 키트는 build 단계 데이터만, 맵 모듈 상태 추가 없음.
- [x] 연결·인스턴스·스레드가 정리된다 — 아레나 Model은 라운드 `cleanup`이 지움(`cleanup:add(model)`), 컨트롤러는 `InstanceRemoved`·`Parent == nil`로 표에서 뺀다. 연결·폴링 스레드는 `start`에서 한 번만 만들고 TweenService를 안 씀(누수 없음). 리스폰은 카메라 위치만 보므로 영향 없음. 서버 쪽에서 `Lighting`을 쓰는 곳은 `LobbyService`뿐(QA 소스 테스트).
- 성능 메모: 움직이는 장식은 거리 250 밖이면 건너뛰고, Pulse는 매 프레임 `Size`를 바꾼다(맵당 Extended 80개 상한). 휴대폰 체감은 AC18.

## 사용자 Studio 확인 체크리스트
(`docs/DEV-SETUP.md` 3-11과 같고 QA가 확인 포인트를 더함)
1. **Future 조명 (AC14)**: Rojo Connect → Explorer `Lighting` → `Technology = Future`, `LightingStyle = Realistic`, `PrioritizeLightingQuality` 켬인지. 아니면 직접 바꾸고 저장. Play → 로비가 너무 어둡거나 하얗게 날아가지 않는지, 회전 접시·우승자 단상 아래 그림자가 있는지.
2. **맵별 조명 (AC15)**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }` → 혼자 Play. 소개가 시작되고 1~2초 안에 부드럽게 바뀌는지(벨트 = 저녁, 철판 = 밤·주황, 꼬치 = 해질녘), 라운드가 끝나 대기석(로비)으로 오면 로비 조명으로 돌아오는지, 번쩍임·깜빡임이 없는지. 추가로 `{ "rotating-belt", "giant-jenga", "skewer-showdown" }`로 한 번 — giant-jenga 소개 **첫 컷이 로비 조명**이면 B2 재현(고친 뒤 다시 확인).
3. **방 2개 (AC16)**: Test → Clients and Servers 2명, 각자 다른 방을 만들어 출발 → 각 화면이 자기 맵 조명. 한 명이 떨어진 뒤 관전으로 다른 방 사람을 비추면 그 방 맵 조명으로 바뀌는지, 관전을 끝내고 로비로 오면 로비 조명인지.
4. **움직이는 장식 (AC17)**: 아무 맵 Art의 `decor()`에 잠깐 `anim = { kind = "Spin", period = 4, amount = 0 }`, `{ kind = "Bob", period = 3, amount = 1 }`, `{ kind = "Sway", period = 3, amount = 10 }`, `{ kind = "Pulse", period = 2, amount = 0.1 }` 장식 4개 → 움직이는지, 서버 Output에 경고가 없는지, 서버 화면(Server 창)에서는 **안 움직이는지**(서버 값 그대로), 2명이 같은 순간 같은 모습인지. 확인 뒤 되돌림.
5. **CornerWedge 방향**: Explorer에서 `CornerWedgePart` 하나를 넣고 회전 0으로 둬서 꼭대기 점이 로컬 (+X, 위, −Z) 귀퉁이인지(Move 도구 화살표: 빨강 = +X, 파랑 화살표 반대쪽 = −Z). 다르면 developer에게(`Scene.luau` `cornerWedge`와 `MapKitShapes.CORNER_YAW`).
6. **휴대폰 성능 (AC18)**: 가장 무거운 맵 소개·달리기 중 30fps 이상(`View → Stats`/MicroProfiler 기록).
7. (B1 고친 뒤) Surface 조명을 range 16으로 넣은 장식이 렌더 PNG와 Studio에서 비슷한 넓이로 비추는지.

## 추가한 테스트
- `tests/m5-23-qa.spec.luau` (22개): 조명 검사 6, pickArena 2, 실제 맵 15개 아레나 상자 2(렌더러 shim으로 진짜 인스턴스 build — 로비 안 걸림·슬롯 안 겹침·스폰 24개·eye 카메라·소개 경유점), 예산 3, validateExtras 2, 움직임 1, `MapKit.buildDecor`·`makeEmitter` 진짜 인스턴스 2, 모양 헬퍼 1, 소스 확인 2, 프로젝트 파일 1.
- B2는 실패 테스트로 넣지 않았다(전체 검증이 깨지면 아트 에이전트들이 막힘). 대신 `KNOWN_INTRO_OUTSIDE` 표로 지금 상태를 고정 — 고치면 그 테스트가 실패해서 표를 비우라고 알려 준다. B1도 실패 테스트로 넣지 않았다(고칠 때 위 3번 테스트를 developer가 추가).

## 인계 메모 (2026-10-13, QA)
- 브랜치: `worktree-agent-adee0b3ef40080bc6` → push `m5-23-qa` (main `1ddf47e` 병합 상태).
- 끝난 것: 검증 5단계, 렌더러 전체 2회 결정성, AC1~AC13 확인, QA 테스트 22개, 이 리포트, 스펙 상태 `in-dev`(B1 P1).
- 남은 것: developer가 B1(필수)·B2(권장) 수정 → QA 재확인(B1 테스트 추가 여부, `KNOWN_INTRO_OUTSIDE` 비었는지) → `qa-passed`. 사용자 Studio 체크리스트 1~7.
- 다음 첫 단계: developer — `MapKitLogic.luau:273` Surface 상한 16, `Scene.luau:586` 자르기, `MapLightingController.measure`에 IntroCamera 점 포함.
- 막힌 점: 없음. 렌더 결과는 `build/`(커밋 안 함).
