status: ready
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

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
