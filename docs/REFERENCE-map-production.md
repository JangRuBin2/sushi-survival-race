# 맵 제작 고도화 리서치 (M4 참고용)

> **이 문서는 M4(아트 맵 단계) 고도화를 위한 리서치 자료이며, 지금 당장 MVP 워크플로우를 바꾸지 않는다.** 현재(M1~M3)는 `CLAUDE.md`에 적힌 대로 "코드로 회색 박스를 생성"하는 방식을 그대로 유지한다. 이 문서는 선택지와 트레이드오프를 정리한 것이지, 결정을 대신 내리지 않는다 — 실제 채택 여부와 조합은 M4 착수 시점에 사용자가 정한다.

---

## 1. Roblox Studio 자체 맵 제작 도구

코드/에이전트 워크플로우와 병행 가능한 스튜디오 내장·플러그인 도구들.

| 레퍼런스 | 요약 |
|---|---|
| [Terrain Editor (공식 문서)](https://create.roblox.com/docs/studio/terrain-editor) | 지형 생성·조각 공식 툴셋(Generate/Edit 탭). 코드에서도 `Terrain:FillRegion` 등으로 스크립트 조작 가능해서, 수작업 다듬기와 절차적 생성을 섞을 수 있음. |
| [Environmental terrain (공식 문서)](https://create.roblox.com/docs/parts/terrain) | Terrain API 레퍼런스. 코드로 지형을 다루고 싶을 때(절차적 접근) 근거가 되는 문서. |
| [Atlas Studio — Node-Based Procedural Terrain](https://devforum.roblox.com/t/plugin-atlas-studio-%E2%80%94-node-based-procedural-terrain-for-roblox-studio/4802748) | 노드 그래프로 지형을 절차적으로 스케치하는 플러그인. 코드 없이 재사용 가능한 "지형 그래프"를 만들 수 있어 그레이박스보다 한 단계 위 완성도를 노릴 때 참고할 만함. |
| [Odyssey Terrain Editor](https://devforum.roblox.com/t/odyssey-terrain-editor-procedural-triangle-terrain-plugin/4646900) | 대규모 스타일화된 지형을 빠르게 생성하는 절차적 플러그인 + 브러시 보정 도구. 오픈월드/서바이벌류 지향. |
| [Surface Studio](https://devforum.roblox.com/t/surface-studio-a-terrain-generator-plugin3e7e2e4e/4627097) | 청크 크기·높이·수위·재질·바이옴·식생·소품까지 다루는 고급 지형 생성기. |
| [Building Tools by F3X (Creator Store)](https://create.roblox.com/store/asset/142785488/Building-Tools-by-F3X) / [GitHub](https://github.com/F3XTeam/RBX-Building-Tools) | 가장 널리 쓰이는 인게임 빌딩 툴(이동/크기/회전/용접 등 14종 도구). 2025년에도 유지보수 중. 수작업으로 디테일을 다듬을 때 표준적인 선택지. |
| [Archimedes 3 — A building plugin](https://devforum.roblox.com/t/introducing-archimedes-3-a-building-plugin/1610366) | 시드 파츠 + 각도로 곡선(도로, 파이프, 나선 계단 등)을 자동 계산해 생성. 회전 벨트처럼 원형/곡선 구조물을 수작업으로 다듬을 때 피벗 계산을 대신해줌. |

**참고**: Toolbox(커뮤니티 에셋 마켓)는 검색 결과에서 구체적 레퍼런스를 찾지 못했지만, 공식 기능으로 라이선스·품질이 에셋마다 달라 상업 배포 전 라이선스 확인이 필요하다는 점은 일반 상식 수준에서만 언급해둔다 (이번 리서치에서 직접 출처를 확인하지 못함).

---

## 2. 외부 3D 툴 → Roblox 파이프라인 (Blender)

| 레퍼런스 | 요약 |
|---|---|
| [Blender (공식 Roblox Creator Docs)](https://create.roblox.com/docs/art/blender) | Roblox가 공식으로 안내하는 Blender 연동 문서. |
| [How To Export a Blender File to Roblox (FBX Guide)](https://nilo.io/articles/export-from-blender-to-roblox-3) | 구체적인 내보내기 설정값 포함: Apply Transforms(Ctrl+A), 카메라/조명 제거, `Selected Only` 체크, Path Mode = Copy, Embed Textures 체크, Apply Scalings = FBX Unit Scale, Forward = -Z Forward / Up = Y Up. 텍스처는 1024×1024 이하 권장, Pack Resources로 임베드. |
| [How To Import an FBX Into Roblox Studio](https://nilo.io/articles/import-fbx-into-roblox-studio) | 워크스페이스 우클릭 → Import 3D 또는 Asset Manager로 일괄 임포트. Import Preview 창에서 스케일/방향/텍스처를 가져오기 전에 검증하는 루프(준비→내보내기→임포트→검증→수정) 제안. |
| [Roblox Studio Custom Model Import: Fix Common Errors](https://nilo.io/articles/roblox-studio-custom-model-import) | 흔한 실패 사례(크기 이상, 옆으로 눕는 문제, 회색 텍스처, 업로드 거부)와 원인 매핑. |

**주의할 점 (요약)**
- 스케일: Blender와 Roblox의 단위 체계가 달라 Apply Scalings/Forward-Up 설정을 안 맞추면 모델이 깨짐.
- 폴리곤 수: 아래 3번 표 참고 (환경 메시 2만 트라이 상한).
- 콜리전: 임포트 후 `CollisionFidelity`를 따로 설정해야 함 (기본값이 항상 적절하지 않음).

---

## 3. 메시 임포트 제한과 콜리전 설정

| 레퍼런스 | 요약 |
|---|---|
| [How to Optimize 3D Models for the Roblox Polygon Limit](https://nilo.io/articles/optimize-3d-models-roblox-limit-2) | Roblox는 MeshPart당 최대 21,000 트라이앵글 하드 리밋. 임포트 시 아바타/캐릭터는 1만, 환경 메시는 최대 2만 트라이 권장. 모바일 고려하면 반복 배치되는 오브젝트는 1만 이하 권장. |
| [What is the Roblox MeshPart polygon limit? (alpha3d.io)](https://www.alpha3d.io/knowledge-base/roblox-meshpart-polygon-limit) | 위와 동일한 수치를 다른 출처에서 교차 확인. |
| [Advanced Roblox Custom Meshes: PBR, Rigging & LOD](https://nilo.io/articles/advanced-roblox-custom-meshes) | `CollisionFidelity` 옵션별 비용: Box(가장 저렴, 사각형 소품) → Hull(불규칙한 형태) → PreciseConvexDecomposition(가장 비쌈, 플레이어가 밟고 다니는 굴곡진 바닥 등에만). |
| [Importing large obj file with useless collision results (devforum)](https://devforum.roblox.com/t/importing-large-obj-file-with-useless-collision-results/446873) | 큰 OBJ를 그대로 임포트하면 콜리전이 쓸모없어지는 실제 사례 — 분할 임포트나 수동 콜리전 박스가 필요함을 보여주는 스레드. |

**이 프로젝트 관련 메모**: 회전 벨트 같은 장애물 레이스 맵은 플레이어가 바닥 전체를 밟고 달리므로, 아트 맵으로 바꿀 때 바닥/경사로는 `PreciseConvexDecomposition`이 필요할 수 있고, 장식용 소품(접시, 간장병 등)은 `Box`/`Hull`로 충분히 저렴하게 처리 가능 — 성능 예산을 부위별로 다르게 가져갈 수 있다.

---

## 4. AI 이미지 → 레벨 디자인 레퍼런스 활용

| 레퍼런스 | 요약 |
|---|---|
| [Introducing Roblox Cube — Core Generative AI System for 3D](https://about.roblox.com/newsroom/2025/03/introducing-roblox-cube) | Roblox가 자체적으로 1.8B 파라미터 3D 생성 파운데이션 모델(Cube 3D)을 발표. 150만 개 3D 에셋으로 학습. |
| [[Beta] Cube 3D Generation Tools and APIs for Creators (공식 devforum 공지)](https://devforum.roblox.com/t/beta-cube-3d-generation-tools-and-apis-for-creators/3558947) | Studio 안에서 Assistant에 `/generate 설명` 입력으로 텍스트→3D 메시 생성. 현재는 **단일 오브젝트만** 지원(파츠 조합/씬 생성은 예정), 경험당 분당 5회 생성 제한, 스케일 수동 조정 필요, 텍스처 품질 개선 여지 있음, 베타 기간엔 무료. Editable Mesh/Image API를 보안 설정에서 켜야 함(계정 인증 필요). |
| [AI Tools for Roblox 2026 개관 (3daistudio.com)](https://www.3daistudio.com/blog/best-ai-tools-for-roblox-2026) | Meshy, Tripo 등 외부 text-to-3D/image-to-3D 툴을 Roblox 워크플로우에 쓰는 사례 정리. "AI는 터레인/레이아웃이 아니라 소품(props)·장식(dressing)을 만드는 데 쓰인다"는 관찰이 핵심. |
| [Meshy AI — Free Game Assets for Roblox](https://www.meshy.ai/use-cases/free-game-assets/roblox-developers) | 이미지/텍스트 → 3D 변환 서비스. 컨셉 이미지를 먼저 만들고 image-to-3D로 넘기는 흐름 소개. |
| [Nano Banana (Gemini 2.5/3 Flash Image) 개요 — DigitalOcean](https://www.digitalocean.com/resources/articles/nano-banana) | "나노 바나나"의 정체 확인: Google Gemini의 이미지 생성 모델 코드네임. 텍스트→이미지, 이미지 리믹스/편집, 여러 레퍼런스 합성 지원. |
| [Gemini 3 Pro Image (공식)](https://deepmind.google/models/gemini-image/pro/) | 최신 버전 공식 소개 페이지 (캐릭터/장면 일관성 유지가 강점으로 언급됨 — 같은 맵의 여러 각도 컨셉아트를 뽑을 때 유용할 수 있음). |

**직접적인 "Roblox 개발자가 AI 이미지 컨셉아트를 보고 Studio에서 그레이박스/아트 맵을 만든 사례"를 다룬 DevForum 글이나 영상은 이번 검색에서 명확히 찾지 못했다.** 대신 확인된 것은 (a) Roblox 자체가 Cube 3D로 텍스트→3D 생성을 Studio에 내장했다는 점, (b) 업계 전반에서 "AI 이미지로 컨셉 레퍼런스를 먼저 뽑고 3D/레벨은 그 레퍼런스를 보고 사람이 만든다"는 흐름이 일반적인 게임 개발 워크플로우로 소개되고 있다는 점이다. Roblox 특화 사례가 아직 커뮤니티에 많지 않은 것은, 이 기능(Cube 3D)이 2025년 3월에 나온 비교적 최근 기능이기 때문일 수 있다.

---

## 5. 재사용 가능한 구조물 컴포넌트화 패턴

| 레퍼런스 | 요약 |
|---|---|
| [Assemble modular environments (공식 Roblox Creator Docs)](https://create.roblox.com/docs/tutorials/use-case-tutorials/modeling/assemble-modular-environments) | 가장 구체적인 공식 가이드. 모듈 메시 최소 길이 7.5 stud, 최대 길이는 7.5의 배수로 통일 → 끊김 없이 연결. Move snapping 7.5 stud / Rotate snapping 45도로 설정. 피벗은 중앙이 아니라 "앞쪽 아래 모서리" 같은 연결 지점에 둬야 함. 한 번에 메시 하나씩만 옮겨야 피벗이 꼬이지 않음. **단, 이 가이드는 수작업 조립 기준이고 코드로 절차적 배치하는 내용은 없음** — 이 프로젝트의 `build(origin: CFrame)` 패턴과 결합하려면 "그리드 간격 + 피벗 컨벤션"만 가져오고 배치 로직은 직접 짜야 함. |
| [Greybox a playable area (공식 Roblox Creator Docs 튜토리얼)](https://create.roblox.com/docs/tutorials/curriculums/core/building/greybox-a-playable-area) | 그레이박스 → 플레이테스트 → 최종 아트 교체라는 표준 순서를 공식 문서로 확인. `World` 폴더 + `Blockout_Parts` 모델 구조, Align Tool로 높이 맞추기, 최소 단차 30 stud 등 수치 제시. 지금 우리 맵 모듈(`build`가 회색 박스 생성)이 이 순서의 전반부와 정확히 일치한다. |
| [(v1.0) Components — Simpler, smarter, modular components (devforum)](https://devforum.roblox.com/t/v10-components-simpler-smarter-modular-components/792902) | CollectionService 태그 대신 `Configuration` 인스턴스에 값/함수/이벤트를 저장하는 컴포넌트 라이브러리. 익스플로러에서 바로 보이고 편집 가능하다는 게 장점으로 제시됨. |
| [Obby Kit — Using Collection Service to Apply Properties to Objects for Modularity (devforum)](https://devforum.roblox.com/t/obby-kit-using-collection-service-to-apply-properties-to-objects-for-modularity/1507206) | 우리 프로젝트와 가장 비슷한 접근. 태그 5종(Stages/Lava/Swing/Conveyor/Moving)에 각각 동작을 매핑하고, Attribute로 기본값을 오버라이드(예: Conveyor의 `Speed` 속성). **이건 사실상 지금 `CLAUDE.md`에 적힌 "`CollectionService` 태그로 장애물 동작"과 거의 같은 아키텍처** — 이미 같은 방향으로 가고 있다는 교차 확인 자료로 유용. |
| [Prefab Manager — Prefabs for Roblox Studio (devforum)](https://devforum.roblox.com/t/prefab-manager-prefabs-for-roblox-studio-free/4018254) | Unity 프리팹처럼 하나를 고치면 같은 태그(`PrefabInstance_[이름]`)를 가진 모든 인스턴스가 갱신되는 플러그인. 수작업 레벨 배치 단계에서 반복 구조물(기둥, 난간 등) 일괄 수정에 유용. |
| [How to build an obby? (devforum)](https://devforum.roblox.com/t/how-to-build-an-obby/1130655) | 초심자 대상이지만 "적은 수의 범용 피스를 반복 사용하라"는 조언이 공식 모듈러 가이드와 같은 결로 반복됨. |

---

## 6. 비슷한 장르(오비/레이스/서바이벌) 게임의 맵 양산 방식

| 레퍼런스 | 요약 |
|---|---|
| [How to make an obby generator similar to Tower of Hell's? (devforum)](https://devforum.roblox.com/t/how-to-make-an-obby-generator-similar-to-tower-of-hells/1065128) | Tower of Hell류 게임의 전형적 패턴: 미리 만든 "세그먼트(스테이지)" 모델들을 `ReplicatedStorage`에 보관 → 각 세그먼트에 시작/끝 커넥터 파츠를 둠 → 라운드 시작 시 세그먼트를 무작위로 골라 `Clone()`해서 이전 세그먼트의 끝 커넥터 CFrame에 다음 세그먼트의 시작 커넥터를 맞춰 이어 붙임. **"맵을 통째로 디자인"하는 대신 "레고 블록처럼 쌓이는 조각(세그먼트) 여러 개를 사람이 공들여 만들고, 조립은 코드가 한다"**는 게 핵심 — 이 프로젝트의 "맵 모듈 하나가 통째로 회색 박스를 생성" 방식과는 결이 다른, 참고할 만한 대안 패턴. |
| [DOORS Room Generator Package (devforum)](https://devforum.roblox.com/t/doors-room-generator-package/3157691) | DOORS(LSPLASH/Red 개발, 호러 로그라이트)류 게임의 방 생성 패키지. 300줄 미만으로 희귀도 기반 랜덤 방 생성을 구현한 사례. 세그먼트 조합형 절차적 생성의 또 다른 실례. |
| [What is a good approach for room generation? (devforum)](https://devforum.roblox.com/t/what-is-a-good-approach-for-room-generation/4015405) | Wave Function Collapse, 미로 생성 알고리즘 등 더 정교한 절차적 생성 기법에 대한 커뮤니티 논의. 지금 당장 필요하진 않지만 맵 풀이 커지고 "매 판 다른 배치"까지 욕심낼 때 참고 가능. |

**참고**: Speed Run 4(Vurse 개발)에 대해서는 개발자 인터뷰나 공식 자료를 찾지 못했다. 검색된 것은 팬 위키·DevForum의 "영감받았다"류 커뮤니티 게시물뿐이라 신뢰할 만한 1차 출처로 인용하지 않았다.

---

## 7. 이 프로젝트에 적용한다면 — 선택지와 트레이드오프

사용자가 이미 "지금은 뼈대, 고도화는 기능이 정상 동작한 뒤"라고 선을 그었으므로, 아래는 **M4 시점에 고를 수 있는 선택지**이지 지금 결정할 사항이 아니다.

### (A) 컴포넌트화 — 지금 구조에서도 미리 준비해볼 여지가 있는 부분
- 현재 `shared/maps/MapTypes.luau`의 `MapModule` 인터페이스(`build`/`start`/`cleanup`)와 `CollectionService` 태그(`Chopstick`, `Wasabi`, `SoySauce`, `HotTile`) 규칙은 [Obby Kit 패턴](https://devforum.roblox.com/t/obby-kit-using-collection-service-to-apply-properties-to-objects-for-modularity/1507206)과 사실상 같은 철학이다 — 이미 올바른 방향.
- 다만 지금은 맵 하나(`RotatingBelt.luau`)가 `build()` 안에서 모든 파츠를 직접 생성한다. [Tower of Hell류 세그먼트 조합 패턴](https://devforum.roblox.com/t/how-to-make-an-obby-generator-similar-to-tower-of-hells/1065128)처럼 "벽/바닥/경사로/병목 구간" 같은 하위 조각을 별도 헬퍼 함수(혹은 `.rbxm`/프리팹 폴더)로 뽑아두면, 아트 맵으로 교체할 때 조각 단위로만 바꿀 수 있어 전환 비용이 줄어든다. **이건 지금 코드 구조에 영향이 적은 리팩터라 M4 전에 틈틈이 준비해도 되는 종류다** — 단, 지금 우선순위는 아니니 사용자가 "준비해라"라고 할 때만 진행.
- 트레이드오프: 너무 일찍 추상화하면(아직 맵이 1개뿐) 과설계(YAGNI) 위험. 맵이 2~3개 더 늘어나는 M2 시점에 공통 패턴이 보이면 그때 뽑아내는 게 안전.

### (B) 외부 3D 툴(Blender) 파이프라인 — M4로 미루는 게 합리적
- 장점: 폴리곤 예산을 사람이 직접 통제할 수 있고, 디테일 있는 아트가 가능.
- 단점: Rojo/에이전트 워크플로우와 결이 다름 — `.fbx`/`.rbxm` 파일은 Git diff로 리뷰가 안 되고, 에이전트가 생성·검증할 수 없음(현재 MVP 방침의 핵심 이유와 정면으로 충돌). GDD 11.1에도 "맵은 Studio에서 만들어 `.rbxm`으로 저장"이라고 이미 M4용으로 정해져 있음 — 이 리서치는 그 결정을 재확인해준다.
- 결정 지점(사용자 몫): M4에서 전체 맵을 Blender로 새로 모델링할지, 아니면 회색 박스 치수를 유지한 채 표면 메시/머티리얼만 교체할지.

### (C) AI 이미지 컨셉아트 → 레퍼런스 활용 — 가장 불확실하고, 그래서 지금 확정 짓지 않는 게 맞아 보임
- Roblox 자체가 Cube 3D(텍스트→3D)를 Studio에 통합했지만, 2026년 10월 기준으로도 "단일 오브젝트만, 씬/레이아웃은 아직"이라는 베타 한계가 있다 — 맵 전체를 AI로 생성하는 건 아직 시기상조.
- 현실적인 조합은 "나노 바나나(Gemini) 같은 이미지 모델로 맵 컨셉 이미지(탑뷰/아이소메트릭 구도)를 먼저 뽑고 → 사람이 그 이미지를 보며 Studio에서 그레이박스 치수에 맞춰 아트를 입히는" 흐름일 가능성이 높다. 다만 이걸 뒷받침하는 Roblox 전용 1차 사례는 이번 검색에서 확인하지 못했으므로, M4 착수 시점에 다시 한번 최신 사례를 확인하는 걸 권장.
- Cube 3D의 "소품/오브젝트 생성"은 지금 맵의 장식 요소(접시, 간장병, 젓가락 등 저폴리곤 소품)에는 M4 시점에 바로 시도해볼 만한 범위로 보인다 — 구조물 전체보다 리스크가 작음.

### (D) 장르 레퍼런스(세그먼트 조합형 절차적 생성) — "맵 다양성"을 더 밀어붙이고 싶을 때의 대안
- 지금 설계는 "맵 모듈 1개 = 완성된 맵 1개"다. 나중에 "같은 Race 맵이라도 매번 배치가 달라지면 좋겠다"는 요구가 생기면, Tower of Hell/DOORS류의 세그먼트 조합 패턴을 참고해 맵 모듈 내부에 "여러 서브 세그먼트 중 랜덤 조합" 레이어를 추가하는 선택지가 있다. 이건 GDD에 없는 추가 기능이므로, 하고 싶다면 GDD 변경 여부를 먼저 사용자와 논의해야 한다.

---

## 요약 표 (한눈에 보기)

| 주제 | 지금(M1~M3) | M4 고도화 때 고려 |
|---|---|---|
| 컴포넌트화 | 이미 올바른 방향(`MapModule` + 태그) | 맵 2~3개 생기면 공통 조각을 헬퍼로 추출 |
| Blender/FBX | 사용 안 함 (Rojo/에이전트 워크플로우와 상충) | GDD 11.1대로 Studio+`.rbxm` 확정 — 전체 재모델링 vs 표면만 교체는 M4에 결정 |
| AI 이미지 레퍼런스 | 사용 안 함 | 컨셉 이미지 레퍼런스 용도로는 유망, 맵 전체 자동 생성은 아직 이름 |
| Cube 3D (Roblox 자체 AI) | 사용 안 함 | 소품 생성에 먼저 시도해볼 만함 (씬 생성은 베타 한계로 아직) |
| 세그먼트 조합형 절차적 생성 | 사용 안 함 (GDD 범위 밖) | 맵 다양성을 더 올리고 싶을 때 후보 — GDD 변경 필요하므로 사용자 논의 선행 |
