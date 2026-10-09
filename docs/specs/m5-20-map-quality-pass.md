status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-20 — 기존 맵 6개 장식 품질 패스 (판정 불변)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.3 "기존 맵 장식 품질 개선 (v0.6, 스펙 `m5-20`)", §11.4 맵 모듈 공통 인터페이스(장식 예산)
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md` §1(W1~W5 진단, 코드 근거)·§2(개선 방향 1~5)
- 참고 코드: `MapKit.luau`·`MapKitLogic.luau`(장식 시스템·예산), `HotPlateArt.luau`·`HotPlate.luau`·`SkewerShowdownArt.luau`·`SkewerShowdown.luau`(파티클·조명을 이름으로 붙이는 기존 패턴), `LobbyFxController.luau`(클라이언트 로컬 애니메이션 선례 — 로비 회전 접시), `tests/map-art-arena.spec.luau`의 `countNamed` 헬퍼(파티클·조명 예산 테스트 패턴)
- 담당 개발 worktree: `m5-mapquality` (Rojo 포트 34881)
- 공용 파일 수정 담당: **이 스펙 (developer, 아래 "공용 파일 변경" 참고)** — `src/client/init.client.luau`에 새 컨트롤러 등록 한 줄만. 병렬로 이 파일을 건드리는 다른 M5 스펙이 지금 없어 충돌 없음(의존 없음, 바로 시작 가능).
- 의존: 없음 (신규 맵 m5-13~19와 독립적)

## 배경 — 메타데이터 가정 수정
작업 지시에는 "`*Art.luau` 파일만 수정, 공용 파일 아님"이라고 돼 있었지만, 실제 코드를 읽어 보니 **파티클(`ParticleEmitter`)·조명(`PointLight`)은 `DecorSpec`(순수 데이터)에 없는 필드라 `<Map>Art.luau`만으로는 못 붙인다.** 기존 `hot-plate`·`skewer-showdown`도 `HotPlateArt.luau`/`SkewerShowdownArt.luau`에 이름 상수(`STEAM_VENT`, `HOOD_LAMP`, `LANTERN`)만 두고, 실제 `Instance.new("ParticleEmitter"/"PointLight")`는 **`HotPlate.luau`/`SkewerShowdown.luau`의 `buildArt` 함수**(그 맵 전용 파일, `shared/maps/init.luau`가 아님)에서 `MapKit.buildDecor`가 만든 파츠를 이름으로 찾아 붙인다. 이 스펙도 같은 패턴을 따른다: `<Map>Art.luau` + 그 맵의 `<Map>.luau`(둘 다 "공용 파일" 목록에 없는, 맵 전용 모듈) 두 파일을 같이 고친다. CLAUDE.md의 "공용 파일" 목록(`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/Attributes.luau`, `shared/maps/init.luau`, `shared/maps/MapTypes.luau`, `default.project.json`, `src/server/init.server.luau`, `src/client/init.client.luau`, `rokit.toml`)에는 해당하지 않는다 — 단, 클라이언트 로컬 애니메이션(방향 4) 때문에 `src/client/init.client.luau`는 한 줄 건드린다(아래 "공용 파일 변경" 참고).

## 목표
판정·수치를 그대로 두고, 완료된 맵 6개 중 `ramen-rapids`·`rotating-belt`·`soy-swamp`·`chef-board`·`hot-plate` 5개의 **장식만** 보강해 "정적인 색칠된 상자" 느낌을 줄인다. `skewer-showdown`은 이미 장식 밀도(~37곳)와 조명(등롱)이 충분해 이번 패스에서 제외한다(제안서 §1 W1·W2 표 근거).

## 범위
맵 6개를 전부 한 스펙에 넣되, 맵마다 받는 처리는 다르다(제안서 §2의 1~5번 방향을 맵별로 배분). 전부 **판정 지오메트리·장애물 수치는 그대로**, `MapTypes.validate`와 기존 순수 로직 테스트(`tests/map-art-race.spec.luau`, `tests/map-art-arena.spec.luau`, `tests/map-chef-board.spec.luau`, `tests/map-ramen-rapids.spec.luau` 등)가 그대로 통과해야 한다.

| 맵 | 받는 처리 | 비고 |
|---|---|---|
| `rotating-belt` | ① 파티클·조명 + ④ 클라이언트 로컬 애니메이션(손님 눈 깜빡임) + ⑤ 반전 샷 | 0/0 → 조명 3·파티클 2 |
| `soy-swamp` | ① 파티클·조명 + ③ 안개 상자 + ⑤ 반전 샷 | 0/0 → 조명 2·파티클 3 |
| `chef-board` | ① 파티클·조명 + ③ 안개 상자 | 0/0 → 조명 3·파티클 1(원샷) |
| `ramen-rapids` | ② 밀도 보강 + ③ 안개 상자 | 가장 단조로움(~15곳) |
| `hot-plate` | ④ 클라이언트 로컬 애니메이션(간장병 흔들림)만 | 파티클·조명은 이미 있음 |
| `skewer-showdown` | **제외** | 이미 밀도(~37곳)·조명(등롱) 충분 |

- 포함: 위 표의 처리, `MapDecorTags`(새 공유 모듈, 파츠 이름이 아니라 CollectionService 태그로 클라이언트가 장식을 찾게 함), `MapDecorFxController`(새 클라이언트 컨트롤러, 로컬 애니메이션 전담), 각 맵의 budget 테스트 확장.
- 제외: 판정 지오메트리·장애물 수치·시간 제한·스폰 배치 변경, `skewer-showdown` 변경, 전역 `Lighting`/`Atmosphere` 변경(`LobbyService.applyLighting`은 그대로), 새 소리 id(기존 `MapSfx` 큐만 재사용, 새 큐 없음).

## 설계

### 공통: 새 파일 `src/shared/maps/MapDecorTags.luau` (공용 파일 목록 아님, 이 스펙이 새로 만듦)
클라이언트가 어떤 아레나에서 만들어졌든(한 플레이스 모드의 여러 방 포함) 장식 애니메이션 대상 파츠를 찾을 수 있게 `CollectionService` 태그 이름 상수만 모아 둔다 (파츠 자체 이름은 이미 여러 맵이 재사용해서 겹칠 수 있음 — 예: "Lantern"이 `rotating-belt`·`soy-swamp`·`skewer-showdown`에 전부 있음).
```lua
-- Roblox API 없음, 상수만
MapDecorTags.EyeBlink = "MapDecorEyeBlink"   -- rotating-belt 손님 얼굴 눈
MapDecorTags.Wobble = "MapDecorWobble"       -- hot-plate 선반 간장병
```

### 방향 ① 빠진 파티클·조명 채우기
`<Map>.luau`의 `buildArt`에서 `MapKit.buildDecor` 결과를 돌며 이름이 맞는 파츠에 `Instance.new`로 붙인다 (`HotPlate.luau`/`SkewerShowdown.luau`와 같은 패턴). `<Map>Art.luau`에 이름 상수를 추가(기존 `HotPlateArt.STEAM_VENT`/`SkewerShowdownArt.LANTERN`과 같은 관례)한다.

- **`rotating-belt`**: `RotatingBeltArt.addLanterns`가 만드는 "Lantern" 파츠(z = -24, -60, -90, 3개) 각각에 `PointLight`(주황 `Color3.fromRGB(255,170,120)`, `Brightness` 1.2, `Range` 25) — 기본값. `RotatingBeltArt.LANTERN = "Lantern"` 상수로 노출. 병목(Narrow) 구간의 `SoyDishSauce` 파츠(각 변 3개 중 맨 앞 1개씩, 2곳) 위에 약한 `ParticleEmitter`(간장 표면 반짝임, `Rate` 1~2, 느린 상승, `Transparency` 높게)를 붙인다 — `RotatingBeltArt.SOY_GLINT = "SoyDishSauce"`로 이름 재사용 가능하면 그대로, 겹치면 새 이름 파츠 추가.
- **`soy-swamp`**: 간장 웅덩이 3곳(`Layout.PUDDLES`) 표면에 느린 보글거림 `ParticleEmitter`(위로 천천히, `Rate` 1, `Lifetime` 2~3초) — 웅덩이마다 "SoyRim" 안쪽에 보이지 않는 작은 앵커 파츠를 하나씩 추가하거나 `SoyDishSauce`류 기존 파츠에 붙인다. 와사비 산 꼭대기 "HillRice"(양옆 2개) 파츠에 `PointLight`(연두 `Color3.fromRGB(150,230,70)`, `Brightness` 1, `Range` 20).
- **`chef-board`**: 머리 위 매달린 등 3개("LampBulb", 이미 `Neon` 재질) 전부에 `PointLight`(따뜻한 노랑 `Color3.fromRGB(255,232,170)`, `Brightness` 1, 가운데(x=0)는 `Range` 30·양옆(x=±26)은 `Range` 18 — 가운데가 "도마 중앙 조명"). 칼(`Blade`)에 `ParticleEmitter`(불꽃, `Enabled = false`, `Rate` 0)를 미리 하나 만들어 두고, `strike` 함수가 칼이 `KNIFE_STRIKE_HEIGHT`에 닿는 순간(기존 `movePivot(..., true)` 호출 직후) `emitter:Emit(10~15)`로 한 번만 터뜨린다 — 상시 파티클이 아니라 예산에 거의 영향 없음(파츠·인스턴스 1개).

### 방향 ② 장식 밀도 보강 (`ramen-rapids`, 제안서 §2-2)
`RotatingBeltArt.addCounterItem`처럼 "작은 소품 + 변형 몇 종을 루프로 반복"하는 헬퍼를 이식한다. `RamenRapidsArt.decor()`에 새 함수 `floatingGarnish(list)`를 추가해 급류 양옆(기존 `floatingToppings`와 같은 좌표 대역, |x| ≥ 30)에:
- 다시마(김과 다른 색, 짙은 녹색 띠) 조각 12개
- 통깨 점(작은 검은 공) 20개 (초저비용 — 지름 0.3 안팎)
- 젓가락 받침(작은 도자기 조각) 6개
총 +38곳 추가. 기존 ~15개 호출 지점 + 밥알·토핑류 합쳐 실제 파츠 수는 충분히 늘지만(현재 어림 ~160개), 예산(600)에는 한참 못 미친다 — AC에서 숫자로 확인한다.

### 방향 ③ 지역 안개 상자 (`soy-swamp`·`ramen-rapids`·`chef-board`, 제안서 §2-3)
맵 바깥 멀리에 아주 크고 옅은 반투명 색 패널 3~4개를 둘러 "이 맵만의 색안개"를 흉내 낸다. 충돌 없음(기존 장식 규칙), 코스 안에는 두지 않음(`courseVolume`/`courseVolumes`와 안 겹치는지 AC로 확인), 파츠 수 3~4개뿐이라 예산 영향 거의 없음.
- **`soy-swamp`**: 간장·나무 톤 갈색-호박색(`{ r = 90, g = 55, b = 30 }`), `Transparency` 0.9.
- **`ramen-rapids`**: 국물 금빛(`{ r = 200, g = 140, b = 60 }`), `Transparency` 0.88(이미 국물 자체가 반투명이라 더 옅게).
- **`chef-board`**: 주방 차가운 청회색(`{ r = 150, g = 170, b = 190 }`), `Transparency` 0.92(스테인리스·타일 배경과 어울리게).

### 방향 ④ 클라이언트 로컬 애니메이션 (`rotating-belt`·`hot-plate`, 제안서 §2-4)
`LobbyFxController`의 "서버는 고정, 클라이언트가 로컬로 움직인다" 패턴(`workspace:GetServerTimeNow()`로 결정적 애니메이션, `RunService.RenderStepped`, 거리 컬링)을 그대로 따르되, 로비는 고정된 `workspace.Lobby` 폴더를 찾는 반면 맵은 한 플레이스 모드에서 방마다 다른 좌표에 아레나가 뜨므로(`Config.Arena`) **고정 경로로 찾을 수 없다** → `CollectionService` 태그로 찾는다(태그는 서버 파츠에 붙여도 기본적으로 클라이언트에 복제됨).

- **새 클라이언트 컨트롤러** `src/client/fx/MapDecorFxController.luau`: `CollectionService:GetTagged(MapDecorTags.EyeBlink)`·`GetTagged(MapDecorTags.Wobble)`를 주기적으로(또는 `GetInstanceAddedSignal`/`GetInstanceRemovedSignal`로) 추적하고, `RunService.RenderStepped`에서 각 파츠의 `Transparency`(눈 깜빡임 — 짧게 1로 깜빡)나 `CFrame`(병 흔들림 — 작은 각도로 좌우) 전용 로컬 오프셋만 바꾼다. 서버 `CFrame`/`Size`는 절대 바꾸지 않는다(판정과 무관한 장식이라 되돌릴 "원래 값"을 기준으로 로컬 오프셋만 얹는다). 로비와 같은 거리 컬링(카메라에서 멀면 매 프레임 갱신을 건너뜀) 적용.
- **`rotating-belt`**: `addFace`가 만드는 "FaceEye"(얼굴당 2개 × 3얼굴 = 6개)에 `MapDecorTags.EyeBlink` 태그. 2~4초마다 한 번 0.15초간 `Transparency`를 1로 올렸다 되돌리는 깜빡임(눈마다 위상 다르게, `os.clock()` 기반 의사 난수 오프셋으로 전부 동시에 깜빡이지 않게).
- **`hot-plate`**: 선반 위 "SauceBottle"(3개)에 `MapDecorTags.Wobble` 태그. ±3도 안팎으로 천천히 좌우로 흔들리는 로컬 회전(사인파, 병마다 다른 주기).

### 방향 ⑤ `IntroCamera` 반전 샷 (`rotating-belt`·`soy-swamp`, 제안서 §2-5)
기존 경유점 목록(둘 다 4점)에 **새 점을 하나씩 추가**(5점이 됨) — `Config.Flow.IntroDuration`은 점 개수와 무관하게 고정 3초라서(`IntroCameraLogic`/`IntroController`가 경로를 비율로 나눔) 소개 연출 길이는 변하지 않는다, 구간 배분만 조금 달라진다.
- **`rotating-belt`**: 병목(Narrow, z ≈ -60) 바로 위 높은 곳(y ≈ 32)에서 아래로 내려다보는 샷을 기존 2번째 점(병목→젓가락)과 3번째 점(결승 노렌) 사이에 끼워 넣는다.
- **`soy-swamp`**: 와사비 산 정상(z ≈ -88) 위(y ≈ 36)에서 내려다보는 샷을 기존 2번째(와사비 패드→절벽)와 3번째(날치알 내리막→결승) 사이에 끼워 넣는다.

## 수용 기준

### 순수 로직 (lune 테스트)
- [ ] AC1: `rotating-belt`·`soy-swamp`·`chef-board`·`ramen-rapids` 4개 맵의 `decor()`가 전부 `MapKitLogic.validate` 통과, `MapKitLogic.count(...) <= DECOR_PART_BUDGET`(600). (`skewer-showdown`·`hot-plate`는 장식 데이터 자체를 바꾸지 않으니 기존 테스트가 그대로 통과하면 됨.)
- [ ] AC2: 새 이름 상수(`RotatingBeltArt.LANTERN`, soy-swamp·chef-board의 등가 상수)로 `countNamed`(기존 `tests/map-art-arena.spec.luau` 헬퍼와 같은 패턴을 각 맵 테스트 파일에 추가)를 셌을 때: `rotating-belt` 조명 3·파티클 2, `soy-swamp` 조명 2·파티클 3, `chef-board` 조명 3·파티클 1 — 각각 `MapKitLogic.LIGHT_BUDGET`(12)·`PARTICLE_BUDGET`(8) 이하.
- [ ] AC3: `ramen-rapids`의 새 `floatingGarnish` 추가분(다시마 12 + 통깨 20 + 젓가락 받침 6 = 38)이 `decor()` 목록에 들어 있고, 전체 파츠 수가 여전히 600 이하다.
- [ ] AC4: 세 맵(`soy-swamp`·`ramen-rapids`·`chef-board`)의 새 안개 상자 파츠(3~4개씩)가 `courseVolume`/`courseVolumes`가 돌려주는 시야 상자들과 겹치지 않는다(기존 `checkNoOverlap`류 헬퍼 재사용).
- [ ] AC5: `rotating-belt`·`soy-swamp`의 `introCamera()`가 각각 5개 경유점을 돌려준다(기존 4 + 반전 샷 1). 기존 점 4개의 `pos`/`lookAt` 값은 그대로다(새 점은 삽입만, 기존 좌표 수정 아님).
- [ ] AC6: `MapDecorTags.luau`가 `EyeBlink`·`Wobble` 두 문자열 상수를 내보내고 서로 다르다. Roblox API 없이 require만으로 동작(lune에서 바로 테스트 가능).
- [ ] AC7: 검증 5단계(`rojo build`, `stylua --check`, `selene`, `lune run tests`, `luau-lsp analyze`) 전부 통과 + 기존 `tests/map-art-race.spec.luau`·`tests/map-art-arena.spec.luau`·`tests/map-chef-board.spec.luau`·`tests/map-ramen-rapids.spec.luau`·`tests/round-logic*.spec.luau`가 전부 그대로(수정 없이) 통과한다 — 판정·스폰·시간 제한이 하나도 안 바뀌었다는 증거.

### Studio 확인
- [ ] AC8: `forceMapPlan = { "rotating-belt", "soy-swamp", "chef-board", "ramen-rapids", "hot-plate" }`로 다섯 라운드를 혼자(Play Solo) 돌며 맵마다: 등불·와사비 산 꼭대기·도마 머리 위 등이 실제로 빛나 보인다(파츠 색만이 아니라 주변 바닥에 빛이 번짐), 간장 웅덩이·병목 간장 종지에서 작은 파티클이 보인다, 칼이 내려찍는 순간 불꽃이 한 번 튄다.
- [ ] AC9: `ramen-rapids`에서 급류 양옆이 이전보다 눈에 띄게 덜 비어 보인다(다시마·통깨·젓가락 받침이 코스를 가리지 않고 양옆에 보임).
- [ ] AC10: `soy-swamp`·`ramen-rapids`·`chef-board`에서 맵 바깥 멀리 옅은 색안개 패널이 보이되, 코스 진행이나 시야(장애물·결승선 확인)를 가리지 않는다. 세 맵이 서로 다른 색 분위기로 구분된다.
- [ ] AC11: `rotating-belt`에서 카운터 너머 손님 얼굴의 눈이 이따금 깜빡인다(세 얼굴이 동시에 깜빡이지 않는다). `hot-plate`에서 선반 위 간장병 3개가 천천히 좌우로 흔들린다. 둘 다 **서버 Output에 복제 관련 경고가 없다**(클라이언트 로컬 변경이라 네트워크 비용이 없어야 함 — 여러 명(Clients and Servers 2+)이 봐도 서버 스크립트 성능에 영향이 없는지 확인).
- [ ] AC12: `rotating-belt`·`soy-swamp`의 라운드 소개 플라이스루에서 새 반전 샷(위에서 아래로 내려다봄)이 자연스럽게 끼어든다 — 카메라가 지오메트리를 뚫고 지나가거나 갑자기 튀지 않는다. 전체 소개 길이는 여전히 `Config.Flow.IntroDuration`(3초)이다.
- [ ] AC13: 예산 초과 경고(`[MapKit] decor has N parts (budget 600)` 또는 파티클·조명 관련 `warn`)가 Output에 없다.
- [ ] AC14: 기존 플레이 감각 회귀 없음 — 다섯 맵 전부 낙하·결승선·탈락 판정이 패스 전과 똑같이 동작한다(장식만 바뀌었다는 걸 체감으로도 확인).

## 공용 파일 변경
- `src/client/init.client.luau`: `CONTROLLERS` 목록에 `require(script.fx.MapDecorFxController)` 한 줄 추가(주석 "m5-20 맵 장식 로컬 애니메이션"). 이 스펙의 developer가 직접 고친다 — 지금 병렬로 이 파일을 건드리는 다른 M5 스펙이 없어 충돌 위험 없음.
- `shared/Config.luau`·`shared/Remotes.luau`·`shared/Types.luau`·`shared/Attributes.luau`·`shared/maps/init.luau`·`shared/maps/MapTypes.luau`·`default.project.json`·`src/server/init.server.luau`·`rokit.toml`: 변경 없음.

## 사용자 작업 (스펙을 막지 않음)
- AC8~AC14 Studio 체감 확인(색·밝기·흔들림 정도가 과하거나 약하면 수치는 "기본값, 플레이테스트 후 조정"이라 알려 주면 바로 조정).
- 새 소리 id 없음(기존 `MapSfx` 큐 재사용만).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · D1 6개 맵을 한 스펙에 다 넣을지 · **5개 포함(`skewer-showdown` 제외), 한 스펙으로 진행**. 근거: `skewer-showdown`은 제안서 §1 W1·W2 진단에서 이미 밀도(~37곳)·조명(등롱)이 충분한 유일한 맵이라 손댈 이유가 약하고, 나머지 5개는 전부 판정 불변·장식만 바꾸는 같은 성격의 작업이라 worktree 하나(`m5-mapquality`)로 묶는 게 리뷰·QA 효율이 좋다. 맵별 처리 깊이는 "범위" 표로 차등을 둬서 과투자를 막았다. · planner
- 2026-10-09 · D2 파티클·조명을 어디서 붙일지(`*Art.luau`만으로 될지) · **안 됨 — `DecorSpec`에 `ParticleEmitter`/`PointLight` 필드가 없어서 `<Map>.luau`의 `buildArt`도 같이 고쳐야 함**(기존 `HotPlate.luau`/`SkewerShowdown.luau`가 이미 그렇게 함). 작업 지시의 "Art.luau만 수정" 가정을 코드 확인 후 정정함. 둘 다 "공용 파일" 목록 밖이라 소유권 문제는 없음. · planner
- 2026-10-09 · D3 클라이언트 로컬 애니메이션을 어떻게 여러 아레나에 적용할지 · 로비처럼 고정 `workspace` 경로를 못 쓰므로(방마다 다른 좌표) **`CollectionService` 태그**로 찾는 새 공유 모듈 `MapDecorTags.luau` + 새 클라이언트 컨트롤러 `MapDecorFxController.luau`를 추가. `src/client/init.client.luau`에 등록 한 줄이 필요해 "공용 파일 변경"에 명시하고 이 스펙 담당으로 뒀다(병렬 충돌 없음). · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
