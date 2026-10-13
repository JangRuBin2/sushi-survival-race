status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-23 — 맵 비주얼 키트 + 미리보기 렌더러

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §11.4 맵 모듈 공통 인터페이스(장식 예산), §5.3 기존 맵 장식 품질(m5-20의 후속)
- 아트 기준: **[`docs/REFERENCE-map-art-direction.md`](../REFERENCE-map-art-direction.md)** (이 스펙과 같이 씀 — 맵 개발자가 반드시 따르는 가이드와 검토 체크리스트)
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md` §1 W1~W5, `docs/specs/m5-20-map-quality-pass.md`(안개 패널·로컬 애니메이션 선례), `docs/REFERENCE-map-production.md`
- 담당 개발 worktree: `main` (기반 스펙 — 다른 맵 worktree가 이걸 받아서 씀)
- 공용 파일 수정 담당: **이 스펙** — `shared/maps/MapTypes.luau`, `src/client/init.client.luau`, `default.project.json`, (필요할 때만) `shared/Config.luau`·`shared/Attributes.luau`. 이 스펙이 `main`에 머지되기 전까지 다른 스펙은 이 파일들을 고치지 않는다.
- 의존: 없음. **이 스펙을 쓰는 스펙**: m5-04 `ikura-bombs`, m5-05 `tempura-pot`, m5-06 `dessert-fridge`(아트 패스), m5-24 기존 맵 12개 아트 패스 v2.

## 배경
사용자(2026-10-13): "맵 퀄리티가 다른 로블록스 맵들에 비해서 퀄리티가 많이 떨어지던데 시각적으로 괜찮게 만드는게 매우 중요함."
지금 맵 아트는 (1) 에이전트가 결과를 **눈으로 볼 수 없어서** Studio 확인 전까지 품질을 판단하지 못하고, (2) `DecorSpec`이 상자·공·원기둥·쐐기와 색·재질뿐이라 둥근 모서리·조명·파티클·움직임을 맵마다 손으로 붙이고(m5-20 D2), (3) `Lighting`이 서버 전역 하나라 맵마다 분위기를 못 바꾼다(제안서 W3). 이 스펙은 세 가지를 모두 푸는 **도구**를 만든다. 맵 자체의 아트는 각 맵 스펙(m5-04~06, m5-24)이 한다.

## 목표
1. 에이전트가 Studio 없이 `lune run tools/render-map <mapId>`로 **실제 `build(origin)` 결과를 PNG로 보고** 고칠 수 있다.
2. 맵 아트를 데이터(`DecorSpec`)만으로 둥근 모서리·조명·파티클·움직임까지 표현한다.
3. 플레이어가 아레나에 들어가면 그 맵만의 조명 분위기(시간대·안개·색 보정)로 부드럽게 바뀌고, 로비로 나오면 돌아온다.

## 범위
- 포함: 아래 설계 A~D, 순수 로직 테스트, 기존 맵 6개 조명 프리셋 초안, `.gitignore`에 `build/` 추가, DEV-SETUP 렌더러 절 초안(개발 메모에 쓰고 docs-writer가 옮김).
- 제외: 맵 장식 자체의 개선(m5-04~06·m5-24), 스카이박스 이미지 업로드(에셋 id가 필요 — 사용자 작업, 아래), 판정 지오메트리·장애물 수치·시간 제한 변경(전부 그대로), Studio와 똑같은 렌더링(렌더러는 **근사**다 — 최종 판단은 Studio).

## 설계

### A. 미리보기 렌더러 `tools/render-map.luau` (Lune)
```
lune run tools/render-map <mapId|all> [--view intro|overview|eye|top|all] [--size 960x540] [--quality fast|high] [--out build/renders] [--studio-art]
```
- **진짜 맵을 짓는다**: `@lune/roblox`의 `Instance`·데이터 타입(CFrame, Vector3, Color3, ColorSequence, NumberSequence, Enum)으로 맵 모듈의 `build(origin)`을 그대로 부른다. `start`는 부르지 않는다(정지 상태 = 출발 직전).
  - origin은 실제 게임과 같게 `CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)`(1번 슬롯, `RoomService.getArenaOrigin` 규칙).
  - **shim**(`tools/render/Shims.luau`): `tests/lib/RobloxRequire.luau`와 같은 방식으로 `script`·인스턴스 `require`를 파일 경로로 바꾸고, `game:GetService`가 `CollectionService`(AddTag/GetTagged/HasTag — 메모리 표), `RunService`(`IsServer` true·`IsStudio` true·`IsClient` false, 이벤트는 연결만 받고 안 부름), `TweenService`(no-op), `ServerStorage`, `Workspace`, `Lighting`을 돌려주게 한다. `task`·`warn`·`Random`(Lune에 없으면 결정적 LCG로) 전역을 준다. 맵 모듈이 쓰는 API가 shim에 없으면 **어떤 API인지 이름을 찍고 실패**한다(조용히 넘어가지 않음).
  - `--studio-art`: `assets/map-art/<id>.rbxm`가 있으면 `@lune/roblox`의 `deserializeModel`로 읽어 `MapKit.attachStudioArt`와 같은 자리에 붙인다(없으면 무시).
- **소프트웨어 래스터라이저** (`tools/render/Raster.luau` 등, 순수 Luau):
  - 모양 → 삼각형: Block(12), Wedge, CornerWedge, Cylinder(측면 24분할 + 뚜껑), Ball(분할 구, 반지름에 따라 2~3단). Roblox 축 규칙 그대로(Cylinder 축 = 로컬 X).
  - z-버퍼, 원근 투영(세로 FOV 70 = Roblox 기본), 근평면 자르기.
  - 셰이딩: 해 방향(조명 프리셋의 `ClockTime`·위도 45로 계산) Lambert + 하늘/땅 반구 앰비언트(프리셋 `Ambient`·`OutdoorAmbient`), 재질별 근사(Neon = 자체 발광, Glass/Ice = 반투명 + 하늘 반사 조금, Metal/Foil = 반사 하이라이트, `reflectance` 반영).
  - **그림자 맵**: 해 방향 직교 깊이 맵(fast 1024², high 2048²), `castShadow = false` 파츠는 그림자를 안 만든다.
  - **점광원·스포트광**: `PointLight`/`SpotLight`/`SurfaceLight`의 색·밝기·범위·각도로 거리 감쇠 더하기(그림자 없음).
  - **Neon 글로우**: 발광 버퍼를 따로 모아 가우시안 블러로 더한다(프리셋 `Bloom` 세기 반영).
  - **반투명**: 불투명을 다 그린 뒤 반투명 삼각형을 먼 것부터 섞는다.
  - **안개**: 프리셋 `Atmosphere`의 Density·Haze·Color로 거리 비례 섞기, 배경은 해 방향 기준 하늘 그라데이션(Color → Decay).
  - **파티클**: 실제 입자 시뮬레이션은 안 하고, 방출 파츠 자리에 프리셋 색·크기의 반투명 점 구름(결정적 난수)으로 근사.
  - **색 보정**: 프리셋 `ColorCorrection`(밝기·대비·채도·틴트)을 마지막에.
  - `--quality high`는 2×2 슈퍼샘플링. 같은 입력이면 **같은 PNG 바이트**(결정적).
- **PNG 저장**: 직접 인코딩(`@lune/serde`의 zlib 압축 + CRC32). 출력 `build/renders/<mapId>/<view>.png`.
- **뷰**:
  - `intro-01` … `intro-NN`: `IntroCamera` 폴더의 파츠 CFrame 그대로 (실제 소개 경유점).
  - `overview`: 맵 모델 경계 상자를 앞-왼쪽 위 3/4 각도(위 35°, 옆 40°)에서 전부 담는 구도.
  - `eye`: `Spawns`의 `01` 위치에서 Roblox 기본 카메라처럼 캐릭터 뒤 12·위 4, 코스 방향(로컬 −Z)을 본다. 캐릭터 대신 계란초밥 크기의 흰 캡슐을 그려 스케일을 보여 준다.
  - `top`: 위에서 직교 투영(판정 바닥 배치·경로 확인용).
  - `mobile`: `eye`를 480×270으로 다시 그린 것(작은 화면 가독성 체크용).
- **통계 한 줄** (콘솔 + `build/renders/<mapId>/stats.txt`):
  `[render] <mapId> decor=<n>/<budget> lights=<n>/<budget> (shadowed <n>/2) particles=<n>/<budget> anim=<n> tris=<n> void=<뷰별 %> time=<s>`
  - `void%` = 각 뷰에서 **수평선 아래인데 하늘(아무 지오메트리도 없는) 픽셀의 비율**. 아트 가이드 체크리스트 1번("빈 공중이 안 보인다")을 숫자로 잰다.
- 시간 목표(참고): 맵 하나 전체 뷰(소개 4~5 + 4) `fast` 960×540이 개발 PC에서 3분 이내. 넘으면 해상도를 낮추는 `--size`로 돌려도 된다.
- 렌더 결과(`build/`)는 커밋하지 않는다(`.gitignore`에 `build/` 추가). 맵 스펙이 요구하는 **최종 PNG만** `docs/renders/<mapId>/`에 복사해 커밋한다(맵당 6장 안팎).

### B. 선언형 장식 확장 (`MapKitLogic`·`MapKit`, 기존 필드는 그대로)
`DecorSpec`에 **선택 필드만** 더한다 — 기존 맵의 장식 목록은 한 글자도 안 바꿔도 그대로 동작해야 한다.
| 필드 | 뜻 | 검사 |
|---|---|---|
| `shape = "CornerWedge"` | `CornerWedgePart` (모서리 깎기·지붕 끝) | SHAPES에 추가 |
| `reflectance: number?` | 0~1 (금속·유약·젤리 광택) | 0~1 |
| `castShadow: boolean?` | nil이면 **가장 긴 변 < 3이면 false, 아니면 true**(작은 소품 그림자 끄기 — Roblox 성능 문서 권장) | boolean |
| `light: LightSpec?` | `{ kind: "Point"|"Spot"|"Surface", color: RGB, brightness: number, range: number, angle: number?, face: string?, shadows: boolean? }` → 파츠 자식으로 만든다 | brightness 0~10, range 0~60, angle 0~180, face는 NormalId 이름, shadows 기본 false |
| `particle: string?` | `MapFxPresets`의 프리셋 이름 → `ParticleEmitter` 자식 | 이름이 프리셋에 있음 |
| `particleRate: number?` | 프리셋 `Rate`를 덮어씀 | 0~50 |
| `anim: AnimSpec?` | `{ kind: "Spin"|"Bob"|"Sway"|"Pulse", period: number, amount: number, axis: ("X"|"Y"|"Z")? }` 클라이언트 로컬 움직임(아래) | period 0.5~60, amount 범위는 kind별 (Spin은 무시, Bob ≤ 4 studs, Sway ≤ 20°, Pulse ≤ 0.15 배율) |

- **`MapFxPresets.luau`** (새 파일, 순수 데이터): `Steam`, `SteamThick`, `Bubbles`, `OilBubbles`, `Sparkle`, `Frost`, `ColdMist`, `Embers`, `SeaSpray`, `Dust`, `Petals`, `Confetti`. 각 프리셋 = Rate·Lifetime·Speed·SpreadAngle·Size/Transparency 키프레임·Color·LightEmission·Texture. 텍스처는 Roblox 기본 `rbxasset://textures/particles/*`만 써서 업로드가 필요 없게.
- **움직이는 장식**: `MapKit.buildDecor`가 `anim`이 있는 파츠에 `MapDecorTags.Anim` 태그 + 속성(`AnimKind`, `AnimPeriod`, `AnimAmount`, `AnimAxis`)을 단다. m5-20의 `MapDecorFxController`가 이 태그도 맡아 `RenderStepped`에서 로컬 오프셋만 얹는다(서버 값은 안 바꿈, 거리 컬링 250, 위상은 `workspace:GetServerTimeNow()` + 파츠 위치 해시로 결정적이어서 모든 플레이어에게 같게 보임). 계산은 순수 `MapDecorAnimLogic.offset(kind, period, amount, axis, t, phase)`.
- **예산**: 기존 상수(`DECOR_PART_BUDGET` 600·`PARTICLE_BUDGET` 8·`LIGHT_BUDGET` 12)는 **값을 바꾸지 않는다**(기존 테스트가 고정). 새 표 `MapKitLogic.BUDGETS = { Standard = {parts 600, particles 8, lights 12, shadowedLights 1, anim 40}, Extended = {parts 1500, particles 16, lights 24, shadowedLights 2, anim 80} }`.
  - opt-in 방법: 맵 아트 모듈이 `Art.BUDGET = "Extended"`를 내보내고, 그 맵의 테스트가 `MapKitLogic.checkBudget(Art.decor(), "Extended")`로 확인한다. `MapKit.buildDecor`의 **함수 모양은 바꾸지 않는다**(기존 `tests/map-art-race.spec.luau`가 `build()` 안의 `MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))` 글자를 찾음). 런타임 경고 기준은 Extended 값(1500 등)으로 올린다.
  - 새 함수: `MapKitLogic.countLights(specs)`, `countShadowedLights(specs)`, `countParticles(specs)`, `countAnimated(specs)`, `checkBudget(specs, tier) -> string?`.
  - 조명·파티클을 `<Map>.luau`에서 직접 `Instance.new`로 붙이는 기존 방식(m5-20)도 그대로 둔다. 렌더러 통계는 둘 다 센다(모델 안 실제 인스턴스 수).
- **팔레트 확장**: `PALETTE`에 색 추가(기존 키는 안 바꿈) — `Ikura`, `TempuraGold`, `Batter`, `CastIron`, `Steel`, `Frost`, `IceBlue`, `Mint`, `Strawberry`, `Lime`, `Cream`, `Chocolate`, `Caramel`, `Matcha`, `Shiso`, `Sea`, `Sunset`, `Plum`, `Pastel*`(분홍·하늘·노랑·보라) 등. 함수 `MapKitLogic.shade(rgb, factor)`(밝게·어둡게), `MapKitLogic.shades(rgb) -> { light, base, dark }`(가이드의 "재질마다 2~3 단계" 규칙용).
- **모양 헬퍼** `MapKitShapes.luau` (새 파일, 순수 — DecorSpec 목록을 돌려줌): `roundedBox`(가운데 상자 + 모서리 원기둥 + 꼭짓점 공), `bevelBox`(위 모서리를 쐐기로 깎은 상자), `rimDisc`(접시: 원판 + 테두리 고리), `ring`(N분할 고리), `capsule`, `lipTrim`(바닥 가장자리 띠), `scatter(seed, count, area, maker)`(결정적 무리 배치 — 고르게 흩뿌리지 않고 무리 중심 2~4개 주위로). 무작위는 자체 LCG(seed 고정)라 렌더·테스트가 매번 같다.

### C. 맵별 조명 분위기
- **`default.project.json`**: `Lighting.$properties`에 `Technology = "Future"`(Studio에서만 바꿀 수 있는 속성이라 프로젝트 파일에 둔다). Rojo 7.7.1이 받아 주면 `LightingStyle = "Realistic"`, `PrioritizeLightingQuality = true`도 같이(스크립트로도 쓸 수 있는 속성이라 안 되면 `LobbyService.init`에서 설정). Rojo live sync가 `Technology`를 못 바꾸면 사용자가 Studio에서 한 번 바꾼다(아래 사용자 작업).
- **`MapLighting.luau`** (새 파일, 순수): 타입 `MapLighting = { ClockTime, Brightness, Ambient, OutdoorAmbient, EnvironmentDiffuseScale?, EnvironmentSpecularScale?, ExposureCompensation?, Atmosphere = {Density, Offset, Color, Decay, Glare, Haze}, ColorCorrection = {Brightness, Contrast, Saturation, TintColor}, Bloom = {Intensity, Size, Threshold}, SunRays = {Intensity, Spread}? }`, `validate`, `lerp(a, b, t)`(ClockTime는 짧은 쪽으로 돌아감), `LOBBY`(= `LobbyLayout.LIGHTING`에서 만든 값), `PRESETS`(이름 → 값).
- **`MapTypes.MapModule`에 `lighting: MapLighting?`** 추가, `MapTypes.validate`가 있으면 `MapLighting.validate`로 검사. 없으면 로비 조명 그대로(지금과 같음).
- **아레나 표시**: 맵 `build` 결과 Model에 `RoundService`가 `MapDecorTags.Arena` 태그 + 속성 `MapId`(새 `Attributes.MapId`)를 단다. 클라이언트는 `Maps.get(MapId).lighting`을 읽는다.
- **`MapLightingController`** (새 클라이언트 컨트롤러, `init.client.luau`에 등록): 0.25초마다 `workspace.CurrentCamera` 위치로 지금 보는 아레나를 고른다(순수 `MapLightingLogic.pickArena(cameraPos, arenas, current)` — 경계 상자 + 들어갈 때 여유 40, 나갈 때 여유 80의 히스테리시스로 깜빡임 방지). 바뀌면 1.2초 동안 `lerp`로 `Lighting` 속성과 효과(Atmosphere·ColorCorrection·Bloom·SunRays)를 **클라이언트에서만** 바꾼다(클라이언트의 `Lighting` 변경은 복제되지 않으니 같은 서버의 다른 방과 충돌 없음 — 제안서 W3 해결). 로비로 나오면 `LOBBY`로 되돌린다. 관전(SpectateController 카메라)·소개·탈락/우승 연출 카메라도 카메라 위치 기준이라 자동으로 따라간다.
  - 효과 인스턴스는 서버가 만든 것(`LobbyAtmosphere` 등)이 있으면 그걸 고치고, 없으면 클라이언트가 같은 클래스 하나만 만든다(두 개가 겹치지 않게).
  - 서버는 `LobbyService.init` 이후 `Lighting`을 바꾸지 않는다(바꾸면 클라이언트 값이 덮임) — 지금 코드도 그렇다, 그대로 유지.
- **기존 맵 6개 프리셋 초안** (값은 기본값, m5-24에서 렌더·Studio로 다듬음):
  | 맵 | 분위기 | ClockTime | 핵심 |
  |---|---|---|---|
  | `rotating-belt` | 저녁 손님 몰리는 가게, 따뜻한 등빛 | 17.5 | 호박색 Ambient, Atmosphere 0.28 따뜻한 복숭아, Bloom 0.45 |
  | `soy-swamp` | 흐린 오후 간장 늪 안개 | 15 | 갈색-올리브 안개 Density 0.38·Haze 1.6, 채도 −0.05, 와사비 산 빛이 튐 |
  | `ramen-rapids` | 김 자욱한 한낮 | 12.5 | 금빛 Haze 2, Density 0.32, Bloom 0.4, SunRays 0.05 |
  | `hot-plate` | 밤의 철판 — 열기 | 20.5 | 낮은 청색 Ambient + 강한 주황 Bloom 0.7, ColorCorrection 따뜻하게 |
  | `chef-board` | 아침 손질 시간, 차갑고 깨끗한 주방 | 9 | 청회색 Ambient, Contrast 0.12, Density 0.2 |
  | `skewer-showdown` | 축제 해질녘 | 18.2 | 자주-주황 Decay, Glare 0.4, 등롱이 돋보이게 Ambient 낮게 |

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1: 기존 맵 15개(`maps/init.luau`의 ALL)의 `Art.decor()`(있는 맵)와 로비 장식이 새 `MapKitLogic.validate`를 그대로 통과한다. 기존 상수 `DECOR_PART_BUDGET`·`PARTICLE_BUDGET`·`LIGHT_BUDGET` 값이 600·8·12 그대로다. 기존 테스트 파일은 **수정 없이** 전부 통과한다.
- [ ] AC2: 새 필드 검사 — 잘못된 `shape`/`reflectance`(1.5)/`light.range`(80)/`light.kind`/없는 `particle` 이름/`anim.period`(0)/`anim.kind`가 각각 이유 문자열을 돌려주고, 올바른 값은 nil.
- [ ] AC3: `checkBudget`: Standard에서 파츠 601개면 실패, Extended에서 1500개 통과·1501개 실패. 조명 25개·그림자 조명 3개·파티클 17개·움직임 81개가 Extended에서 각각 실패. `castShadow` nil일 때 가장 긴 변 2.9 → false, 3 → true(`MapKitLogic.resolveCastShadow`).
- [ ] AC4: `MapFxPresets`의 모든 프리셋이 필수 키를 갖고 Texture가 `rbxasset://`로 시작한다.
- [ ] AC5: `MapKitShapes`의 모든 헬퍼 결과가 `validate`를 통과하고, 같은 인자(같은 seed)면 같은 목록을 돌려준다. `roundedBox`의 `bounds`가 요청한 크기와 ±0.01 안에서 같다.
- [ ] AC6: `MapDecorAnimLogic.offset`: t = 0과 t = period가 같은 값, Bob 최대 변위 = amount, Sway 최대 각도 = amount, Pulse 배율이 1 ± amount 안.
- [ ] AC7: `MapLighting.validate`가 6개 프리셋과 `LOBBY`를 통과, `lerp(a, b, 0) == a`, `lerp(a, b, 1) == b`, ClockTime 23 → 1 사이 lerp가 0시를 지나 짧게 돈다. `MapTypes.validate`가 잘못된 `lighting`(ClockTime 30)을 거절한다.
- [ ] AC8: `MapLightingLogic.pickArena`: 경계 상자 안 → 그 아레나, 들어간 뒤 여유 40~80 사이 → 그대로 유지, 80 밖 → nil(로비), 두 아레나가 가까우면 더 가까운 쪽.
- [ ] AC9: 렌더러 순수 부분(`tools/render/*` 중 Roblox API 없는 것): 삼각형 하나를 그렸을 때 덮는 픽셀 수가 예상 ±2%, z-버퍼가 가까운 면을 남긴다, PNG 헤더·IHDR·CRC가 맞다(직접 만든 2×2 이미지 바이트 비교), 같은 장면 두 번 렌더 결과 바이트가 같다.
- [ ] AC10: 검증 5단계 통과(`rojo build`, `stylua --check src tests tools`, `selene src`, `lune run tests`, `luau-lsp analyze`).

### 렌더러 (개발 PC에서 명령으로 확인)
- [ ] AC11: `lune run tools/render-map all`이 ALL의 맵 15개 전부에 대해 오류 없이 `build/renders/<mapId>/`에 intro-NN·overview·eye·top·mobile PNG와 stats.txt를 만든다(껍데기 맵은 회색 박스여도 됨). shim에 없는 API를 쓰는 맵이 있으면 그 API 이름이 찍히고 그 맵만 실패, 나머지는 계속.
- [ ] AC12: 렌더 PNG에서 기존 맵이 알아볼 수 있게 보인다 — `rotating-belt` overview에 벨트·카운터·등이, `hot-plate` intro에 층 구조가, `skewer-showdown` overview에 꼬치·등롱 빛이 보인다(개발자가 PNG를 보고 개발 메모에 3장 경로 + 한 줄 설명).
- [ ] AC13: stats 줄의 decor·lights·particles 수가 같은 맵의 lune 테스트(`countNamed` 등)로 센 값과 같다(rotating-belt 조명 3·파티클 2, soy-swamp 조명 2·파티클 3 — m5-20 값).

### Studio 확인
- [ ] AC14: Studio에서 `Lighting.Technology`가 Future다(Rojo 동기화 또는 사용자가 한 번 설정). 로비가 Future에서도 이상하지 않다(너무 어둡거나 하얗게 날아가지 않음). 회전 접시·우승자 단상에 그림자가 생긴다.
- [ ] AC15: `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`로 혼자 돌리면 라운드 소개가 시작될 때 1~2초 안에 조명이 그 맵 분위기로 부드럽게 바뀌고(철판은 밤·주황, 꼬치는 해질녘), 라운드가 끝나 대기석(로비)으로 오면 로비 조명으로 돌아온다. 갑자기 번쩍이거나 깜빡이지 않는다.
- [ ] AC16: 2명(Clients and Servers, 한 플레이스 모드에서 방 2개)으로 서로 다른 맵을 동시에 돌리면 각 클라이언트가 **자기 아레나의** 조명으로 보인다. 탈락 뒤 관전으로 다른 사람을 비출 때도 그 아레나 조명이다.
- [ ] AC17: `anim`을 단 장식(테스트용으로 한 맵에 Spin·Bob·Sway·Pulse 하나씩 — 확인 뒤 지워도 되고 m5-24에서 실제로 씀)이 움직이고, 서버 Output에 복제 경고가 없다. 2명이 같은 장식을 보면 같은 위상으로 움직인다.
- [ ] AC18: 휴대폰 성능(사용자, 실제 휴대폰 또는 비공개 테스트): 24명(또는 가능한 최대) 판에서 가장 무거운 맵 소개·달리기 중 프레임이 눈에 띄게 끊기지 않는다(목표 30fps 이상, Studio `View → Stats`/MicroProfiler로 PC 기준 렌더 시간 비교 기록). Future는 지원 안 하는 기기에서 ShadowMap/Voxel로 자동으로 내려가니 저사양에서 조명이 단순해지는 건 정상.

## 공용 파일 변경 (이 스펙 담당)
- `shared/maps/MapTypes.luau`: `MapModule.lighting: MapLighting.MapLighting?` + validate.
- `src/client/init.client.luau`: `CONTROLLERS`에 `require(script.fx.MapLightingController)` 한 줄(주석 "m5-23 맵 조명 분위기").
- `default.project.json`: `Lighting.$properties` (`Technology`, 가능하면 `LightingStyle`·`PrioritizeLightingQuality`).
- `shared/Attributes.luau`: `MapId`(아레나 Model, 맵 id) 한 줄.
- `shared/Config.luau`: 필요 없으면 안 고침(조명 전환 시간 1.2초·여유 40/80은 `MapLightingLogic` 상수).
- 공용 파일 아님(이 스펙이 고침): `MapKit.luau`, `MapKitLogic.luau`, `MapDecorTags.luau`(태그 `Anim`·`Arena` 추가), `MapDecorFxController.luau`, `RoundService.luau`(태그·속성 두 줄), 새 파일 `MapFxPresets`·`MapKitShapes`·`MapDecorAnimLogic`·`MapLighting`·`MapLightingLogic`·`MapLightingController`, 기존 맵 6개 메인 모듈에 `lighting = MapLighting.PRESETS.<id>` 한 줄씩, `tools/`, `tests/`(새 파일), `.gitignore`.

## 사용자 작업 (스펙을 막지 않음)
- Studio에서 `Lighting.Technology`를 Future로 한 번 확인(Rojo가 못 바꾸면 직접 설정 후 플레이스 저장).
- (선택) 맵별 스카이박스 이미지: 지금은 Roblox 기본 하늘 + Atmosphere로만. 원하면 나중에 Sky 에셋 id를 프리셋에 추가.
- AC18 휴대폰 체감.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-13 · D1 품질을 에이전트가 어떻게 판단하나 · **Lune 소프트웨어 렌더러로 실제 `build` 결과를 PNG로** 보고 가이드 체크리스트로 비평 → 고침 → 다시 렌더를 3회 이상(맵 스펙 AC). Studio 스크린샷은 에이전트가 못 찍고, 렌더러는 근사지만 구도·실루엣·빈 공중·색 비율·밀도 판단에는 충분. 최종 체감은 Studio AC로. · main 세션 결정, planner 정리
- 2026-10-13 · D2 맵마다 조명을 어떻게 다르게 · 서버 전역 `Lighting`은 하나지만 **클라이언트가 바꾼 `Lighting`은 복제되지 않는다** → 카메라가 있는 아레나 기준으로 클라이언트가 바꾸면 한 플레이스 모드의 여러 방이 충돌하지 않음. 제안서 W3의 "불가능" 판단과 m5-20 안개 패널(반투명 큰 판 = 겹친 픽셀 여러 번 그림, 성능 문서 주의)을 대신한다. 새 맵은 안개 패널을 쓰지 않는다. 근거: REFERENCE-map-art-direction 1절(Atmosphere·Future 공식 문서). · planner
- 2026-10-13 · D3 예산을 올려도 되나 · 기본은 그대로(600/8/12), 맵이 **명시적으로 Extended(1500/16/24, 그림자 조명 2)**를 고를 때만. 그림자 조명은 비싸서(공식 "점광 그림자가 가장 비쌈") 맵당 2개, 좁은 SpotLight 권장. 작은 파츠 그림자는 기본으로 끔(성능 문서). 근거: REFERENCE-map-art-direction 1·6절. **기본값, 휴대폰 테스트(AC18) 뒤 조정** · planner
- 2026-10-13 · D4 `buildDecor` 함수 모양 · 바꾸지 않는다 — 기존 테스트가 `build()` 소스에서 호출 글자를 찾음(m5-20 개발 메모). 예산 단계는 Art 모듈의 `BUDGET` 상수 + 맵 테스트로. · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
2026-10-13 developer — 구현 완료 (코드 `3b20944`, main). 인계 메모: `docs/developer/m5-23-map-visual-kit.md`.

**바뀐 파일**
- 렌더러: `tools/render-map.luau`, `tools/render/{Shims,Scene,Raster,Materials,Png}.luau`. 사용법·한계는 `docs/DEV-SETUP.md` 2-1(이번에 바로 넣음 — docs-writer는 다듬기만).
- 공유: `MapKitLogic`(새 필드·BUDGETS·count*·checkBudget·resolveCastShadow·팔레트·shade/shades/mix), `MapKit`(buildDecor 새 필드, `makeEmitter`·`makeLight`, 런타임 경고는 Extended 기준, **함수 모양 그대로**), 새 `MapFxPresets`·`MapKitShapes`·`MapDecorAnimLogic`·`MapLighting`·`MapLightingLogic`, `MapDecorTags`(Anim·Arena + Anim 속성 이름), `MapTypes`(lighting + validate), 기존 맵 6개 `lighting = MapLighting.PRESETS[ID]`, `LobbyLayout` 주석.
- 서버: `RoundService`(맵 Model에 `MapDecorTags.Arena` 태그 한 줄 — `Attributes.MapId`는 이미 있어서 `Attributes.luau`는 안 고침).
- 클라이언트: 새 `fx/MapLightingController.luau`(init.client 등록), `fx/MapDecorFxController.luau`(Anim 태그).
- `default.project.json` Lighting: `Technology = Future`, `LightingStyle = Realistic`, `PrioritizeLightingQuality = true` (Rojo 7.7.1이 받음 — build.rbxl을 Lune으로 열어 Future 확인). `.gitignore`에 `build/`.
- 테스트: `tests/m5-23-visual-kit.spec.luau` (AC1~AC9). 기존 테스트 파일은 수정 없음.

**검증**: rojo build OK · `stylua --check src tests tools` OK · `selene src` 0/0/0 · `lune run tests` 1247 passed / 0 failed · `luau-lsp analyze` 끝 코드 0 · `lune run tools/render-map all` 15개 전부 성공(high, 약 3분 25초).

**AC12 렌더 (개발자 확인)**
- `build/renders/rotating-belt/overview.png` — 벨트 두 줄·카운터·빨간 등·손님 얼굴·결승 노렌이 다 보임 (저녁 프리셋).
- `build/renders/rotating-belt/eye.png` — 출발점 뒤 시점, 계란초밥 인형 3개로 크기 비교, 벨트가 결승 문까지 이어짐.
- `build/renders/skewer-showdown/intro-02.png` — 팔각 무대·꼬치·기둥과 옆 가게 문·빨간 등롱 빛 (해질녘).
- `build/renders/hot-plate/overview.png` — 철판 3층 구조·기둥·후드·손님 얼굴.
AC13: rotating-belt lights 3·particles 2, soy-swamp lights 2·particles 3 (stats 줄 = m5-20 값).

**스펙과 다르게 한 작은 것 (질문 아님, 확인용)**
- eye 뷰: Race는 코스 앞(-Z), Survival·Final은 스폰에서 플레이 영역 가운데 쪽을 봐요(원형 결승 맵에서 -Z면 허공을 봐서). 흰 캡슐 대신 계란초밥 근사 인형(밥·계란·김 띠).
- overview: 모델 경계 상자가 플레이 영역의 3배를 넘으면(먼 배경판) 플레이 영역 기준 2배 상자로 잡아요. 상자 꼭짓점이 화면에 다 들어오는 거리로 정확히 맞춰요.
- `void%`는 화면 전체 중 "수평선 아래 허공" 픽셀 비율. overview·top은 떠 있는 아레나라 원래 높으니 intro·eye 값으로 판단.
- `--quality` 기본은 high(속도가 충분히 빨라서). Ball 분할은 반지름과 상관없이 16×10, Cylinder 16분할.
- Shim의 `RunService:IsStudio()`는 true. `--lobby-light` 옵션을 더했어요(맵 조명과 비교용).
- `particle`은 스펙대로 이름 문자열 + `particleRate`만. 색 바꾸기는 `MapKit.makeEmitter`로 만든 뒤 `Color`를 덮어쓰면 돼요.

**Studio 확인**: `docs/DEV-SETUP.md` 3-11 (Future·조명 전환·방 2개·anim·CornerWedge 방향·휴대폰).

**남은 이슈**
- R1 CornerWedge 꼭대기 방향(로컬 +X·위·-Z)은 가정이에요 — 렌더러와 `MapKitShapes.bevelBox` 귀퉁이가 같은 가정이라 서로는 맞지만, Studio와 다르면 `Scene.cornerWedge`·`CORNER_YAW` 두 곳을 고쳐야 해요(3-11의 5번).
- R2 렌더러는 근사 — Studio와 밝기·재질감·그림자 부드러움이 달라요. 특히 밤 프리셋(hot-plate)은 렌더가 실제보다 어두울 수 있어요.
- R3 `castShadow` nil → 가장 긴 변 < 3이면 그림자 끔이 기존 맵 장식에도 적용돼요(의도, 작은 소품 그림자가 사라짐).
