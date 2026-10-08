# QA — m4-07 플레이어 데이터 저장 (DataStore) · 음소거 설정 저장

- 스펙: `docs/specs/m4-07-data-persistence.md`
- 검증 커밋: `9157728` (브랜치 `m4-07-data`, `origin/main` f33086b 병합 — 이미 최신, 충돌 없음)
- 결과: **통과** (P0/P1 없음, P2 2건·P3 5건). Studio 확인 AC6~AC10은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 567 passed / 0 failed (개발 547 + QA 20) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `profile-logic.spec` migrate 테스트들 + QA `qa: migrate treats numeric strings as invalid`, `qa: migrate drops non-true and non-string skin entries`, `qa: migrate keeps a valid owned equipped skin and mute setting`, `qa: migrate resets an out-of-range mute level` |
| AC2 | 통과 | `future version is not persistable`, QA `qa: future-version data survives load and release byte for byte`, `qa: non-numeric version is not treated as future data` |
| AC3 | 통과 | `lockDecision`, `canWrite only with my lock` + QA 경계 `qa: lock expires exactly at SessionLockExpiry`, `qa: a lock stamped in the future (clock skew) still means wait` |
| AC4 | 통과 | `dayNumber changes at UTC midnight`, QA `qa: dayNumber boundaries` (86399 → 0, 86400 → 1) |
| AC5 | 통과 | 위 자동 검증 |
| AC6 | 사용자 확인 필요 (사용자 작업 필요: 퍼블리시 + API 접근 + `persistDataInStudio = true`) | 체크리스트 2 |
| AC7 | 사용자 확인 필요 (사용자 작업 필요: 같음) | 체크리스트 3. 코드 경로는 lune 가짜 환경 테스트로 확인 (`mute:` 테스트들, QA `qa: mute restore ignores an invalid saved level`) |
| AC8 | 사용자 확인 필요 (앞부분은 사용자 작업 없음, 뒷부분은 퍼블리시된 플레이스에서 API 접근 끄기) | 체크리스트 1, 5. 코드: `DataService.luau:428-444`, `107-114`, `141-144` |
| AC9 | 사용자 확인 필요 (사용자 작업 필요) | 체크리스트 4. 코드: `onClose` `DataService.luau:412-426` |
| AC10 | 사용자 확인 필요 (사용자 작업 필요: Team Test 또는 실서버 2개) | 체크리스트 6. 순수 로직은 `second server waits, then reads the first server's last save`로 확인 |

수용 기준 10개 중 자동 확인 5개 통과, 5개 사용자 확인 필요, 실패 0개.

## 코드 리뷰 요약 (데이터 유실·복제 중점)
- **세션 잠금 경합 (서버 둘)**: 로드는 `UpdateAsync` 안에서 `claim` — 남의 잠금이면 아무것도 쓰지 않고(`nil`) 2초 간격 5번 기다린 뒤 가져온다. 저장은 `commit`이 내 잠금일 때만 쓴다. 잠금을 뺏긴 서버는 쓰지 못하고 임시 프로필로 바뀐다 (`DataService.luau:239-243`). 두 서버가 서로 덮어쓰는 경로는 찾지 못했다. QA 테스트로 "해제 뒤 다시 쓰기 금지", "가져간 서버의 저장을 옛 서버가 덮지 않음", "가져가도 저장된 프로필은 그대로"를 확인.
- **잠금 만료·10분 갱신**: 만료는 `now - at >= 1800`에서 steal (경계 테스트 추가). 자동 저장이 바뀐 게 없어도 600초마다 잠금 시간을 갱신 (`DataService.luau:405`). 갱신 간격 600 + 자동 저장 60 < 1800 확인 테스트 추가.
- **저장 실패 → 임시 프로필, 덮어쓰기 금지**: 로드 요청이 3번 재시도 뒤에도 실패하면 `ProfileSchema.new()` + `persist = false` (`DataService.luau:184-189`). 임시 프로필은 `writeOnce`/`unload`/`onClose`/`autosave`/`saveNow` 모두에서 저장하지 않는다. 저장 실패 시 `dirty`를 되돌려 다음 자동 저장에서 다시 쓴다 (`235-237`).
- **미래 버전 데이터**: `persistable = false`면 잠금만 즉시 해제하고 프로필은 쓰지 않는다. `release`는 저장된 값을 복사해 `lock`만 지우므로 미래 데이터가 한 글자도 바뀌지 않음을 테스트로 확인.
- **BindToClose 25초**: 모든 세션에 해제 저장을 동시에 걸고 `saving`이 빌 때까지 최대 25초 기다린다. 종료 중에는 재시도 사이 대기를 건너뛴다 (`146`). 단, 요청 예산 대기(최대 10초)는 종료 중에도 한다 — 25초 안이라 문제 없음.
- **나갈 때 저장 vs 60초 자동 저장**: 같은 세션의 저장은 `runSaves`가 세대 번호로 직렬화하고, 나갈 때 요청한 해제(`wantRelease`)는 진행 중인 자동 저장 다음 차례에 최신 사본으로 쓴다. 중복 쓰기는 생겨도 내용이 거꾸로 가지 않는다(매번 그 순간의 `deepCopy`).
- **요청 예산**: `GetRequestBudgetForRequestType(UpdateAsync)`가 0이면 0.5초씩 최대 10초 기다림 (`116-128`).
- **로드 중 퇴장**: 기다리는 중이면 잠금 없이 끝냄, 잠금을 건 뒤면 해제 저장 (`304-310`). 다만 같은 서버로 바로 다시 들어오면 문제 있음 → D1.
- **Studio 기본값**: `Config.DEBUG.persistDataInStudio = false` (`Config.luau:171`) → Studio에서는 `store = nil`, 모든 프로필 `persist = false`, 저장소 요청 0번. 라이브 서버(`IsStudio() == false`)는 이 값과 무관하게 저장. 실수로 실제 저장소를 쓰는 경로 없음.
- **SaveSettings 서버 검증**: 표 여부, 정수 1~3(NaN·무한대·소수 거부), 0.5초 간격 제한, `muteLevel`만 반영. 잘못된 값은 조용히 무시. QA 테스트로 11가지 잘못된 입력 확인. 로드 전에는 `update`가 false라 무시됨 → D4.
- **m4-01 API 호환**: `get`/`waitForProfile`/`update`/`onLoaded`/`canPersist` 시그니처 그대로 + `saveNow`. 동작 차이: 로드가 비동기라 접속 직후 `get`이 잠깐 nil. 현재 `src/`에서 DataService를 쓰는 곳은 없음 (main 기준). `canPersist`는 `session.persist and store ~= nil`.
- **m4-08 RewardService(`origin/m4-08-rewards`)와의 상호작용**: `DataService.get or waitForProfile(10)` → `update`만 쓰고 `saveNow`는 쓰지 않는다. 지급은 `dirty`가 되어 60초 자동 저장/퇴장/종료 때 저장. 임시 프로필이면 코인이 보이지만 저장 안 됨(`persistent = false`로 표시) — 의도대로. 접속 직후 로드가 10초를 넘으면 지급이 버려질 수 있음 → D7. `RewardLogic.dayNumber`와 `ProfileLogic.dayNumber`가 중복 구현(같은 식) — 병합 때 하나로 모으면 좋음(버그 아님).
- **스펙 밖 파일 `tests/lib/FakeSfxEnv.luau`**: Sfx가 `script.Parent.ProfileStore`를 require하고 `FireServer`를 부르게 되어 기존 m3 QA 테스트가 가짜 환경에서 깨지는 것을 막는 최소 추가(가짜 ProfileStore, `env.sent`, `script` 전역). 기존 동작 변경 없음, 기존 테스트 모두 통과. 타당하다고 판단. (QA 소유 파일이지만 사유가 스펙 결정 기록에 있음.)
- **Sfx 음소거 저장·복원**: 마지막 누름 0.5초 뒤 한 번, 전송 간격 1초 이상, 서버에 있는 값과 같으면 안 보냄. 첫 프로필만 따르고(잠금을 잃어 다시 오는 ProfileUpdated는 무시), 먼저 누른 값 우선. 잘못된 저장 값(7, 2.5, 0, 문자열)은 무시됨을 테스트로 확인.

## 버그
### [P2] D1 같은 서버로 바로 다시 들어오면 새 세션의 잠금이 풀려 그 접속 동안 진행이 저장되지 않음
- 재현 (같은 JobId 안에서 일어남, 두 경우):
  1. 플레이어가 나감 → `unload`의 해제 저장(`save(session, true)`)이 요청 예산 대기·재시도로 몇 초 걸리는 동안 같은 서버로 다시 접속 → 새 `Player`로 `load` → `claim`이 잠금 주인이 같은 JobId라 바로 `take` → 이전 세션 저장 **전** 값을 읽음 → 이전 세션의 해제 `commit`이 `canWrite`(같은 JobId) 통과 → 잠금이 `nil`이 됨 → 새 세션의 다음 저장은 `canWrite(nil)` = false → "session lock lost" 경고, `persist = false`.
  2. 로드가 다른 서버 잠금 때문에 기다리는 중(최대 10초)에 나갔다가 같은 서버로 다시 들어옴 → 옛 `load`가 잠금을 얻은 뒤 `player.Parent == nil`이라 해제 저장 → 새 `load`가 그 전에 잠금을 얻었으면 위와 같은 결과.
  - 순수 로직으로: `claim(stored, "A")`(새 세션) → `commit(stored, oldProfile, "A", now, true)`(옛 세션 해제, 성공) → `commit(stored, newProfile, "A", now, false)` → `false`.
- 기대: 같은 서버의 새 세션이 옛 세션의 저장이 끝난 뒤에 읽고, 옛 세션의 해제가 새 세션의 잠금을 풀지 않는다.
- 실제: 새 세션은 옛 저장 전 값(예: 코인 50, 저장소는 곧 100)을 보여 주고, 그 접속 동안 얻은 것은 모두 저장되지 않는다 (`persistent = false`로 바뀌므로 m4-14는 결제를 거절). 저장소의 값이 거꾸로 덮이지는 않음(복제·롤백 없음).
- 위치: `src/server/DataService.luau:285-316` (load), `:318-326` (unload), `src/shared/ProfileLogic.luau:138` (같은 JobId면 take), `:191` (commit/release가 JobId만 비교)
- 제안: 잠금에 세션 id(GUID)를 더해 `canWrite`가 세션 단위로 비교하거나, 같은 UserId의 저장(`saving`)이 끝날 때까지 `load`가 기다리게.

### [P2] D2 BindToClose가 잠금을 푼 뒤 `saveNow`가 쓰지 않고 true를 돌려줌 (m4-14 시작 전 수정 필요)
- 재현: 서버 종료 → `onClose`가 모든 세션을 `save(session, true)`로 해제(`released = true`), 세션은 `sessions`에 남음 → 종료 대기 25초 안에 `DataService.update(player, ...)` 후 `DataService.saveNow(player)` (예: m4-14 ProcessReceipt).
- 기대: 쓰지 못했으니 `false` (m4-14가 `NotProcessedYet`을 돌려 다음 접속에서 다시 처리).
- 실제: `writeOnce`가 `session.released`면 바로 `true` → `saveNow`가 `true`. 바뀐 값은 저장되지 않는다. 결제라면 로벅스는 빠지고 스킨은 사라진다.
- 위치: `src/server/DataService.luau:217-220` (writeOnce), `:373-379` (saveNow), `:412-421` (onClose는 세션을 남겨 둠)
- 지금은 `saveNow`를 부르는 곳이 없어 실제 피해 없음 → P2. m4-14가 이 API를 쓰기 전에 고쳐야 한다 (released면 false, 또는 closing 중 saveNow는 false).

### [P3] D3 Studio에서 저장 도중 DataStore가 끊기면 화면은 계속 `persistent = true`
- 재현: Studio, `persistDataInStudio = true`, 로드 성공 뒤 요청 하나가 에러 → `disableStore`로 `store = nil`.
- 기대: 이후 `ProfileView.persistent = false`.
- 실제: `canPersist`는 false가 되지만 `sendView`는 `session.persist`(true)를 보냄. Studio 전용.
- 위치: `src/server/DataService.luau:84`, `:107-114`

### [P3] D4 프로필 로드 전에 누른 음소거는 저장되지 않음
- 재현: 접속 직후 서버 로드가 끝나기 전(잠금 대기 등)에 음소거 버튼을 누름.
- 기대: 사용자 값이 우선이니 로드 뒤 저장된다.
- 실제: 서버 `onSaveSettings`의 `update`가 세션이 없어 false로 버려지고, 클라이언트는 `lastMuteSent`를 이미 그 값으로 바꿔 다시 보내지 않음. 다음 접속은 옛 값으로 시작. `restoreMute`에서 `userChangedMute`면 다시 보내면 해결.
- 위치: `src/server/DataService.luau:381-395`, `src/client/Sfx.luau` `sendMuteLevel`/`restoreMute`

### [P3] D5 로드 중에 서버가 꺼지면 잠금을 풀지 못함 (개발 메모에 이미 적힘)
- 실제: `onClose`는 `sessions`만 돌고, 아직 로드 중인 사람은 기다리지 않음 → 다음 서버가 10초 기다린 뒤 가져감. 데이터 유실 없음, 접속 지연만.
- 위치: `src/server/DataService.luau:304-310`, `:412-426`

### [P3] D6 옛 서버의 퇴장 저장이 10초를 넘기면 마지막 진행이 버려짐 (스펙 설계 그대로)
- 실제: 새 서버는 `LoadRetries × RetryDelay`(약 10초) 뒤 잠금 만료와 무관하게 가져간다. 옛 서버의 퇴장 저장이 예산 대기·재시도로 그보다 늦으면 쓰기가 거절되어 마지막 자동 저장 뒤 진행(최대 60초분, 예: 마지막 매치 코인)이 사라진다. 복제는 없음. 스펙 2번이 정한 동작이라 버그가 아니라 위험 메모. m4-11 텔레포트 때 실제 지연을 보고 `LoadRetries`를 정하면 좋음.
- 위치: `src/server/DataService.luau:172-199`, `src/shared/Config.luau:122-123`

### [P3] D7 `waitForProfile` 기본 10초가 최악의 로드 시간보다 짧음
- 실제: 로드는 잠금 대기 약 10초 + 요청 시간 + 예산 대기가 될 수 있다. m4-08 RewardService는 10초 뒤 지급을 버린다. 지급은 보통 접속 몇 분 뒤라 실제로는 드묾.
- 위치: `src/server/DataService.luau:56`, `:333-342`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — `SaveSettings`: 타입·정수 범위·NaN/무한대·요청 간격, `muteLevel` 외 칸 무시 (방 소속·방장은 해당 없음)
- [x] 코인·스킨 등 프로필 변경은 서버(`DataService.update`)에만 있다. 클라이언트는 `muteLevel`만 바꿀 수 있다
- [x] 맵 상태 — 해당 없음
- [x] 정리 — 퇴장 때 `sessions`/`dirtyView`/`lastSettingsAt` 제거. (아주 작은 것: 퇴장 처리 뒤 도착한 `SaveSettings`가 `lastSettingsAt[player]`를 다시 만들 수 있음, 무시해도 됨)

## 사용자 Studio 확인 체크리스트
1. **AC8 기본 (사용자 작업 없음)**: `Config.DEBUG.persistDataInStudio = false`(기본) 그대로 Play → Output에 `[DataService]` 경고·에러가 없다. 클라이언트 커맨드 바에서 `print(require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get().persistent)` → `false`.
2. **AC6 (사용자 작업 필요)**: 게임 퍼블리시, Game Settings → Security → Enable Studio Access to API Services 켜기, `persistDataInStudio = true`. Play → 서버 커맨드 바(Server 보기)에서 `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.coins = 123 end)` → 2초 기다림 → Stop → 다시 Play → 클라이언트에서 `ProfileStore.get().coins` = 123, `.persistent` = true.
3. **AC7 (사용자 작업 필요, 2와 같은 설정)**: 오른쪽 위 음소거 버튼을 🔇(모두 끔)까지 누르고 2초 기다림 → Stop → 다시 Play → 버튼이 🔇로 시작하고 효과음이 안 남.
4. **AC9 (사용자 작업 필요)**: 2의 `update`로 coins = 456으로 바꾸고 **바로** Stop (자동 저장 60초 전) → 다시 Play → 456. Output에 `session lock lost`나 `failed` 경고 없음.
5. **AC8 뒷부분 (사용자 작업 필요)**: API 접근을 끈 채 `persistDataInStudio = true` → Play → `DataStore unavailable in Studio, using memory only` 경고 **한 줄만**, 게임(방 만들기·매치)은 정상, `persistent = false`.
6. **AC10 (사용자 작업 필요, Team Test 또는 실서버 2개)**: 같은 계정으로 서버 A에서 코인을 바꿈(2의 방법 또는 m4-08 지급) → A에서 나가 바로 서버 B 접속 → B에서 코인이 A의 마지막 값이고 줄지 않음. B의 Output에 `taking the lock` 경고가 나오면 A 저장이 10초 넘게 걸린 것(D6) — 알려 주세요.
7. 확인이 끝나면 `persistDataInStudio = false`로 되돌리고, API 접근 설정은 그대로 둬도 됨.

## 추가한 테스트
`tests/m4-07-data-qa.spec.luau` (20개)
- 잠금: 만료 경계(1799 wait / 1800 steal), 미래 시각 잠금은 wait, 갱신 간격이 만료 안쪽, 갱신 뒤 다른 서버 대기, wait일 때 아무것도 안 씀, steal해도 저장된 프로필 그대로, 해제한 서버는 다시 못 씀, 가져간 서버의 저장을 옛 서버가 못 덮음
- 미래 버전: 로드 → 해제 뒤 저장 값이 원본과 완전히 같음, 잠금만 있는 값(첫 저장 전 크래시)은 새 프로필
- migrate: 숫자 문자열은 0, 잘못된 스킨 항목 제거, 보유 스킨 장착·음소거 유지, 범위 밖 음소거 초기화, 숫자가 아닌 version은 현재 버전 취급
- dayNumber 경계, SaveSettings 잘못된 입력 11가지 거부, `muteLevel` 외 칸 무시
- 음소거: 잘못된 저장 값 무시, 3에서 한 번 누르면 1 저장

## 인계 메모
- **브랜치**: `m4-07-qa` (`origin/m4-07-data` 9157728 기반, `origin/main` 병합 — 이미 최신), push 완료
- **끝난 것**: 자동 검증 4개, AC1~AC5 통과, 코드 리뷰(잠금·저장·종료·Studio·SaveSettings·Sfx·m4-08 상호작용), QA 테스트 20개, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인 AC6~AC10 (위 체크리스트). 개발: D1·D2(P2) 수정 권장 — D2는 m4-14 시작 전 필수. P3 D3~D7은 백로그.
- **다음에 할 첫 단계**: 사용자가 체크리스트 1~7 실행. 병합 시 m4-08과 `dayNumber` 중복 정리 검토.
- **막힌 점**: 없음.
