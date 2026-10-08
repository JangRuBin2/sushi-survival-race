status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-11 — 로비/매치 플레이스 분리 (텔레포트 · 같은 방으로 복귀 · 서버 간 방 목록)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §4-1(방 인원 전체가 매치 서버로 이동), §4-5(같은 방으로 로비 복귀), §11.2(Lobby/Match 플레이스, `ReserveServer`, MemoryStore 방 목록, 텔레포트 데이터)
- 담당 개발 worktree: `main` (**순차, 병렬 단계 m4-02~m4-10이 모두 `main`에 병합된 뒤**)
- 공용 파일 수정 담당: **이 스펙** (병렬 단계가 끝난 뒤라 공용 파일·`init`을 다시 맡는다)
- 의존: m4-01 ~ m4-10 병합 (특히 m4-07 세션 잠금 — 텔레포트 때 데이터를 넘겨받음)
- **이 스펙이 고치는 파일**: `src/server/PlaceService.luau`, `src/server/RoomService.luau`, `src/server/MatchService.luau`, `src/server/CharacterUtil.luau`(필요하면), `src/shared/RoomLogic.luau`, 공용 파일(`Types.luau` `RoomListing.remote` 등, `Config.luau` DEBUG 값), 새 파일 `src/shared/PlacePayload.luau`, `src/shared/RoomDirectoryLogic.luau`, `src/server/RoomDirectory.luau`, `tests/place-split.spec.luau`

## 목표
공개 서비스에서 방이 출발하면 방 인원 전체가 **그 방만 쓰는 매치 서버**로 옮겨 가 한 판을 하고, 끝나면 **같은 로비 서버의 같은 방으로 함께 돌아와** 바로 한 판 더 할 수 있다. 로비 서버가 여러 개여도 방 목록에서 다른 서버의 공개 방이 보이고 들어갈 수 있다. Studio와 플레이스 id가 없는 상태에서는 지금(한 플레이스)과 똑같이 돈다.

## 범위
- 포함:
  1. **역할**: `PlaceService.role()` = `PlaceRole.resolve(...)`. `"Single"`은 지금 동작 그대로(이 스펙의 모든 분기는 `Single`에서 꺼짐). `Config.DEBUG.simulateMatchServer = false`(새, Studio 전용 — true면 Studio에서 `"Match"` 흐름 일부를 텔레포트 없이 흉내: 접속한 플레이어 전원을 매니페스트 멤버로 보고 매치 시작).
  2. **로비 → 매치** (`Lobby` 역할, `RoomService.beginMatch` 분기):
     - `TeleportService:ReserveServer(MatchPlaceId)` → (accessCode, privateServerId). **매니페스트**(`PlacePayload.manifest`: `{ v = 1, roomKey, settings = { maxPlayers, isPrivate, name }, hostUserId, memberUserIds, lobbyJobId, createdAt }`)를 MemoryStore HashMap `MatchManifest`에 키 `privateServerId`로 저장(TTL 10분). 텔레포트 데이터에는 `roomKey`만 넣는다 — **신뢰하는 값은 MemoryStore 매니페스트**(클라이언트가 바꿀 수 있는 TeleportData는 힌트로만).
     - 방 멤버 전원을 한 번의 `TeleportAsync(MatchPlaceId, players, options{ ReservedServerAccessCode })`로 보낸다. 실패(`TeleportInitFailed`)하면 `Config.Teleport.MaxRetries`까지 그 사람만 다시. 끝내 실패한 사람은 로비에 남고 방에서 빠지며 "매치 서버로 이동하지 못했어요" 알림(`RoomUpdated` 기존 경로로 방 나감 처리 + 간단한 메시지).
     - 텔레포트가 시작되면 로비의 그 방은 `InMatch`로 두고, 멤버가 다 떠나면 지금처럼 닫힌다.
  3. **매치 서버** (`Match` 역할):
     - 시작할 때 `game.PrivateServerId`로 매니페스트를 읽는다(재시도 3번). 없으면 접속하는 사람을 모두 로비로 돌려보낸다(경고 로그).
     - 매니페스트 멤버가 다 오거나 `Config.Teleport.ArrivalTimeout`(20초)이 지나면 도착한 멤버로 방을 복원(`RoomService.restoreRoom(manifest, arrivedPlayers)` — 설정·방장 그대로, 방장이 안 왔으면 먼저 온 사람)하고 **바로 매치를 시작**한다(대기실·시작 버튼 없음). 도착 2명 미만이면 매치 없이 모두 로비로.
     - 늦게 온 매니페스트 멤버: 그 방에 들어가 관전자가 된다(매치 생존자 아님). 매니페스트에 없는 사람: 바로 로비로 텔레포트.
     - 로비 UI(방 목록·방 만들기)는 매치 서버에서 보이지 않는다 — 클라이언트에 보낼 `RoomList`를 비우고, 방 대기실 화면 대신 "매치 서버 연결 중…" 안내만(기존 화면 파일 수정 최소, 필요하면 HUD Starting 단계 문구로 대신).
     - 매치가 끝나면(우승 화면 뒤) 결과 `{ roomKey, winnerUserId, winnerName, appearanceId }`를 MemoryStore `MatchResult`(키 roomKey, TTL 2분)에 쓰고, 남은 멤버 전원을 **한 번의 `TeleportAsync(LobbyPlaceId, players, options)`**로 보낸다. TeleportData = `PlacePayload.returnTicket{ v = 1, roomKey, settings, hostUserId, memberUserIds }`. 가능하면 원래 로비 서버(`lobbyJobId`, `ServerInstanceId`)로, 그 서버가 꽉 찼거나 없으면 아무 로비 서버로 같이.
     - 매치 서버에서 "로비로"(관전 끄기)는 지금처럼 관전만 끈다. 방을 떠나는 요청(`LeaveRoom`)은 그 사람만 로비로 텔레포트.
  4. **로비 복귀 → 같은 방** (`Lobby` 역할):
     - 텔레포트로 들어온 플레이어의 `GetJoinData().TeleportData`에 `returnTicket`이 있으면 `PlacePayload.validateReturnTicket`으로 검사(모양·크기·자기 userId가 멤버에 있는지). 같은 `roomKey`의 방이 이 서버에 없으면 그 설정으로 새 방을 만들고(방장 = ticket의 hostUserId가 와 있으면 그 사람, 아니면 먼저 온 사람), 있으면 들어간다. `RestoreWindow`(30초) 동안 같은 roomKey로 오는 사람을 받는다. 방 이름은 다시 텍스트 필터를 거친다(실패 시 기본 이름). 비공개 방이면 새 코드를 만든다.
     - `MatchResult[roomKey]`를 읽어 우승자가 있으면 `MatchEvents.fireWinnerShowcase`(→ m4-06 단상).
     - 티켓이 위조돼도 할 수 있는 일은 "그 설정의 방을 만드는 것"뿐이라(CreateRoom과 같은 검증) 위험하지 않다.
  5. **서버 간 방 목록** (`RoomDirectory`, `Lobby` 역할):
     - 각 로비 서버가 자기 **공개·대기 중** 방을 MemoryStore SortedMap `RoomDirectory`에 `DirectoryRefresh`(5초)마다 올린다(키 `<JobId>:<roomId>`, 값 `{ jobId, roomId, name, maxPlayers, memberCount, state }`, TTL 30초). 닫히거나 매치를 시작하면 지운다.
     - 비공개 방 코드는 SortedMap `RoomCodes`(키 코드 → `{ jobId, roomId }`)에 올리고, 만들 때 다른 서버와 겹치면 코드를 다시 뽑는다.
     - 클라이언트에 보내는 `RoomList` = 이 서버 방 + 다른 서버 방(`RoomListing.remote = true`, 이 서버 방이 먼저). 목록 크기 최대 50.
     - `JoinRoom(roomId)`가 다른 서버 방이면: 디렉터리에서 다시 확인(자리 있음) → 그 로비 서버로 `TeleportAsync(LobbyPlaceId, {player}, options{ ServerInstanceId = jobId })` + TeleportData `{ joinRoomId }` → 도착한 서버가 그 방에 자동 참가(꽉 찼거나 없으면 로비에 남기고 알림). `JoinByCode`도 같은 방식. `QuickJoin`은 이 서버 방 → 다른 서버 방 → 새 방 순.
     - MemoryStore 요청이 실패하면 이 서버 방만 보여 준다(게임은 계속).
  6. **순수 로직**: `PlacePayload`(manifest·returnTicket·joinTicket 만들기/검증: 필드 타입, 멤버 수 ≤ 24, 문자열 길이 제한), `RoomDirectoryLogic`(로컬+원격 합치기·정렬·중복 제거·만료 거르기, 빠른 참가 고르기), 도착 대기 판단 `arrivalReady(expected, arrived, elapsed, timeout) -> "wait" | "start" | "abort"`, 복귀 방장 고르기.
  7. **`StreamingEnabled`**: 그대로 false (매치 서버에도 관전 카메라가 먼 아레나를 봄). 재검토 결과를 결정 기록에 남긴다.
- 제외:
  - 매치 서버 재접속(튕긴 사람이 같은 매치로 돌아오기)
  - 친구 따라가기·파티 초대 UI
  - 서버 간 채팅

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/place-split.spec.luau`)
- [ ] AC1: `PlacePayload` manifest/returnTicket을 만들고 검증하면 통과하고, 멤버 25명·이름 200자·숫자 아닌 userId·v 누락 값은 거부한다. returnTicket 검증은 "본인 userId가 멤버에 없음"도 거부한다.
- [ ] AC2: `arrivalReady`: 전원 도착 → start, 일부 도착 + 시간 남음 → wait, 시간 초과 + 2명 이상 → start, 시간 초과 + 1명 이하 → abort.
- [ ] AC3: `RoomDirectoryLogic.merge`가 이 서버 방을 먼저, 만료된 원격 항목을 빼고, 같은 키 중복을 하나로, 최대 50개로 돌려준다. 빠른 참가가 이 서버 → 원격 → 없음 순으로 고른다.
- [ ] AC4: 복귀 방장: 원래 방장이 도착 목록에 있으면 그 사람, 없으면 가장 먼저 온 사람.
- [ ] AC5: `PlaceRole`이 `Single`이면(Studio 기본) 기존 테스트 전부와 Studio 동작이 그대로다.
- [ ] AC6: 검증 명령 통과 (m4-12 이후면 타입 검사 포함).

### Studio 확인
- [ ] AC7: (Single 회귀) 플레이스 id가 nil인 지금 상태로 `docs/DEV-SETUP.md` 3-7·3-8 핵심 항목과 M4 병렬 스펙 기능이 그대로 된다.
- [ ] AC8: `simulateMatchServer = true`로 Studio 2~4명(Clients and Servers)을 켜면 대기실 없이 바로 매치가 시작돼 끝까지 돌고, 끝나면 에러 없이 "로비로 돌아가는" 지점에서 Studio 대체 동작(로그 + 로비 스폰으로)이 된다.

### 실제 서버 확인 (사용자: 퍼블리시 + Match 플레이스 생성 + `Config.Places` 입력, 친구 3명 이상)
- [ ] AC9: 방에서 시작하면 4명 모두 같은 매치 서버로 옮겨 가(로딩 화면) 한 판을 하고, 끝나면 함께 로비로 돌아와 **같은 이름·설정의 방에 같은 방장**으로 다시 모여 있다. 단상에 우승자가 서 있다.
- [ ] AC10: 다른 로비 서버에 있는 친구가 만든 공개 방이 내 방 목록에 보이고, 누르면 그 서버로 옮겨 가 그 방에 들어간다. 비공개 코드도 서버를 넘어 된다.
- [ ] AC11: 매치 중 한 명이 게임을 나가도 매치가 계속되고, 돌아간 로비에서 나머지가 같은 방에 모인다.
- [ ] AC12: 매치 서버에서 받은 코인·승수가 로비에 돌아와도 그대로다 (세션 잠금 넘겨받기).
- [ ] AC13: 매치 서버로 가는 텔레포트가 실패한 사람(시험: 한 명이 텔레포트 직전 게임을 닫음)이 있어도 나머지는 매치를 한다.

## 공용 파일 변경
- `shared/Types.luau`: `RoomListing.remote: boolean?` (그 밖에 필요한 것은 개발이 이 스펙 안에서)
- `shared/Config.luau`: `DEBUG.simulateMatchServer = false`
- `shared/Remotes.luau`: 원칙적으로 변경 없음 (기존 `JoinRoom`/`JoinByCode`/`QuickJoin`이 서버 간 처리를 맡음). 알림 메시지에 새 리모트가 꼭 필요하면 이 스펙에서 추가
- `default.project.json`: 변경 없음 (같은 빌드를 두 플레이스에 퍼블리시)

## 사용자 작업
1. 게임을 퍼블리시한다(지금 플레이스 = **Lobby, 시작 플레이스**).
2. Creator Dashboard(또는 Studio Asset Manager → Places)에서 **같은 게임에 새 플레이스 "Match"**를 만들고, 같은 Rojo 빌드(`rojo build -o build.rbxl`)를 열어 그 플레이스에도 퍼블리시한다. 코드가 바뀔 때마다 두 플레이스 모두 다시 퍼블리시.
3. 두 플레이스의 PlaceId를 메인 세션에 알려 주면 `Config.Places`에 넣는다(또는 직접 넣고 커밋).
4. Match 플레이스 설정: 최대 인원 24(= 방 최대 인원), Lobby: 40(m4-12 체크리스트).
5. AC9~AC13을 친구들과 확인.

## 결정 기록
- 2026-10-08 · 신뢰하는 매치 정보는 MemoryStore 매니페스트(키 = PrivateServerId), TeleportData는 힌트 · TeleportData는 클라이언트를 거쳐 바뀔 수 있음 · planner
- 2026-10-08 · 매치 서버는 대기실 없이 도착하면 바로 시작(최대 20초 대기), 2명 미만이면 취소 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 서버 간 방 목록을 M4에 포함(GDD 11.2). 실패하면 이 서버 방만 보이게 해서 게임은 막지 않음 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · Studio·플레이스 id 없음 = 한 플레이스 모드 유지 · 사용자 작업 없이도 개발·테스트 가능 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
