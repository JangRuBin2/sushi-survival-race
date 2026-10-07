status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m2-06 — 관전 모드 · 탈락 선택 · 우승 순위 화면 (클라이언트)

- 마일스톤: M2
- GDD 근거: `docs/GDD.md` §4(4. 결과 → 관전 또는 로비 복귀, 5. 우승 → 같은 방으로 복귀), §10(탈락: "관전하기 / 로비로", 결과: 우승자), §13(M2부터 모바일 테스트)
- 담당 개발 worktree: `m2-spectate` (Rojo 포트 34877)
- 공용 파일 수정 담당: 없음
- 의존: **m2-01 머지 후 시작** (`Types`의 `aliveUserIds`/`racerUserIds`/`standings`, `StreamingEnabled = false`). 값은 m2-05가 채운다 — m2-05보다 먼저 끝나면 필드가 비어 있을 때도 깨지지 않게 만들고, 최종 확인은 m2-05 머지 뒤 m2-07에서 한다.
- **이 스펙이 고치는 파일**: `src/client/ui/HudScreen.luau`, `src/client/ui/HudController.luau`, 새 파일 `src/client/ui/Spectate*.luau`(컨트롤러/화면), 새 파일 `src/shared/SpectateLogic.luau`(순수), 새 파일 `tests/spectate.spec.luau`. 필요하면 `src/client/init.client.luau`에 한 줄 추가. M2 동안 HUD 파일은 이 worktree만 고친다.

## 목표
탈락해도 판이 끝날 때까지 남은 사람들을 구경할 수 있고(GDD: 탈락이 볼거리), 원하면 로비로 갈 수 있다. 우승 때는 모두가 우승자를 보고 전체 순위를 확인한다.

## 범위
- 포함:
  1. **탈락 뒤 선택** (Q3 확정) — 내가 탈락하면 탈락 연출 시간(`Config.Match.EliminationCutscene`) 뒤 **아무것도 누르지 않아도 자동으로 관전이 시작**되고, 관전 화면에 **[로비로]** 버튼이 있다. "로비로"는 관전만 끄고 카메라를 로비의 내 캐릭터로 돌린다 — **방 멤버십은 유지**(리모트 호출 없음)되어 매치가 끝나면 다른 멤버와 함께 같은 방 대기실로 돌아온다. 로비에 있는 동안 HUD에 **[관전하기]** 버튼이 있어 다시 관전할 수 있다.
  2. **관전 카메라** — 클라이언트 카메라만 바꾼다(서버 판정·캐릭터 위치는 건드리지 않음): `Camera.CameraSubject`를 대상의 Humanoid로.
     - 대상 후보: 이번 라운드에서 아직 달리는 사람(`RoundProgress.racerUserIds`)을 우선, 비어 있으면 매치 생존자(`MatchPhase.aliveUserIds`). 나 자신은 제외.
     - 화면: "👀 관전 중: (이름)" + [◀] [▶] 버튼. PC는 ←/→ 키(또는 Q/E)로도 바꿀 수 있다.
     - 보고 있던 대상이 통과·탈락·퇴장하면 자동으로 다음 후보로 넘어간다. 후보가 없으면 카메라를 내 캐릭터로 돌리고 "관전할 사람이 없어요"를 띄운다.
     - 라운드가 바뀌어도(새 RoundIntro) 관전은 이어지고 새 라운드의 레이서를 보여 준다.
  3. **통과자 관전** — Q4 확정(Race 통과자는 즉시 대기석으로 이동, m2-05)에 따라 Race 통과자도 다음 `RoundIntro`까지 같은 관전 화면을 쓴다 (버튼은 [◀][▶] + [내 캐릭터 보기]). 다음 라운드 소개가 시작되면 자동으로 내 캐릭터 카메라로 돌아온다.
  4. **우승 화면** (`MatchPhase` = `Victory`): 모든 클라이언트의 카메라가 우승자 캐릭터를 비추고, 기존 "🏆 우승!" 배너 아래 **순위표**를 보여 준다 — `standings`의 등수·이름, 내 줄 강조, 최대 24줄(넘치면 스크롤). 우승 단계가 끝나면 카메라를 내 캐릭터로 되돌린다.
  5. **매치 종료/퇴장 시 정리**: 방이 대기실로 돌아오거나(`RoomUpdated` state ≠ InMatch) 방을 나가면 관전·순위 UI를 닫고 카메라를 원래대로(`CameraType = Custom`, 내 Humanoid).
  6. **모바일**: 버튼은 터치하기 충분한 크기(최소 44px 높이)이고 모바일 점프 버튼(오른쪽 아래)과 겹치지 않는다.
  7. **순수 로직** `src/shared/SpectateLogic.luau`: 후보 목록 만들기(달리는 사람 우선, 나 제외, 순서 고정), 다음/이전 대상(끝에서 처음으로 순환), 대상이 사라졌을 때 다음 대상 고르기.
- 제외:
  - 탈락·우승 연출(젓가락 픽업, 바다 다이빙), 관전 응원 이펙트 (M3, 로벅스 제안서는 미승인)
  - 보상 정산, "한 판 더" 별도 버튼 — M2에서는 우승 화면 뒤 기존 방 대기실로 돌아가 방장이 시작하는 것이 "한 판 더"다 (보상은 M4)
  - 서버 로직 (m2-05)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/spectate.spec.luau`)
- [ ] AC1: 달리는 사람 {3, 5}, 생존자 {1, 3, 5, 7}, 나 = 1 → 후보는 {3, 5}. 달리는 사람이 비면 → {3, 5, 7}. 나만 남았으면 → 빈 목록.
- [ ] AC2: 후보 {3, 5, 7}에서 현재 7의 다음은 3, 현재 3의 이전은 7 (순환).
- [ ] AC3: 현재 대상 5가 후보에서 빠져 {3, 7}이 되면 다음 대상은 7(목록에서 5 다음 자리), 후보가 비면 nil.
- [ ] AC4: `lune run tests` 전체 통과.

### Studio 확인
Test → Clients and Servers 3~4명. 혼자 확인은 어렵다(관전 대상이 필요).
- [ ] AC5: 1라운드에서 탈락한 플레이어 화면: 탈락 안내 뒤 약 3초 후 아무것도 누르지 않아도 관전이 시작되고 [로비로] 버튼이 보인다. 관전 중에는 아직 달리는 플레이어가 화면 가운데 보이고 "👀 관전 중: (이름)"이 맞는 이름이다.
- [ ] AC6: [▶]/[◀] 버튼(또는 ←/→ 키)으로 대상이 바뀌고, 마지막 다음은 처음으로 돌아간다.
- [ ] AC7: 보고 있던 사람이 결승선을 통과하거나 탈락하면 1초 안에 다른 사람으로 자동으로 넘어간다.
- [ ] AC8: 관전자는 캐릭터가 로비에 있어도 아레나 맵과 장애물이 정상적으로 보인다 (안 보이면 m2-01 `StreamingEnabled` 확인).
- [ ] AC9: [로비로]를 누르면 카메라가 로비의 내 캐릭터로 돌아오고 로비를 걸어 다닐 수 있다. 방 멤버 목록에서 빠지지 않는다. HUD의 [관전하기]로 다시 관전할 수 있고, 매치가 끝나면 다른 멤버와 함께 같은 방 대기실 화면으로 돌아온다.
- [ ] AC9-1: Race에서 결승선을 통과해 대기석으로 옮겨진 플레이어는 관전 화면([◀][▶] + [내 캐릭터 보기])을 쓸 수 있고, 다음 라운드 소개가 시작되면 카메라가 자동으로 내 캐릭터로 돌아온다.
- [ ] AC9-2: 생존형 결승과 중간 Survival에서는 HUD 왼쪽 위가 "통과 n/목표" 대신 "남은 인원 n"을 보여 준다 (Race는 지금처럼 "통과 n/목표").
- [ ] AC10: 다음 라운드가 시작돼도 관전이 끊기지 않고 새 맵의 레이서를 보여 준다.
- [ ] AC11: 우승이 결정되면 4명 화면 모두 같은 우승자 캐릭터를 비추고, 순위표에 시작 인원만큼 줄이 1등부터 있으며 내 줄이 강조돼 있다. 각자 받은 "n등" 안내와 순위표 등수가 같다.
- [ ] AC12: 우승 화면이 끝나고 방 대기실로 돌아오면 모든 플레이어의 카메라가 자기 캐릭터를 따라가고, 관전·순위 UI가 남아 있지 않다. 이어서 한 판 더 해도 UI가 겹치지 않는다.
- [ ] AC13: Studio 기기 에뮬레이터(휴대폰)에서 관전 버튼을 터치로 누를 수 있고 점프 버튼과 겹치지 않는다.
- [ ] AC14: 관전 중에 방을 나가거나(LeaveRoom) 접속을 끊어도 다른 클라이언트·서버 Output에 에러가 없다.

## 공용 파일 변경
- `shared/Config.luau`: 없음 (읽기만: `Match.EliminationCutscene`, `Match.VictoryDuration`)
- `shared/Remotes.luau`: 없음 — 관전과 "로비로"는 클라이언트 카메라만 바꾼다.

## 결정 기록
- 2026-10-08 · 관전 대상 순서 · 이번 라운드에서 달리는 사람 우선, 없으면 생존자 · planner
- 2026-10-08 · "한 판 더" 버튼 · M2에서는 따로 만들지 않고 기존 방 대기실(방장 시작/자동 시작)로 대신함. 보상 정산은 M4 · planner
- 2026-10-08 · **확정 Q3** (메인 세션 경유) · (B) "로비로" = 관전만 끄고 방 멤버십 유지, 아무것도 안 누르면 연출 뒤 자동 관전 · user
- 2026-10-08 · **확정 Q4** · Race 통과자도 대기석에서 관전 화면 사용 (서버 이동은 m2-05) · user
- 2026-10-08 · 생존형 라운드 HUD 표시 · Survival·결승에서는 "남은 인원 n"을 보여 줌 (통과 목표가 의미 없음) · planner
- 2026-10-08 · 개발 판단 (QA·기획 확인 권장): Race 통과자 관전은 버튼을 누르지 않아도 **통과 즉시 자동 시작**한다 (대기석에서 할 일이 없고, 탈락자와 같은 흐름). [내 캐릭터 보기]로 끄면 [관전하기]로 다시 켤 수 있다. Survival 통과(라운드 끝에 남은 사람)는 볼 레이서가 없으므로 관전을 켜지 않는다 · developer
- 2026-10-08 · 개발 판단: 관전 후보 순서는 userId 오름차순으로 고정 (서버 목록 순서가 바뀌어도 ◀/▶ 순서가 흔들리지 않게). 캐릭터(Humanoid)가 없는 사람은 후보에서 잠시 빠진다 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 인계 메모
- 브랜치: `worktree-m2-spectate` (03d752a 위). 구현·검증·커밋 완료, 상태 `in-qa`. 남은 것: QA, m2-05 머지 뒤 m2-07에서 실제 값으로 Studio 확인. 막힌 점 없음.

### 바뀐 파일
- `src/shared/SpectateLogic.luau` (새, 순수): `candidates(racers, alive, me, isAvailable?)` — 달리는 사람 우선, 없으면 생존자, 나·중복 제외, userId 오름차순. `step(list, current, dir)` — 순환. `reconcile(old, new, current)` — 대상이 사라지면 old에서 다음 자리부터 new에 남은 첫 사람, 비면 nil.
- `tests/spectate.spec.luau` (새): AC1~AC3 + 경계(중복, isAvailable, 목록 통째로 바뀜) 11개.
- `src/client/ui/SpectateScreen.luau` (새): 아래 가운데 패널(폭 340, 버튼 높이 48). watching = "👀 관전 중: 이름" + ◀ ▶ + [로비로]/[내 캐릭터 보기], idle = [👀 관전하기] 하나.
- `src/client/ui/SpectateController.luau` (새): 상태(role None/Eliminated/Passed, watching, 탈락 연출 중, Victory). 카메라는 `CameraType = Custom` + `CameraSubject = 대상 Humanoid`만 바꾸고, 우리가 바꿨을 때만 내 Humanoid로 되돌린다. 0.25초마다 대상 존재·CameraSubject를 다시 맞춘다(리스폰 때 기본 카메라가 되돌려도 복구). ←/→, Q/E 키. 리모트 호출 없음.
  - 탈락(PlayerResult Eliminated, 나) → `Config.Match.EliminationCutscene` 동안 UI 없음 → 자동 관전.
  - Race 통과(PlayerResult Passed + 현재 mapKind Race) → 즉시 관전, 다음 `RoundIntro`에서 해제.
  - `RoundIntro`마다 지난 라운드 `racerUserIds`를 버리고 새 `RoundProgress`가 올 때까지 생존자를 후보로 쓴다.
  - `Victory` → 관전 UI 숨기고 모두 우승자 Humanoid를 비춤. `RoomUpdated`가 InMatch가 아니거나 nil → 전부 초기화 + 카메라 복구. `Starting`에서도 초기화.
  - `aliveUserIds`/`racerUserIds`/`standings`가 nil이어도 동작 (후보 없음 → "관전할 사람이 없어요", 순위표 생략).
- `src/client/ui/HudScreen.luau`: `new(parent, nameOf, myUserId)`. Victory 때 배너를 위(0.2)로 올리고 그 아래 순위표(ScrollingFrame, 등수순 정렬, 내 줄 노란색 + "(나)"). 다른 단계·숨김 때 순위표 제거. 우승자 이름은 순위표 이름 우선(이미 나간 경우). 진행 표시: mapKind Survival/Final이면 "남은 인원 n", Race는 기존 "통과 n/목표 · 남은 인원 n".
- `src/client/ui/HudController.luau`: `HudScreen.new`에 `player.UserId` 전달.
- `src/client/init.client.luau`: `SpectateController.start(gui)` 한 줄.

### Studio 확인 방법 (m2-05 머지 뒤가 정확함)
- Test → Clients and Servers 3~4명, 한 명이 방을 만들고 나머지 참가 → 시작 (`minPlayersToStart` 1).
- AC5~AC7, AC10: 1라운드에서 한 명이 일부러 떨어진다 → 탈락 안내 3초 뒤 아래 가운데에 "👀 관전 중: 이름"과 [◀][▶][로비로]. ◀▶·←/→·Q/E로 순환, 보던 사람이 통과/탈락하면 0.25초 안에 다음 사람. 다음 라운드에도 관전이 이어지는지.
- AC8: 관전자 화면에서 아레나·장애물이 보이는지 (`workspace.StreamingEnabled == false`).
- AC9: [로비로] → 내 캐릭터 카메라, 로비 이동 가능, 방 멤버 유지(서버 Output·다른 클라 방 목록), [👀 관전하기]로 재관전, 매치 끝나면 방 대기실.
- AC9-1: Race 결승선 통과 → 바로 관전 + [내 캐릭터 보기], 다음 라운드 소개 때 자동으로 내 카메라.
- AC9-2: 철판·결승에서 왼쪽 위 "남은 인원 n".
- AC11~AC12: 우승 때 4개 화면 모두 우승자 캐릭터, 순위표 줄 수 = 시작 인원, 내 줄 노란색, 각자 "n등"과 같음. 대기실로 돌아오면 UI 없음·카메라 정상, 한 판 더.
- AC13: Studio Device Emulator(휴대폰 가로)에서 패널 버튼 터치, 점프 버튼과 겹치지 않는지.
- AC14: 관전 중 방 나가기 / 클라이언트 창 닫기 → 다른 창·서버 Output 에러 없음.
- m2-05 전(이 브랜치만): `aliveUserIds`가 안 와서 레이서가 없는 라운드 사이엔 "관전할 사람이 없어요"가 나오고, 순위표는 안 뜬다(배너만). 탈락 관전 자체는 `racerUserIds`(m2-01)로 동작한다.

### 남은 이슈 / 알아둘 점
- 기본 카메라 스크립트는 ←/→ 키로 카메라를 돌리기도 해서 관전 중 ←/→를 누르면 시점도 살짝 돈다. 거슬리면 Q/E만 쓰거나 ContextActionService로 입력을 가로채면 된다.
- 순위표 패널 높이는 `0.8 × 화면 − 170px`라 아주 작은 화면에선 몇 줄만 보이고 스크롤된다.
