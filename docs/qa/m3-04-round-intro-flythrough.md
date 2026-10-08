# QA — m3-04 라운드 소개 플라이스루 · "출발!"

- 스펙: `docs/specs/m3-04-round-intro-flythrough.md`
- 검증 커밋: `31f1ba8` (m3-04-intro) + `origin/main` `4841705` 머지 (`0dc970a`, 충돌 없음)
- 결과: **통과 (P0/P1/P2 없음, P3 2건)** → 스펙 상태 `qa-passed`. Studio 확인(AC6~AC11)은 사용자 확인 필요.

## 자동 검증
머지 후 트리(main의 m3-02·03·06·08 포함) 기준.

| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 366 passed, 0 failed (개발 10 + QA 추가 9 포함) |

참고: 검증 4종에는 Luau 타입 검사가 없다 (m2-07 I2와 같음).

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `intro-camera.spec.luau` AC1 2개 + QA `Race 규칙이 네 방향·짧은/긴 코스 모두에서 지켜져요`(4방향 × 길이 30/200/600, 마지막 점이 스폰 뒤인지까지), `스폰 뒤로도 파츠가 있는 맵…` |
| AC2 | 통과 | 개발 AC2 + QA 같은 Race 스윕, `납작하거나(높이 0) 길쭉한 Survival·Final 맵도…` |
| AC3 | 통과 | 개발 AC3 3개 + QA 납작/길쭉/기둥 모양 × 4방향 모든 점 내적 > 0.9, 궤도가 맵 바깥 위, 스폰이 가운데 모이면 forward 반대쪽에서 끝남 |
| AC4 | 통과 | 개발 AC4 3개 + QA `sample은 t에 대해 경로상 진행 거리가 줄지 않아요`(폴리라인 투영 arc length 단조), 입력/경로 별칭 없음, 빈 경로 에러 |
| AC5 | 통과 | 위 자동 검증 |
| AC6 | 사용자 확인 필요 | 체크리스트 1 |
| AC7 | 사용자 확인 필요 | 체크리스트 2 |
| AC8 | 사용자 확인 필요 | 체크리스트 3. 코드상 일치(아래 "출발 타이밍") |
| AC9 | 사용자 확인 필요 | 체크리스트 4. 코드상 `aliveUserIds`로 판정(`IntroController.luau:301`) |
| AC10 | 사용자 확인 필요 | 체크리스트 5. 코드상 `RoomId`+`RoundIndex` 둘 다 비교(`IntroController.luau:61-72`) |
| AC11 | 사용자 확인 필요 | 체크리스트 6. 코드상 `RoomUpdated(nil)` → `stopIntro`(`IntroController.luau:280-292`) |

요약: 순수 로직 AC1~AC5 통과(5/5), 실패 0, Studio AC6~AC11 사용자 확인 필요(6).

## 코드 리뷰

### 변경 범위
- `31f1ba8`이 바꾼 소스: `src/client/fx/IntroController.luau`(껍데기 → 구현), 새 `src/client/fx/IntroScreen.luau`, 새 `src/shared/IntroCameraLogic.luau`, 새 `tests/intro-camera.spec.luau`. 스펙 지정 파일과 정확히 일치. 공용 파일(Config/Remotes/Types/maps/init/default.project.json/Attributes/SfxCues)·HUD·서버 변경 없음.
- `origin/main`(m3-02·03·06·08) 머지 충돌 없음. main 쪽은 `IntroController`/`IntroCameraLogic`을 건드리지 않았다.

### 서버 판정 · 정리
| 항목 | 결과 |
|---|---|
| 서버 변경 | 없음. 클라이언트 연출만. 새 리모트 없음 |
| 맵 찾기 | `workspace` 직속 Model 중 `RoomId == 내 방 id`, `RoundIndex == info.roundIndex` (`IntroController.luau:61-72`). 서버는 속성을 단 뒤 `Parent = workspace` (`RoundService.luau:143-146`), `StreamingEnabled = false`라 모델 전체가 온다. 다른 방 맵·이전 라운드 맵과 섞이지 않음 |
| 최대 1초 대기 | `os.clock() - introStart < MAP_WAIT`, 매 루프 `token == mine` 확인 (`:209-216`). 못 찾으면 배너만 |
| 카메라 우선순위 | `CameraDirector.request("Intro", Priority.Intro=30)` (`:249`), 매 프레임 `CameraDirector.isActive("Intro")`일 때만 CFrame 설정 (`:261-263`) |
| 관전자 | `RoundIntro`의 `aliveUserIds`에 없으면 `participant=false` → `stopIntro`만, "출발!" 없음 (`:299-307`, `:310`). Spectate(10)는 Intro(30)보다 낮지만 관전자에게는 Intro 요청 자체가 없다 |
| 탈락 연출(40) | Intro보다 높아 가져가면 Intro는 카메라를 안 움직이고, 놓으면 CameraDirector가 Intro apply를 다시 부른다. 아래 B1 참고 |
| 정리 | 새 `RoundIntro`/`RoundActive`/그 밖 단계/`RoomUpdated`(방 나감·매치 끝) 모두 `stopIntro` → `token += 1`(대기 루프·렌더 콜백 무효화), `UnbindFromRenderStep`, `release`. 안전장치: 복귀 뒤 2초 안에 `RoundActive`가 없으면 스스로 release (`:257-259`). `IntroScreen`은 token으로 지연 tween을 무효화 |
| 경로 계산 실패 | `pcall(pathOf)` → warn 후 건너뜀 (`:218-222`), 빈 경로 건너뜀 |

### 출발 타이밍 (AC8)
- 서버: `RoundIntro`(endsAt = now + 3) → `task.wait(3)` → `RoundActive` 방송 → 바로 `prepared.run`(잠금 해제) (`MatchService.luau:159-207`). 잠금 해제와 `RoundActive`가 같은 서버 프레임.
- 클라이언트: 소개 길이 = `endsAt - GetServerTimeNow()`(0.6~3초로 clamp), 비행 80% → 복귀 20%가 `endsAt` 무렵에 끝나고, 그 뒤 `RoundActive`가 올 때까지 캐릭터 뒤 위치를 따라간다. `RoundActive`를 받는 순간 release + "출발!" + `Sfx.play("Go")`. 클라이언트가 출발을 늦추는 경로 없음(카메라 복귀가 끝나기를 기다리지 않음).

### M2 회귀
- HUD 소개 배너(`HudController`/`HudScreen`)는 m3-04에서 변경 없음. main의 `HudController` 변경(m3-03, 탈락 개인 결과 숨김)은 소개 배너와 무관.
- `SpectateController`: Race 통과자의 관전이 `RoundIntro`에서 끝나고(`setRole("None")`) 같은 순간 Intro가 30으로 요청 — 순서와 상관없이 Intro가 1등.

## 버그
P0/P1/P2 없음.

### [P3] B1 소개 도중 리셋해 탈락한 사람에게도 "출발!"이 뜨고, 남은 소개 시간 동안 플라이스루가 다시 잡힐 수 있음
- 재현: 2명 이상, 라운드 소개 3초 중에 Esc → R(리셋). 서버는 소개 중 리셋을 탈락으로 처리한다(`MatchService.luau:169`).
- 기대: 탈락한 순간부터 관전자 — 스펙 범위 5 "플라이스루를 안 본 관전자에게는 띄우지 않는다"의 취지대로 "출발!"·`Go` 소리 없음, 플라이스루 중단.
- 실제(코드상): `participant`는 `RoundIntro`를 받을 때 한 번만 정하고, 탈락(`PlayerResult`)이나 `RoundActive`의 새 `aliveUserIds`로 다시 확인하지 않는다. 그래서 `RoundActive`에서 "먹혔다!" 스탬프 위에 "출발!"과 `Go`가 같이 나온다. 또 Intro 요청이 남아 있어 탈락 연출(40)이 소개보다 먼저 끝나면(연출 3초 = 소개 3초라 보통은 소개가 먼저 끝남) 남은 시간 동안 플라이스루 카메라가 다시 잡히고 관전(10)은 그 뒤에 시작된다.
- 제안: `RoundActive`에서 `participant and isAlive()`로 판정하거나, 내 `PlayerResult`(Eliminated)를 받으면 `participant = false; stopIntro()`.
- 위치: `src/client/fx/IntroController.luau:299-314`

### [P3] B2 Survival·Final 끝점이 "지난 라운드의 내 위치"로 정해질 수 있음
- 재현(코드상): 모든 방 맵은 같은 아레나 원점(`getArenaOrigin`)에 지어진다. 새 맵을 찾은 첫 프레임에 서버의 스폰 배치(`placeAt` → `PivotTo`)가 아직 복제되지 않았으면, 지난 라운드 자리에 서 있던(또는 떨어지던) 내 루트가 새 맵 경계 XZ 안에 있어 `originOf`가 그 위치를 끝점으로 쓴다.
- 기대: 반 바퀴가 스폰 쪽(또는 내 스폰 위치)에서 끝난다.
- 실제: 끝점 방향만 달라지고 복귀 0.6초에 캐릭터 뒤로 붙으므로 기능 문제는 없음. 복귀 이동이 길어 보일 수 있음. m3-09 튜닝 때 Studio에서 보고 판단.
- 위치: `src/client/fx/IntroController.luau:134-143`

### 관찰 (버그 아님)
- `IntroCamera` 폴더(M4)가 있으면 경유점의 바라보는 점은 파츠 LookVector 20 studs 앞이다. M4 맵 제작 문서에 "파츠 앞면이 볼 곳을 향하게" 적어 두면 좋다.
- 개발 메모대로 release 뒤 기본 카메라 줌(12.5)과 `FOLLOW_OFFSET`(뒤 12, 위 4) 차이로 출발 순간 살짝 튈 수 있음 — 체크리스트 3에서 확인.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 해당 없음(새 리모트·서버 변경 없음)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 클라이언트는 카메라·글씨·소리만
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 맵 변경 없음. 컨트롤러 상태는 `start()` 클로저 안
- [x] 연결·인스턴스·스레드가 정리된다 — RenderStep 바인딩·Director 요청은 `stopIntro`로, 대기 스레드·tween은 token으로 무효화. 리모트 연결은 컨트롤러 수명 동안 유지(다른 컨트롤러와 같음)

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`, `rojo serve`(이 worktree 포트) 연결. 확인이 끝나면 `forceMapPlan = nil`로 되돌린다(커밋 금지).

1. **AC6** 혼자 F5 → 방 만들기 → 시작. 라운드 4번 모두: 소개 3초 동안 카메라가 새 맵 위를 훑고, 끝날 무렵 내 초밥 뒤로 돌아오는지. 화면 위 HUD에 "라운드 n/4 · 맵 이름 · 규칙" 배너가 같이 보이는지(M2 회귀). Output에 `[IntroController]` 경고·에러가 없는지.
2. **AC7** 회전 벨트·간장 늪: 결승선 쪽 높은 곳에서 시작해 출발 지점 뒤쪽으로 날아와 코스 방향을 보는지. 철판·꼬치 쇼다운: 맵 가운데를 보며 반 바퀴 도는지.
3. **AC8** 소개가 끝나는 순간 화면 가운데 큰 "출발!"이 커졌다 사라지고(약 0.8초) 소리가 나는지. 그 순간 바로 WASD로 움직일 수 있는지. 카메라가 기본 카메라로 넘어갈 때 크게 튀지 않는지(살짝 튀면 메모).
4. **AC9** Test → Clients and Servers 3명, `forceMapPlan`은 그대로 또는 `nil`. 1라운드에서 한 명(C)이 일부러 떨어져 탈락 → C는 관전 화면. 2라운드 소개 때 C 화면: 관전 화면 유지, 플라이스루·"출발!" 없음. A·B 화면: 플라이스루와 "출발!".
5. **AC10** Clients and Servers 4명, `minPlayersToStart` 1(Studio 기본), `forceMapPlan` 설정. 방 2개(각 2명)를 만들고 거의 동시에 시작. 각 방 사람이 자기 방 아레나(서버 Workspace에서 `Round1_…` 모델의 `RoomId` 속성으로 확인)를 훑는지 — 다른 방 맵 위를 날지 않는지.
6. **AC11** 플라이스루 도중(소개 3초 안) "방 나가기"(또는 로비로) → 카메라가 로비의 내 캐릭터로 돌아오고, Output에 에러가 없고, 그 뒤 다시 방을 만들어 시작해도 소개가 정상인지.
7. (B1 확인용, 선택) 2명, 소개 도중 Esc → R 리셋 → "먹혔다!"와 "출발!"이 같이 뜨는지 확인해 메모.

## 추가한 테스트
`tests/intro-camera-qa.spec.luau` (9개)
- Race 규칙 4방향 × 코스 길이 30/200/600 스윕 (첫 점 결승 쪽, 마지막 점 스폰 쪽·스폰 뒤, 코스 방향 바라봄, 모두 꼭대기 위, NaN 없음)
- 스폰 뒤에 발판이 있어 경계 상자가 스폰 뒤로 뻗은 Race 맵
- forward가 기울었거나 0벡터일 때 수평 기준·NaN 없음 (Race/Survival/Final)
- 납작(높이 0)·길쭉·높은 기둥 모양 Survival·Final × 4방향: 꼭대기 위, 중심을 봄, 맵 바깥 위 궤도
- 스폰이 가운데 모였을 때 forward 반대쪽에서 반 바퀴 끝
- `sample`의 경로상 진행 거리(arc length) 단조 증가
- `autoPath`·`sample`이 입력을 바꾸지 않고 결과가 경로와 별칭이 아님
- 빈 경로 `sample` 에러
- `ease` 단조·범위 밖 clamp

## 인계 메모
- **브랜치**: `m3-04-qa` (`origin/m3-04-intro` + `origin/main` 4841705 머지), push함.
- **끝난 것**: 자동 검증 4종 통과(366/0), 순수 AC1~AC5 통과, 코드 리뷰, QA 테스트 9개, 이 리포트, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인(체크리스트 1~7). P3 B1·B2는 개발 담당이 원하면 m3-09에서 처리. 메인 세션이 `m3-04-qa`(또는 `m3-04-intro` + 이 브랜치)를 main에 병합.
- **다음에 할 첫 단계**: 메인 세션이 `m3-04-qa`를 main에 병합 → docs-writer 반영.
- **막힌 점**: 없음. 참고 — 작업 시작 때 `git merge origin/main`은 "Already up to date"였는데 그 뒤 main이 m3-02·03·06·08 병합으로 앞서가서 한 번 더 머지했다(충돌 없음).
