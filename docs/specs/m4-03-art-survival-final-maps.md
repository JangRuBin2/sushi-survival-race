status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-03 — 맵 아트 패스: 뜨거운 철판 · 회전 꼬치 쇼다운

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §5.2 ⑤⑥, §7(떨어지면 손님 입 / 결승은 셰프 손), §8(가게 문 탈출), §12(M4)
- 참고: `docs/REFERENCE-map-production.md` §3·§5·§7, `docs/specs/m4-02-art-race-maps.md` "공통 규칙"
- 담당 개발 worktree: `m4-art-arena` (Rojo 포트 34873)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/maps/HotPlate.luau`, `src/shared/maps/HotPlateLogic.luau`(색 단계 상수만, 판정 수치는 그대로), `src/shared/maps/SkewerShowdown.luau`, `src/shared/maps/SkewerShowdownLogic.luau`(판정 수치는 그대로), 새 파일 `src/shared/maps/HotPlateArt.luau`, `src/shared/maps/SkewerShowdownArt.luau`, `tests/map-art-arena.spec.luau`

## 목표
Survival·결승 맵이 "주방 철판"과 "가게 문 앞 접시 무대"로 보인다. 떨어지는 곳 아래에 **입 벌린 손님**(철판)과 **셰프**(결승)가 실제로 보여서 "떨어지면 먹힌다"가 화면만 봐도 이해된다. 판정은 그대로.

## 범위
- 포함:
  1. **공통 규칙**은 m4-02 "공통 규칙"과 같다 (판정 파츠 크기·위치 고정, `DecorSpec` + `MapKit.buildDecor`, 예산, 시야 상자, `attachStudioArt`, `IntroCamera`). Survival·결승의 "시야 상자"는 각 층/무대 윗면 위 2~12 studs, 무대 바깥 반지름 안쪽이다.
  2. **뜨거운 철판 (`hot-plate`)**:
     - 타일: 철판 질감(`DiamondPlate` 또는 `Metal`, 진회색). 달아오름 색 단계는 지금 로직 그대로 두고 **색만** 회색 → 주황 → 빨강(`Neon` 약하게)으로 다듬는다 (단계 시간·사라지는 시간은 그대로).
     - 층 사이 기둥·테두리: 스테인리스(`Metal`, 밝은 회색). 층 가장자리에 기름 튄 자국 장식(얇은 노란 원판).
     - 맨 아래층 밑: **입 벌린 거대 손님 얼굴 2~3개**가 위를 보고 있다 (빨간 입속, 혀, 이빨 — 블록 조합). 떨어지는 플레이어가 그 쪽으로 보인다.
     - 배경: 철판 옆 주걱 2개(거대), 김 올라오는 연기 ParticleEmitter 2~4개(타일 위가 아니라 테두리에서), 환풍기 후드(머리 위 20 studs 이상).
  3. **회전 꼬치 쇼다운 (`skewer-showdown`)**:
     - 접시 무대: 흰 도자기 + 가장자리 남색 띠, 부채꼴 조각 사이 얇은 금 장식(충돌 없음, 윗면 위 0.05).
     - 꼬치: 나무색(`Wood`) 막대. 꼬치에 꽂힌 음식(닭꼬치·대파 조각) 장식은 **꼬치 판정 크기 안쪽**에만 둔다 — 보이는 것보다 판정이 크면 억울하므로 장식이 판정 바깥으로 튀어나오지 않게 (순수 테스트로 확인).
     - 가운데 기둥: 옻칠 빨강.
     - 셰프 손: 피부색 둥근 손가락(블록·볼 조합), 소매(흰 조리복). 경고 표시는 지금처럼 잘 보이게.
     - 배경: 무대 한쪽 끝에 **가게 문**(나무 미닫이 + 노렌 + "출구" 느낌 판) — 우승 연출(m3-05)이 박차고 나가는 문과 같은 방향에 둔다. 무대 아래 깊은 곳에 셰프 상체(모자) 실루엣.
     - 꼬치 넉백·셰프 손이 조각을 가져갈 때 서버가 캐릭터 속도를 바꾸면 `MoveExempt.mark(character)`.
  4. **순수 데이터 분리**: `HotPlateArt.luau`, `SkewerShowdownArt.luau` — `decor()`, `introCamera()`, `courseVolume()` + (꼬치) `skewerFoodWithinHitbox()` 검사에 쓸 장식 목록.
- 제외:
  - 철판 층 수·타일 크기·사라지는 시간, 꼬치 속도·서든데스 시간 변경
  - 우승 연출 장면 자체(m3-05 파일) — 문 위치만 맞춘다. 연출과 문 방향이 어긋나면 결정 기록에 적고 사용자에게 알림

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/map-art-arena.spec.luau`)
- [ ] AC1: 두 맵 `decor()`가 `MapKitLogic.validate`를 통과하고 600개 이하다.
- [ ] AC2: 장식 외곽이 각 층/무대의 시야 상자와 겹치지 않는다 (꼬치 음식 장식은 이 검사 대신 AC3).
- [ ] AC3: 꼬치 음식 장식이 모두 꼬치 판정 상자 안쪽에 있다.
- [ ] AC4: `introCamera()` 경유점 3~5개, 마지막 점이 무대/맨 위층 바깥 높이 10~25에서 무대 중심을 본다 (m3-04 B2 "끝점이 지난 라운드 내 위치 쪽" 해소).
- [ ] AC5: 기존 `map-hot-plate*`, `map-skewer-showdown*` 테스트가 수정 없이 통과한다.
- [ ] AC6: 검증 명령 4개 통과.

### Studio 확인 (`forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`)
- [ ] AC7: 철판이 주방 철판으로, 결승 무대가 가게 문 앞 도자기 접시로 보인다 (스크린샷).
- [ ] AC8: 철판 맨 아래층에서 떨어지면 아래 손님 얼굴 쪽으로 떨어지는 게 보이고, 탈락 연출(손님 입)이 그 근처에서 나온다.
- [ ] AC9: 타일 달아오름이 회색 → 주황 → 빨강으로 바뀌고 사라지는 타이밍이 M3와 같다.
- [ ] AC10: 꼬치 음식 장식에 "안 닿았는데 맞은" 느낌이 없다 (2명 이상, 사용자 확인).
- [ ] AC11: 결승 플라이스루가 무대를 한 바퀴 보여 주고 무대 바깥에서 끝난다.
- [ ] AC12: 우승 연출에서 우승 초밥이 박차고 나가는 문이 맵의 가게 문과 같은 쪽이다 (다르면 개발 메모에 적고 사용자에게 알림).
- [ ] AC13: 프레임이 M3보다 눈에 띄게 떨어지지 않는다 (연기 파티클 포함, 사용자 확인).

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- (선택) `assets/map-art/hot-plate.rbxm`, `assets/map-art/skewer-showdown.rbxm` 장식 Model.
- AC7·AC10·AC13 확인.

## 결정 기록
- 2026-10-08 · 떨어지는 곳 아래 손님·셰프를 실제로 보이게 · GDD 5.2 "아래에서 입 벌리고 기다리는 손님" 표현. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 꼬치 장식은 판정 상자 안쪽만 · 보이는 것과 맞는 것이 같아야 억울하지 않음 · planner
- 2026-10-08 · "꼬치 판정 상자" = 꼬치 원기둥을 감싸는 상자(길이 19.5 × 지름 1.2 × 1.2, 꼬치 로컬). 서버는 몸통(반지름 1)이 꼬치 원기둥에 닿으면 맞음이라, 이 상자 안 장식에 몸이 닿아 보이면 실제로도 맞아요. 그래서 닭·대파 조각은 단면이 꼬치 굵기(1.2) 그대로인 사각 블록(모서리가 꼬치 밖으로 살짝 보임) · 기본값으로 진행 · developer
- 2026-10-08 · `courseVolume()`은 층/무대가 여러 개라 상자 목록 `{ Bounds }`을 돌려줘요 (m4-02는 상자 1개). 셰프 손 장식은 손이 원래 무대로 내려오는 판정 물체라 시야 상자 검사(AC2)에서 빼고 검사·예산만 확인 · developer
- 2026-10-08 · 타일이 마지막 40%(0.9초~)에 Neon으로 바뀌어요. 재질이 바뀌어도 마찰이 같도록 타일에 `CustomPhysicalProperties = DiamondPlate`를 고정. 기둥도 Metal → 옻칠(SmoothPlastic)로 바꾸면서 물성은 Metal 고정 · developer
- 2026-10-08 · 색 단계 상수: 기존 테스트("달아오르는 동안 초록·파랑이 늘지 않음") 때문에 COLD의 g·b가 WARM보다 커야 해서 진회색 (104,106,112), 주황 (232,100,24), 빨강 (196,36,16) · developer

## 개발 메모
- **브랜치/커밋**: `m4-03-art-arena` — 65bcb96 (코드) + 문서 커밋.
- **바뀐 파일**
  - 새 파일 `src/shared/maps/HotPlateArt.luau` — 철판 장식(층 테두리·기름 자국·모서리 기둥·위를 보는 손님 얼굴 3개·주걱 2개·환풍기 후드·주방 벽), 김 나는 곳 4개, 후드 조명 2개, `introCamera()`(손님 얼굴 → 층 옆 → 위층 → 앞쪽 바깥), `courseVolume()`(층 3개), `isGlowing()`.
  - 새 파일 `src/shared/maps/SkewerShowdownArt.luau` — 기둥 금 띠·뚜껑, 접시 굽, 가게 문(미닫이·창호지·노렌·출구 판·등롱 2개·기와 차양·가게 앞면), 무대 아래 셰프 상체(모자·팔), `sliceDecor(index)`(금 선·남색 테두리), `skewerFood(spec)`·`skewerHitbox`·`skewerFoodWithinHitbox`, `handDecor()`(손끝·소매), `introCamera()`(문 → 무대 한 바퀴 → 바깥 높이 16), `courseVolume()`.
  - `HotPlate.luau` — `buildArt`: Decor + ParticleEmitter(김, Rate 3) 4개 + PointLight 2개 + IntroCamera + attachStudioArt. 타일 물성 고정, 마지막 단계 Neon. 타일·층·탐지·탈락 코드는 그대로.
  - `HotPlateLogic.luau` — 색 상수 3개만.
  - `SkewerShowdown.luau` — 조각 흰 도자기 + 바깥 줄 남색, 조각 장식은 조각 Model 안(같이 흔들리고 사라짐), 기둥 옻칠 빨강, 꼬치 `PALETTE.Wood` + 음식 장식(`Decor/LowSkewerFood`, `HighSkewerFood`, 매 프레임 `BulkMoveTo`로 꼬치 따라감, 높은 꼬치 등장 전엔 숨김), 셰프 손 피부색 + 손끝·소매, 옛 `ShopDoor`(M2 회색 박스)를 Art 장식으로 교체(같은 자리), 등롱 PointLight 2개, IntroCamera, attachStudioArt, 넉백에 `MoveExempt.mark(character)`. 꼬치 속도·맞음 판정·손 일정·낙하 높이는 그대로.
  - `tests/map-art-arena.spec.luau` — 18개 (AC1~AC4 + 예산·판정 수치 고정·소스 계약).
- **검증**: rojo build OK, `stylua --check` OK, selene 0/0/0, `lune run tests` 582 passed / 0 failed (기존 map-hot-plate*·map-skewer-showdown* 수정 없이 통과).
- **Studio 확인 방법**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`(커밋 금지) → Play.
  - AC7: 철판 = 진회색 다이아몬드 철판 + 스테인리스 테두리·기둥 + 위 후드 + 뒤 흰 타일 벽, 결승 = 흰 도자기 접시(남색 테두리·금 선) + 앞쪽(-Z) 가게 문. 스크린샷.
  - AC8: 철판 맨 아래층에서 떨어지면 아래 손님 얼굴 3개 쪽으로 떨어지는지. 탈락 연출(손님 입)은 m3-03의 별도 장면이라 위치가 맵과 이어지진 않아요 — 어색하면 알려 주세요.
  - AC9: 밟은 타일이 회색 → 주황 → 빨강(마지막 0.6초 Neon) → 1.5초에 사라지는지.
  - AC10: 2명 이상으로 결승, 닭·대파 조각에 "안 닿았는데 맞음" 느낌이 없는지.
  - AC11: 결승 플라이스루가 가게 문 → 무대 한 바퀴 → 무대 밖에서 끝나는지 (철판도 손님 얼굴 → 층 옆 → 앞쪽 바깥).
  - AC12: 우승 연출(m3-05)은 별도 장면에서 초밥이 장면 로컬 -Z로 문을 박차고 나가요. 맵 가게 문도 무대 로컬 -Z(아레나 origin은 회전 없음)라 같은 방향 — 코드상 일치, 눈으로 확인 필요.
  - AC13: Shift+F1/F2로 프레임 확인 (김 파티클 4개, 조명 4개).
- **남은 이슈**: 없음 (Studio 확인 AC7~AC13만 남음). `assets/map-art/hot-plate.rbxm`·`skewer-showdown.rbxm`을 넣으면 `Decor/StudioArt`로 붙어요.
