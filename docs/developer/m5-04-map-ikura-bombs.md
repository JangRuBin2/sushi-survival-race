# m5-04 연어알 폭탄 접시: 개발 작업 기록

## 2026-10-08 — 설계만 함, 코드 없음 (최신)
- **브랜치**: `m5-04-ikura` (origin/main c4ca608에서 분기). 스펙 status `in-dev`. `inPool = false`는 그대로 둠.
- **끝난 것**: 스펙과 참고 코드(SkewerShowdown/Logic/Art, MapKit/Logic, MoveExempt, SoySwampHazards launch, MapTypes 연장전 계약, RoundService overtime 호출)를 읽고 아래 설계를 정함. 코드와 테스트는 아직 없음.
- **검증 상태**: 코드를 바꾸지 않아 돌리지 않음 (main 상태 그대로).
- **다음에 할 첫 단계**: `src/shared/maps/IkuraBombsLayout.luau`(상수·칸 표·스폰) → `IkuraBombsLogic.luau` → `tests/map-ikura-bombs.spec.luau` → `IkuraBombsArt.luau` → `IkuraBombs.luau` 덮어쓰기.
- **막힌 점 / 주의**: `inPool = false`를 지우면 기존 테스트가 깨진다. 이 테스트들은 스펙의 파일 목록 밖이다.
  - `tests/m5-03-foundation.spec.luau`: AC1(ikura `inPool == false` 기대), AC2(`#Maps.infos() == 6`, SHELLS에 ikura 포함), buildRoundPlan 껍데기 표
  - `tests/m2-01-qa.spec.luau:62` "결승은 언제나 skewer-showdown", `tests/m4-foundation.spec.luau:321` "Final 1"
  - 최소한으로 고친다(ikura를 껍데기 목록에서 빼고 개수 +1, Final 1 → 2). 보고에 적을 것. m5-05/06도 같은 줄을 고치므로 병합 충돌이 날 수 있다.

## 설계 (정한 것, 스펙 기본값)
- **좌표**: 접시 중심 = origin, 칸 윗면 = origin 높이(y 0), 두께 1.5. 각도는 꼬치 쇼다운과 같은 `atan2(-z, x)` (CFrame.Angles(0, θ, 0) 기준).
- **칸 기하 (틈 0)**:
  - 원을 6°씩 60조각으로 나눈다. Ring 1·2 칸은 조각마다 직사각형 1개다. 폭 = 바깥 현 `2·rOut·sin3°`, 깊이 = `(rOut − rIn)·cos3°`, 조각 이등분선 위에 둔다.
  - 고리 경계(r 8·16)가 같은 현 위에 있어서 고리 사이 틈은 0이다. 조각끼리는 최대 0.42 겹친다.
  - Ring 0은 지름 16 Cylinder 1개.
  - 칸은 Model이다 (태그 `IkuraTile`, 속성 `Ring`·`Index`·`TileId`·`Cracks`).
  - Ring 1 = 6칸 × 10조각, Ring 2 = 10칸 × 6조각 → 충돌 파츠 121개.
- **상태는 모듈 표가 아니라 속성에 둔다**:
  - 칸 속성: `Cracks`, `Falling`(경고 시작), `Dropped`.
  - 맵 Model 속성: `StartedAt`(os.clock), `OvertimeAt`(출발 기준 초).
  - 그래서 모듈 상태가 없고, overtime은 ctx.model만 읽는다.
- **스폰**: r 13에 12개(30° 간격), r 19에 12개(15° 어긋남). 앞 번호부터 흩어지게 순서를 섞는다. 테스트로 고정할 것: 모두 `tileAt` 안, 접시 가장자리까지 4 이상, 서로 3 이상.
- **Logic API**:
  - `tileAt(x, z) -> id?`
  - `bombWave(elapsed, overtimeAt?) -> { interval, count, warn, radius }?`
  - `pickTargets(rng, racers { {x, z} }, aliveIds, count)`: rng는 NextNumber/NextInteger만 있는 최소 타입(테스트는 가짜 rng). 칸 밖 점은 극좌표에서 반지름과 각도를 남은 칸 범위(0.5 안쪽)로 클램프한다.
  - `knockback(dx, dz, radius, awayX?, awayZ?) -> { x, y, z }?`: 거리 0이면 접시 중심 반대 방향, 그것도 0이면 +X.
  - `inBlast(dx, dy, dz, radius)`: 높이 차 6 이하.
  - `crack(ring, cracks) -> (cracks, drop)`
  - `pickDrop(ring, alive, rng?)`
  - `scheduledDrops(elapsed, alive, rng?)`: 바깥은 40+6k초, 가운데는 60+6k초 정각. 바깥 3칸·가운데 2칸은 남긴다. 금 간 칸이 먼저.
  - `overtimeRings(D, warn)`: dropAt = warn + (D − warn)·k/2.
- **런타임**:
  - Heartbeat 하나: 낙하 판정(y < −30), 숟가락이 목표를 따라감.
  - 폭탄 루프는 task.spawn으로 bombWave 간격마다 돈다. 폭탄마다 task.delay 스레드를 쓰고 전부 ctx.cleanup에 넣는다.
  - 폭탄은 `Bombs` 폴더 아래 Model(태그 `IkuraBomb`). 빨간 원(Cylinder, 충돌 없음)이 깜빡이고, 마지막 0.5초에 지름 4 주황 구가 떨어진다.
  - 폭발: LinearVelocity 0.12초 + AssemblyLinearVelocity + PlatformStand 1초 + `MoveExempt.mark(char, 1.5)`. 같은 사람은 0.5초 쿨다운. `MapSfx.play(.., "IkuraPop")`, ParticleEmitter:Emit.
  - PlatformStand가 켜지면 잡기가 풀린다(GrabService 60행).
- **금 가기 (연장전 전에만)**: 1이면 색을 어둡게 하고 칸 Model 안에 검은 얇은 선 장식을 넣는다. 2가 되면 1초 흔들림·빨간 깜빡임 뒤 CanCollide/CanTouch/CanQuery false + 투명 + `TileVanish`.
- **연장전**: `OvertimeAt` 속성을 설정한다(정해진 낙하·금 낙하 중지). 폭탄은 `bombWave`가 연장전 값을 준다. 고리 2 → 1 → 0을 `overtimeRings`대로 task.delay(ctx.cleanup)로 붕괴시킨다. 장식은 전부 충돌 없음.
- **아트 (예산 600)**:
  - 칸 경계 얇은 선(칸 Model 안).
  - 남색 무늬 도자기 테두리 lip (r 24~25, y 1 이하 → 시야 상자 y 2~12 밖).
  - 접시 바닥·굽, 부두·바다·가게 앞. 무대 높이 가짜 바닥은 금지 — map-art-arena의 fakeFloors 규칙대로 무대보다 6 이상 낮게.
  - 높이 28에 셰프 손 + 은 숟가락 (별도 Model `Spoon`, 장식 규칙).
  - 고추냉이·생강, 등롱 PointLight 12개 이하, IntroCamera 4점.
