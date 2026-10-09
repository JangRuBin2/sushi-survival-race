status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-13 — 맵 확장 1차 기반: 신규 맵 6개 껍데기 + 풀 등록

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.3("맵 테마 원칙 (v0.6)", "1차 확장 맵 6개 (v0.6 확정)"), §11.4(맵 모듈 인터페이스)
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md`(전체 배경, 특히 §3의 4·5·7·9·11·14번 — 이번에 고른 6개의 원안), `docs/specs/m5-03-foundation.md`(똑같은 역할을 한 선례 — "새 맵 껍데기 3개" 절)
- 담당 개발 worktree: **main (순차, 단계 0)** — 이 스펙이 머지·push된 뒤에 `m5-14`~`m5-19` worktree를 만든다(m5-03과 같은 방식). 공용 파일을 고치는 동안은 다른 M5 작업과 겹치지 않게 이 스펙을 먼저 끝낸다.
- 공용 파일 수정 담당: **이 스펙** — `src/shared/maps/init.luau`. `src/shared/maps/MapTypes.luau`는 이번에 바꾸지 않는다(계약 변경 없음, `inPool` 필드는 m5-03에서 이미 있음).
- **이 스펙이 고치는 파일**
  - 공용: `src/shared/maps/init.luau`(`ALL`에 6개 추가, `inPool = false`)
  - 새 파일 6개(아래 "맵 id ↔ 모듈 파일" 표): `src/shared/maps/BouncyCastleMaze.luau`, `src/shared/maps/LanternBridge.luau`, `src/shared/maps/GiantJenga.luau`, `src/shared/maps/CatCafeShelves.luau`, `src/shared/maps/TugOfWarPlatform.luau`, `src/shared/maps/ClawMachinePrize.luau`
  - 테스트: `tests/maps.spec.luau`(맵 개수 기대값 갱신), `tests/m5-03-foundation.spec.luau`(`Maps.allInfos()` 개수 기대값이 9 → 15로 바뀜 — AC1·AC2 관련 단언, 다른 스펙이 먼저 손댄 공용 테스트라 **수정하되 그 스펙의 의도는 건드리지 않는다**, 숫자만 맞춘다)

## 목표
사용자가 승인한 신규 맵 6개(`docs/GDD.md` §5.3, Race 2 / Survival 2 / Final 2)의 **껍데기**를 만들어 `shared/maps/init.luau`에 등록한다. m5-03이 `ikura-bombs`·`tempura-pot`·`dessert-fridge`에 했던 것과 똑같은 역할 — 회색 박스 지오메트리로 끝까지 한 판을 돌 수 있지만, `inPool = false`라 랜덤 판에는 아직 안 나온다. 이 스펙이 머지된 뒤 맵마다 스펙 하나씩(`m5-14`~`m5-19`)이 각자 worktree에서 실제 구현으로 덮어쓴다. 플레이어가 보기에 달라지는 것은 없다(랜덤 판 그대로 9개).

## 범위
- 포함:
  1. **새 맵 껍데기 6개** — `IkuraBombs.luau`(Final)·`DessertFridge.luau`(Race)·`TempuraPot.luau`(Survival) 패턴을 그대로 따른다: 회색 평면(`Part`, `Anchored`, `SmoothPlastic`) + `Spawns` 폴더(BasePart 24개, 이름순 `Spawn01`~`Spawn24`, 전부 판정 바닥 위, `CanCollide/CanTouch/CanQuery = false`) + 낙하 탈락 판정(`RunService.Heartbeat`로 `ctx.getRacers()`를 돌며 origin 기준 로컬 Y가 `-FALL_DEPTH` 아래면 `ctx.eliminate`). Race 맵은 추가로 `FinishLine` 파츠(Neon, 충돌 없음)와 로컬 -Z 진행도로 결승선 통과 판정(`ctx.pass`). Final 맵 2개는 추가로 `overtime` 훅(`IkuraBombs`와 동일한 패턴: `info.collapseDuration`초 뒤 바닥의 `CanCollide = false` + `Transparency = 1`, `task.delay`를 `ctx.cleanup:add`에 넣고 훅 자체는 즉시 반환).

     | id | kind | displayName | rule | 껍데기 모양 |
     |---|---|---|---|---|
     | `bouncy-castle-maze` | Race | 방방 미로 | 말랑한 바닥 위를 튕기며 미로를 빠져나가요. | `DessertFridge` 패턴(바닥 + Spawns 24 + FinishLine) |
     | `lantern-bridge` | Race | 등불 다리 건너기 | 흔들리는 다리와 종이 등불 사이를 건너요. | `DessertFridge` 패턴 |
     | `giant-jenga` | Survival | 와르르 나무 블록 | 흔들리는 블록탑 위에서 안 떨어지게 버텨요. | `TempuraPot` 패턴(바닥 + Spawns 24, 낙하만) |
     | `cat-cafe-shelves` | Survival | 고양이 카페 캣타워 | 흔들리는 캣타워 선반 위에서 버텨요. | `TempuraPot` 패턴 |
     | `tug-of-war-platform` | Final | 줄다리기 발판 | 발판이 기울며 한쪽 끝으로 미끄러져요. | `IkuraBombs` 패턴(접시 + Spawns 24 + 낙하 + overtime) |
     | `claw-machine-prize` | Final | 인형뽑기 기계 속 | 집게가 훑고 지나가는 유리 상자 안에서 버텨요. | `IkuraBombs` 패턴 |

     - id·kind·displayName·rule은 GDD §5.3에서 이미 확정이라 바꾸지 않는다(문구를 손보고 싶으면 각 맵 스펙(`m5-14`~`m5-19`)의 결정 기록에 적는다).
     - 치수(`SIZE`/`LENGTH`/`WIDTH`/`FALL_DEPTH`/`CENTER_Z` 등)는 기존 3개 껍데기와 같은 값을 그대로 써도 되고(겹치는 아레나라 큰 의미는 없음), 맵마다 살짝 달라도 된다 — 어차피 `m5-14`~`m5-19`가 전부 덮어쓴다. 각 파일 머리 주석에 "m5-13 껍데기 → `m5-1X`가 이 파일을 덮어씀. 실제 기믹은 결정 기록 참고"를 적고, 어떤 아이디어를 원안으로 하는지 1줄 남긴다(아래 "맵 id ↔ 모듈 파일" 표의 "원안" 칸).
  2. **맵 id ↔ 모듈 파일 ↔ 원안** (PascalCase 변환, `docs/proposals/map-expansion-and-quality.md` §3 번호)

     | id | 모듈 파일 | 원안(제안서 §3 번호) |
     |---|---|---|
     | `bouncy-castle-maze` | `BouncyCastleMaze.luau` | 4번 — 바닥 전체 트램펄린, 멈춰 설 수 없는 Race |
     | `lantern-bridge` | `LanternBridge.luau` | 5번 — 흔들리는 외나무다리, 몰린 인원이 많을수록 더 흔들림 |
     | `giant-jenga` | `GiantJenga.luau` | 7번 — 부분마다 다르게 흔들리는 블록탑 |
     | `cat-cafe-shelves` | `CatCafeShelves.luau` | 9번 — 좁은 선반 사이를 옮겨 다니며 버팀 |
     | `tug-of-war-platform` | `TugOfWarPlatform.luau` | 11번 — 살아남은 인원의 무게 분포로 기우는 시소 |
     | `claw-machine-prize` | `ClawMachinePrize.luau` | 14번 — 집게가 판정 지오메트리를 직접 들어 옮김 |
  3. **`shared/maps/init.luau` 등록** — `ALL`에 6개를 `require(script.<모듈명>)`로 추가(주석에 "m5-13 껍데기 → m5-1X"). `inPool = false`라 `Maps.infos()`는 **지금과 똑같이 9개만** 돌려준다. `Maps.allInfos()`는 9 → **15개**가 된다. `Maps.get(id)`로 15개 전부 조회 가능. `MatchService`의 강제 플랜(`Maps.allInfos()`)에는 새 6개도 바로 쓸 수 있다(m5-03이 만들어 둔 경로라 `MatchService` 수정 불필요).
  4. **테스트 기대값 갱신** — `tests/maps.spec.luau`의 "맵 풀 6개가 모두 validate를 통과해요"(`Maps.infos()` 개수 6 그대로 — 안 바뀜, 혼동 방지로 수용 기준에 명시)와 `tests/m5-03-foundation.spec.luau`의 `#Maps.allInfos() == 9` 단언을 15로, `allInfos` 순회 검증 루프에서 `inPool = false`로 기대하는 id 목록(지금 `ikura-bombs`·`tempura-pot`·`dessert-fridge`)에 새 6개를 추가.
- 제외:
  - 실제 기믹 구현(트램펄린 바운스, 다리 흔들림, 블록탑 무게중심, 선반 밀림, 시소 기울기, 집게 들어올리기) — `m5-14`~`m5-19`.
  - 장식(`<Map>Art.luau`), 소리(`MapSfx`), Studio 아트 연결 — 각 맵 스펙.
  - GDD 추가 수정(이미 v0.6에 확정 반영됨).

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `MapTypes.validate`가 신규 맵 6개 전부에 nil(통과)을 돌려준다. `tug-of-war-platform`·`claw-machine-prize`는 `type(map.overtime) == "function"`.
- [ ] AC2: `Maps.allInfos()`의 길이가 **15**(기존 9 + 신규 6). `Maps.infos()`의 길이는 **9 그대로**(신규 6개가 전부 `inPool = false`라 랜덤 풀에 안 들어간다 — 기존 3개 껍데기와 같은 상태). `Maps.infos()`를 순회해도 신규 6개 id가 하나도 안 나온다.
- [ ] AC3: `Maps.get("bouncy-castle-maze")` 등 6개 id 전부 `Maps.get`으로 조회된다(에러 없이 `MapModule`을 돌려준다). 중복 id 없음(`shared/maps/init.luau`의 `assert(not byId[map.id], ...)`가 통과한다는 뜻 — 즉 lune 테스트에서 15개 require가 전부 통과).
- [ ] AC4: `Rules.resolveForcedPlan({ "lantern-bridge", "giant-jenga", "claw-machine-prize" }, Maps.allInfos())`가 그 순서의 라운드 플랜을 돌려준다(신규 맵도 강제 플랜 대상이 된다는 확인).
- [ ] AC5: `Rules.buildRoundPlan`을 `Maps.infos()`로 여러 번(예: 1,000회) 돌려도 신규 6개 id가 한 번도 안 나온다(기존 AC2 패턴과 동일).
- [ ] AC6: 검증 5단계 통과(rojo build, stylua, selene, lune run tests, luau-lsp 타입 검사). 못 돌린 단계는 보고에 적는다.

### Studio 확인 (사용자 확인 필요)
- [ ] AC7: `Config.DEBUG.forceMapPlan = { "bouncy-castle-maze", "giant-jenga", "tug-of-war-platform" }`(또는 Race/Survival/Final 조합 아무거나)로 혼자 한 판이 신규 껍데기 3개를 끝까지 돈다. Race는 평평한 바닥을 달려 결승선을 통과, Survival은 60초(또는 `Config.TimeLimit.Survival`)간 평평한 바닥에 서 있으면 생존 통과, Final은 90초에 연장전이 걸리고 `Config.Final.CollapseDuration`초 뒤 바닥이 사라져 떨어지고 그 전까지 버틴(마지막까지 남은) 사람이 우승. Output에 에러 없음. **확인 뒤 `forceMapPlan`을 nil로 되돌린다.**
- [ ] AC8: Play Solo로 로비에 들어가 지금과 똑같이 보인다(새 버튼·새 맵 표시 없음, 랜덤 판에 신규 맵이 안 나온다는 걸 몇 판 돌려 체감 확인해도 됨 — 필수는 아님).

## 공용 파일 변경
- `shared/maps/init.luau`: `ALL`에 6개 추가(`inPool = false`). `Maps.infos()`는 그대로 9개, `Maps.allInfos()`는 15개.
- `shared/maps/MapTypes.luau`: 바꾸지 않음(계약 그대로).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · 신규 맵 6개의 id·kind·displayName·rule을 이 스펙에서 확정할지, GDD만 따를지 · GDD §5.3(v0.6)이 이미 확정한 값을 그대로 쓴다 — 이 스펙은 문구를 바꾸지 않는다. 문구 수정이 필요하면 각 맵 스펙(`m5-14`~`m5-19`)의 결정 기록에 적고 GDD도 같이 고친다 · planner
- 2026-10-09 · 껍데기 치수를 맵마다 다르게 할지 · 기존 3개 껍데기처럼 동일한 기본값(60×60 또는 160×40 등)을 재사용해도 되고, developer가 맵마다 살짝 바꿔도 된다 — 실제 구현(`m5-14`~`m5-19`)이 전부 덮어쓰므로 치수 자체는 중요하지 않다 · planner
- 2026-10-09 · `MapTypes.luau`를 안 건드리는 이유 · `inPool` 필드와 `overtime` 계약은 m5-01·m5-03에서 이미 만들어졌다. 이번 스펙은 그 계약을 쓰기만 하므로 공용 파일 중 `maps/init.luau`만 고치면 된다 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
