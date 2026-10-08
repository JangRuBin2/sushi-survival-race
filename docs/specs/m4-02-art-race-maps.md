status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-02 — 맵 아트 패스: 회전 벨트 · 간장 늪 & 와사비 산 (+ 회전 벨트 태그 전환)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §5.2 ①②, §11.4(장애물 태그), §12(M4 "맵 6개 아트")
- 참고: `docs/REFERENCE-map-production.md` §3(콜리전 비용), §5(그레이박스 → 아트 교체), §7(A)(B)
- 담당 개발 worktree: `m4-art-race` (Rojo 포트 34872)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작** (`MapKit`, `MapKitLogic`, `MoveExempt`)
- **이 스펙이 고치는 파일**: `src/shared/maps/RotatingBelt.luau`, `src/shared/maps/RotatingBeltChopstick.luau`, `src/shared/maps/SoySwamp.luau`, `src/shared/maps/SoySwampLayout.luau`, `src/shared/maps/SoySwampHazards.luau`, 새 파일 `src/shared/maps/RotatingBeltArt.luau`, `src/shared/maps/SoySwampArt.luau`, `tests/map-art-race.spec.luau`

## 목표
회색 박스였던 Race 맵 2개가 한눈에 "회전초밥집"으로 보인다. **코스 치수·판정은 그대로**(밟는 곳, 벽, 결승선, 장애물 타이밍이 M3와 같음)이고, 색·재질·장식만 바뀐다. 에이전트가 코드로 할 수 있는 만큼(코드 지오메트리·색·재질·소품·조명 부품)을 하고, 더 정교한 아트는 사용자가 Studio에서 `assets/map-art/<id>.rbxm`으로 덧붙일 수 있게 한다.

## 범위
- 포함:
  1. **공통 규칙** (m4-03·m4-04·m4-05도 같은 규칙):
     - 밟고 부딪히는 파츠(바닥·벽·결승선·장애물)의 **크기·위치·CanCollide는 바꾸지 않는다**. 바꿀 수 있는 건 `Color`, `Material`, `Transparency`(장애물 경고처럼 판정과 무관한 것만), `Reflectance`, 그리고 표면 디테일 장식.
     - 장식은 `MapKitLogic.DecorSpec` 목록(순수 데이터, `<Map>Art.luau`)으로 쓰고 `MapKit.buildDecor`로 `Decor` 폴더에 만든다 → 충돌·쿼리·터치 없음. 장식 파츠 수 ≤ `DECOR_PART_BUDGET`(600), ParticleEmitter ≤ 8, PointLight/SpotLight ≤ 12.
     - 장식은 플레이어 시야를 가리지 않게 **코스 바닥 위 2~12 studs 높이의 코스 안쪽 공간(폭 × 코스 길이)에는 두지 않는다** — 벽 바깥, 바닥 아래, 머리 위 15 studs 이상만. (순수 테스트로 확인: 장식 외곽 상자가 "코스 공간 상자"와 겹치지 않음)
     - `build` 끝에서 `MapKit.attachStudioArt(model, ID, origin)`을 부른다 (사용자 Studio 아트 자리).
     - `MapKit.introCamera`로 `IntroCamera` 경유점 3~5개를 둔다 (m3-04 자동 경로 대신 손으로 짠 경로: 출발 위 → 코스 중간 하이라이트(장애물) → 결승 → 끝점은 출발선 뒤 높이 12).
     - 맵 전체 톤은 "따뜻한 나무 + 흰 도자기 + 빨간 옻칠"(MapKitLogic.PALETTE). 바닥 색은 장애물·경고 표시(빨간 원, 와사비 연두)와 헷갈리지 않게 채도를 낮춘다.
  2. **회전 벨트 (`rotating-belt`)** — "회전초밥 레일 위를 거꾸로 달리기":
     - 벨트 바닥: 진한 회색 고무(`Fabric` 또는 `Slate` 대신 어두운 `SmoothPlastic`) + 진행 방향과 수직인 얇은 슬랫 줄무늬 장식(바닥에 0.05 studs 띄운 얇은 파츠, 충돌 없음). 출발·결승 구역은 나무 바닥.
     - 벽: 은색 레일(`Metal`) + 위에 나무 손잡이.
     - 벽 바깥 양쪽: 손님 테이블·의자 줄, 테이블 위 간장병·찻잔, **거대한 손님 얼굴**(입 벌림, 2~3개)이 벽 너머에서 코스를 내려다봄.
     - 병목 구간(간장 종지): 종지를 흰 도자기 + 남색 테두리로, 접시 더미는 색이 다른 접시 층(빨강·파랑·금색 = 회전초밥 가격표 접시).
     - 젓가락: 옻칠 빨강/검정, 끝은 나무색. 빨간 경고 원은 지금처럼 잘 보이게 유지.
     - 결승: 노렌(남색 천 + 흰 글씨 느낌) 걸린 문틀. 결승선 바닥 체크무늬.
     - 벨트 위를 따라 장식 초밥 접시(연어·참치·계란 니기리 소품, 벽 바깥 레일 위)를 몇 개 둔다 — 코스 안 아님.
     - **태그 전환 (M1 B10)**: `start`가 `Hazards` 폴더 순회 대신 `CollectionService:GetTagged("Chopstick")` 중 `IsDescendantOf(ctx.model)`인 것만 돌린다. `Hazards` 폴더는 정리용으로 남겨도 되지만 동작이 폴더 구조에 의존하지 않는다. 벨트 미는 구역도 태그(`Conveyor`)로 찾는다.
     - 젓가락이 캐릭터를 들어 올리거나 떨어뜨릴 때, 벨트가 밀 때는 `MoveExempt.mark(character)`를 부른다 (m4-10 이동 감시 오탐 방지).
  3. **간장 늪 & 와사비 산 (`soy-swamp`)**:
     - 간장 웅덩이: 진한 갈색 반짝임(`Glass` 또는 `SmoothPlastic` + Reflectance 0.2~0.3), 가장자리에 흰 도자기 종지 테두리 장식.
     - 와사비 패드: 밝은 연두 + 울퉁불퉁한 작은 공(Ball) 장식(충돌 없음, 패드 위로 0.5 studs 이하). 와사비 산은 연두 층층 언덕 장식.
     - 날치알 공: 주황 `Sand` 또는 `Neon` 약하게(눈에 띄게). 굴러오는 위쪽에 날치알 그릇 소품.
     - 배경: 거대한 간장병(라벨 붉은 띠), 고추냉이 강판, 생강 더미(분홍) — 코스 밖.
     - 와사비 튕김·간장 감속·날치알 공에 맞아 넘어짐처럼 서버가 속도를 바꾸거나 큰 충격이 생기는 곳은 `MoveExempt.mark(character)`를 부른다.
  4. **순수 데이터 분리**: `RotatingBeltArt.luau`, `SoySwampArt.luau`는 Roblox 자료형 없이 `decor(): { DecorSpec }`, `introCamera(): { points }`, `courseVolume(): { min, max }`(장식이 들어가면 안 되는 상자)을 돌려준다 → lune 테스트.
- 제외:
  - 코스 길이·장애물 수치 변경 (친구 테스트 뒤 사용자 지시가 있을 때)
  - 메시(MeshPart)·텍스처 업로드, Blender — 사용자 작업(아래)
  - 맵 안 랜덤 변형 (REFERENCE-party-royale §1 — M5 이후 후보)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/map-art-race.spec.luau`)
- [ ] AC1: 두 맵의 `decor()`가 `MapKitLogic.validate`를 통과하고 파츠 수가 600 이하다.
- [ ] AC2: 두 맵 장식의 각 외곽 상자가 `courseVolume()`(코스 바닥 위 2~12 studs, 벽 안쪽)과 겹치지 않는다.
- [ ] AC3: `introCamera()` 경유점이 3~5개이고 마지막 점이 출발선 뒤(로컬 z > 0)·높이 8~20이다.
- [ ] AC4: 기존 `map-soy-swamp`·`maps`·M1 회전 벨트 관련 테스트가 수정 없이 통과한다 (`SoySwampLayout`의 판정 수치가 그대로).
- [ ] AC5: (소스 테스트) `RotatingBelt.luau`의 `start`가 `Hazards` 폴더 이름으로 장애물을 찾지 않고 `CollectionService` 태그를 쓴다.
- [ ] AC6: 검증 명령 4개가 통과한다.

### Studio 확인 (`forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`)
- [ ] AC7: 두 맵이 회색이 아니라 위 설명대로 색·재질·소품이 있는 초밥집으로 보인다 (스크린샷 2장 이상을 사용자에게 남김).
- [ ] AC8: 장식에 걸리거나 막히는 곳이 없다 — 벽 너머 소품·바닥 줄무늬를 밟아도 걸리지 않고, 카메라를 돌려도 코스가 가려지는 곳이 없다.
- [ ] AC9: M3와 같은 방식으로 완주할 수 있고 걸리는 시간이 비슷하다 (벨트 밀기·젓가락·간장·와사비·날치알 동작 그대로).
- [ ] AC10: 라운드 소개 플라이스루가 손으로 짠 경로(출발 → 장애물 → 결승 → 내 뒤)로 날고, 벽에 묻히지 않는다.
- [ ] AC11: 2개 방이 동시에 회전 벨트를 돌려도 각 방의 젓가락이 자기 맵에서만 움직인다 (태그 전환 회귀).
- [ ] AC12: `ServerStorage.MapArt`에 `rotating-belt` Model(파트 1개)을 넣으면 맵에 나타나고 밟고 지나갈 수 있다 (m4-01 AC11).
- [ ] AC13: Studio 성능 통계(Shift+F1/F2)에서 이 맵이 돌 때 클라이언트 프레임이 M3보다 눈에 띄게 떨어지지 않는다 (60fps 기기 기준 50 이상 유지 — 사용자 확인).

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- (선택) 더 정교한 장식이 필요하면 Studio에서 Model을 만들어 `assets/map-art/rotating-belt.rbxm`, `assets/map-art/soy-swamp.rbxm`로 저장. 원점(0,0,0) = 맵 origin, 앞 = -Z. 충돌은 자동으로 꺼진다. 메시는 환경 메시 2만 트라이 이하(REFERENCE §3).
- (선택) 컨셉 이미지(이미지 생성 모델)로 분위기 참고 자료를 만들어 `docs/`에 넣으면 다음 아트 패스에 반영.
- AC7·AC13 스크린샷·프레임 확인.

## 결정 기록
- 2026-10-08 · 아트 범위 · 코드로 만드는 색·재질·장식 + IntroCamera까지가 이 스펙, 메시·텍스처·Studio 수작업은 사용자 선택 작업. 판정 지오메트리는 안 바꿈. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 회전 벨트 태그 전환(M1 B10)을 아트 패스에 같이 넣음 — 같은 파일이라 충돌 없음 · planner
- 2026-10-08 · 장식 예산 · 맵당 파츠 600, 파티클 8, 조명 12. 모바일 고려(REFERENCE §3 "반복 오브젝트는 가볍게"). **기본값으로 진행, 사용자 수정 가능** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
