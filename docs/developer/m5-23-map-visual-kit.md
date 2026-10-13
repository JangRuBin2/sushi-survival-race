# m5-23 map visual kit + preview renderer — 개발 작업 기록

## 2026-10-13 — QA 수정 (최신)
- QA 리포트 B1~B6 + Lune `CFrame.lookAt` 버그 우회(렌더러 shim). 자세한 내용은 스펙 "개발 메모"의 "QA 수정". 스펙 `in-qa`로.
- **다음 첫 단계**: QA 재확인(B1 테스트, `KNOWN_INTRO_OUTSIDE` 빈 표). 아트 에이전트는 intro 렌더를 다시 뽑아야 해요(이전 intro는 방향이 틀렸음).
- 막힌 점 없음. CornerWedge 방향 Studio 확인은 여전히 남음.

## 2026-10-13 — 구현 완료, in-qa
- **브랜치**: `main` (worktree 없음, 메인 세션 허락으로 main에 직접 커밋·push). 코드 커밋 `3b20944`, 문서 커밋은 그다음.
- **끝난 것**: 스펙 설계 A~D 전부, AC1~AC13(순수 로직 + 렌더러 명령 확인). Studio AC14~AC18은 사용자/QA 차례.
  - **렌더러** `tools/render-map.luau` + `tools/render/`(`Shims` 가짜 Roblox 환경·모듈 로더, `Scene` 파츠→삼각형·조명·파티클·빔 수집, `Raster` 래스터라이저·그림자 지도·하늘 가림 지도·블룸·톤매핑·색 보정, `Materials` 재질 근사, `Png` 인코더). 사용법은 `docs/DEV-SETUP.md` 2-1.
  - **장식 확장** `MapKitLogic`(CornerWedge·reflectance·castShadow·light·particle·particleRate·anim, BUDGETS Standard/Extended, count*·checkBudget·resolveCastShadow, 팔레트 단계 색 + 새 테마 색, shade/shades/mix), `MapKit`(buildDecor가 새 필드 처리, `makeEmitter`·`makeLight` 공개), 새 `MapFxPresets`(12종), `MapKitShapes`(roundedBox·bevelBox·rimDisc·ring·capsule·lipTrim·scatter·transform), `MapDecorAnimLogic`, `MapDecorTags`(Anim·Arena 태그, Anim 속성 이름).
  - **조명** 새 `MapLighting`(validate·resolve·lerp·LOBBY·PRESETS 6개), `MapLightingLogic`(pickArena 40/80 히스테리시스·blendAlpha 1.2초), `MapTypes.lighting`, 기존 맵 6개 `lighting = MapLighting.PRESETS[ID]`, `RoundService`가 맵 Model에 `MapDecorTags.Arena` 태그(속성 `MapId`는 원래 있음 — `Attributes` 안 고침), 클라이언트 `MapLightingController`(init.client 등록), `MapDecorFxController`가 Anim 태그 처리, `default.project.json` Lighting(Technology Future·LightingStyle Realistic·PrioritizeLightingQuality — Rojo 7.7.1이 받아 줌, build.rbxl에서 확인), `.gitignore`에 `build/`.
  - 테스트 `tests/m5-23-visual-kit.spec.luau` (AC1~AC9, 14개).
- **검증**: `rojo build` OK, `stylua --check src tests tools` OK, `selene src` 0/0/0, `lune run tests` 1247 passed / 0 failed, `luau-lsp analyze` 끝 코드 0. `lune run tools/render-map all` 15개 맵 전부 성공(3분 25초, high).
- **남은 것**: QA, Studio AC14~AC18 (`docs/DEV-SETUP.md` 3-11). m5-24(기존 맵 아트 v2)와 m5-04~06 아트 패스가 이 키트를 씀.
- **다음에 할 첫 단계**: QA가 `lune run tools/render-map all`로 렌더·stats를 보고, Studio에서 3-11 순서로 Future·조명 전환·방 2개 동시 확인.
- **막힌 점**: 없음. Studio가 없어 실제 Future 화면·전환 체감은 확인 못 함.

### 메모 (다음 사람이 알아야 할 것)
- **Lune 한계와 우회** (`tools/render/Shims.luau`): `BasePart.Position`은 Lune 반사 DB에 기본값이 없어 읽으면 에러이고 `implementProperty`로도 못 덮어요(DB가 우선). 그래서 모듈 소스의 `<이름>.Position` **읽기**를 `__pos(<이름>)`로 바꿔 불러요(쓰기 `.Position =`는 그대로). `Model:PivotTo/GetPivot/GetBoundingBox`는 `implementMethod`로 보충. 새 맵이 다른 API를 쓰면 에러 메시지에 이름이 나오니 여기에 보태면 돼요.
- **origin**은 실제 게임 1번 슬롯 `CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)`.
- **CornerWedge 방향은 가정**: 렌더러는 꼭대기를 로컬 (+X, 위, -Z)로 그리고, `MapKitShapes.bevelBox`의 귀퉁이 회전(`CORNER_YAW`)도 그 가정으로 맞췄어요. Studio에서 처음 확인할 때 어긋나면 `Scene.cornerWedge`와 `CORNER_YAW` 두 곳만 고치면 돼요(3-11의 5번).
- **castShadow 기본이 바뀜**: `castShadow`가 nil인 장식은 가장 긴 변 < 3이면 그림자를 안 만들어요(스펙 B). 기존 맵의 작은 소품 그림자가 사라지는 건 의도.
- **anim은 움직이는 판정 파츠에 붙은 장식에 쓰지 않기**(스펙): 클라이언트가 처음 본 CFrame을 기준으로 오프셋을 얹어서, 서버가 그 파츠를 옮기면 덮어써요.
- **렌더러 결과를 볼 때**: intro·eye의 `void%`가 높으면 빈 공중이 보이는 것. overview·top은 떠 있는 아레나라 원래 높아요. m5-20 안개 패널(Glass 0.9)과 출발 유리벽이 eye 뷰를 뿌옇게 만드는 게 실제로 보여요(soy-swamp·ramen-rapids) — 스펙 D2대로 새 맵은 안개 패널 대신 `lighting`의 Atmosphere를 쓰면 돼요.
- `tests/m4-12-hardening.spec.luau`의 "모듈 전역 표마다 지우는 곳" 정적 검사 때문에 `MapLightingController`에 캐시 표를 두지 않았어요(바뀔 때만 resolve).
- 조명 프리셋 값은 스펙 표의 초안 + 렌더러로 본 첫 조정(hot-plate 밤이 너무 어두워 Ambient를 올림). m5-24에서 Studio로 다듬어요.
