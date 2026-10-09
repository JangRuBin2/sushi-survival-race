status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-17 — 새 Survival 맵: 고양이 카페 캣타워 (`cat-cafe-shelves`)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.2 Survival 맵(최대 60초, 목표 인원만 남으면 끝, **시간이 끝나면 버틴 사람 전원 통과**, 점수 = 높이), §5.3 "1차 확장 맵 6개"의 `cat-cafe-shelves`, "맵 테마 원칙 (v0.6)"(비초밥 테마 허용), §11.4
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md` §3의 9번(원안), `docs/specs/m5-13-map-expansion-foundation.md`(이 스펙이 덮어쓸 껍데기를 만든 선례)
- 참고 코드: `TempuraPot.luau`(이 스펙이 덮어쓸 껍데기 자체의 패턴), `HotPlate.luau`·`HotPlateLogic.luau`(층 구조·단순 낙하 판정), `SoySwampHazards.luau`(`launch`로 LinearVelocity 넉백 거는 패턴, `MoveExempt.mark`), `ChefBoardLogic.pickLine`(가중 랜덤 + 같은 대상 연속 금지), `RamenRapidsLogic.chashuHeight`(사인파로 왕복 위치 계산)
- 담당 개발 worktree: `m5-catcafe` (Rojo 포트 34878)
- 공용 파일 수정 담당: 없음 (id·이름·규칙 문구·등록은 m5-13. `shared/SfxCues.luau`·`shared/SfxLibrary.luau`는 공용 파일 목록에 없어 이 스펙이 새 cue를 추가해도 된다 — `OilSplash`를 m5-05가 그랬듯)
- 의존: **m5-13 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/maps/CatCafeShelves.luau`(껍데기 덮어쓰기, 끝나면 `inPool = false` 줄 삭제), 새 파일 `src/shared/maps/CatCafeShelvesLayout.luau`, `CatCafeShelvesLogic.luau`, `CatCafeShelvesArt.luau`, `tests/map-cat-cafe-shelves.spec.luau`, `shared/SfxCues.luau`·`shared/SfxLibrary.luau`(새 cue 3개 추가, 아래 "소리")

## 목표
고양이 카페 한가운데 놓인 3단짜리 캣타워. 선반은 사라지지 않지만 **좁아서** 거대한 고양이 발이 훑고 지나가거나 장난감 공이 굴러와 부딪히면 바깥쪽으로 밀려나고, 가장자리 밖으로 밀리면 떨어져 탈락한다. 철판(타일이 사라짐)·도마(칼 줄을 읽고 피함)와 달리 이 맵은 **좁은 선반 사이를 옆으로 옮겨 다니며 버티는 수평형** Survival — 위로 올라가는 것은 필수가 아니라 "더 안전한 자리"를 찾는 선택지다.

## 규칙 (수치는 전부 기본값, Layout·Logic 상수)

### 구조 — 3단 캣타워 (정사각 테두리가 아래로 갈수록 좁아지는 피라미드)
캣타워 중심은 origin 기준 로컬 `(0, -40)`(`TOWER_CENTER`). 각 단(tier)은 **가운데가 뚫린 사각 테두리**(= 선반 4개가 액자처럼 이어짐) 모양이고, 위 단일수록 작아서 아래 단의 뚫린 구멍 위로 떠 있다 — 안쪽 가장자리에 서서 점프하면 위 단으로 올라간다.

| 단 | 바깥 한 변 | 테두리 폭(선반 폭) | 윗면 높이(topY) | 모양 |
|---|---|---|---|---|
| 1단(맨 아래, 스폰) | 44 | 4 | 4 | 테두리(가운데 구멍 36) |
| 2단 | 28 | 4 | 9 | 테두리(가운데 구멍 20) |
| 3단(꼭대기) | 12 | — | 14 | 꽉 찬 판(구멍 없음, "캣방석") |

- 선반은 `CatCafeShelvesLayout.shelves()`가 9개(1단 4개 + 2단 4개 + 3단 1개)를 돌려준다. 각 선반은 `{ key, tier, side, axis, length, width, topY, centerX, centerZ }`(로컬 좌표, 타워 중심 기준 오프셋은 Layout이 더해서 돌려준다). `axis`는 공이 왕복하는 긴 쪽 방향("X" 또는 "Z").
- **오르는 틈**: 1단 안쪽 가장자리 → 2단 바깥 가장자리 수평 **4**, 2단 안쪽 가장자리 → 3단 바깥 가장자리 수평 **4**. 단 사이 높이 차는 둘 다 **5**(점프력 50 → 점프 높이 약 6.4, `docs/specs/m5-05-map-tempura-pot.md` 산출값 재사용 — 수평 4 + 수직 5 조합 점프가 가능해야 한다, `Logic.climbGap(tierIndex)`로 확인).
- **스폰 24개**: 1단의 선반 4개에 6개씩, 각 선반 길이 방향으로 양 끝 여백 4 띄우고 고르게(간격 약 7.2, 서로 3 이상). 전부 1단 판정 바닥 위(`Spawns` 폴더 약속, 24개 모두 확인).
- 바깥 벽·기둥은 없다 — 테두리 밖은 그냥 허공이고, 아래로 **`ELIMINATION_Y`**(1단 topY − 15 = **−11**, origin 기준 로컬 y) 아래로 떨어지면 탈락.

### 장난감 공 (`CatToy`, 서버가 왕복시킴 — 물리 시뮬 아님, `RamenRapidsLogic.chashuHeight`처럼 사인파로 위치를 직접 정함)
- 선반마다 공 1개, 총 9개. 선반의 긴 축(`axis`)을 따라 중심에서 `amplitude = length/2 − BALL_DIAMETER/2 − 0.5`만큼 사인파로 왕복(`CatCafeShelvesLogic.ballOffset(shelf, t)`), 주기 **`BALL_PERIOD` = 4.5초**, 선반마다 위상(phase)을 달리해 어긋나게 움직인다(`index / 9 * 2π`, 전부 같이 안 움직이게).
- 지름 **2**. 선반 위 플레이어의 (선반 축 기준) 위치와 공 위치 차가 `BALL_DIAMETER/2 + 1.2`(= 2.2) 이하면 맞은 것(`Logic.isHit`).
- 맞으면 선반 중심에서 바깥쪽(타워 중심에서 멀어지는 수평 방향, `Logic.outwardDirection`)으로 **수평 14 + 위 6**, `SoySwampHazards.launch`와 같은 방식(`LinearVelocity`를 짧게 걸고 그 뒤는 포물선) **0.1초**만 강제. 같은 플레이어 쿨다운 **1.2초**. `MoveExempt.mark(character, 1.2)`(이동 감시 오탐 방지, CLAUDE.md 면제 규칙).
- 3단("캣방석")에도 공이 있다(안전 지대가 아예 무해하진 않게).

### 고양이 발 (`CatPaw`, 서버가 주기적으로 선반 하나를 고름)
| 시각 | 간격 |
|---|---|
| 0 ~ 8초 | 없음(그레이스) |
| 8 ~ 25초 | 5초 |
| 25 ~ 45초 | 3.2초 |
| 45 ~ 60초 | 2초 |
- 매번 **그 순간 선반에 1명 이상 서 있는 선반 중(occupant 수 가중 랜덤, 바로 전에 고른 선반은 빼고 — `CatCafeShelvesLogic.pickShelf`, `ChefBoardLogic.pickLine`과 같은 패턴) 하나**를 고른다. **3단("캣방석")은 대상에서 빼요**(꼭대기까지 올라간 보상으로 고양이 발은 안전, 공은 그대로 — `TempuraPot`의 "23·27·31층 안전" 설계와 같은 취지, 결정 기록 D2).
- 경고 **1.1초**(선반 전체에 주황빛/고양이 발 그림자) → 그 순간 그 선반 위에 있던 **모든** 플레이어를 바깥쪽(타워 중심에서 멀어지는 방향)으로 **수평 20 + 위 9**, **0.12초** 강제(공보다 세게 — 가장자리 밖으로 확실히 밀려날 정도). `MoveExempt.mark(character, 1.6)`.
- 후보가 하나도 없으면(아무도 안 서 있거나 바로 전 선반뿐) 그 차례는 건너뛴다(`pickShelf`가 nil을 돌려주면 아무 일도 안 일어남).

### 끝
- Survival 공통 규칙 그대로: 남은 인원 ≤ 목표 인원이면 즉시 끝, **60초가 끝나면 버틴 사람 전원 통과**(시간 제한 `Config.TimeLimit.Survival`). 점수는 높이(HumanoidRootPart Y) — 더 높은 단에 있던 사람이 동시 탈락·시간 종료 때 유리.
- 탈락 연출은 Survival 낙하 = 손님 입(`Mouth`, 지금 규칙).

### 아트 (`CatCafeShelvesArt.luau`, 장식 예산 파츠 600·파티클 8·조명 12)
- 파스텔톤 카페(연분홍·크림색 벽, 나무 바닥 느낌 선반), 테두리에 고양이 발자국 패턴 장식, 캣타워 기둥(장식용 — 구조적으로 단을 떠받치는 게 아니라 순수 장식 기둥을 3단 옆에 세워 "캣타워처럼 보이게" 함, 충돌 없음), 선반 위 작은 고양이 쿠션·장난감 바구니 장식. 고양이 발 경고 때 쓸 발그림자 데칼/파티클 2종, 창가 햇살 느낌 조명 몇 개. `IntroCamera` 4점(카페 전경 → 1단 스폰 → 타워 옆모습 올려보기 → 꼭대기 캣방석).
- 선반 파츠는 `CollectionService` 태그 `CatCafeShelf`를 달고 `Attributes`에 `ShelfKey`(Layout의 `key`와 동일)를 저장해, `start`가 경고 색 변경 때 `ctx.model` 하위의 태그 파츠만 찾아 쓴다(M1 B10 패턴).

### 소리 (새 cue 3개, `shared/SfxCues.luau`·`shared/SfxLibrary.luau`에 추가 — 공용 파일 아님, 이 스펙이 바로 추가)
- `CatToyBounce`(공에 맞음), `CatPawWarn`(고양이 발 경고 시작), `CatPawSwipe`(밀림 순간). 기존 맵들처럼 소리 id는 비워 두고(`sfx(nil, 볼륨)`) 사용자가 나중에 고른다(`docs/USER-TODO.md`에 추가).

## 범위
- 포함: 위 규칙, 순수 로직 분리(Layout/Logic), 아트, IntroCamera, `inPool = false` 줄 삭제.
- 제외: 선반 자체가 사라지거나 움직이는 것(공·고양이 발 넉백만이 위험 요소), 공 물리 시뮬레이션(사인파 스크립트로 대체), 플레이어끼리 밀치기 상호작용(잡기 시스템은 GDD 6의 기존 룰 그대로, 이 맵 전용 추가 없음).

## 수용 기준
### 순수 로직 (lune 테스트, `tests/map-cat-cafe-shelves.spec.luau`)
- [ ] AC1: `MapTypes.validate` 통과(Survival, `overtime` 없어도 됨).
- [ ] AC2: `CatCafeShelvesLayout.shelves()`가 선반 9개를 돌려준다. 1단 4개(길이 44 또는 36, 폭 4, topY 4), 2단 4개(길이 28 또는 20, 폭 4, topY 9), 3단 1개(길이·폭 12, topY 14) — 위 표와 정확히 일치.
- [ ] AC3: 스폰 24개 전부 1단 선반 중 하나의 범위 안(길이 방향 중심에서 ±(length/2 − 2) 안쪽, 폭 방향 중심 근처)에 있고, 선반 양 끝에서 4 이상 떨어져 있으며, 서로 3 이상 떨어져 있다.
- [ ] AC4: `CatCafeShelvesLogic.climbGap(1)`과 `climbGap(2)`가 둘 다 **4**(1→2단, 2→3단 수평 틈), 단 사이 높이 차(`topY` 차)는 둘 다 **5**.
- [ ] AC5: `Logic.ballOffset(shelf, t)`를 0~60초(0.25초 간격)로 돌려도 모든 선반에서 `|offset| <= shelf.length/2 - BALL_DIAMETER/2`(선반 밖으로 안 나감). `t=0`일 때 선반별 위상이 달라 전부 같은 오프셋이 아니다.
- [ ] AC6: `Logic.isHit(diff)`류 판정: `diff = 2.2`면 true, `2.21`이면 false, `0`이면 true.
- [ ] AC7: `Logic.outwardDirection(centerX, centerZ, x, z)`: 중심에서 (x, z) 방향으로 단위 벡터를 돌려주고(4개 샘플 좌표로 방향 확인), `(x,z) == (centerX,centerZ)`(정확히 중심)일 때도 에러 없이 고정된 기본 방향을 돌려준다.
- [ ] AC8: `Logic.pawInterval(t)`: `7.9 → nil`, `8 → 5`, `24.9 → 5`, `25 → 3.2`, `44.9 → 3.2`, `45 → 2`, `60 → 2`.
- [ ] AC9: `Logic.pickShelf(occupancy, previousKey, rng)`: 가짜 rng로 — ① occupant 0인 선반은 절대 안 고름, ② `"Top"`(3단)은 절대 안 고름, ③ 후보가 2개 이상이면 `previousKey`와 같은 선반을 연달아 고르지 않음, ④ 후보가 `previousKey` 하나뿐이면 `nil`을 돌려줌.
- [ ] AC10: 장식 `MapKitLogic.validate` 통과, 파츠 600개 이하, 파티클 8개 이하, 조명 12개 이하. `inPool` 없음 또는 true.
- [ ] AC11: 검증 5단계 통과(rojo build, stylua, selene, lune run tests, luau-lsp) + 기존 `maps`·`m5-13-foundation` 테스트 그대로 통과. 못 돌린 단계는 보고에 적는다.

### Studio 확인 (`Config.DEBUG.forceMapPlan = { "rotating-belt", "cat-cafe-shelves", "skewer-showdown" }`, **확인 뒤 nil로 되돌림**)
- [ ] AC12: 혼자 1단 선반 위에 가만히 서 있어도(공·고양이 발에 안 맞으면) 떨어지지 않는다.
- [ ] AC13: 공이 선반 위를 왕복하는 게 보이고, 맞으면 바깥쪽으로 살짝 밀린다. 선반 가장자리 가까이서 맞으면 떨어져 탈락(손님 입 연출)한다.
- [ ] AC14: 8초가 지나면 주기적으로 선반 하나에 경고(주황빛/고양이 발 그림자)가 뜨고 1.1초 뒤 그 선반 위 사람 전원이 바깥쪽으로 크게 밀린다. 가장자리 근처였으면 떨어진다. 안쪽(구멍 쪽)에 가까이 서 있었으면 밀려도 안 떨어질 수 있다.
- [ ] AC15: 점프로 1단 → 2단 → 3단(꼭대기)까지 올라갈 수 있다. 꼭대기에서는 고양이 발 경고가 안 뜨지만 공은 여전히 돌아다닌다.
- [ ] AC16: 60초가 끝나면 그때 서 있던 사람 전원이 통과한다(목표 인원보다 많이 남아 있어도). 4명 이상인 판에서는 목표 인원만 남는 순간 바로 끝난다.
- [ ] AC17: 공·고양이 발에 밀린 직후 이동 감시(MovementGuard) 로그가 찍히지 않는다(`MoveExempt` 확인).
- [ ] AC18: 재미 확인(사용자): 좁은 선반 사이를 옮겨 다니는 느낌이 나는지, 밀리는 세기가 너무 약해서 안 떨어지거나 너무 세서 늘 떨어지지 않는지. 수치는 Layout 상수만 고친다.

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- AC18 체감, `CatToyBounce`·`CatPawWarn`·`CatPawSwipe` 소리 id(`docs/USER-TODO.md`에 추가). (선택) `assets/map-art/cat-cafe-shelves.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · D1 구조를 3단 "뚫린 테두리가 쌓인 피라미드"로 할지, 여러 독립된 타워를 늘어놓을지 · 단일 캣타워 + 위로 갈수록 좁아지는 테두리 모양을 골랐다. 테두리 자체가 "여러 개의 좁은 선반"(테두리 한 변 = 선반 하나)이라 GDD 원안의 "여러 높이의 좁은 선반들이 캣타워처럼 배치"를 literal하게 만족하고, 가운데 구멍으로 위 단에 점프해 올라가는 구조라 기하 계산이 간단해 순수 로직 테스트가 쉽다(독립 타워 여러 개 + 타워 간 다리를 놓는 안은 틈 계산이 더 복잡해 이번 배치에서는 제외). · planner
- 2026-10-09 · D2 꼭대기(3단)를 고양이 발에서 빼는 이유 · Survival은 시간 종료 때 버틴 사람 전원이 통과해서, 안전 지대가 전혀 없으면 60초 내내 쫓기기만 하다 운으로 갈릴 수 있다. `TempuraPot`도 맨 위 세 층을 "60초까지 안전"으로 뒀다(D2). 다만 공은 꼭대기에도 둬서 완전 무풍지대는 아니게 했다 · planner
- 2026-10-09 · D3 공·고양이 발 넉백을 둘 다 "타워 중심에서 바깥쪽"으로 통일한 이유 · 공은 선반 길이 방향으로 왕복하지만 맞았을 때 그 방향으로 계속 밀면 선반 반대쪽 끝(테두리 모서리)으로 갈 뿐 떨어지지 않는 경우가 많다. "가장자리 밖으로 밀리면 떨어진다"(GDD 원안)를 직접 만족시키려면 넉백이 테두리 폭(좁은 쪽) 방향, 즉 타워 중심 기준 바깥쪽이어야 한다 — 고양이가 테이블 위 물건을 앞발로 쳐서 바닥에 떨어뜨리는 것과 같은 그림이라 테마에도 맞다. 세기는 공(수평14)을 `SoySwamp` 날치알 넉백(공식 없음, 넘어짐 위주)보다 작게, 고양이 발(수평20)을 `SoySwamp` 와사비(수평 30 + 위 80, 점프대 역할이라 훨씬 큼)보다는 약하게 잡아 "밀려남"과 "큰 점프대"를 구분했다. **기본값, 플레이테스트 후 조정** · planner
- 2026-10-09 · D4 공을 물리 시뮬레이션 대신 사인파로 스크립트할지 · `RamenRapidsLogic.chashuHeight`(차슈 높낮이)가 같은 방식으로 이미 검증됐고, 네트워크 소유권 문제(`SoySwampHazards`의 날치알 공은 서버가 `SetNetworkOwner(nil)`로 소유해야 했던 전례, M1 B10)를 아예 피할 수 있어 더 단순하다 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 2026-10-09 · developer
- **바뀐 파일**
  - `src/shared/maps/CatCafeShelvesLayout.luau` (신규): 캣타워 3단 치수, `shelves()`(9개), `spawnOffsets()`(24개), `outerSideOf`/`topYOf`.
  - `src/shared/maps/CatCafeShelvesLogic.luau` (신규): `climbGap`, `ballOffset`(사인파 왕복), `isHit`, `outwardDirection`, `pawInterval`, `pickShelf`(occupant 가중 랜덤 + Top 제외 + 연속 금지).
  - `src/shared/maps/CatCafeShelvesArt.luau` (신규): 파스텔 카페 장식(벽·창문·기둥·캣방석·바구니·발자국), `introCamera()` 4점, `WINDOW_LIGHT`·`SUNBEAM` 마커.
  - `src/shared/maps/CatCafeShelves.luau` (덮어씀): 선반·공·스폰 빌드, 장난감 공 왕복·맞음 판정(`MoveExempt` 1.2초), 고양이 발 경고·넉백(`MoveExempt` 1.6초), `inPool = false` 줄 삭제.
  - `src/shared/SfxCues.luau`·`src/shared/SfxLibrary.luau`: `CatToyBounce`·`CatPawWarn`·`CatPawSwipe` cue 3개 추가(공용 파일 아님, 스펙대로).
  - `tests/map-cat-cafe-shelves.spec.luau` (신규): AC1~AC10 전부.
  - `docs/USER-TODO.md`: 새 소리 3개 항목 A2에 추가.
  - cat-cafe-shelves가 껍데기(inPool=false)에서 실제 맵(랜덤 풀에 들어감)으로 바뀌면서 맵 개수를 하드코딩한 기존 테스트를 맞게 고쳤어요: `tests/camera-priority.spec.luau`(SfxCues 목록에 cue 3개 추가), `tests/maps.spec.luau`(풀 6→7), `tests/m4-foundation.spec.luau`(Survival 2→3, cat-cafe-shelves 포함), `tests/m5-03-foundation.spec.luau`(SHELLS 목록에서 cat-cafe-shelves 제거, infos() 6→7, 기대표에서 cat-cafe-shelves 행 삭제), `tests/m4-12-hardening.spec.luau`(5판 강제 플랜 중 하나에 cat-cafe-shelves 추가해 맵 풀 전체를 덮게 함). GDD는 안 건드렸어요.
- **구현 메모**
  - 선반 9개 = "뚫린 사각 테두리"(긴 선반 North/South 바깥 한 변 전체 + 짧은 선반 East/West 겹치지 않는 길이) × 2단 + 3단 꽉 찬 판(Top). `Logic.climbGap`은 Layout의 단 치수를 읽어 안쪽 구멍 반지름 − 다음 단 바깥 반지름으로 계산.
  - 서 있는 선반 판정은 HotPlate와 같은 패턴(루트에서 아래로 짧은 레이캐스트, 태그 "CatCafeShelf" + Attribute "ShelfKey"만 필터)을 하나의 레이로 사용 — 공 맞음 판정(선반 축 기준 along 차)과 고양이 발 occupant 집계를 같은 틱에서 함께 계산.
  - 장난감 공은 Anchored 파츠를 매 Heartbeat마다 `Logic.ballOffset`으로 직접 재배치(물리 시뮬 아님, RamenRapids 차슈와 같은 방식) — 네트워크 소유권 문제를 피함.
  - 넉백은 `SoySwampHazards.launch`와 같은 방식(Attachment + LinearVelocity를 hold초만 걸고 destroy)을 이 파일 안에 그대로 재구현(공용 유틸로 빼지 않음, 다른 맵도 각자 구현하는 기존 관례를 따름).
  - 고양이 발 경고 시각 효과는 "선반 파츠 색을 주황으로 바꿨다가 되돌리는" 것으로 단순화했어요(스펙의 "주황빛/고양이 발 그림자" 중 전자만 구현, 둘 다는 과한 범위로 판단) — AC14 문구상 둘 중 하나면 충분.
- **Studio 확인 방법** (AC12~AC18, `docs/DEV-SETUP.md` 패턴 그대로)
  1. `Config.DEBUG.forceMapPlan = { "rotating-belt", "cat-cafe-shelves", "skewer-showdown" }`로 바꾸고 Studio Play.
  2. 1단 선반 위에 가만히 서서(AC12) 공·고양이 발을 피해 보고, 공에 맞아 바깥쪽으로 밀리는지/가장자리 근처에서 맞으면 떨어지는지(AC13) 확인.
  3. 8초가 지난 뒤 선반 하나가 주황으로 변하고 1.1초 뒤 그 위 전원이 크게 밀리는지, 가장자리 근처면 떨어지는지(AC14) 확인.
  4. 1단→2단→3단(꼭대기)까지 점프로 올라갈 수 있는지(수평 4 + 수직 5 조합), 3단에서는 고양이 발 경고가 안 뜨고 공만 도는지(AC15) 확인.
  5. 60초가 끝나면 그때 서 있던 사람 전원이 통과하는지, 4명 이상이면 목표 인원만 남는 순간 바로 끝나는지(AC16) 확인.
  6. 밀린 직후 서버 콘솔에 MovementGuard 로그(되돌림)가 안 찍히는지(AC17, `MoveExempt` 확인) 확인.
  7. 확인 뒤 `forceMapPlan`을 `nil`로 되돌리는 것 잊지 않기.
  8. AC18(재미 체감)은 사용자 몫 — 밀리는 세기가 과하거나 약하면 `CatCafeShelvesLogic`의 `BALL_KNOCK_*`/`PAW_KNOCK_*` 상수만 조정.
- **남은 이슈**: 없음. 소리 3개는 무음 상태(`docs/USER-TODO.md`에 추가), 사용자가 id를 고르면 됨. Studio 확인(AC12~AC18)은 아직 안 함 — QA·사용자 몫.
