# QA — m2-01 M2 기반 작업 (공용 파일 · 맵 풀 · 라운드 구성 · 디버그 플랜)

- 스펙: `docs/specs/m2-01-foundation.md`
- 검증 커밋: `7f4cb8d` (main, 위에 문서 커밋 `f304e6a`)
- 결과: **통과 (P0/P1 없음)** → 스펙 상태 `qa-passed`. P2 1건(점프 설정 고정, 확인 필요)은 m2-02~06 worktree를 만들기 **전에** 처리하길 권한다 (아래 F1).

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과. 별도로 `.rbxlx`로 빌드해 `Workspace.StreamingEnabled = false`가 들어간 것도 확인 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 94 passed, 0 failed (개발 88 + QA 추가 6) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m2-01 AC1: Race 2·Survival 1·Final 1 풀의 4라운드 …` (시드 1~500). 같은 성질을 **실제 풀**로도 확인: `실제 맵 풀: 3·4라운드 구성 500판씩 …` (QA) |
| AC2 | 통과 | `m2-01 AC2: 같은 풀의 3라운드는 중복 0, 가운데가 Race인 판과 Survival인 판이 둘 다 나와요` |
| AC3 | 통과 | `m2-01 AC3: … Survival이 2라운드인 판과 3라운드인 판이 둘 다 나와요` |
| AC4 | 통과 | 기존 `buildRoundPlan: 첫 Race, 끝 Final …`(6맵 풀), `맵이 모자라면 있는 맵으로 채워요`, `맵 풀이 비면 에러` 그대로 통과. 무작위 풀 2000개 성질 테스트(QA): 개수가 충분하면 중복 0, 첫 Race·끝 Final·4라운드 Survival ≥ 1 |
| AC5 | 통과 | `m2-01 AC5: resolveForcedPlan은 그 순서의 MapInfo를 돌려줘요`, `… 길이 2·5, 모르는 id, 목록이 아닌 값을 거절해요`, `스펙 계약: m2-01 AC10 예시(no-such-map)는 거절돼요` (QA) |
| AC6 | 통과 | `m2-01 AC6: 맵 풀에 Race 2개 이상 …`, `m2-01 AC6: 새 맵 3개가 확정된 id·종류·이름·규칙으로 …`. 표의 id·kind·displayName·rule이 글자 그대로 일치 (`maps/SoySwamp.luau`, `HotPlate.luau`, `SkewerShowdown.luau`) |
| AC7 | 통과 | 위 자동 검증 |
| AC8 | 사용자 확인 필요 | 코드상 `forceMapPlan = nil`이면 예전 경로(`MatchService.luau:92-110`). 혼자면 생존자 1명이라 라운드 없이 끝나는 것도 예전과 같다 |
| AC9 | 사용자 확인 필요 | 코드 경로 확인: 강제 플랜이면 라운드 수 = 목록 길이, 건너뛰기 없음, `minAlive = 1` (`MatchService.luau:92-128`). 혼자 4라운드 흐름을 추적해 보면 R1 soy-swamp stub(결승선 통과 → remaining 0으로 종료), R2 hot-plate stub(목표 2 > 1명 → 60초 시간 종료 → 버틴 사람 통과), R3 회전 벨트, R4 결승 stub(90초 시간 종료 → 1명 `Won`) 순서로 돈다 |
| AC10 | 사용자 확인 필요 | `forcedPlan`이 매치마다 한 번 `warn` 후 nil (`MatchService.luau:67-77`), 그러면 랜덤 구성 |
| AC11 | 빌드 확인 / 실행은 사용자 확인 필요 | `default.project.json:29`, rbxlx에 `StreamingEnabled=false` |

요약: 순수 로직 7/7 통과, Studio 4개는 사용자 확인 필요.

## 개발 메모의 "스펙에서 벗어난 점" 판단
1. **stub 결승선을 Touched 대신 위치로 판정** (`StubMap.luau:128-146`) → **승인.** 스펙 3번의 "Touched"는 M1 B2 이전 문구다. B2 수정(회전 벨트)과 m2-02 범위("점프해서 넘어도 통과… B2 수정에서 쓴 방식을 따른다")가 모두 위치 판정을 요구하므로, Touched로 만들었다면 오히려 B2를 다시 만드는 셈이다. 결승선 뒤 4스터드 바닥과 `EndWall`(높이 16)도 B2 수정과 같은 구조다. → planner가 m2-01 "결정 기록"에 한 줄 남기면 충분하다.
2. **`resolveForcedPlan`이 종류 순서를 검사하지 않음** (`Rules.luau:211-231`) → **승인.** 스펙 2번은 "길이가 3·4가 아니거나 모르는 id면 무시"만 요구한다. 게다가 m2-03 AC8과 m2-05 AC14가 `{ "hot-plate", "rotating-belt", "skewer-showdown" }`(Survival을 1라운드에)를 쓰라고 하므로, 순서를 검사하면 두 스펙의 Studio 절차가 막힌다. 마지막 칸이 Final 맵이 아니어도 결승 판정은 `roundIndex == roundCount`(B8 수정) 기준이라 결승으로 돈다. 같은 id를 두 번 넣는 것도 허용되지만 디버그 전용이라 문제없다.
   - QA 테스트 `스펙 계약: m2-01~07 Studio 절차의 forceMapPlan 목록이 전부 …`가 m2-01·02·03·04·05·07 스펙에 적힌 강제 플랜 6개가 실제 풀에서 그 순서대로 풀리는지 확인한다.

## 병렬 worktree(m2-02~06) 계약 대조
| 스펙 | 기대하는 것 | 실제 | 결과 |
|---|---|---|---|
| m2-02 | `maps/SoySwamp.luau` stub이 풀에 등록됨, 확정 id/kind/이름/규칙 | `maps/init.luau` ALL에 등록, 값 일치 | ✅ |
| m2-02 | `Config.Character.WalkSpeed`·`JumpPower` (간장 감속·점프 불가 복구) | `Config.luau:53-56` (16, 50) | ✅ 단 F1 |
| m2-02 | 결승선 위치 판정 패턴 | `StubMap.luau`, `RotatingBelt.luau` 둘 다 같은 패턴 | ✅ |
| m2-02~04 | 맵 파일만 덮어쓰면 됨 (`maps/init.luau`, `maps.spec.luau` 수정 불필요) | ALL이 `require(script.SoySwamp)` 등 파일 이름으로 참조. StubMap은 맵 파일이 안 쓰면 그냥 남음 | ✅ |
| m2-02~04 | Studio 절차의 `forceMapPlan` 목록이 풀린다 | QA 계약 테스트로 확인 | ✅ |
| m2-03 | Survival을 1라운드로 두는 강제 플랜 (AC8) | 허용 | ✅ |
| m2-03 | 중간 Survival 시간 종료 = 전원 통과 | **아직 아님** (`RoundService.luau:187` — 시간 종료는 진행도 순으로 목표만큼만 통과). m2-05 범위라 정상 | ⏳ m2-05 |
| m2-04 | 결승 = 마지막 1명 남으면 종료 | **아직 아님** — `roundShouldEnd`는 `map.kind == "Survival"`만 "남은 인원 ≤ 목표"로 끝낸다 (`RoundService.luau:169`). Final stub은 1명이 남아도 90초까지 간다. m2-05 범위. m2-04 AC11도 "(m2-05 머지 뒤)"라고 적혀 있다 | ⏳ m2-05 |
| m2-05 | `Types`의 `aliveUserIds?`, `standings?`, `Standing{userId,name,place}`, `RoundProgress.racerUserIds` | `Types.luau:57-72` 스펙 4번과 글자 그대로 일치. `racerUserIds`는 이미 채움 (`RoundService.luau:129-137`) | ✅ |
| m2-05 | 대기석 = "B1 수정이 만든 라운드 사이 안전 장소" | B1 수정은 **로비 스폰**(`CharacterUtil.toLobby`)을 쓴다. 그래서 m2-05의 대기석 = 로비 스폰이다. 별도 플랫폼을 만들 필요 없음 | ✅ (m2-05 개발에 알림) |
| m2-05 | MatchService/RoundService는 m2-05만 고침 | m2-01이 이미 MatchService에 강제 플랜 분기(`isForced`, `minAlive`, 지역 `roundToPlay/nextRound`, `:67-128`)를 넣었다. m2-05가 루프를 다시 쓸 때 **이 분기를 유지해야 한다** (안 그러면 m2-02~04 Studio 절차가 깨짐) | ⚠️ 알림 |
| m2-06 | `Types` 필드, `StreamingEnabled = false` | 있음 | ✅ |
| m2-06 | HUD "남은 인원 n"(Survival·결승)에 필요한 정보 | `MatchPhaseInfo.mapKind`, `roundIndex/roundCount`, `RoundProgress.remaining` 이미 방송 | ✅ |
| m2-06 | m2-05 전에는 `aliveUserIds`/`standings`가 nil | 타입이 optional, 서버가 아직 안 채움 | ✅ (nil 처리 필요, 스펙에 적혀 있음) |
| m2-07 | AC2 "m2-01 테스트가 실제 풀로 도는지" | m2-01 테스트는 하드코딩 풀(`M2_POOL`)이었다 → QA가 실제 `Maps.infos()` 테스트를 추가 | ✅ (QA 추가) |
| 전체 | `Remotes.luau` 변경 없음 | 변경 없음 | ✅ |

## 버그
### [P2] F1 `StarterPlayer.CharacterUseJumpPower`가 고정돼 있지 않아 `JumpPower`로 점프를 막는 동작이 무시될 수 있다 (확인 필요)
- 재현: Studio Play 중 서버 Command bar에서 `print(game.StarterPlayer.CharacterUseJumpPower)`. `false`면 문제가 재현된다.
- 기대: 서버가 `Humanoid.JumpPower = 0`으로 점프를 막고 `Config.Character.JumpPower`(50)로 되돌리는 동작이 실제로 먹힌다. m2-02 AC5(간장에서 점프 불가), m2-05 AC11(출발 전 이동 잠금), 회전 벨트 젓가락 잡기가 모두 이 방식에 기대고 있다.
- 실제: `default.project.json`이 `StarterPlayer` 속성을 지정하지 않는다 (rbxlx에 `CharacterUseJumpPower` 없음). 값이 `false`(JumpHeight 사용)면 `JumpPower` 변경은 효과가 없어서 위 기능이 전부 "점프가 막히지 않음"이 된다. 엔진 기본값을 여기서는 확인하지 못했다.
- 위치: `default.project.json:15-21` (StarterPlayer), `src/server/CharacterUtil.luau` `resetMovement`, `src/shared/maps/RotatingBeltChopstick.luau` `grab`
- 왜 지금: `default.project.json`은 m2-01 소유 공용 파일이라, worktree가 갈라진 뒤에는 m2-02/m2-05가 직접 고칠 수 없다. **worktree를 만들기 전에** 메인 세션(m2-01 담당)이 `"StarterPlayer": { "$properties": { "CharacterUseJumpPower": true }, ... }`를 넣거나, 위 print로 `true`를 확인하는 것을 권한다.

### [P3] F2 (중간 상태) m2-05 머지 전까지 main의 일반 매치는 Survival·결승 stub에서 시간 종료까지 기다린다
- 현재 main에서 랜덤 구성은 마지막이 항상 `skewer-showdown` stub이다 (QA 테스트 `실제 맵 풀: 결승은 언제나 skewer-showdown`). R2가 Survival이면 `hot-plate` stub이다.
- stub은 평평한 바닥이라 아무도 안 떨어지면 Survival은 60초, 결승은 90초를 다 쓴다. 시간이 끝나면 **로컬 -Z 진행도**로 통과자·우승자가 정해진다. 결승에서 한 명만 남아도 바로 끝나지 않는다 (위 표 m2-04 줄).
- m2-05·m2-03·m2-04가 고칠 범위라 m2-01의 결함은 아니다. 그 사이 Studio에서 일반 매치를 돌리는 사람은 이렇게 동작한다는 것을 알고 있어야 한다.

## 문서 갱신 필요 (docs-writer)
- **D1** `docs/DEV-SETUP.md` 3-5절(방금 M1 기준으로 갱신한 것)이 m2-01 이후 다시 맞지 않는다. 고칠 곳:
  - "맵 풀에는 회전 벨트 하나뿐" → 이제 4개
  - "두 명" 결승 체크리스트: 결승이 `skewer-showdown` stub(결승선 없음)이라 "먼저 결승선을 넘은 사람이 우승"과 "점프로 넘어도 통과"가 해당하지 않는다. 지금은 90초 시간 종료로 우승자가 정해진다 (F2)
  - R1도 `soy-swamp` stub(곧은 회색 길)일 수 있다
  - 회전 벨트를 확실히 보려면 `forceMapPlan`을 쓰는 법을 안내해야 한다
- **D2** 강제 플랜을 쓰는 Studio 절차는 공용 파일 `Config.luau`를 **로컬에서만** 고치는 것이다. 커밋하면 `maps.spec.luau`의 `m2-01 Config: forceMapPlan은 기본 nil …` 테스트가 실패해서 막힌다 (좋은 안전장치). worktree 담당에게도 이렇게 알려 두면 좋다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트·인자 없음. `forceMapPlan`은 서버 Config이고 `RunService:IsStudio()`일 때만 읽는다 (`MatchService.luau:69`)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — stub 판정은 서버 Heartbeat (`StubMap.luau:134-150`)
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — stub `start`는 지역 `finishProgress`만 쓰고, stub 정보(`info`)는 불변
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — stub Heartbeat는 `ctx.cleanup`, 모델은 RoundService가 정리. stub은 스레드를 만들지 않음
- 참고: M1 재검증 N1(라운드 시작 순간 리스폰 중인 캐릭터가 로비에서 낙하 판정)은 stub에도 똑같이 적용된다 (`StubMap.luau:144`). m2-05 범위 1번("소개 동안 배치를 끝내고 RoundActive에 start")이 들어가면 해소된다.

## 사용자 Studio 확인 체크리스트
`rojo serve` → Studio 연결. 확인이 끝나면 `Config.DEBUG.forceMapPlan`을 반드시 `nil`로 되돌린다 (커밋 금지).

1. **F1 점프 설정 (먼저)** — F5 → 서버 Command bar에서 `print(game.StarterPlayer.CharacterUseJumpPower)`.
   - [ ] `true`인지 기록. `false`면 메인 세션에 알린다 (`default.project.json`에 고정 필요)
2. **AC11** — 같은 Command bar에서 `print(workspace.StreamingEnabled)`.
   - [ ] `false`
3. **AC8 (혼자, `forceMapPlan = nil`)** — 방 만들기 → 시작.
   - [ ] "매치 시작!" 뒤 라운드 없이 "🏆 우승!"(생존자 1명), 6초 뒤 대기실
   - [ ] 서버 Output에 빨간 에러 없음
4. **AC9 (혼자, 강제 4라운드)** — `forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" } :: { string }?`로 바꾸고 F5 → 방 만들기 → 시작.
   - [ ] 소개 배너가 "라운드 1 / 4 · 간장 늪 & 와사비 산" → "2 / 4 · 뜨거운 철판" → "3 / 4 · 회전 벨트" → "4 / 4 · 회전 꼬치 쇼다운" 순서
   - [ ] R1: 곧은 회색 길. 끝쪽 노란 결승선을 지나면(점프해서 넘어도) 통과하고 라운드가 바로 끝남
   - [ ] R2: 벽 없는 40×40 회색 바닥 가운데 배치. 60초를 버티면 통과
   - [ ] R3: 회전 벨트에서 결승선 통과
   - [ ] R4: 40×40 바닥에서 90초를 버티면 "🏆 우승했어요!" + "🏆 우승!" 배너
   - [ ] 라운드 사이에 맵이 남지 않고, 서버 Output에 빨간 에러 없음
5. **AC10** — `forceMapPlan = { "no-such-map", "hot-plate", "skewer-showdown" } :: { string }?`로 2명(Clients and Servers) 시작.
   - [ ] 서버 Output에 `ignoring Config.DEBUG.forceMapPlan — forceMapPlan has an unknown map id: no-such-map` 경고가 **한 번**
   - [ ] 랜덤 구성으로 진행 (2명이라 바로 "라운드 3 / 3 · 회전 꼬치 쇼다운")
6. **강제 플랜 + 여러 명 (m2-03·m2-05 절차 미리 확인)** — `forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" } :: { string }?`, 4명.
   - [ ] "라운드 1 / 3 · 뜨거운 철판"으로 시작한다 (Survival 1라운드가 허용됨)
   - [ ] 한 명이 바닥 밖으로 떨어지면 탈락하고, 남은 인원이 목표(2) 이하가 되면 라운드가 끝난다
7. 끝나면 `forceMapPlan = nil :: { string }?`으로 되돌리고 `lune run tests` 통과를 확인한다.

## 추가한 테스트
`tests/m2-01-qa.spec.luau` (6개, 모두 통과)
- 실제 맵 풀(`Maps.infos()`)로 3·4라운드 각 500판: 첫 Race, 끝 Final, 중복 0, 가운데는 Race/Survival, 4라운드 Survival ≥ 1 (m2-07 AC2를 미리 확인)
- 실제 풀에서 결승은 언제나 `skewer-showdown`
- 스펙 계약: m2-01·02·03·04·05·07의 Studio 절차에 적힌 `forceMapPlan` 6개가 실제 풀에서 그 순서로 풀림
- `no-such-map` 예시 거절, 이유에 id 포함
- 강제 플랜(건너뛰기 없음)에서 나올 수 있는 인원 1~24 × 라운드 수 3·4: `qualifyCount`가 에러 없이 1 이상
- 무작위 풀 2000개(종류별 0~3개): 개수가 충분하면 중복 0, 첫 Race·끝 Final·4라운드 Survival ≥ 1
