# QA — m2-06 관전 모드 · 탈락 선택 · 우승 순위 화면

- 스펙: `docs/specs/m2-06-spectate-victory-ui.md`
- 검증 커밋: `2a722a9` (브랜치 `worktree-m2-spectate`)
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. Studio 확인(AC5~AC14)은 사용자 확인 필요. 실제 값(`aliveUserIds`, `standings`)으로 하는 최종 확인은 m2-05 머지 뒤 m2-07에서 한다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 111 passed, 0 failed (개발 105 + QA 추가 6) |

base(`03d752a`)에서 바뀐 파일은 스펙의 "이 스펙이 고치는 파일" 목록 안에 있다: `HudScreen`, `HudController`, 새 파일 `SpectateController`·`SpectateScreen`·`shared/SpectateLogic`·`tests/spectate.spec.luau`, 그리고 `init.client.luau` 한 줄. 서버 코드와 공용 파일(Config, Types, Remotes, maps/init, default.project.json)은 바뀌지 않았다. 리모트 호출도 추가되지 않았다.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `AC1: 달리는 사람 우선, 나 제외`, `AC1: 달리는 사람이 비면 생존자`, `AC1: 나만 남았으면 빈 목록` |
| AC2 | 통과 | `AC2: 끝에서 처음으로 순환`. QA 무작위 테스트: 목록 길이만큼 돌면 제자리, 다음 → 이전은 원래 대상 |
| AC3 | 통과 | `AC3: 대상이 빠지면 목록에서 그 다음 자리`, `AC3: 후보가 비면 nil`. QA 무작위 테스트: reconcile 결과는 항상 새 목록 안, 대상이 남아 있으면 그대로 |
| AC4 | 통과 | 전체 통과 |
| AC5 | 사용자 확인 필요 | 내 `PlayerResult(Eliminated)` → 연출 시간(`Config.Match.EliminationCutscene` = 3초, 서버의 고정 시간과 같은 값) 동안 UI 없음 → 자동 관전 + [로비로] (`SpectateController.luau:239-250`) |
| AC6 | 사용자 확인 필요 | ◀▶ 버튼, ←/→·Q/E 키 → `SpectateLogic.step` 순환 (`:162-169, :260-270`) |
| AC7 | 사용자 확인 필요 | 다른 사람의 `PlayerResult`·`RoundProgress`가 올 때마다 다시 그리고, 0.25초마다 확인 → `reconcile`로 다음 대상 (`:229-237, :273-280`) |
| AC8 | 사용자 확인 필요 | `StreamingEnabled = false`는 m2-01에서 빌드 결과까지 확인했다 |
| AC9 | 사용자 확인 필요 | [로비로]는 `watching = false`만 바꾸고 리모트를 부르지 않는다 → 방 멤버십 유지. idle 상태에서 [👀 관전하기] (`:178-184, :126-130`) |
| AC9-1 | 사용자 확인 필요 | Race에서 내가 `Passed` → 즉시 관전 + [내 캐릭터 보기], 다음 `RoundIntro`에 해제 (`:211-219, :251-253`) |
| AC9-2 | 사용자 확인 필요 (로직 확인) | `progressText`: mapKind가 Survival/Final이면 "남은 인원 n", Race면 기존 문구 (`HudScreen.luau`) |
| AC10 | 사용자 확인 필요 | `RoundIntro`에서 지난 라운드 레이서 목록을 버리고 새 `RoundProgress`의 `racerUserIds`로 이어간다 |
| AC11 | 사용자 확인 필요 (m2-05 뒤) | Victory → 관전 UI 숨김 + 우승자 Humanoid를 비춤. `standings`를 등수순으로 정렬해 표시하고 내 줄 강조. m2-05 전에는 `standings`가 nil이라 순위표 없이 배너만 나온다 |
| AC12 | 사용자 확인 필요 | `RoomUpdated`가 InMatch가 아니면 `resetAll` + 카메라 복구. HUD `setVisible(false)`가 순위표와 배너 위치를 초기화 |
| AC13 | 사용자 확인 필요 | 버튼 높이 48px, 패널 폭 340px, 아래 가운데. 휴대폰 가로(폭 약 640px)면 패널이 x 150~490이고 점프 버튼은 오른쪽 95px 안이라 겹치지 않는다 (계산상) |
| AC14 | 사용자 확인 필요 | 방을 나가면 `RoomUpdated(nil)` → `resetAll`. 다른 플레이어가 나가면 `PlayerRemoving` → 다시 그림 |

요약: 순수 로직 AC1~AC4 통과, Studio AC5~AC14는 사용자 확인 필요. 실패한 기준은 없다.

## m2-05 전(nil 필드)에서 깨지지 않는지
- `aliveUserIds` nil: `SpectateLogic.candidates(racers, nil, …)`가 빈 목록을 돌려주고, "관전할 사람이 없어요"로 표시된다. QA 테스트 `m2-05 전: 생존자·레이서가 모두 nil/빈 목록이면…` (nil/빈 목록 네 가지 조합에서 `candidates`/`step`/`reconcile` 모두 안전).
- `racerUserIds`: m2-01이 이미 채운다. nil이어도 `filtered`가 `ids or {}`로 처리한다.
- `standings` nil: `showStandings`는 nil이나 빈 목록이면 바로 끝나고, 우승자 이름 찾기는 `info.standings or {}`다 (`HudScreen.luau`). 우승자 이름은 `nameOf`로 대신한다.
- `winnerUserId` nil: 배너는 "?님이 우승했어요!"이고, 카메라는 `restoreCamera`.
- 결론: 코드 경로상 nil 필드로 에러가 나는 곳은 없다. 실행 확인은 체크리스트 1.

## 개발 판단 2건 — GDD v0.3과 맞는지
1. **Race 통과자는 통과 즉시 자동으로 관전 시작** ([내 캐릭터 보기]로 끄고 [관전하기]로 다시 켬). Survival 통과자는 관전을 켜지 않음.
   → **승인.** GDD v0.3 §4(76줄)는 "Race에서 결승선을 통과하면 바로 코스 밖 대기석으로 옮겨져 다음 라운드를 기다리며 **관전할 수 있어요**"다. 강제가 아니라 할 수 있다는 뜻이고, 자동 시작이지만 한 번에 끌 수 있으니 어긋나지 않는다. 탈락자 자동 관전(Q3)과 같은 흐름이라 일관성도 있다. Survival 통과는 라운드가 끝나는 순간이라 볼 레이서가 없으므로 켜지 않는 것이 맞다.
   - 참고: m2-05 전에는 통과자가 대기석으로 옮겨지지 않고 결승 구역에 남아 있다. 카메라만 다른 사람을 보게 되지만 해는 없다.
   - planner가 스펙의 "결정 기록"에 확정으로 옮기면 된다 (지금은 developer 판단으로만 적혀 있음).
2. **관전 후보 순서는 userId 오름차순으로 고정.**
   → **승인.** GDD에는 순서 규칙이 없고, 스펙 범위 7번은 "순서 고정"만 요구한다. 서버 목록 순서와 상관없이 ◀▶ 순서가 흔들리지 않는다.
   - 참고 (P3): Studio 테스트 플레이어는 userId가 음수(Player1 = -1, Player2 = -2, …)라서 오름차순이면 Player4 → Player3 → … → Player1 순서로 보인다. 실제 서버에서는 문제없다.

## 버그
P0/P1/P2 없음.

### [P3] S1 관전 중 ←/→ 키가 기본 카메라 회전에도 쓰인다
- ←/→를 누르면 대상이 바뀌면서 시점도 살짝 돈다. 개발 메모에 이미 적혀 있다. Q/E는 영향이 없다. 거슬리면 `ContextActionService`로 관전 중에만 입력을 가로채면 된다.
- 위치: `src/client/ui/SpectateController.luau:260-270`

### [P3] S2 Studio에서 관전 순서가 플레이어 번호의 역순으로 보인다 (위 판단 2 참고)
- 실제 서버에는 영향 없음. 체크리스트에서 혼동하지 않게 적어 둔다.

### 참고 (버그 아님)
- `MatchPhase(Starting)`이 `RoomUpdated(InMatch)`보다 먼저 도착한다. RoomService가 방송을 프레임 끝으로 미루고, 매치 핸들러는 바로 실행되기 때문이다. `SpectateController`는 Starting에서 `resetAll`만 하고, `inMatch`는 RoomUpdated에서 켜서 문제없다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트·인자 없음. 관전·"로비로"는 클라이언트 카메라만 바꾼다 (스펙대로)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 클라이언트는 받은 값을 표시만 한다
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음 (클라이언트 UI). 컨트롤러 상태는 `start` 안의 지역 변수
- [x] 정리 — 매치가 끝나거나 방을 나가면 `resetAll` + `restoreCamera`(우리가 바꿨을 때만). 순위표 행은 매번 지우고 다시 만든다. 연결은 클라이언트 수명 동안 하나씩이고 GUI는 `ResetOnSpawn = false`

## 사용자 Studio 확인 체크리스트
이 worktree에서 `rojo serve --port 34877` → Studio 연결. Test → Clients and Servers 3~4명. (Studio에서는 관전 순서가 Player 번호 역순이다 — S2)

1. **m2-05 전 nil 필드 (지금 브랜치 그대로)** — 3명, 방 하나에 모여 시작.
   - [ ] 1라운드에서 한 명이 일부러 떨어지면(코스 밖) 탈락 안내 약 3초 뒤 아래 가운데에 "👀 관전 중: (이름)" + [◀][▶][로비로]가 뜬다
   - [ ] 라운드 사이(결과·소개 단계)에는 "관전할 사람이 없어요"가 떠도 된다 (m2-05 전 정상). 클라이언트·서버 Output에 빨간 에러 없음
   - [ ] 우승 때 배너만 뜨고 순위표는 없다 (m2-05 전 정상), 에러 없음
2. **AC5~AC7** — [▶]/[◀]와 ←/→·Q/E로 대상이 바뀌고 끝에서 처음으로 돈다. 보던 사람이 결승선을 넘거나 탈락하면 1초 안에 다른 사람으로 넘어간다
3. **AC8** — 관전 중 아레나 맵과 장애물이 정상으로 보인다 (내 캐릭터는 로비에 있음)
4. **AC9** — [로비로] → 카메라가 로비의 내 캐릭터로 돌아오고 걸어 다닐 수 있다. 다른 창의 방 멤버 목록에서 내가 빠지지 않는다. [👀 관전하기]로 다시 관전. 매치가 끝나면 모두와 함께 방 대기실로
5. **AC9-1** — Race에서 결승선을 통과하면 바로 관전 화면 + [내 캐릭터 보기]. 다음 라운드 소개가 시작되면 카메라가 자동으로 내 캐릭터로 돌아온다
6. **AC9-2** — `forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" } :: { string }?`로 시작하면 철판과 결승에서는 왼쪽 위가 "남은 인원 n", 회전 벨트에서는 "통과 n/목표 · 남은 인원 n" (끝나면 `forceMapPlan = nil`)
7. **AC10** — 1라운드에 탈락해 관전하던 사람이 2라운드에도 관전이 이어지고 새 맵의 레이서를 본다
8. **AC11~AC12 (m2-05 머지 뒤 m2-07에서 정확히)** — 우승 때 모든 화면이 같은 우승자를 비추고, 순위표에 시작 인원만큼 줄이 있고 내 줄이 노란색. 대기실로 돌아오면 관전·순위 UI가 없고 카메라가 내 캐릭터를 따라간다. 이어서 한 판 더 해도 겹치지 않는다
9. **AC13** — Studio Device Emulator(휴대폰 가로)에서 관전 버튼을 터치로 누를 수 있고 오른쪽 아래 점프 버튼과 겹치지 않는다
10. **AC14** — 관전 중 방 나가기, 관전 중 클라이언트 창 닫기 → 다른 창·서버 Output 에러 없음

## 추가한 테스트
`tests/spectate-qa.spec.luau` (6개, 모두 통과)
- m2-05 전: 생존자·레이서가 nil/빈 목록(4가지 조합)이면 후보 빈 목록, `step`/`reconcile`이 nil
- 레이서 목록에 나만 있으면 생존자로 넘어감, 음수 userId도 오름차순
- 무작위 3000개: 후보에 나 없음·중복 없음·오름차순·올바른 출처(레이서가 있으면 레이서에서만)
- 무작위 500개: `step` 한 바퀴 제자리, 다음 → 이전 = 원래 대상
- 무작위 2000개: `reconcile` 결과 ∈ 새 목록(비면 nil), 대상이 남아 있으면 유지

## 인계 메모 (2026-10-08, qa)
- 브랜치: `worktree-m2-spectate`. 리포트·테스트·스펙 상태(`qa-passed`)를 이 브랜치에 커밋하고 push했다.
- 끝난 것: 검증 4종(111 passed), 코드 리뷰, nil 필드 안전성, 개발 판단 2건 판단, 테스트 추가.
- 남은 것: Studio 체크리스트 1~10 (사용자 확인 필요). AC11·AC12는 m2-05 머지 뒤 m2-07에서.
- 다음 첫 단계: Studio에서 문제가 나오면 이 리포트에 추가하고 P0/P1이면 `in-dev`.
- 막힌 점: 없음.
