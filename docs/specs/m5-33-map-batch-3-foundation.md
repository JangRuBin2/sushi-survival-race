status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-33 — 맵 3차 배치 기반: 새 맵 6개 껍데기 + 등록 + 소리·파티클 이름 + 풀 개수 테스트 정리

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.1(한 판 맵 규칙), §5.3 "3차 배치 맵 6개 (v0.7, 사용자 콘셉트 시트)", §11.4(맵 모듈 인터페이스)
- 콘셉트: 사용자 시트 [`docs/스시 서바이벌 레이스 신규 맵 6종.png`](../스시%20서바이벌%20레이스%20신규%20맵%206종.png) (커밋 84ddcc1)
- 레퍼런스: [`docs/REFERENCE-map-batch-3.md`](../REFERENCE-map-batch-3.md)(사례·겹침 분석·풀 균형), 선례 [`m5-13`](m5-13-map-expansion-foundation.md)(같은 역할 — 껍데기 6개 + 등록)
- 담당 개발 worktree: **main (순차, 단계 0)** — 이 스펙이 머지·push된 뒤에 `m5-34`~`m5-39` worktree를 만든다.
- 공용 파일 수정 담당: **이 스펙 한 명** — `src/shared/maps/init.luau`. `MapTypes.luau`·`Config.luau`·`Remotes`·`Types`·`Attributes`·`default.project.json`·init 스크립트는 **바꾸지 않는다**(아래 "공용 파일 변경").
- 의존·순서:
  - `m5-23`·`m5-24`가 `main`에 있는 상태에서 시작(Extended 예산·`Art.LIGHTING`·렌더러 — 지금 `main`에 있음).
  - **`m5-32`(고등어 스킨, 다른 worktree 개발 중)가 `src/shared/SfxCues.luau`·`SfxLibrary.luau`에 `FishFlop`·`FishSplash`를 넣는다.** 이 스펙도 두 파일 끝에 cue를 더하므로, **m5-32가 먼저 `main`에 머지되면 그 뒤에 시작**한다. 먼저 시작해야 하면 두 파일 맨 끝에 "-- 맵 3차 배치 (m5-33)" 묶음으로 따로 넣어 병합 충돌을 줄이고, 병합 때 두 묶음을 모두 살린다. 이 스펙은 m5-32의 스킨·캐릭터 파일(`Skins.luau`, `SushiBody*`, `AppearanceService`, `CharacterFxController` 등)을 건드리지 않는다.

## 목표
사용자가 보낸 콘셉트 시트의 새 맵 6개(Race 2 · Survival 2 · Final 2)를 **회색 껍데기**로 만들어 맵 목록에 등록한다. 껍데기는 `inPool = false`라 랜덤 판에는 아직 안 나오고, 강제 플랜으로는 끝까지 한 판을 돌 수 있다. 6개 맵 스펙(`m5-34`~`m5-39`)이 각자 worktree에서 껍데기를 실제 맵으로 덮어쓸 때 **공용 파일·공용 테스트를 다시 고칠 일이 없게**, 소리 cue·파티클 프리셋·풀 개수 테스트를 여기서 한 번에 정리한다. 플레이어가 보기에 달라지는 것은 없다(랜덤 판 그대로 15개).

## 범위
### 포함
1. **새 맵 껍데기 6개** — `m5-13`과 같은 패턴. 회색 평면(`Part`, `Anchored`, `SmoothPlastic`) + `Spawns`(BasePart 24개, `Spawn01`~`Spawn24`, 전부 판정 바닥 위, 서로 3 이상, `CanCollide/CanTouch/CanQuery = false`) + 낙하 탈락(origin 기준 로컬 Y < −`FALL_DEPTH`면 `ctx.eliminate`). Race는 `FinishLine`(Neon, 충돌 없음) + 로컬 −Z 진행도 통과 판정. Final은 `overtime` 훅(`info.collapseDuration`초 뒤 바닥 `CanCollide = false` + `Transparency = 1`, `task.delay`를 `ctx.cleanup`에, 훅은 바로 반환). 각 파일 머리 주석: "m5-33 껍데기 → `m5-3X`가 이 파일을 덮어씀".

   | id | kind | displayName | rule (라운드 소개 한 줄) | 모듈 파일 | 덮어쓸 스펙 |
   |---|---|---|---|---|---|
   | `dish-sink` | Race | 깨끗하게! 설거지통 | 빙글빙글 접시와 움직이는 수세미를 피해 깨끗한 접시까지 달려요! | `DishSink.luau` | `m5-34` |
   | `space-conveyor` | Race | 우주 회전초밥 | 방향이 바뀌는 우주 레일을 타고, 떨어지는 운석을 피해 결승까지! | `SpaceConveyor.luau` | `m5-35` |
   | `rice-cooker` | Survival | 초대형 밥솥 | 끓어오르는 밥알과 뜨거운 증기를 피해 밥 위에서 버텨요! | `RiceCooker.luau` | `m5-36` |
   | `fish-market` | Survival | 수산시장 | 떨어지는 생선과 밀려오는 얼음을 피해 상자 위에서 버텨요! | `FishMarket.luau` | `m5-37` |
   | `tea-garden` | Final | 찻잎 정원 | 굴러오는 찻잔을 피해 단을 옮기고, 무너지는 차밭에서 끝까지 버텨요! | `TeaGarden.luau` | `m5-38` |
   | `onsen-claw` | Final | 온천탕 인형뽑기 | 인형뽑기가 쿵! 퍼지는 충격파는 점프로 넘고, 차오르는 온천물을 피해요! | `OnsenClaw.luau` | `m5-39` |

   - 이 표의 id·kind·displayName·rule이 확정값이다(GDD §5.3에 같은 표). 문구를 바꾸고 싶으면 각 맵 스펙의 결정 기록 + GDD를 같이 고친다.
   - 껍데기가 기존 "모든 맵" 테스트(예: `tests/m5-23-qa.spec.luau`의 맵별 조명·소개 카메라 검사, 아레나 상자 + 40)를 통과해야 한다. 필요하면 **최소 `<Map>Art.luau` 껍데기**(`BUDGET = "Extended"`, 로비와 ClockTime이 다른 `LIGHTING`, 빈 `decor()`, 소개 카메라 점 2개)를 같이 만들고 모듈에 `lighting = Art.LIGHTING`. 이 Art 껍데기도 각 맵 스펙이 덮어쓴다.
2. **등록** — `src/shared/maps/init.luau`의 `ALL` 끝에 6개 `require(script.<모듈>)`(주석 "m5-33 껍데기 → m5-3X"). `Maps.allInfos()` 15 → **21**, `Maps.infos()`는 **15 그대로**.
3. **소리 cue 14개 (무음)** — `src/shared/SfxCues.luau`의 `Effects` 끝과 `src/shared/SfxLibrary.luau`에 `sfx(nil, 볼륨)`으로. 맵 스펙들은 이 두 파일을 고치지 않는다(병렬 충돌 방지).

   | cue | 맵 (스펙) | 언제 | 볼륨 |
   |---|---|---|---|
   | `SpongeSquish` | `dish-sink` (m5-34) | 수세미에 밀리는 순간 | 0.7 |
   | `RailSwitch` | `space-conveyor` (m5-35) | 레일 방향이 바뀌기 0.4초 전 경고 | 0.6 |
   | `MeteorWarn` | `space-conveyor` (m5-35) | 운석 경고 원이 뜰 때 | 0.6 |
   | `MeteorImpact` | `space-conveyor` (m5-35) | 운석이 떨어진 순간 | 0.8 |
   | `RiceBubble` | `rice-cooker` (m5-36) | 밥알이 끓어 터지는 순간 | 0.7 |
   | `SteamWhistle` | `rice-cooker` (m5-36) | 증기 분사 경고(밸브 휘파람) | 0.6 |
   | `SteamBlast` | `rice-cooker` (m5-36) | 증기 분사 시작 | 0.8 |
   | `MarketFishWarn` | `fish-market` (m5-37) | ⚠ 생선 낙하 경고 | 0.6 |
   | `MarketFishSlam` | `fish-market` (m5-37) | 생선이 떨어진 순간·팔딱 | 0.8 |
   | `IceBlockSlide` | `fish-market` (m5-37) | 얼음 블록이 줄을 바꿔 출발 | 0.6 |
   | `TeaCupRoll` | `tea-garden` (m5-38) | 찻잔이 단을 옮기기 경고 | 0.6 |
   | `TeaFieldCrumble` | `tea-garden` (m5-38) | 차밭 단이 무너지는 순간 | 0.8 |
   | `ClawSlam` | `onsen-claw` (m5-39) | 인형뽑기가 "쿵" 내리찍는 순간 | 0.9 |
   | `OnsenRise` | `onsen-claw` (m5-39) | 물이 한 칸 오르고 데크가 가라앉기 경고 | 0.6 |

   - `m5-32`의 `FishFlop`·`FishSplash`(고등어 스킨)와 이름이 겹치지 않게 수산시장 cue는 `MarketFish*`로 했다.
4. **파티클 프리셋 3개** — `src/shared/maps/MapFxPresets.luau`의 `PRESETS`에 추가(기존 형식 그대로, `MapKitLogic.validate`가 아는 이름이 되게):
   - `SoapFoam`: 크고 느린 비눗방울(흰-하늘색, 투명도 0.4 → 1, 크기 0.6 → 1.6, 위로 천천히, Rate 기본 3) — `dish-sink`.
   - `Stardust`: 반짝이며 떠도는 별가루(흰·연보라, 크기 0.15~0.4, Speed 0.2~0.6, Lifetime 3~5) — `space-conveyor`.
   - `TeaLeaves`: 떨어지는 찻잎(연두·초록, `Petals`와 같은 움직임, 색만 다르게) — `tea-garden`(무너질 때 경고에도 씀).
   - 나머지(김·거품·벚꽃·반짝임)는 기존 `Steam`·`SteamThick`·`Bubbles`·`Petals`·`Sparkle`·`Embers`·`SeaSpray`를 쓴다.
5. **풀 개수 테스트를 "숫자 고정"에서 "목록 기준"으로** — 맵 스펙이 각자 `inPool = false` 줄을 지울 때마다 공용 테스트 숫자가 깨져 6개 worktree가 같은 줄을 고치는 일을 막는다(m5-19 개발 메모: 풀에 들어갈 때 테스트 5개가 깨졌음).
   - `#Maps.infos()`·`count == 15`처럼 **랜덤 풀 개수를 숫자로 고정한 단언**(지금 `tests/maps.spec.luau` 88줄, `tests/m5-03-foundation.spec.luau` 127줄 등)과, 랜덤 풀 id **목록을 고정한 단언**(m5-19 개발 기록의 `m4-foundation`·`m4-12-hardening`·`m2-01-qa` 등)을 찾아, 기대값을 `15 + (배치 3 중 inPool ~= false인 맵 수)` / "기존 15개 + 배치 3 중 풀에 든 것"으로 계산하게 바꾼다. 배치 3 id 목록은 새 테스트 파일 `tests/m5-33-batch3.spec.luau`(또는 `tests/lib/`의 작은 모듈)에 **한 곳**만 둔다.
   - `#Maps.allInfos()`를 고정한 단언(`m5-03-foundation` 95줄, `m5-13-qa` 78줄)은 21로 바꾼다(배치 3 동안 안 바뀜).
   - 그 테스트들의 **원래 의도는 그대로** 둔다(m5-13 선례: 숫자·목록만 맞춘다). 바꾼 파일·줄·전후는 개발 메모에.
6. **새 테스트 `tests/m5-33-batch3.spec.luau`** — 아래 AC1~AC7.
7. **현지화(m5-26)와의 순서** — `m5-26`(현지화, ready)이 이 스펙보다 먼저 `main`에 들어가 있으면, 그 AC5("모든 맵의 `map.<id>.name|rule`이 CSV에 있어야 함")가 새 6개 때문에 깨진다. 그때는 **이 스펙이 6개 맵의 `map.<id>.name`·`map.<id>.rule` 줄(한국어 원문 + 영어)을 CSV에 한 번에** 넣는다(맵 스펙 6개가 같은 CSV를 고치지 않게). 영어 초안: Squeaky Clean Sink / Space Sushi Lane / Giant Rice Cooker / Fish Market / Tea Leaf Garden / Hot Spring Claw Machine (rule 영어는 developer가 짧게 번역, 결정 기록에). m5-26이 아직이면 할 일 없음(m5-26이 그때 21개 전부를 수집).
8. **길이 기준 공유** — 새 Race 2개는 약 445·470 studs(빠른 사람 45~55초), 새 Survival 2개는 맵 `timeLimit = 75`(`m5-34`~`m5-37` 결정 기록, 사용자 요청 "맵이 좀 짧다"). 껍데기는 이 길이를 흉내 낼 필요 없다. `m5-40`(기존 맵 길이 늘리기)과 파일이 겹치지 않는다.

### 제외
- 실제 장애물·지형·아트(각 맵 스펙 `m5-34`~`m5-39`).
- `Config`·`MapTypes` 계약 변경 — 필요 없음(아래 결정 기록 D2). 맵 상태·수치는 각 맵 `*Layout`·`*Logic` 상수.
- 공용 넉백 도우미 모듈 — 만들지 않는다. 맵마다 기존 패턴(`SoySwampHazards`·`IkuraBombs`의 `LinearVelocity` 짧게 + `PlatformStand` + `MoveExempt.mark`)을 자기 파일에 둔다(병렬 개발 중 공용 모듈을 함께 고치면 충돌). 배치가 끝난 뒤 정리 후보.
- GDD 추가 수정(planner가 이미 §5.3에 반영).

## 수용 기준
### 순수 로직 (lune 테스트, `tests/m5-33-batch3.spec.luau`)
- [x] AC1: 새 6개가 `MapTypes.validate`를 통과한다. `tea-garden`·`onsen-claw`는 `type(map.overtime) == "function"`. id·kind·displayName·rule이 위 표와 똑같다.
- [x] AC2: `#Maps.allInfos() == 21`. 껍데기 상태에서 `#Maps.infos() == 15`이고 새 6개 id가 `Maps.infos()`에 없다. 6개 모두 `Maps.get(id)`로 조회된다(중복 id 없음).
- [x] AC3: `Rules.resolveForcedPlan({ "dish-sink", "rice-cooker", "tea-garden" }, Maps.allInfos())`와 `{ "space-conveyor", "fish-market", "onsen-claw" }`가 그 순서의 플랜을 돌려준다.
- [x] AC4: `Rules.buildRoundPlan`을 `Maps.infos()`로 1,000번 돌려도 껍데기 상태(inPool = false)인 배치 3 id가 하나도 안 나온다. **배치 3 맵이 풀에 들어간 뒤에도** 이 테스트가 깨지지 않게, 기대는 "inPool = false인 배치 3 맵은 안 나옴"으로 쓴다(풀에 든 것은 나와도 됨).
- [x] AC5: 껍데기 6개의 `build(CFrame.new())`가 `Spawns` 24개(전부 판정 바닥 위, 서로 3 이상)를 만들고, Race 2개는 `FinishLine`이 스폰보다 −Z 쪽이다.
- [x] AC6: `SfxCues.isEffect`가 위 cue 14개에 true, `SfxLibrary`에 14개 항목이 있고 id가 nil(무음). `MapFxPresets.PRESETS`에 `SoapFoam`·`Stardust`·`TeaLeaves`가 있고 기존 프리셋 검사(있다면)를 통과한다.
- [x] AC7: "목록 기준"으로 바꾼 풀 개수 테스트가 **배치 3 중 아무거나 `inPool = false`를 지워도** 통과한다 — 테스트 안에서 껍데기 하나를 풀에 넣은 가짜 목록으로 계산 함수를 한 번 확인(예: 기대 개수 함수가 15 + 1을 돌려줌).
- [x] AC8: 검증 5단계 통과(rojo build, stylua, selene, lune run tests — 마지막 줄 `0 failed`, luau-lsp 타입 검사). 못 돌린 단계는 보고에 적는다.

### Studio 확인 (사용자 확인 필요)
- [ ] AC9: `Config.DEBUG.forceMapPlan = { "dish-sink", "rice-cooker", "tea-garden" }`로 혼자 한 판이 끝까지 돈다(Race 결승선 통과 → Survival 60초 버티면 통과 → Final 90초 연장전 → 20초 뒤 바닥 사라짐 → 우승). `{ "space-conveyor", "fish-market", "onsen-claw" }`도 같다. Output 에러 없음. **확인 뒤 `forceMapPlan = nil`.**
- [ ] AC10: 강제 플랜 없이 몇 판 하면 지금과 똑같이 기존 15개만 나온다(체감 확인, 필수 아님).

## 공용 파일 변경
- `src/shared/maps/init.luau`: `ALL`에 6개 추가(껍데기는 `inPool = false`). **이 스펙만 수정.**
- `shared/maps/MapTypes.luau`, `shared/Config.luau`, `Remotes`, `Types`, `Attributes`, `default.project.json`, init 스크립트, `rokit.toml`: 바꾸지 않음.
- 공용 목록 밖이지만 병렬 충돌을 막으려고 이 스펙이 한 번에 고치는 파일: `src/shared/SfxCues.luau`, `src/shared/SfxLibrary.luau`, `src/shared/maps/MapFxPresets.luau`, 풀 개수를 고정한 기존 테스트들. **맵 스펙 6개는 이 파일들을 고치지 않는다.**

## 맵 스펙 작업 나눔 (worktree 병렬)
| 스펙 | 맵 | worktree / Rojo 포트 | 그 스펙만 고치는 파일 |
|---|---|---|---|
| `m5-34` | `dish-sink` | `m5-map-sink` / 34892 | `DishSink.luau`(덮어씀)·`DishSinkLayout`·`DishSinkLogic`·`DishSinkArt`, `tests/map-dish-sink.spec.luau`, `docs/renders/dish-sink/` |
| `m5-35` | `space-conveyor` | `m5-map-space` / 34893 | `SpaceConveyor*`, `tests/map-space-conveyor.spec.luau`, `docs/renders/space-conveyor/` |
| `m5-36` | `rice-cooker` | `m5-map-rice` / 34894 | `RiceCooker*`, `tests/map-rice-cooker.spec.luau`, `docs/renders/rice-cooker/` |
| `m5-37` | `fish-market` | `m5-map-fish` / 34895 | `FishMarket*`, `tests/map-fish-market.spec.luau`, `docs/renders/fish-market/` |
| `m5-38` | `tea-garden` | `m5-map-tea` / 34896 | `TeaGarden*`, `tests/map-tea-garden.spec.luau`, `docs/renders/tea-garden/` |
| `m5-39` | `onsen-claw` | `m5-map-onsen` / 34897 | `OnsenClaw*`, `tests/map-onsen-claw.spec.luau`, `docs/renders/onsen-claw/` |
- 각 맵 스펙은 끝날 때 **자기 모듈의 `inPool = false` 줄만 지운다**(`init.luau`는 안 고침). 풀에 넣어서 다른 공용 테스트가 깨지면 고치지 말고 결정 기록에 적고 멈춘다(그건 AC7이 막았어야 할 일 — m5-33 담당이 main에서 고침).
- 머지 순서 자유(파일이 안 겹침). **머지할 때마다 `main`에서 검증 5단계를 다시** 돌린다(m4-09 B1·m5-08 교훈). 6개가 다 들어가면 `#Maps.infos() == 21`(Race 8 · Survival 7 · Final 6)이 되는지 메인 세션이 확인한다.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · D1 시트 이름에서 "레이스/생존/결승"을 뺄지 · 뺀다. 기존 맵 표시 이름(`회전 벨트`, `인형뽑기 기계 속`)에 종류 낱말이 없고, 라운드 소개가 종류를 따로 보여 준다. 시트 콘셉트 낱말(깨끗하게!·우주 회전초밥·초대형·온천탕 인형뽑기)은 그대로 살림 · planner (메인 세션 위임)
- 2026-10-14 · D2 `Config`·`MapTypes`를 바꿔야 하나 · 아니요. 시간 제한은 `Config.TimeLimit` 기본(Race 90·Survival 60·Final 90 + 연장전), 저중력(우주)·타이머 표시(밥솥)·충격파(온천)는 전부 맵 모듈 안에서 끝난다. 밥솥 시트의 "00:45"는 예시 숫자로 보고 Survival 60초를 유지 · planner (메인 세션 위임)
- 2026-10-14 · D3 공용 테스트 숫자 문제 · m5-13~19 때 맵이 풀에 들어갈 때마다 공용 테스트 5개를 맵 담당이 고쳤다. 6개 병렬이면 같은 줄 충돌이 6번 난다 → 기반에서 "목록 기준"으로 바꿔 한 번에 끝낸다 · planner
- 2026-10-15 · D5 (developer) 범위 7 현지화 CSV · `m5-26`이 아직 `main`에 없어서(`src/shared/Localization` 없음) 할 일 없음 — m5-26 병합 때 21개 전부를 수집 · developer
- 2026-10-15 · D6 (developer) 껍데기 Race 바닥 · m5-13 껍데기 패턴 그대로면 스폰 4번째 줄(z = 15)이 바닥 뒤 가장자리(z = +10) 밖이라 AC5 "전부 판정 바닥 위"를 못 지켜요. 새 껍데기 2개는 바닥을 뒤로 10 늘림(뒤 가장자리 z = +20). 기존 맵 파일은 안 건드림 · developer
- 2026-10-14 · D4 cue·파티클 프리셋을 기반에서 · 같은 이유(공용 목록 밖이지만 6개가 같은 파일 끝에 줄을 더함). 맵 스펙에서 새 cue·프리셋이 더 필요해지면 결정 기록에 적고 이 스펙 담당이 main에서 추가 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
2026-10-15 · developer · `main` 커밋 55e578c (push 안 함 — 메인 세션 판단)

**바뀐 파일**
- 새 맵 껍데기 6개 + Art 껍데기 6개 (`src/shared/maps/`): `DishSink`·`SpaceConveyor`(Race: 회색 바닥 + 스폰 24 + `FinishLine` z = −160), `RiceCooker`·`FishMarket`(Survival: 60×60 접시 + 스폰 24), `TeaGarden`·`OnsenClaw`(Final: 접시 + `overtime` — `collapseDuration`초 뒤 접시 `CanCollide = false`·`Transparency = 1`, `task.delay`를 `ctx.cleanup`에). 모두 `inPool = false`, `lighting = Art.LIGHTING`, 낙하 Y < −25 탈락, build 끝에서 `MapKit.introCamera`·`attachStudioArt`. `<Map>Art.luau`는 `BUDGET = "Extended"`, 로비(14시)와 다른 `ClockTime`의 `LIGHTING`(10 / 0 / 16 / 7 / 17.5 / 20), 빈 `decor()`, 소개 카메라 점 2개(아레나 상자 + 40 안). **둘 다 각 맵 스펙이 덮어씀.**
- 공용 `src/shared/maps/init.luau`: `ALL` 끝에 6개 `require` (주석 "m5-33 껍데기 → m5-3X").
- `src/shared/SfxCues.luau`·`SfxLibrary.luau`: 표의 cue 14개를 "맵 3차 배치 (m5-33)" 묶음으로 끝에 추가, 전부 `sfx(nil, 볼륨)` 무음. m5-32 `FishFlop`·`FishSplash`는 그대로.
- `src/shared/maps/MapFxPresets.luau`: `SoapFoam`·`Stardust`·`TeaLeaves` (TeaLeaves = Petals 움직임 + 연두·초록).
- 새 테스트: `tests/lib/Batch3.luau`(배치 3 id·종류 **한 곳**, `expectedPoolCount(get)` = 15 + 풀에 든 배치 3, `pooledOfKind`, `isBatch3`), `tests/m5-33-batch3.spec.luau`(AC1~AC7, 7개). AC5는 껍데기 파츠 이름(Floor·Plate)에 기대지 않고 "스폰 아래 충돌 파츠 윗면"으로 검사해서 맵 스펙이 덮어써도 그대로 쓸 수 있어요.

**"목록 기준"으로 바꾼 기존 테스트 (원래 의도 유지, 숫자·목록만)**
| 파일 | 전 | 후 |
|---|---|---|
| `tests/maps.spec.luau` ("맵 풀 15개 validate") | `t.eq(count, 15)` | `t.eq(count, Batch3.expectedPoolCount(Maps.get))` |
| `tests/m5-03-foundation.spec.luau` AC1 | `#Maps.allInfos() == 15`, 모든 비-expected 맵 `inPool ~= false` | `== 21`, 배치 3은 `inPool` 검사에서 제외(`Batch3.isBatch3`) |
| `tests/m5-03-foundation.spec.luau` AC2 | `#Maps.infos() == 15` | `Batch3.expectedPoolCount(Maps.get)` |
| `tests/m5-13-qa.spec.luau` | `#Maps.allInfos() == 15` | `== 21` |
| `tests/m4-foundation.spec.luau` AC6 | 종류별 풀 id 목록 고정 | 같은 목록 + `Batch3.pooledOfKind(Maps.get, kind)` |
| `tests/m2-01-qa.spec.luau` "결승은 등록된 Final 중 하나" | Final 4개 고정 | + 풀에 든 배치 3 Final |
| `tests/m4-12-hardening.spec.luau` "연속 플랜이 풀의 맵을 모두 씀" | 풀 전체 | 배치 3은 제외(각 맵 테스트가 강제 플랜을 봄) |
| `tests/camera-priority.spec.luau` AC3 (cue 확정 목록) | 51개 | + 새 cue 14개 |
- **AC7 실제 확인**: 껍데기 2개(`rice-cooker`·`tea-garden`), 그다음 6개 전부의 `inPool = false`를 임시로 지우고 `lune run tests` → 둘 다 **1999 passed, 0 failed** (그 뒤 원래대로 되돌림). 맵 스펙이 `inPool = false` 줄만 지워도 공용 테스트는 안 깨져요.

**검증 5단계** (2026-10-15, Windows): `rojo build` 성공 · `stylua --check src tests tools` 통과 · `selene src` 0 errors 0 warnings · `lune run tests` **1999 passed, 0 failed**(이전 1992 → +7) · `luau-lsp analyze` 끝 코드 0.

**Studio 확인 (사용자, AC9·AC10)**
1. `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "dish-sink", "rice-cooker", "tea-garden" }` → Play Solo(`minPlayersToStart = 1`)로 시작 → 회색 바닥을 달려 노란 결승선 통과 → 회색 접시에서 60초 버티면 통과 → 결승 접시에서 90초에 연장전 경적 → 20초 뒤 접시가 사라지고 떨어져 마무리(혼자면 우승). Output에 빨간 에러 없음. 라운드마다 조명 분위기가 바뀌는지(설거지통 오전·밥솥 오후·찻잎 저녁)도 보면 좋아요.
2. `{ "space-conveyor", "fish-market", "onsen-claw" }`로 한 번 더(우주 = 밤 조명).
3. **확인 뒤 `forceMapPlan = nil`로 되돌리기.**
4. (선택) 강제 플랜 없이 몇 판 — 기존 15개만 나와야 해요.

**남은 이슈**: 없음. 맵 스펙(m5-34~39)에서 cue·프리셋이 더 필요하면 결정 기록에 적고 m5-33 담당이 main에서 추가(D4).
