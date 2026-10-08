# QA — m4-11 로비/매치 플레이스 분리 (텔레포트 · 같은 방 복귀 · 서버 간 방 목록)

- 스펙: `docs/specs/m4-11-place-split.md`
- 검증 커밋: `178758f` (구현) + `25022c2` (문서), 브랜치 `m4-11-qa` (origin/main `25022c2`에서 분기)
- 결과: **통과 (qa-passed)** — P0/P1 없음. P2 1건(R1, 위조 복귀 티켓으로 방장 넘겨받기), P3 5건. Studio(AC7·AC8)와 실제 서버(AC9~AC13)는 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors / 0 warnings / 0 parse errors |
| `lune run tests` | **889 passed, 0 failed** (구현 커밋 863 + QA 26) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `place-split.spec` AC1 7개 + QA: JSON 왕복(MemoryStore·TeleportData는 JSON을 거침) 뒤에도 매니페스트·티켓·결과 검증 통과, 10자리 userId 유지, 실수·음수·0·NaN·2^53·문자열·구멍 난 배열·키 섞인 표 거부, roomKey 공백·따옴표·65자 거부, 버전 2·종류 다름·maxPlayers 5 거부 |
| AC2 | 통과 | `place-split.spec` AC2 + QA 경계: 딱 timeout이면 더 기다리지 않음, 24명 중 23명, 2명 방 1명 도착 → 취소 |
| AC3 | 통과 | `place-split.spec` AC3 + QA: 만료 경계(딱 TTL은 살아 있음), 같은 키는 최신 값, 이 서버 방 60개면 원격 0개, 빠른 참가가 꽉 참·게임 중·만료 원격을 건너뜀 |
| AC4 | 통과 | `pickRestoreHost` (place-split + QA: 빈 목록 nil, 방장이 늦게 와도 방장) |
| AC5 | 통과 (코드) | `PlaceRole.resolve`: Studio·id 없음 → Single. `PlaceService.start`는 Single이면 훅 없이 return, `RoomService` 훅 기본값 `{}` → 기존 경로. 기존 테스트 전부 통과. Studio 동작은 AC7 |
| AC6 | 통과 | 위 4개 명령 (m4-12 전이라 타입 검사 없음) |
| AC7 | 사용자 확인 필요 | 아래 체크리스트 A |
| AC8 | 사용자 확인 필요 | 아래 체크리스트 B |
| AC9~AC13 | 사용자 확인 필요 (사용자 작업 선행) | 아래 체크리스트 C |

### 기존 테스트 2개 기대값 변경 — 타당
- `m4-foundation.spec` 리모트 16 → 17: 스펙 "공용 파일 변경"이 "알림 메시지에 새 리모트가 꼭 필요하면 이 스펙에서 추가"를 허용했고, 결정 기록에 `Notice` 추가가 남아 있다. 서버는 `FireClient`만, `OnServerEvent` 연결 없음(QA 정적 테스트로 확인), 클라이언트는 문자열이 아니면 무시.
- `camera-priority.spec` Attributes 10 → 11: `Attributes.PlaceRole`(workspace, 서버가 씀) 추가에 맞춤.
- `m4-foundation.spec` PlaceService resolve 문자열을 앞부분만 찾게 바꿈: 4번째 인자(흉내 모드) 추가 때문. 검사 의도(역할을 `PlaceRole.resolve`로 정함)는 그대로.

## 버그

### [P2] R1 위조 복귀 티켓으로 살아 있는 방의 방장을 가져가고 비공개 코드 없이 들어갈 수 있음 (MatchResult가 없을 때)
- 전제: 공격자가 그 방의 `roomKey`를 안다(한 번이라도 그 방 멤버였으면 `matchHint`/복귀 티켓 TeleportData로 받음). 복원된 방은 같은 키를 계속 쓴다. 클라이언트는 같은 게임 안에서 TeleportData를 마음대로 넣어 텔레포트할 수 있다(로비 서버 JobId는 다른 서버 방 목록 id `"<JobId>:<roomId>"`에도 보임).
- 재현(코드 기준):
  1. A·B·C·D가 방 K로 한 판을 하고 로비 서버 L로 돌아와 방 K가 복원됨(대기실). B가 그 방을 나감.
  2. 2분(`ResultTtl`) 뒤, B가 `{ v=1, kind="return", roomKey=K, settings=<아무 유효 값>, hostUserId=B, memberUserIds={B} }`를 TeleportData로 넣고 서버 L로 텔레포트.
  3. `handleReturn` → `restores[K]` 없음 → 티켓으로 새 Restore → `loadResult`가 `MatchResult[K]`를 못 찾아 **티켓 값을 그대로 믿음** → `findByKey(K)`가 살아 있는 방을 찾음 → `joinRestored(B, room, hostUserId=B)`.
- 기대: 티켓만으로는 "그 설정의 새 방 만들기" 이상을 못 한다(스펙 범위 4, 결정 기록 "위조 티켓으로 남의 방에 끼어들기 어렵게").
- 실제: B가 방에 들어가고(`joinRoom`은 비공개 여부를 보지 않음 → 비공개 방이면 새 코드 없이 들어감) `pickRestoreHost(B, members)`로 **방장이 B로 바뀐다**. `MatchResult` 쓰기가 실패했을 때도 같은 일이 정상 복귀 중에 일어날 수 있다(먼저 온 멤버의 티켓이 방장을 정함).
- 영향: 방장 권한(시작) 가로채기, 비공개 방 코드 우회. 데이터·판정·결제와는 무관, 공격자는 그 방의 옛 멤버로 한정 → P2.
- 고치는 방향(개발 판단): (a) `MatchResult`로 확인되지 않은 Restore는 기존 방(`findByKey`)에 넣지 말고 새 방만 만들기, 또는 (b) 기존 방에 들어갈 때는 방장을 바꾸지 않기 + 비공개 방이면 거부, 또는 (c) 복원이 끝나면(RestoreWindow 뒤) 방 키를 새로 바꾸기.
- 위치: `src/server/PlaceService.luau:317-340`(결과 없으면 티켓 값 유지), `:391-401`(`findByKey` → `joinRestored`), `src/server/RoomService.luau:701-716`(`joinRestored`가 방장 교체)

### [P3] R2 다른 서버 방 참가가 진행 중이어도 같은 요청을 또 받아 저장·텔레포트를 반복함
- 재현: 다른 서버 방(🌐)을 누름 → 서버가 `saveNow` 뒤 텔레포트를 걸고 `true`를 돌려줌 → 클라이언트 `busy`가 풀림 → 실제 이동 전 몇 초 동안 다시 누름(또는 익스플로잇으로 0.3초마다).
- 기대: 텔레포트가 진행 중인 사람의 방 요청은 거부.
- 실제: `requireNoRoom`은 "방에 들어가 있는지"만 봐서 매번 MemoryStore 읽기 + `DataService.saveNow`(DataStore 쓰기) + `TeleportAsync`가 다시 일어남. 세션 저장은 합쳐지지만(한 번에 하나) 계속 누르면 연달아 쓴다 → 서버 DataStore 예산을 한 사람이 먹을 수 있음.
- 위치: `src/server/RoomService.luau:418`(`requireNoRoom`), `src/server/PlaceService.luau:445-455`(`teleportToLobbyServer`). `pending[player]`가 있으면 거부하면 됨.

### [P3] R3 크래시 경로가 Won 받은 우승자를 MatchResult·단상에 넘기지 않음 (m4-01 B2 남은 부분)
- `onMatchEnd`에는 이제 `RoundLogic.winnerOf`로 우승자가 들어간다(B2 해결). 하지만 그 다음 `finish(room.id, nil)`이라 매치 서버의 `MatchResult`에 우승자가 없고 로비 단상이 비어 있다(Single도 크래시 경로는 단상 없음 — 원래와 같음). 코인·승수는 `onResult(Won)`이라 영향 없음.
- 위치: `src/server/MatchService.luau:339-343`

### [P3] R4 저장이 5초 안에 안 끝나면 도착 서버가 잠금을 가져간 뒤 늦은 저장이 거부될 수 있음 (드묾)
- 경로 확인 결과: 잠금 대기로 **임시 프로필로 떨어지지는 않는다** — `loadFromStore`는 `LoadRetries`(5 × 2초)를 다 기다리면 잠금을 가져간다(steal). 임시 프로필은 DataStore 요청 자체가 실패할 때뿐(기존 m4-07 동작).
- 위험: 떠나는 서버의 `saveNow`가 `SaveBeforeTeleport`(5초)를 넘기면 텔레포트는 그냥 진행되고 저장은 뒤에서 계속된다. 그 저장 + 해제가 도착 서버의 약 10초 대기보다 늦으면 도착 서버는 옛 값을 읽고, 늦은 저장은 `commit`에서 거부("session lock lost")돼 그 사이 받은 코인(예: 매치 끝 DailyFirstMatch·Win)이 사라진다. DataStore가 몹시 느릴 때만. 결정 기록대로 실제 서버에서 `[DataService] ... was locked by another server, taking the lock` 경고가 보이면 `LoadRetries`를 늘릴 것.
- 정상 경로는 안전: 코인 지급(`onResult`·`onMatchEnd`)은 `finish` 전에 `DataService.update`로 반영되고 → `saveNow` → 텔레포트 → 떠날 때 해제 저장. 재시도 중에는 다시 저장하지 않아 중복 저장 없음.
- 위치: `src/server/PlaceService.luau:186-201`, `src/server/DataService.luau:180-213`

### [P3] R5 복귀 가장자리 두 가지
- (a) RestoreWindow(30초)가 지난 뒤 `ResultTtl`(2분) 안에 늦게 돌아온 사람마다 새 Restore가 생겨 `fireWinnerShowcase`가 같은 우승자로 다시 불린다(단상이 다시 세워질 뿐, 해 없음). 위치 `PlaceService.luau:351-368, 383-386`.
- (b) 매치 서버가 2명 미만으로 취소(20초)했을 때 로비의 원래 방(InMatch)이 아직 닫히지 않았으면(텔레포트를 재시도 중인 멤버가 남음) 돌아온 사람이 `findByKey`로 그 방을 찾고 "이미 게임 중인 방이에요"로 방 없이 남는다. 위치 `PlaceService.luau:392-401`.

### [P3] R6 (확인 요청) 복귀한 방이 정원이면 10초 뒤 자동으로 다음 판 출발
- 4/4 방이 다 돌아오면 `insertRoom`/`joinRoom`의 `refreshAutoStart`로 10초 카운트다운이 걸린다. Single에서도 `endMatch` 뒤 같은 동작이라 회귀는 아님. 다만 플레이스 분리에서는 로딩·프로필 로드 시간이 끼어 체감이 더 짧다. 의도와 다르면 기획이 정할 것.

## 코드 리뷰 요약

### 보안
- [x] 매치 서버는 `MatchManifest[game.PrivateServerId]`만 믿는다. `validateMatchHint`는 어디서도 안 부름(TeleportData 무시). 매니페스트는 `validateManifest`로 모양·크기 검사.
- [x] 매니페스트에 없는 사람은 `sendToLobby`. 매니페스트를 읽는 동안 온 사람도 읽은 뒤 같은 검사(`onMatchPlayerAdded`). 도착 인원은 매니페스트 멤버만 센다. 예약 서버는 access code 없이는 못 들어옴.
- [x] 다른 방 코드로 끼어들기: 매치 서버에서는 `CreateRoom`·`JoinRoom`·`JoinByCode`·`QuickJoin`·`StartRoom` 모두 막힘. 로비의 참가 티켓은 `JoinRoom`/`JoinByCode`와 같은 검증(공개 방 id 또는 4자리 코드, 비공개 방은 id로 못 들어감).
- [x] `Notice`는 서버 → 클라이언트만. 클라이언트는 타입 검사.
- [x] 리모트 인자: `JoinRoom` 문자열 길이 200 제한 추가, 원격 id는 `parseKey`(128자) → 저장소에서 다시 읽고 `canJoin` 확인 후에만 텔레포트.
- [ ] 복귀 티켓: R1.

### 데이터
- [x] 로비→매치, 매치→로비, 로비→다른 로비 모두 텔레포트 직전 `saveNow`(최대 5초). 잠금 해제는 떠날 때 기존 `unload`.
- [x] 도착 서버 잠금 대기는 임시 프로필이 아니라 10초 뒤 steal. 위험은 R4(드묾).
- [x] 텔레포트 재시도 중 다시 저장하지 않음. R2만 예외(요청 반복).

### 흐름
- [x] 도착 대기: 전원 도착 즉시 시작, 20초 뒤 2명 이상 시작 / 미만 취소(취소 때 복귀 티켓으로 로비). 늦게 온 멤버 → `addLateMember`(관전자, 정원 안에서), 끝난 뒤 온 사람 → 바로 로비.
- [x] 같은 방 복귀: `MatchResult` 먼저 읽고 방 정보·멤버·방장을 그걸로 덮어씀 → 우승자 있으면 단상. 원래 로비 서버(`ServerInstanceId`)로, 실패하면 1초 모아 `fallback`(아무 로비)으로 같이. 이름 다시 필터, 비공개면 새 코드.
- [x] 서버 간 목록: 5초마다 공개·대기 방 올림(출발·닫힘 때 바로 지움), 다른 서버 방은 이 서버 방 뒤, 최대 50. 실패하면 경고(60초에 한 번)만 하고 이 서버 방만. 코드 예약은 `UpdateAsync`로 다른 서버와 겹치면 다시 뽑음, 예약 요청이 실패하면 이 서버 안에서만 유일(게임 계속).
- [x] 빠른 참가: 이 서버 → 원격(다시 확인) → 새 방.

### 회귀
- [x] Single: 훅 없음 → `beginMatch`는 `matchStartHandler`, 목록은 `listPublic`(+50개 자르기), `JoinByCode`는 로컬, `finishMatch`는 false → `endMatch`. 방 만들기 리팩터(`reserveRoomId`·`pickCode`·`insertRoom`)는 로컬 코드 중복 검사와 같은 결과. 기존 room 테스트 전부 통과.
- [x] `MatchService.finish()`: `sendHome` → `matches[roomId] = nil` → `PlaceService.finishMatch`(pcall) → 처리 안 되면 `endMatch`. 정상·크래시 두 경로가 같은 함수를 씀.
- [x] MatchEvents 순서·횟수: `onMatchEnd`는 `endFired`로 매치당 한 번, Victory 직후(우승자 있음) 또는 `finish` 직전(없음). `onWinnerShowcase`는 Single = MatchService(VictoryDuration 뒤, sendHome 전 — 예전과 같은 자리), Lobby = PlaceService 복귀 때 Restore당 한 번(R5a), Match = 안 보냄.
- [x] m4-01 B2: `onMatchEnd`는 해결, MatchResult·단상은 R3.
- [x] m4-06 L3: 로비 역할에서 `LobbyService`가 단상을 짓고 `onWinnerShowcase`를 듣고, `PlaceService.loadResult`가 보낸다 → 해결. 매치 역할은 로비 건물을 짓지 않음.
- [x] 커밋 상태: `Config.Places` 비어 있음, `simulateMatchServer = false`, `forceMapPlan = nil` (QA 테스트로 고정).
- 참고: `StreamingEnabled` false 유지 결정 타당(관전 카메라·우승 무대가 스폰에서 멂).

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 (타입, 길이, 방 소속, 방장 여부 — 매치 서버에서는 로비 요청 자체를 막음)
- [x] 통과·탈락·순위 판정이 서버에만 있다 (변경 없음, 우승자는 서버가 MatchResult에 씀)
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 (변경 없음)
- [x] 연결·스레드 정리: `pending`은 PlayerRemoving에서 지움, 재시도 묶음은 한 번 돌고 사라짐, Restore는 RestoreWindow 뒤 지움, 디렉터리 항목은 BindToClose에서 지움. 매치 서버 연결은 서버 수명 동안(한 번만 연결)
- [ ] 텔레포트 데이터(클라이언트를 거침) 신뢰 범위 — R1

## 사용자 Studio 확인 체크리스트

### A. AC7 Single 회귀 (설정 그대로, Test → Clients and Servers 2~4명)
1. `Config.Places`가 비어 있고 `simulateMatchServer = false`인지 확인.
2. 방 만들기(공개/비공개), 목록에서 참가, 4자리 코드로 참가, 빠른 참가(방 있을 때/없을 때 새 방), 방 나가기, 방장 시작.
3. 한 판을 끝까지(필요하면 `forceMapPlan`) → 우승 화면 → 모두 로비 스폰, 같은 방 대기실로 돌아옴 → 로비 단상에 우승자 인형.
4. 서버 출력에 `[PlaceService]`·`[RoomDirectory]` 줄이 **하나도 없어야** 한다. 방 목록에 🌐 표시가 없어야 한다.
5. M4 병렬 기능 몇 개 훑기: 코인 지급 알림(m4-08), 옷장/외형(m4-02 등), 이동 감시 경고 없음(m4-10).

### B. AC8 매치 서버 흉내 (`Config.DEBUG.simulateMatchServer = true`, 로컬에서만)
1. Test → Clients and Servers 2~4명. 로비 건물·방 목록·대기실 없이 화면 가운데 "매치 서버 연결 중…".
2. 마지막 플레이어가 들어오고 약 5초 뒤 대기실 없이 바로 Starting → 라운드들 → 우승 화면.
3. 매치 중 한 클라이언트에서 방 만들기/참가 같은 로비 요청이 없어야(UI 자체가 없음) 하고, 관전 "로비로"는 관전만 끔.
4. 우승 화면 뒤 서버 출력 `[PlaceService] (Studio) would teleport N players back to the lobby (match finished), room studio-simulated`, 캐릭터가 로비 스폰으로, 화면 "로비로 돌아가는 중…". 에러 없음.
5. (선택) 1명만 켜고 시작: `minPlayersToStart`(1)로 시작되는지.
6. 끝나면 **`simulateMatchServer = false`로 되돌리기** (QA 테스트가 커밋 상태를 검사함).

### C. AC9~AC13 실제 서버 (사용자 작업 선행: 퍼블리시 → Match 플레이스 생성·같은 빌드 퍼블리시 → PlaceId 2개를 `Config.Places`에 → 두 플레이스 다시 퍼블리시. 친구 3명 이상)
1. AC9: 4명이 한 방에서 시작 → 4명 모두 로딩 화면 뒤 같은 매치 서버 → 한 판 → 함께 로비로 → **같은 이름·설정·방장**의 방에 모여 있음(비공개면 새 코드) → 단상에 우승자. F9 Server 로그 `[PlaceService] room ... → match server`, `... arrived, starting match`, `... players → lobby (match finished)`.
2. AC10: 친구가 다른 로비 서버에 있게 하고(서버가 둘 이상일 때) 공개 방 → 내 목록에 🌐 방이 보이는지(최대 5초 지연) → 누르면 "방이 있는 서버로 이동하고 있어요…" → 그 방에 들어감. 비공개 코드도 같은 방식.
3. AC11: 매치 중 한 명이 게임을 종료 → 매치 계속 → 나머지가 로비의 같은 방으로.
4. AC12: 매치 전 코인·승수를 기억 → 매치에서 코인 받고(우승이면 승수 +1) → 로비로 돌아와 그대로인지. 다시 한 판 더 갔다 와도 그대로인지. F9 Server에 `[DataService] ... taking the lock` 경고가 보이면 기록(R4).
5. AC13: 시작 버튼을 누르자마자 한 명이 게임을 닫음 → 나머지는 매치 서버로 가서 약 20초 뒤 시작. 남은 사람이 1명이면 매치 없이 로비로 돌아와 같은 방.
6. (추가) 매치 서버 링크를 직접 열거나 친구 따라가기로 매치 서버에 들어가려 하면 로비로 돌려보내지는지.

## 추가한 테스트
`tests/m4-11-qa.spec.luau` (26개)
- 로비가 만드는 기본 이름(DisplayName 20자 + "의 초밥집" 잘림, 한글·이모지)이 매니페스트 검증 통과 — 실패하면 매치 서버가 매번 취소되는 경로라 고정
- `cleanName` 멱등(정리된 이름을 다시 검증해도 통과), 빈·공백·제어 문자·잘못된 UTF-8·25자 거부
- JSON 왕복(lune serde) 뒤 매니페스트·복귀/참가 티켓·결과(우승자 있음/없음) 검증 통과, 10자리 userId 유지
- 멤버·roomKey·티켓 버전/종류·maxPlayers·참가 티켓 코드/id·결과 우승자 필드 경계
- `arrivalReady` timeout 경계, 24명/2명 방, `pickRestoreHost` 빈 목록
- `RoomLogic.addLateMember`(게임 중 방, 중복, 정원)
- `RoomDirectoryLogic`: parseKey 경계(빈 job/room, 콜론 여러 개, 128자 초과), 만료 경계, 깨진 항목, 같은 키 최신, 한도 0, 이 서버 방 60개, 빠른 참가 건너뛰기, entryFor JSON 왕복
- 정적: 커밋 상태(Places 비어 있음, 흉내 모드·강제 맵 꺼짐, 잠금 대기 ≥ 10초 ≥ 저장 대기), Notice 방향, 매치 서버 로비 요청·자동 시작·로비 건물 없음, 매니페스트 읽기 전 방 배정 없음, 복귀 때 MatchResult 먼저, 저장 후 텔레포트(세 방향)

## 인계 메모
- **지금 브랜치**: `m4-11-qa` (origin/main `25022c2`에서 분기, QA 커밋 + push)
- **끝난 것**: 자동 검증 4종(889/0), AC1~AC6 통과, 보안·데이터·흐름·회귀 코드 리뷰, QA 테스트 26개, 리포트, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인 A(AC7)·B(AC8), 사용자 작업 뒤 실제 서버 C(AC9~AC13). R1(P2)은 머지 차단은 아니지만 공개 테스트 전에 developer가 고치길 권장(고치는 방향 3가지 위에). R2·R3은 한두 줄 수정. R4는 실제 서버 로그를 보고 판단. R6은 기획 확인.
- **다음에 할 첫 단계**: 메인 세션이 `m4-11-qa`를 main에 병합 → 사용자 체크리스트 A·B → PlaceId 받으면 C. developer가 R1·R2를 m4-12 전에 고칠지 결정.
- **막힌 점**: 없음. 실제 텔레포트·MemoryStore는 퍼블리시된 서버에서만 확인 가능.
