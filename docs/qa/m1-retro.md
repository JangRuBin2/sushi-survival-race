# QA — m1-retro M1 뼈대 소급 QA (방 시스템 · 매치 상태 머신 · 회전 벨트 Race 맵 · HUD)

- 스펙: 없음 (M1은 스펙 파일 없이 병합됨). 기준: `docs/GDD.md` §3, §4, §11.4, §12 M1 완료 기준 + `CLAUDE.md` 규칙
- 검증 커밋: `5c5e49e` (main)
- 재검증 (수정 커밋 `0e9d757` `269c57a` `398e804` `6824f34`): **통과 — 남은 P0/P1/P2 없음** (아래 "재검증" 절). Studio 확인은 남아 있다.
- 최초 결과: **반려 권고 (P1 1건)**. 스펙 파일이 없어서 상태는 바꾸지 않았다. M2 작업 전에, 또는 M2 첫 스펙에 묶어서 P1·P2를 고치는 것을 권한다.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 61 passed, 0 failed (기존 38 + QA 추가 23) |

## 수용 기준
스펙이 없어서 GDD와 CLAUDE.md에서 기준을 뽑았다.

| AC | 기준 (출처) | 결과 | 근거 (테스트 이름 / 파일:줄 / 사용자 확인 필요) |
|---|---|---|---|
| AC1 | 최대 인원 4/8/12/16/24, 기본 12 (§3.2) | 통과 | `validateSettings accepts every max player option`, `validateSettings: 선택지 밖의 숫자(경계·NaN·무한·소수)는 거절`, `Config.luau:9-10` |
| AC2 | 공개/비공개(4자리 코드) (§3.2) | 통과 | `isValidCode: 공백·전각 숫자·부호·nil은 거절`, `generateCode: 경계값 0과 9999도 4자리로`, `RoomService.luau:301` (비공개 방은 id로 참가 불가) |
| AC3 | 방 이름 자유 입력 + 텍스트 필터, 기본 "○○의 초밥집" (§3.2) | 부분 통과 | 정리·길이: `cleanName: …` 테스트들. 필터: `RoomService.luau:178-188` 코드 확인. 실제 필터 동작은 라이브 서버에서만 확인 가능 (사용자 확인 필요). 필터 대기 중 퇴장 경계는 버그 B5 |
| AC4 | 방장만 시작, 최소 4명 (§3.2) | 통과 | `canStart needs host…`, `실서버 최소 인원은 4명, 3명이면 방장도 시작 못 해요`, `새 방장은 시작 권한을 갖고, 이전 방장은 잃어요`, `RoomService.luau:350-362` |
| AC5 | 정원이 차면 10초 뒤 자동 시작, 자리가 비면 취소 (§3.2) | 로직 통과 / 타이머는 사용자 확인 필요 | `정원이 찬 방에서 한 명이 나가면 자동 시작 조건이 꺼지고…`, `RoomService.luau:143-157` |
| AC6 | 방장이 나가면 가장 먼저 들어온 사람이 승계 (§3.2) | 통과 | `host leaves -> earliest joined member…`, `방장이 연달아 나가면 매번…`, `마지막 사람이 나가면 멤버가 비어요` |
| AC7 | 빠른 참가: 시작이 가장 임박한 공개 방, 없으면 12명 방 생성 (§3.2) | 통과 | `pickQuickJoin …` 테스트 3개, `RoomService.luau:323-340` |
| AC8 | 라운드 수 4~8 → 3, 9~24 → 4 (§3.3) | 통과 | `roundCount: …`, `roundCount 경계: 8명 3라운드, 9명 4라운드` |
| AC9 | 통과 = clamp(round(n×비율), 2, n−1), 결승 전 ≤2명이면 바로 결승 (§4.1) | 부분 통과 | 순수 함수는 통과: `nextRound: 결승 전 남은 인원이 2명 이하이면…`, `nextRound가 결승 아닌 라운드를 주면 그 라운드는 항상 1명 이상 탈락해요`, `GDD 4.1: 결승 직전 인원은 항상 2명 이상…`. 단 MatchService가 라운드 소개 중 이탈을 반영하지 않음 (버그 B7) |
| AC10 | 상태 머신 RoomWaiting → Starting → [Intro → Active → Results]×N → Victory → RoomWaiting (§11.4) | 코드 통과 / 사용자 확인 필요 | `MatchService.luau:73-169`, `RoomService.luau:397-405` |
| AC11 | 라운드 소개 3초(맵 이름·규칙), 결과 5초 (§4) | 부분 통과 | 텍스트 배너와 시간은 맞음 (`Config.luau:30-36`, `HudScreen.luau:175-188`). 플라이스루 카메라는 미구현 (CLAUDE.md에 "아직 없는 것"으로 명시됨, M3) |
| AC12 | 결과 뒤 같은 방으로 로비 복귀 (§4) | 부분 통과 | `MatchService.luau:166-168`. 단 통과자는 라운드가 끝날 때마다 맵이 사라져 떨어진다 (버그 B1) |
| AC13 | 판정(결승선·탈락·순위)은 서버에서만 (§11.4, CLAUDE.md) | 통과 | 결승선 `RotatingBelt.luau:230-237`(서버 Touched), 낙하 `RotatingBelt.luau:250-253`, 순위 `RoundService.luau:137-152`. 클라이언트(`src/client/**`)는 리모트를 받기만 하고 판정하지 않음 |
| AC14 | 클라이언트 리모트 인자 서버 검증 (타입·범위·방 소속·방장) (CLAUDE.md) | 통과 | 아래 "서버 판정 · 보안 체크" 참고 |
| AC15 | 맵 상태는 모듈이 아니라 ctx에 (CLAUDE.md) | 통과 | `RotatingBelt.luau:208-282` (지역 클로저/ctx), `RotatingBeltChopstick.luau` (station Model 안), `RoundService.luau:105-116` (runRound 지역) |
| AC16 | 장애물은 CollectionService 태그로 동작 (§11.4, CLAUDE.md) | 부분 통과 | 태그는 붙인다 (`RotatingBeltChopstick.luau:42`) 하지만 동작은 태그 조회가 아니라 `Hazards` 폴더 순회로 돈다 (`RotatingBelt.luau:271-281`). 버그 B10 |
| AC17 | 연결·인스턴스·스레드 Cleanup 정리 (CLAUDE.md) | 부분 통과 | 대부분 `ctx.cleanup`에 들어감. 잡힌 플레이어 상태 복구 누락(B4), 라운드 도중 에러 시 정리 누락(B9) |
| AC18 | 혼자 테스트용 DEBUG 설정 (CLAUDE.md) | 통과 | `minPlayersToStart uses the debug value only in studio`, `Config.luau:57-59`. 단 1명이면 라운드 없이 바로 우승 (DEV-SETUP 3-5에 이미 적혀 있음) |
| AC19 | **M1 완료 기준**: 방에서 4명이 시작 → 1라운드 → 통과자 집계 (§12) | 사용자 확인 필요 | 코드상 가능 (`MatchService.luau:115-138`, `RoundService.luau:87-280`). 아래 체크리스트 2~3 |

요약: 통과 11 · 부분 통과 7 · 사용자 확인만 남음 1 (AC19). 실패한 기준은 없지만 부분 통과 항목에 버그가 걸려 있다.

## 버그
심각도: P0 크래시/진행 불가 · P1 핵심 흐름이 매번 깨짐 · P2 재현되는 기능 버그(우회 가능 또는 드묾) · P3 사소함/향후 위험.

### [P1] B1 라운드가 끝나면 맵이 바로 사라져서 통과자가 허공으로 떨어져 죽는다
- 재현: 2명 이상으로 매치 시작 → 1라운드에서 결승선 통과 → 라운드가 끝나는 순간을 본다.
- 기대: 통과자는 결과 화면(5초) 동안 안전한 곳(결승 구역, 대기 공간, 로비 등)에 있다가 다음 라운드 맵에 배치된다. 결승 우승자도 우승 연출 동안 살아 있다.
- 실제: `runRound`가 끝나면서 `cleanup:run()`이 맵 Model을 바로 Destroy한다. 통과자는 아무도 옮기지 않아서 높이 300의 아레나(x=2000×슬롯, 로비 바닥 256×256 밖)에서 떨어져 FallenPartsDestroyHeight(-500)에서 죽고, `RespawnTime = 1`이라 로비에 다시 태어난다. 매 라운드 통과자 전원, 결승에서는 우승자가 Victory 배너가 뜨는 동안 죽는다. 다음 라운드 배치는 `waitForCharacter`가 새 캐릭터를 기다려서 흐름은 이어진다 (그래서 P0는 아님).
- 위치: `src/server/RoundService.luau:103` (모델을 cleanup에 추가), `src/server/RoundService.luau:277` (라운드 끝에 바로 Destroy), `src/server/MatchService.luau:136-146` (결과 단계에 통과자 이동 없음), `src/server/MatchService.luau:166` (sendHome은 매치가 끝날 때만)
- 비고: 코드만 보고 확정했다. Studio 체크리스트 3에서 실제로 확인해 달라.

### [P2] B2 결승선을 점프로 넘거나 끝 모서리에서 떨어지면 통과로 판정되지 않고 낙하 탈락할 수 있다
- 재현: 회전 벨트에서 결승 구역 끝까지 달려가 결승선(코스 맨 끝 1스터드, 높이 0.4) 바로 앞에서 점프한다.
- 기대: 결승선을 지나면 통과.
- 실제: 결승선이 바닥 높이의 얇은 판(0.4)이고 `Touched`로만 판정한다. 점프하면 발이 판 위로 지나가 닿지 않는다. 결승선이 결승 바닥의 맨 끝에 있고 끝쪽 벽이 없어서(`addWalls`는 양옆만), 점프한 채로 넘으면 코스 밖으로 떨어져 `VOID_DROP` 판정으로 **탈락**한다.
- 위치: `src/shared/maps/RotatingBelt.luau:189-197` (결승선 크기·위치), `src/shared/maps/RotatingBelt.luau:74-86` (끝쪽 벽 없음), `src/shared/maps/RotatingBelt.luau:230-237` (Touched 판정)
- 제안(개발 판단): 키 큰 투명 트리거 볼륨, 또는 Heartbeat에서 로컬 Z 위치로 판정. 결승선 뒤에 바닥/벽 추가.

### [P2] B3 시간 종료 때 탈락자의 등수가 거꾸로 매겨진다
- 재현: 4명 이상으로 Race 라운드를 시작하고 아무도 결승선을 넘지 않은 채 90초를 보낸다. 탈락한 사람들의 "🥢 탈락했어요… (n등)"을 비교한다.
- 기대: 탈락자 중 더 멀리 간 사람이 더 좋은(작은) 등수.
- 실제: `leftover`를 멀리 간 순으로 정렬한 뒤 앞에서부터 `finalizeEliminated`를 부르는데, 등수가 `totalRacers - #eliminated + 1`이라 먼저 탈락 처리된 사람(=탈락자 중 가장 멀리 간 사람)이 가장 나쁜 등수를 받는다. 예: 8명, 목표 5명, 통과 0 → 6번째로 멀리 간 사람이 8등, 가장 못 간 사람이 6등.
  목표 인원이 들어와서 끝날 때(`isTimeout = false`)는 `remaining` 해시 순서로 탈락 처리해서 등수가 임의로 정해진다.
- 위치: `src/server/RoundService.luau:150` (등수 공식), `src/server/RoundService.luau:182-191` (시간 종료), `src/server/RoundService.luau:198-203` (목표 도달 종료)
- 제안: 탈락 처리는 못 간 사람부터(정렬 역순으로) 한다. 목표 도달 종료도 진행도 순으로 정렬한다.

### [P2] B4 젓가락에 잡힌 채로 라운드가 끝나면 이동/점프 값이 복구되지 않는다
- 재현: 젓가락에 잡혀 있는 3초 사이에 라운드가 끝나게 한다 (2명 중 다른 한 명이 마지막 목표 통과, 또는 시간 종료). 잡힌 사람이 탈락해서 로비로 돌아간 뒤 점프해 본다.
- 기대: 라운드가 끝나면 잡힘이 풀리고 WalkSpeed/JumpPower가 원래대로.
- 실제: 젓가락 스레드는 `task.wait(GRAB_DURATION)` 중에 `ctx.cleanup`의 `task.cancel`로 멈춰서 `release`가 불리지 않는다. 탈락 연출(`EliminationService`)과 다음 라운드 배치(`placeAt`)는 **WalkSpeed만** 되돌리고 **JumpPower는 0으로 남는다**. 탈락자는 죽지 않고 로비로 순간이동하므로 리스폰 전까지 점프를 못 한다. (StarterPlayer `CharacterUseJumpPower`가 false면 JumpPower 0이 효과가 없을 수도 있다 → 그 경우 반대로 "잡혀도 점프 가능" 문제. 체크리스트 5)
- 위치: `src/shared/maps/RotatingBeltChopstick.luau:104-105, 163-165`, `src/shared/maps/RotatingBelt.luau:275-278`, `src/shared/Cleanup.luau:30-33`, `src/server/EliminationService.luau:72-75`, `src/server/RoundService.luau:67-71`
- 제안: 잡을 때 `ctx.cleanup:add(function() release(grabbed) end)` 같은 복구 작업을 등록하거나, 잡힘 해제를 RoundService 쪽 공통 복구로 옮긴다.

### [P2] B5 방 만들기 중(텍스트 필터 대기) 퇴장하면 주인 없는 "유령 방"이 남는다
- 재현: 방 이름을 넣고 **만들기**를 누른 직후(필터 응답 전) 접속을 끊는다. 라이브 서버에서 필터가 느릴 때 생기기 쉽다.
- 기대: 방이 만들어지지 않는다.
- 실제: `filterRoomName`이 yield하는 동안 `PlayerRemoving → leaveRoom`은 방이 없어서 아무것도 안 한다. 필터가 끝나면 `roomIdByUser`가 비어 있으니 `createRoom`이 나간 사람을 방장으로 방을 만든다. 이 방은 목록에 "1/n"으로 계속 보이고, 방장이 없으니 아무도 시작을 못 하며(정원이 차야만 자동 시작), 마지막 사람이 나가도 유령 멤버 때문에 닫히지 않는다. 같은 사람이 같은 서버에 다시 들어오면 `roomIdByUser`가 남아 있어 "이미 방에 들어가 있어요"만 나오고 로비에서 아무것도 못 한다.
- 위치: `src/server/RoomService.luau:281-285` (yield 뒤 `player.Parent` 확인 없음), `src/server/RoomService.luau:217`
- 제안: 필터 뒤 `if player.Parent == nil then return false, ... end`.

### [P3] B6 매치 중 나간 사람의 탈락 결과가 다른 멤버에게 방송되지 않는다
- 재현: 4명 매치의 라운드 중 한 명이 접속을 끊는다 (또는 LeaveRoom).
- 기대: 남은 멤버도 그 사람의 `PlayerResult(Eliminated)`를 받는다.
- 실제: `leaveRoom`이 `roomIdByUser`를 먼저 지운 뒤 `memberLeftHandler`를 불러서, `EliminationService.audienceFor`가 방을 못 찾고 본인에게만 보낸다. 지금 HUD는 내 결과만 보여서 눈에 안 띄지만, M2 관전·탈락 피드에서 드러난다.
- 위치: `src/server/RoomService.luau:238, 248-250`, `src/server/EliminationService.luau:22-28`

### [P3] B7 라운드 소개 중 이탈로 2명이 되면 결승으로 건너뛰지 않고, 아무도 탈락하지 않는 라운드를 한다
- 재현: 3명이 남은 상태로 R2 소개(3초)가 뜨는 동안 한 명이 나간다.
- 기대 (GDD 4.1): 결승 전 2명 이하 → 바로 결승. 매 라운드 최소 1명 탈락.
- 실제: 소개 뒤에는 `aliveCount <= 1`만 확인하고 그대로 R2를 돈다. `qualifyCount(2, …)`는 2라서 둘 다 통과해야(또는 시간 종료로 둘 다 통과) 끝나고, 아무도 탈락하지 않은 채 최대 90초를 쓴다. 순수 함수 `nextRound`는 맞게 동작한다 (테스트 `nextRound: 결승 전 남은 인원이 2명 이하이면…`) — 문제는 MatchService가 결과 단계 뒤에만 `nextRound`를 부르는 데 있다.
- 위치: `src/server/MatchService.luau:112-115`, `src/server/MatchService.luau:148`

### [P3] B8 결승 여부를 맵 종류로 판단해서, 맵 풀이 모자랄 때 결승 규칙이 어긋난다
- 재현: 지금 맵 풀(회전 벨트 하나)로 결승까지 간다.
- 기대: 마지막 라운드(결승)는 1등에게 `Won`.
- 실제: `isFinal = map.kind == "Final"`이라 회전 벨트(Race)로 도는 결승에서는 `Passed`가 간다. CLAUDE.md·DEV-SETUP에 알려진 한계로 적혀 있다. M2에서 Final 맵이 생기면 사라지지만, 판정 기준은 `args.roundIndex == args.roundCount`가 더 안전하다 (Survival 맵이 대체로 쓰이면 `roundShouldEnd`의 Survival 분기가 결승에 적용되는 문제도 같은 원인).
- 위치: `src/server/RoundService.luau:113, 140, 162`

### [P3] B9 라운드 도중 에러가 나면 맵·리무버가 정리되지 않고 플레이어가 아레나에 남는다
- 재현: (코드 경로) `build()`가 Spawns 없는 모델을 돌려주거나 `runRound` 안에서 에러.
- 기대: 맵이 지워지고 멤버가 로비로 돌아간다.
- 실제: 모델을 `workspace`에 넣은 뒤(`:92`) assert(`:95, :97`)를 해서, 실패하면 cleanup에 들어가기 전의 모델이 남는다. `activeRemovers[roomId]`도 남는다. MatchService의 crash 처리(`:177-182`)는 `endMatch`만 하고 `sendHome`을 안 해서 캐릭터가 아레나에 남는다.
- 위치: `src/server/RoundService.luau:90-103, 247, 270`, `src/server/MatchService.luau:177-182`

### [P3] B10 장애물이 CollectionService 태그가 아니라 폴더 구조로 동작한다
- 실제: `Chopstick` 태그를 붙이지만 아무도 태그를 조회하지 않고, `RotatingBelt.start`가 `Hazards` 폴더를 돌며 직접 실행한다. CLAUDE.md "장애물은 CollectionService 태그로 동작시킨다"와 어긋난다. 여러 방이 동시에 돌면 전역 태그 조회는 ctx 모델 안으로 걸러야 해서, 지금 방식이 의도적일 수 있다 → 기획/개발이 규칙을 확정해 달라 (예: "태그 + `ctx.model:IsAncestorOf`").
- 위치: `src/shared/maps/RotatingBeltChopstick.luau:42`, `src/shared/maps/RotatingBelt.luau:271-281`

### [P3] B11 (향후 위험) 위치·결승선 판정이 클라이언트 소유 물리를 그대로 믿는다
- 결승선 `Touched`와 진행도(`progressOf`)는 클라이언트가 네트워크 소유한 캐릭터 위치를 쓴다. 익스플로잇 클라이언트가 결승선으로 순간이동하면 통과한다. 서버 판정 원칙 자체는 지키고 있으니 MVP에서는 P3, 공개 전(M4)에 속도/순간이동 검사 추가를 권한다.
- 위치: `src/shared/maps/RotatingBelt.luau:230-237`, `src/server/RoundService.luau:77-85`

## 기획 확인 필요 (버그 아님, planner/사용자 결정)
- **Survival 시간 종료 규칙**: GDD 5.2에 없음. 지금은 시간이 끝나면 Race처럼 "로컬 -Z로 멀리 간 순"으로 목표 인원만 통과시키고 나머지는 탈락시킨다 (`RoundService.luau:180-192`). Survival 맵에서는 의미 없는 기준이다. "시간 끝까지 버틴 사람 전원 통과"인지 정해야 한다. M2 Survival 스펙에 넣어 달라.
- **매치 뒤 자동 시작**: 매치가 끝나고 대기실로 돌아왔을 때 방이 정원이면 10초 자동 시작이 다시 걸린다 (`RoomService.luau:403`). GDD "같은 멤버로 바로 한 판 더 가능"과 맞는지, 의도한 동작인지 확인.
- **2명 남은 결승 전 라운드**: GDD 공식 `clamp(round(2×비율), 2, 1)`은 min > max라 정의가 안 된다. 구현은 2(아무도 탈락 안 함)를 돌려준다. `nextRound`가 이 경우를 결승으로 보내므로 정상 흐름에선 안 나오지만, B7처럼 중간 이탈 시 나온다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 (타입, 범위, 방 소속, 방장 여부)
  - 클라이언트→서버는 RemoteFunction 6개뿐이고 RemoteEvent는 전부 서버→클라이언트.
  - `CreateRoom`: `validateSettings`로 타입·선택지·이름 타입 검증 (`RoomLogic.luau:70-89`), 이미 방에 있으면 거절, 필터 yield 뒤 재확인 (`RoomService.luau:272-290`). 단 퇴장 재확인 없음(B5).
  - `JoinRoom`: 문자열 확인, 비공개 방 거절 (`RoomService.luau:292-305`). `JoinByCode`: 숫자 4자리 패턴 (`:307-321`). 정원·게임 중·중복은 `canJoin`.
  - `StartRoom`: 자기 방 조회 후 `canStart`로 방장·대기 상태·최소 인원 (`:350-362`). `LeaveRoom`: 방 소속 확인 (`:342-348`).
  - 모든 요청에 0.3초 간격 제한과 pcall (`:364-381`).
- [x] 통과·탈락·순위 판정이 서버에만 있다 (클라이언트 코드는 표시만)
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다
- [ ] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 연결·스레드·모델은 정리됨. 잡힌 플레이어 상태 복구(B4), 에러 경로(B9) 누락

## 사용자 Studio 확인 체크리스트
`rojo serve` 후 Studio에서 연결. "Clients and Servers"는 Test 탭 → 플레이어 수 지정 → Start.

1. **방 시스템 회귀** — `docs/DEV-SETUP.md` 3-4 체크리스트를 그대로 한 번 돈다 (로비, 방 만들기, 4명 참가, 방장 승계, 비공개 코드, 자동 시작 10초 + 취소, 연타 제한).
2. **M1 완료 기준 (AC19)** — Clients and Servers 4명. 공개 방 4명 정원으로 만들고 전원 참가 → 자동 시작(또는 방장 시작).
   - [ ] 4명 화면 모두 "매치 시작!" → "라운드 1 / 3" + "회전 벨트" 소개 → 맵으로 이동
   - [ ] 왼쪽 위가 "통과 0/2 · 남은 인원 4"로 시작 (4명 × 0.6 = 2.4 → 2)
   - [ ] 2명이 결승선을 넘는 순간 라운드가 끝나고 나머지 2명은 "🥢 탈락했어요… (n등)"
   - [ ] 서버 Output에 빨간 에러 없음
3. **B1 확인 (통과자 낙하)** — 위 2번에서 결승선을 넘은 플레이어 화면을 라운드 종료 순간 지켜본다.
   - [ ] 맵이 사라지면서 캐릭터가 떨어져 죽고 로비에 리스폰되는지 (예상: 그렇다 = 버그 재현)
   - [ ] 결승에서 우승자도 "🏆 우승!" 배너 동안 떨어지는지
4. **B2 확인 (결승선 점프)** — 2명 매치. 결승 구역 끝까지 간 뒤 결승선 바로 앞에서 점프해 넘어간다.
   - [ ] "✅ 통과" 대신 코스 밖으로 떨어져 탈락하는지 (예상: 재현됨)
   - [ ] 점프 없이 걸어서 넘으면 정상 통과하는지
5. **B4 확인 (젓가락 잡힘 복구)** — 2명 매치 R1(목표 2명). A가 먼저 결승선을 넘고, B는 젓가락 경고 구역에 서 있다가 잡힌다. 잡힌 상태에서 90초가 끝나게 둔다 (또는 결승에서 A가 통과하는 순간 B가 잡혀 있게 한다).
   - [ ] 젓가락에 잡혔을 때 점프가 막히는지 (안 막히면 `CharacterUseJumpPower` 설정 문제)
   - [ ] 라운드가 끝나고 로비로 돌아간 B가 점프할 수 있는지 (예상: 못 함 = 버그 재현)
6. **B3 확인 (시간 종료 등수)** — 4명 매치, 아무도 결승선을 넘지 않고 각자 출발선에서 다른 거리만큼 가서 90초를 기다린다.
   - [ ] 탈락한 2명 중 더 멀리 간 사람이 더 큰 숫자 등수(4등)를 받는지 (예상: 재현됨)
7. **벨트 밀기 동작** — 서버가 클라이언트 소유 캐릭터의 속도를 직접 바꾸는 방식이라 체감을 확인해야 한다 (`RotatingBelt.luau:254-264`).
   - [ ] 벨트 위에서 가만히 있으면 뒤로 밀리는지, 끊기거나 떨리지 않는지
   - [ ] 벨트를 거슬러 달리면 느리지만 전진할 수 있는지
8. **매치 중 퇴장** — 4명 매치 라운드 중 한 명이 Stop(접속 끊기), 다른 한 명이 방장이라면 방장도 끊기.
   - [ ] 서버 Output에 에러 없음, 남은 인원 표시가 줄어듦, 라운드가 정상 종료
   - [ ] 매치가 끝나고 대기실에 남은 멤버 중 가장 먼저 들어온 사람이 👑
9. **매치 뒤 자동 시작 (기획 확인 항목)** — 정원 4명 방에서 매치를 끝까지 돌린 뒤 대기실로 돌아왔을 때
   - [ ] 다시 "정원이 다 찼어요! 10초 뒤 자동 시작"이 뜨는지 기록 (의도인지 기획이 결정)

## 추가한 테스트
`tests/m1-retro.spec.luau` (23개, 모두 통과)
- 방 설정: 선택지 밖 숫자(0/3/5/25/-4/12.5/NaN/±inf) 거절, 알 수 없는 필드 제거, 공백·제어 문자뿐인 이름 → nil, table/boolean 이름 거절
- 방 이름: 정확히 24자 유지·25자 자르기, 자른 끝 공백 제거, NUL/탭 처리, 문자열 아닌 값
- 방 코드: 공백·전각 숫자·부호·빈 문자열·nil·table 거절, 0000/9999 경계
- 참가/방장: 방장 연쇄 이탈 시 승계 순서, 마지막 사람 퇴장, 퇴장 뒤 재참가, 이전 방장 권한 상실, 자동 시작 조건 토글, 실서버 최소 4명, 정원 직전 방 빠른 참가
- 라운드 규칙: 8/9명 경계, 결승 전 0~2명이면 어느 라운드 뒤든 결승, 결승 아닌 다음 라운드는 항상 1명 이상 탈락, 3명 → 2명 통과, 0~2명에서도 qualifyCount 에러 없음, 모든 시작 인원에서 결승 직전 2명 이상

---

## 재검증 (B1~B9 수정 후)
- 대상 커밋: `0e9d757` `269c57a` `398e804` `6824f34` (`b983c24` 이후, main)
- 결과: **통과. 남은 P0/P1/P2 없음.** B1~B9 모두 고쳐졌다. B10·B11(P3)은 이번 범위 밖이라 그대로 남았다. 새로 찾은 문제는 P3 2건과 문서 갱신 1건이다.
- 아래 판정은 diff와 코드를 읽고 순수 로직 테스트를 돌린 결과다. Studio에서 직접 돌려 보지는 않았고, 실제 동작은 갱신한 체크리스트로 사용자가 확인해야 한다.

### 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 78 passed, 0 failed (개발 수정 후 72 + QA 재검증 추가 6) |

### 버그별 결과
| 버그 | 결과 | 근거 |
|---|---|---|
| B1 [P1] 통과자 낙하 | **고쳐짐** (Studio 확인 필요) | 라운드가 끝나면 맵 정리 **전에** 통과자를 `CharacterUtil.toLobby`로 옮긴다 (`RoundService.luau:278-284`, 정리는 `runRound`의 `cleanup.run`, `:291-303`). 결승 우승자도 qualified라 같이 옮겨지고, Victory 동안 로비에 있다. 탈락자는 고정(Anchored)된 상태라 떨어지지 않고 3초 뒤 `toLobby` (`EliminationService.luau`) |
| B2 [P2] 결승선 점프 | **고쳐짐** (Studio 확인 필요) | 판정이 `Touched`에서 Heartbeat의 로컬 Z 비교로 바뀌어 높이와 상관없다 (`RotatingBelt.luau:240-243, 255-261`). 결승선을 끝에서 4스터드 앞으로 당겼고(`:30, :204`), 높이 12의 `EndWall`이 끝을 막는다 (`:190-199`) |
| B3 [P2] 탈락 등수 역전 | **고쳐짐** | `Rules.settleLeftover`가 탈락자를 못 간 사람부터 돌려주고, 목표 도달 종료도 진행도 순으로 정렬한다 (`Rules.luau`, `RoundService.luau:187-200`). 테스트: `m1-fixes`의 B3 6개, QA가 추가한 `settleLeftover: 무작위 입력 500개 …`, `… 더 멀리 간 탈락자가 절대 더 나쁜 등수를 받지 않아요`, `eliminationPlace: 한 판 전체에서 탈락 등수는 2..시작 인원을 한 번씩 써요` |
| B4 [P2] 젓가락 잡힘 복구 | **고쳐짐** (Studio 확인 필요) | 잡을 때마다 `releaseOnce`를 `ctx.cleanup`에도 등록해서, 스레드가 취소돼도 정리 단계에서 풀린다 (`RotatingBeltChopstick.luau:164-175`). 그와 별개로 `CharacterUtil.resetMovement`가 WalkSpeed·JumpPower·PlatformStand를 모두 되돌리고, 다음 라운드 배치와 로비 이동에서 쓰인다 |
| B5 [P2] 유령 방 | **고쳐짐** | 필터 yield 뒤 `player.Parent == nil`이면 방을 만들지 않는다 (`RoomService.luau:289-291`). yield하는 요청 처리기는 CreateRoom 하나뿐이라 다른 경로는 해당 없음 |
| B6 [P3] 퇴장자 결과 방송 | **고쳐짐** | `memberLeftHandler`를 방 매핑을 지우기 **전에** pcall로 동기 호출한다 (`RoomService.luau:244-252`). 떠나는 중인 플레이어에게는 `target.Parent`를 확인한 뒤 보낸다 (`EliminationService.luau`). 방만 나간 사람은 바로 로비로 옮긴다 (`MatchService.luau:189-192`) |
| B7 [P3] 소개 중 이탈 | **고쳐짐** | 루프 시작과 소개 직후에 `Rules.roundToPlay`로 다시 확인하고, 바뀌면 `continue`해서 결승 소개부터 한다 (`MatchService.luau:89, 109-111`). `continue` 뒤에는 결승 번호로 고정돼서 무한 반복이 없다. 테스트: `m1-fixes`의 B7 4개, QA가 추가한 `무작위 소개 중 이탈 2000판 …` (MatchService 루프를 흉내 냄) |
| B8 [P3] 결승 판정 | **고쳐짐** | `isFinal = args.roundIndex == args.roundCount` (`RoundService.luau:115`). Race 맵으로 도는 결승에서도 1등이 `Won`을 받는다. Survival 맵이 결승으로 대신 쓰여도 목표가 1명이라 1명 남으면 끝나서 문제없다 |
| B9 [P3] 에러 시 정리 | **고쳐짐** | 모델을 Workspace에 넣기 전에 cleanup에 등록한다 (`RoundService.luau:93, 103`). `runRound`가 `playRound`를 pcall로 감싸서 성공이든 실패든 `activeRemovers`를 지우고 정리한 뒤 에러를 다시 던진다 (`:291-303`). MatchService의 crash 처리가 `sendHome`을 부른다 (`MatchService.luau:177`). 남은 틈은 N2 |
| B10 [P3] 태그 미사용 | 안 됨 (이번 범위 밖) | 그대로다. 기획/개발이 규칙을 정해야 한다 |
| B11 [P3] 클라이언트 위치 신뢰 | 안 됨 (이번 범위 밖, M4) | 결승 판정을 위치 비교로 바꿨지만 여전히 클라이언트가 소유한 캐릭터 위치를 쓴다 |

### 회귀 · 새로 찾은 문제
#### [P3] N1 라운드 시작 순간 캐릭터가 리스폰 중이면 로비에서 바로 낙하 탈락할 수 있다
- 재현: 통과자가 결과·소개 단계(로비 대기) 동안 리셋(Esc → Reset)해서, 다음 라운드 시작 시점에 리스폰 중이 되게 한다 (`RespawnTime = 1`).
- 기대: 새 캐릭터가 생기면 스폰으로 옮겨진 뒤 레이스를 시작한다.
- 실제: `placeAt`은 캐릭터를 0.1초 간격으로 기다리는데(`RoundService.luau:47-61`), 그 사이 Heartbeat가 로비(Y≈3)에 막 생긴 새 캐릭터를 보면 `origin.Y - 40`(=260)보다 낮아서 바로 `ctx.eliminate`한다 (`RotatingBelt.luau:262`). 원래 있던 경로지만, B1 수정으로 통과자가 라운드 사이에 로비에 머물게 되면서 리셋·낙사로 이 상황이 생길 수 있게 됐다.
- 제안: 배치가 끝난 플레이어만 낙하·결승 판정에 넣는다 (예: ctx에 "placed" 집합, 또는 `placeAt`이 끝날 때까지 판정 유예).

#### [P3] N2 `placeAt` 스레드가 정리되지 않는다
- `task.spawn(placeAt, …)` (`RoundService.luau:109`)은 cleanup에 들어가지 않는다. 캐릭터를 기다리는 동안(최대 5초) 라운드가 에러로 끝나거나 아주 빨리 끝나면, 늦게 생긴 캐릭터가 이미 지워진 아레나의 스폰 위치(공중)로 옮겨져 떨어진다. 드문 경우다. cleanup에 스레드를 등록하면 된다.

#### [문서] N3 2명으로 시작하면 이제 R1 없이 바로 결승
- B7 수정으로 루프가 처음부터 `roundToPlay`를 적용한다. 그래서 2명으로 시작(Studio 전용)하면 `roundToPlay(1, 3, 2) = 3`이 되어 바로 결승을 한다 (테스트 `2명으로 시작(Studio)하면 R1 없이 바로 결승을 해요`). GDD 4.1("결승 전 2명 이하 → 바로 결승")과 맞는 동작이다.
- 그런데 `docs/DEV-SETUP.md` 3-5절 "두 명" 체크리스트(124-131줄: "라운드 1 / 3", "둘 다 결승선을 넘어야", "2라운드를 건너뛰고 라운드 3 / 3")는 예전 동작 기준이다. **docs-writer가 고쳐야 한다.** 1라운드 동작을 보려면 3명 이상이 필요하다.
- 같은 절 114줄의 "결승 1등 안내가 ✅ 1번째로 통과"도 B8 수정 후에는 "🏆 우승했어요!"로 바뀐다.

#### 확인했지만 문제 아님
- `leaveRoom`에서 핸들러를 동기로 부르게 바꿨지만 핸들러 경로(MatchService → RoundService 리무버 → EliminationService)에 yield가 없어서 방 상태가 중간에 꼬이지 않는다. 나중에 핸들러에 yield를 넣으면 이 가정이 깨지니 주의.
- 방만 나간 사람(LeaveRoom)은 즉시 `toLobby`되고, 3초 뒤 탈락 연출의 `toLobby`가 한 번 더 불린다. 둘 다 로비 스폰이라 해롭지 않다.
- `releaseOnce`는 젓가락 사이클마다 cleanup에 하나씩 쌓인다 (90초에 station당 10개 남짓). 무시해도 된다.
- 시간 종료된 결승에서는 가장 멀리 간 1명이 `finalizeQualified` → `Won`을 받는다 (GDD 5.2 ⑥ "시간이 끝나면 가장 멀리 간 플레이어가 우승"과 일치).
- 서버 검증: 새 리모트나 인자는 없다. 기존 검증은 그대로다.

### 재검증 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 (변경 없음, 유령 방 경로 막힘)
- [x] 통과·탈락·순위 판정이 서버에만 있다 (결승 판정은 서버 Heartbeat 위치 비교)
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 (`finishProgress`, `releaseOnce`는 start/run 안의 지역 상태)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다. 예외는 `placeAt` 스레드(N2, P3)

### 사용자 Studio 확인 체크리스트 (수정 후 기준)
위의 최초 체크리스트를 이것으로 대신한다. `rojo serve` → Studio 연결 → Test 탭 → Clients and Servers.

1. **방 시스템 회귀** — `docs/DEV-SETUP.md` 3-4 체크리스트를 한 번 돈다.
2. **M1 완료 기준 (AC19), 4명** — 정원 4명 공개 방에 전원 참가 → 자동 시작.
   - [ ] "매치 시작!" → "라운드 1 / 3" + "회전 벨트" 소개 → 맵으로 이동, "통과 0/2 · 남은 인원 4"
   - [ ] 2명이 결승선을 넘는 순간 라운드가 끝나고, 나머지 2명은 "🥢 탈락했어요… (3등/4등)". **결승선에 더 가까웠던 사람이 3등**이다 (B3)
   - [ ] 서버 Output에 빨간 에러 없음
3. **B1: 통과자가 살아 있는지** — 위 2번에서 통과한 플레이어 화면.
   - [ ] 라운드가 끝나면 **죽지 않고** 로비 스폰으로 순간이동하고, 결과 배너 동안 로비에 서 있다
   - [ ] 다음 라운드(결승) 시작 때 새 맵 스폰으로 옮겨진다
   - [ ] 결승 1등이 "🏆 우승했어요!"(B8)를 받고, Victory 배너 동안 로비에 살아 있다
4. **B2: 결승선 점프** — 결승선(끝 벽 4스터드 앞의 노란 줄) 바로 앞에서 점프해 넘는다.
   - [ ] 점프로 넘어도 "✅ n번째로 통과"가 뜬다
   - [ ] 끝 벽에 막혀 코스 밖으로 떨어지지 않는다. 벽을 점프로 넘을 수 없다
   - [ ] 걸어서 넘어도 정상 통과
5. **B4: 젓가락 잡힘 복구** — 3명 매치(목표 2명). A·B가 결승선을 넘는 순간 C가 젓가락에 잡혀 있게 한다.
   - [ ] 잡히면 3초간 못 움직이고 **점프도 막히는지** 기록 (막히지 않으면 StarterPlayer `CharacterUseJumpPower`가 false라는 뜻이고, 별도 이슈로 개발에 넘긴다)
   - [ ] C가 탈락해 3초 뒤 로비로 돌아간 뒤 **걷기·점프가 정상**이다
6. **B3: 시간 종료 등수** — 4명 매치, 아무도 결승선을 넘지 않고 각자 다른 거리만큼 가서 90초를 기다린다.
   - [ ] 가장 멀리 간 2명이 통과하고, 탈락한 2명 중 더 멀리 간 사람이 3등, 덜 간 사람이 4등이다
7. **B6·B7: 매치 중 퇴장**
   - [ ] 4명 매치 라운드 중 한 명이 **나가기**를 할 수는 없으니(매치 중 UI 없음) Stop으로 접속을 끊는다 → 서버 Output에 에러 없음, 남은 인원 표시가 줄어든다
   - [ ] **5명**으로 시작한다 (R1 목표 3명 → 3명이 R2로 간다). R2 소개("라운드 2 / 3")가 뜨는 3초 사이에 한 명이 접속을 끊으면 R2를 하지 않고 "라운드 3 / 3"(결승) 소개가 이어서 뜬다
   - [ ] 방장이 매치 중 접속을 끊어도 매치가 이어지고, 끝난 뒤 대기실에서 다음 사람이 👑
8. **2명 테스트 (N3, 동작 변경 확인)** — 2명으로 시작.
   - [ ] "라운드 1 / 3" 없이 바로 "라운드 3 / 3"(결승) 소개가 뜬다 (GDD 4.1대로 정상). DEV-SETUP 3-5절과 다르다는 것만 확인
9. **N1 재현 (선택)** — 5명 매치 R1을 통과한 사람이 결과 배너 동안 Esc → Reset을 하고, 리스폰 직후 다음 라운드가 시작되게 타이밍을 맞춘다.
   - [ ] 다음 라운드 시작 즉시 "🥢 탈락"이 뜨는지 기록 (뜨면 N1 재현)
10. **벨트 밀기 체감** — 벨트 위에서 가만히 있으면 뒤로 밀리는지, 끊기거나 떨리지 않는지.
11. **매치 뒤 자동 시작 (기획 확인 항목)** — 정원 4명 방에서 매치가 끝난 뒤 대기실에서 자동 시작 카운트다운이 다시 뜨는지 기록.

### 재검증에서 추가한 테스트
`tests/m1-recheck.spec.luau` (6개, 모두 통과)
- `settleLeftover` 무작위 입력 500개: 개수, 빠짐·중복 없음, 통과자/탈락자 정렬, 통과자가 탈락자보다 앞섬 (동률과 음수·초과 빈 자리 포함)
- `settleLeftover + eliminationPlace` 300개: 더 멀리 간 탈락자가 더 나쁜 등수를 받는 경우 없음
- 한 판 전체(4~24명)의 탈락 등수가 2..n을 한 번씩만 쓰고 1등은 우승자 몫
- 이탈 없는 한 판에서 `roundToPlay`를 넣어도 GDD 예시 라운드와 같음 (24/8/4명)
- 2명으로 시작하면 바로 결승
- 소개 중 무작위 이탈 2000판 (MatchService 루프 흉내): 라운드 수 이하, 결승은 마지막에 한 번, 결승 아닌 라운드는 이탈 반영 후 3명 이상에서만
