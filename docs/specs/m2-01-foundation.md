status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m2-01 — M2 기반 작업 (공용 파일 · 맵 풀 · 라운드 구성 · 디버그 플랜)

- 마일스톤: M2
- GDD 근거: `docs/GDD.md` §5.1(라운드 구성 규칙), §5.2(맵 목록), §11.4(상태 머신)
- 담당 개발 worktree: `main` (**순차, M2에서 가장 먼저**. 이 스펙이 `main`에 병합된 뒤에 m2-02~m2-06 worktree를 만든다)
- 공용 파일 수정 담당: **이 스펙** — `shared/Config.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `default.project.json`. M2의 다른 스펙은 이 파일들을 고치지 않는다.
- 의존: **M1 버그 수정(`docs/qa/m1-retro.md` B1~B9) 커밋이 `main`에 들어간 뒤 시작**한다. 그 수정 위에서 작업하고, B1~B9 수정은 이 스펙 범위가 아니다. → **m2-02, m2-03, m2-04, m2-05, m2-06이 이 스펙에 의존**

## 목표
M2 병렬 개발이 서로 같은 파일을 건드리지 않도록 공용 파일 변경을 한 번에 끝낸다. 새 맵 3개를 "동작하는 최소 껍데기(stub)"로 먼저 맵 풀에 넣어서, 맵 담당 worktree는 자기 맵 파일만 고치고 매치 흐름 담당은 처음부터 4종 맵으로 한 판을 돌려 볼 수 있게 한다.

## 범위
- 포함:
  1. **라운드 구성 중복 제거** (`shared/Rules.luau`): 맵 풀이 GDD 구성을 만족할 만큼 있으면 한 판에 같은 맵이 절대 나오지 않게 한다. 지금 `roundKinds`는 맵 개수를 보지 않고 가운데 라운드를 Survival로 두 번 뽑을 수 있다 → Survival 맵이 1개뿐이면 같은 맵이 두 번 나온다. 종류별 맵 개수를 넘지 않게 종류를 고른다. 맵이 모자란 개발 초기 fallback(같은 맵 재사용)은 그대로 둔다.
  2. **디버그 강제 플랜**: `Config.DEBUG.forceMapPlan: { string }?` (기본 `nil`). Studio(`RunService:IsStudio()`)에서 값이 있으면:
     - 라운드 구성을 그 맵 id 순서 그대로 쓰고, 라운드 수 = 목록 길이.
     - 남은 인원이 2명 이하여도 결승으로 건너뛰지 않고, **혼자여도 목록의 모든 라운드를 끝까지 돈다** (MatchService 루프 조건을 "생존자 1명 이상"으로).
     - 목록 길이가 3이나 4가 아니거나 모르는 id가 있으면 경고를 찍고 무시한다(평소처럼 랜덤 구성).
     - 검증은 순수 함수 `Rules.resolveForcedPlan(ids, pool) -> ({MapInfo}?, string?)`로 분리한다.
     - 실제 서버(Studio 아님)에서는 값이 있어도 무시한다.
  3. **새 맵 3개 stub** (파일 생성 + `maps/init.luau`의 `ALL`에 등록). id·종류·이름·규칙 문구는 아래 값으로 **확정**이다(이후 스펙이 바꾸지 않는다).

     | 파일 | id | kind | displayName | rule |
     |---|---|---|---|---|
     | `maps/SoySwamp.luau` | `soy-swamp` | Race | 간장 늪 & 와사비 산 | 간장 웅덩이는 피하고, 와사비 패드로 튀어 올라 결승선까지! |
     | `maps/HotPlate.luau` | `hot-plate` | Survival | 뜨거운 철판 | 밟은 철판은 곧 사라져요. 계속 움직여서 끝까지 버티세요! |
     | `maps/SkewerShowdown.luau` | `skewer-showdown` | Final | 회전 꼬치 쇼다운 | 돌아오는 꼬치를 뛰어넘고 끝까지 버티세요! 마지막 1명만 탈출해요 |

     stub의 `build`는 회색 바닥 + `Spawns` 24개 (+ Race는 `FinishLine`), `start`는 (Race만) 결승선 Touched → `ctx.pass`, origin 아래 40 studs 낙하 → `ctx.eliminate`만 한다. Survival·Final stub은 결승선 없이 떨어지면 탈락하는 바닥만 둔다(결승은 v0.3부터 생존형). 실제 맵은 m2-02~04가 같은 파일을 덮어쓴다.
  4. **`shared/Types.luau` 데이터 모양 추가** (값을 채우는 건 m2-05, 쓰는 건 m2-06):
     ```lua
     export type Standing = { userId: number, name: string, place: number }
     -- MatchPhaseInfo에 추가
     aliveUserIds: { number }?,   -- 이 매치에서 아직 탈락하지 않은 플레이어 (모든 단계에 실어 보냄)
     standings: { Standing }?,    -- Victory: 최종 순위 (1등부터)
     -- RoundProgress에 추가
     racerUserIds: { number },    -- 이번 라운드에서 아직 통과/탈락하지 않은 플레이어
     ```
     m2-05가 머지되기 전에도 깨지지 않게 `RoundService`의 RoundProgress 방송에 `racerUserIds`만 채워 둔다(지금 `remaining` 목록 그대로).
  5. **`shared/Config.luau`**: `Config.DEBUG.forceMapPlan = nil`, `Config.Character.JumpPower = 50` 추가. 서버가 캐릭터 이동 잠금을 풀 때 이 값으로 되돌린다(m2-02·m2-05에서 사용). M1 B4 수정이 이미 점프 복구 값을 Config에 넣었다면 새로 만들지 말고 그 값을 쓴다.
  6. **`default.project.json`**: `Workspace`에 `StreamingEnabled = false`를 명시한다. 관전자는 캐릭터가 로비(원점)에 있고 카메라만 수천 studs 떨어진 아레나를 보기 때문에, 스트리밍이 켜져 있으면 아레나가 안 보인다. M4 플레이스 분리 때 다시 검토한다.
  7. 테스트: `tests/rules.spec.luau`, `tests/maps.spec.luau`에 아래 순수 로직 기준을 추가한다. (이후 맵 worktree는 `maps.spec.luau`를 고치지 않고 필요하면 자기 파일 `tests/map-<id>.spec.luau`를 만든다.)
- 제외:
  - 각 맵의 실제 코스·장애물 (m2-02, m2-03, m2-04)
  - 라운드 진행·탈락·순위 로직 변경 (m2-05), 관전·우승 UI (m2-06)
  - M1 소급 QA 버그 B1~B9 (main에서 따로 수정 중)
  - `shared/Remotes.luau`: M2에서는 **변경 없음** (새 리모트가 필요 없게 설계했다. 필요해지면 사용자에게 먼저 알린다)

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: 맵 풀 `{Race 2개, Survival 1개, Final 1개}`로 시드 1~500에서 `buildRoundPlan(4, …)`을 만들면 매번 첫 라운드 Race, 마지막 Final, 맵 중복 0회, Survival 정확히 1번, Race 정확히 2번이다.
- [ ] AC2: 같은 풀로 `buildRoundPlan(3, …)`을 시드 1~500에서 만들면 중복 0회이고, 가운데 라운드가 Race인 경우와 Survival인 경우가 둘 다 나온다.
- [ ] AC3: 같은 풀의 4라운드 구성에서 Survival이 2라운드에 오는 경우와 3라운드에 오는 경우가 둘 다 나온다.
- [ ] AC4: 기존 테스트(6맵 GDD 풀 규칙, 맵 1개뿐일 때 fallback, 빈 풀 에러)가 그대로 통과한다.
- [ ] AC5: `Rules.resolveForcedPlan({"soy-swamp","hot-plate","skewer-showdown"}, pool)`은 그 순서의 MapInfo 3개를 돌려준다. 길이 2·5인 목록, 모르는 id가 섞인 목록은 `nil`과 이유 문자열을 돌려준다.
- [ ] AC6: `Maps.infos()`에 Race가 2개 이상, Survival 1개 이상, Final 1개 이상 있고, `soy-swamp`/`hot-plate`/`skewer-showdown`이 각각 위 표의 kind로 `MapTypes.validate`를 통과한다.
- [ ] AC7: `rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests`가 통과한다.

### Studio 확인
- [ ] AC8: 혼자(F5) `forceMapPlan = nil`로 방을 만들고 시작하면 지금처럼 매치가 돌고, 서버 Output에 빨간 에러가 없다.
- [ ] AC9: `Config.DEBUG.forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`로 두고 혼자 시작하면 라운드 소개 배너가 "라운드 1/4 · 간장 늪 & 와사비 산" → "2/4 · 뜨거운 철판" → "3/4 · 회전 벨트" → "4/4 · 회전 꼬치 쇼다운" 순서로 뜨고, 각 stub 맵에 캐릭터가 배치된다. 결승선 통과로 Race 라운드가 끝나고, Survival은 시간 종료(60초)로 끝난다. 결승 stub은 혼자일 때 떨어지거나 시간(90초)이 끝나면 "🏆 우승!"이 뜬다 (혼자 결승의 우승 처리는 m2-05 규칙. m2-05 전에는 시간 종료 때 우승이면 된다).
- [ ] AC10: `forceMapPlan`에 `"no-such-map"`을 넣고 시작하면 서버 Output에 경고가 한 번 찍히고 랜덤 구성으로 매치가 돈다.
- [ ] AC11: Play 중 서버에서 `workspace.StreamingEnabled`가 `false`다.

## 공용 파일 변경
- `shared/Config.luau`: `DEBUG.forceMapPlan` (기본 nil), `Character.JumpPower = 50`
- `shared/Remotes.luau`: 없음
- `shared/Types.luau`: `Standing`, `MatchPhaseInfo.aliveUserIds/standings`, `RoundProgress.racerUserIds`
- `shared/maps/init.luau`: `ALL`에 SoySwamp, HotPlate, SkewerShowdown 추가
- `default.project.json`: `Workspace.$properties.StreamingEnabled = false`
- 이 스펙 머지 이후 위 파일을 바꿔야 하면 해당 worktree는 직접 고치지 말고 사용자에게 알린다.

## 결정 기록
- 2026-10-08 · M2에 어떤 맵을 만들지 · Race ②"간장 늪 & 와사비 산", Survival ⑤"뜨거운 철판", Final ⑥. 이유: CLAUDE.md에 예약된 태그(`SoySauce`, `Wasabi`, `HotTile`)를 그대로 쓰고, ⑤가 ④"셰프의 도마"(기울어지는 물리 원판)보다 회색 박스로 판정이 안정적이다. ③라멘 급류·④도마는 M4 이후. · planner
- 2026-10-08 · **확정 (사용자 결정, 메인 세션 경유)** · "마지막 라운드는 무조건 서바이벌로. 폴가이즈 참고" → 결승은 마지막 1명이 남을 때까지 버티는 생존형(GDD v0.3). 레이스형이던 ⑥"꼬치 다리 대탈출"(`skewer-bridge`)을 생존형 ⑥"회전 꼬치 쇼다운"(`skewer-showdown`, 폴가이즈 Jump Showdown 참고)으로 다시 설계했다. kind 세 종류와 라운드 구성 규칙(`Rules`)은 그대로라 AC1~AC4는 바뀌지 않는다. · user / planner
- 2026-10-08 · 혼자 테스트로 Survival/Final을 확인할 방법 · `Config.DEBUG.forceMapPlan`(Studio 전용) 추가 · planner
- 2026-10-08 · 관전 카메라가 먼 아레나를 보려면 · MVP는 `StreamingEnabled = false`. M4 플레이스 분리 때 재검토 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
