status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-07 — 플레이어 데이터 저장 (DataStore) · 음소거 설정 저장

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §9.5(DataStore에 저장), §11.3(`DataService`), §13("결제했는데 스킨이 안 들어옴" — 저장 성공 확인), CHANGELOG M3 "음소거 단계는 저장되지 않아요 (M4)"
- 담당 개발 worktree: `m4-data` (Rojo 포트 34877)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작** (`DataService` 메모리 버전, `ProfileSchema`, `ProfileStore`, `SaveSettings`)
- **이 스펙이 고치는 파일**: `src/server/DataService.luau`, `src/client/Sfx.luau`(음소거 저장·복원만), 새 파일 `src/shared/ProfileLogic.luau`, `tests/profile-logic.spec.luau`

## 목표
코인·승수·보유 스킨·장착 스킨·음소거 설정이 **나갔다 들어와도 남는다**. 서버가 갑자기 꺼지거나 다른 서버(매치 플레이스)로 옮겨 가도 데이터가 사라지거나 두 서버가 서로 덮어쓰지 않는다. 저장할 수 없는 상황(Studio, DataStore 장애)에서는 게임은 그대로 되고 저장만 안 된다.

## 범위
- 포함:
  1. **저장 위치**: `DataStoreService:GetDataStore(Config.Data.StoreName)`, 키 `u_<UserId>`. 저장 값 = `{ profile = Profile, lock = { jobId: string, at: number }? }`.
  2. **로드** (`PlayerAdded`):
     - `UpdateAsync`로 읽으면서 세션 잠금을 건다. 잠금이 다른 `JobId`이고 `at`이 `Config.Data.SessionLockExpiry` 안이면 → 잠금을 건드리지 않고 `RetryDelay`초 뒤 다시(최대 `LoadRetries`번, 텔레포트 직후 이전 서버가 저장을 끝내길 기다림) → 그래도 잠겨 있으면 잠금을 가져온다(이전 서버가 죽었다고 봄, 경고 로그).
     - 읽은 값은 `ProfileLogic.migrate(raw)`로 정리: 없는 칸은 기본값, 숫자 칸이 숫자가 아니거나 음수면 0, `ownedSkins`에 `tamago` 항상 포함, `equippedSkin`이 보유하지 않은 스킨이면 `tamago`, 모르는 칸은 버리지 않고 보존(나중 버전 호환), `version`이 더 높으면(미래 데이터) **저장하지 않는 임시 프로필**로 쓴다.
     - DataStore 요청이 에러면 `MaxRetries`(Config.Teleport가 아니라 이 스펙 안 상수 3)번 재시도, 그래도 실패하면 **임시 프로필**(`ProfileSchema.new()`, `canPersist = false`, 저장 안 함 — 진짜 데이터를 빈 값으로 덮어쓰지 않기 위해). `ProfileView.persistent = false`.
  3. **저장**:
     - 바뀐 프로필(dirty)은 `AutosaveInterval`(60초)마다, `PlayerRemoving` 때(잠금 해제 포함), `game:BindToClose`에서(모든 플레이어 동시에, 최대 25초 기다림) 저장.
     - 저장도 `UpdateAsync`: 저장소의 잠금이 내 `JobId`가 아니면 **덮어쓰지 않는다**(잠금을 뺏긴 것, 경고 로그 + 이후 그 플레이어는 임시 프로필로 전환).
     - `DataService.saveNow(player): boolean` — 즉시 저장하고 성공 여부를 돌려준다 (m4-14 결제가 "저장 성공 후에만 완료"에 씀). 같은 플레이어 저장은 한 번에 하나씩(겹치면 앞 저장이 끝난 뒤 한 번 더).
     - 요청 예산: 저장 전에 `DataStoreService:GetRequestBudgetForRequestType`이 0이면 잠깐 기다린다.
  4. **Studio**: `RunService:IsStudio()`이고 `Config.DEBUG.persistDataInStudio = false`면 지금처럼 메모리만(`canPersist = false`). `true`인데 API 접근이 꺼져 있으면(에러) 경고 한 줄 + 메모리. → 사용자가 Studio에서 저장을 시험하려면 Game Settings에서 API 접근을 켜고 이 값을 true로.
  5. **API는 m4-01 그대로** (`get`, `waitForProfile`, `update`, `onLoaded`, `canPersist`) + `saveNow`. 다른 스펙은 이 API만 쓴다.
  6. **음소거 저장** (`Sfx.luau`): 음소거 버튼을 누르면 `SaveSettings({ muteLevel })`를 보낸다(마지막 누름 0.5초 뒤 한 번 — 연타해도 한 번). 접속 후 `ProfileStore`에 첫 프로필이 오면 그 `settings.muteLevel`로 음소거 단계·버튼 표시를 맞춘다(사용자가 그 전에 이미 눌렀으면 사용자 값 우선).
  7. **순수 로직** `ProfileLogic`: `migrate(raw) -> (Profile, { persistable: boolean, notes: { string } })`, `lockDecision(lock?, myJobId, now, expiry) -> "take" | "wait" | "steal"`, `canWrite(lock?, myJobId) -> boolean`, `dayNumber(unixTime) -> number`(UTC).
- 제외:
  - 코인 지급 규칙(m4-08), 구매 기록(m4-14 — 별도 저장소)
  - 데이터 초기화·관리자 도구, GDPR 삭제 요청 처리(사용자 작업, 아래)
  - ProfileService 같은 외부 라이브러리 (직접 구현, 의존성 없이)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/profile-logic.spec.luau`)
- [ ] AC1: `migrate(nil)` = 새 프로필. `migrate({ coins = "abc", wins = -3 })`는 coins 0, wins 0. `ownedSkins = {}`이면 tamago가 들어간다. 보유하지 않은 `equippedSkin = "salmon"`은 tamago로 바뀐다. 모르는 칸 `foo = 1`은 그대로 남는다.
- [ ] AC2: `version = 99`인 값은 `persistable = false`로 돌아온다.
- [ ] AC3: `lockDecision`: 잠금 없음 → take, 내 잠금 → take, 남의 잠금이 만료 전 → wait, 만료 뒤 → steal. `canWrite`: 내 잠금만 true.
- [ ] AC4: `dayNumber`가 UTC 자정 기준으로 바뀐다 (예: 1970-01-02 00:00:00 = 1).
- [ ] AC5: 검증 명령 4개 통과.

### Studio 확인 (사용자: 게임 퍼블리시 + API 접근 허용 + `persistDataInStudio = true`)
- [ ] AC6: 접속 → (m4-08 전이면 콘솔/임시 코드로) 코인을 바꾸고 → 나갔다(Stop) 다시 F5 → 값이 남아 있다. `ProfileStore.get().persistent = true`.
- [ ] AC7: 음소거를 🔇로 바꾸고 나갔다 다시 들어오면 🔇로 시작한다.
- [ ] AC8: `persistDataInStudio = false`(기본)면 저장되지 않고 `persistent = false`, Output에 에러가 없다. API 접근을 끈 채 true로 하면 경고 한 줄만 나오고 게임은 된다.
- [ ] AC9: Studio에서 Stop을 누를 때(BindToClose) 바뀐 값이 저장된다 (다음 실행에서 확인).
- [ ] AC10: (Team Test 또는 실제 서버 2개, 사용자) 같은 계정으로 서버 A에 있다가 서버 B로 옮기면 B가 A의 마지막 저장을 읽는다(코인이 줄지 않음).

## 공용 파일 변경
- 없음

## 사용자 작업
- **게임을 Roblox에 퍼블리시**하고 Studio **Game Settings → Security → Enable Studio Access to API Services** 켜기 (AC6~AC10 확인에 필요). 확인 뒤 `persistDataInStudio`는 false로 되돌려 커밋.
- 공개 전: Roblox "Right to Erasure" 요청이 오면 `u_<UserId>` 키를 지우는 절차를 운영 메모로 남김 (m4-12 체크리스트).

## 결정 기록
- 2026-10-08 · 세션 잠금 직접 구현(UpdateAsync + JobId + 30분 만료), 외부 라이브러리 없음 · 텔레포트(m4-11)·다중 서버에서 덮어쓰기 방지. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 로드 실패 시 임시 프로필(저장 안 함) · 진짜 데이터를 빈 값으로 덮어쓰지 않는 것이 우선. 임시 프로필에서는 결제를 받지 않음(m4-14) · planner
- 2026-10-08 · Studio 기본은 메모리 저장(`persistDataInStudio = false`) · 테스트가 실제 데이터를 더럽히지 않게 · planner

- 2026-10-08 · (developer) `ProfileLogic`에 스펙 7번 함수 외에 `readLock`·`claim`·`commit`·`release`·`deepCopy`를 더함 · UpdateAsync 변환 함수 내용을 순수 로직으로 빼서 가짜 저장소로 두 서버 흐름(대기→해제 후 읽기, 잠금 뺏긴 서버는 못 씀)을 lune에서 확인하려고 · developer
- 2026-10-08 · (developer) `tests/lib/FakeSfxEnv.luau`(QA 테스트 도우미)를 고침 — 스펙 파일 목록 밖 · Sfx가 `script.Parent.ProfileStore`를 require하고 `FireServer`를 부르게 되어 기존 m3-01/m3-08 QA 테스트가 가짜 환경에서 깨짐. 가짜 ProfileStore(`env.pushProfile`)·`env.sent`만 더하고 기존 동작은 그대로 · developer
- 2026-10-08 · (developer) 음소거 저장은 보내는 간격을 최소 1초로 둠(마지막 누름 0.5초 뒤 + 직전 전송에서 1초) · 서버 `SettingsMinInterval` 0.5초에 네트워크 지연이 겹치면 마지막 값이 조용히 버려질 수 있어서 · developer
- 2026-10-08 · (developer) Studio에서 `persistDataInStudio = true`인데 DataStore 요청이 에러면 재시도 없이 바로 그 서버 전체를 메모리 모드로 바꿈(경고 한 줄) · AC8 "경고 한 줄만". 라이브 서버는 스펙대로 3번 재시도 후 임시 프로필 · developer
- 2026-10-08 · (developer) 30분 넘게 바뀐 게 없어도 잠금이 만료되지 않게 자동 저장 때 `SessionLockExpiry / 3`(10분)마다 잠금 시간을 갱신 · 스펙에 없던 빈틈 · developer

## 개발 메모
- 바뀐 파일: `src/server/DataService.luau`(DataStore·세션 잠금·자동 저장·BindToClose·`saveNow`), `src/shared/ProfileLogic.luau`(새), `src/client/Sfx.luau`(음소거 저장·복원), `tests/profile-logic.spec.luau`(새, 28개), `tests/lib/FakeSfxEnv.luau`(가짜 ProfileStore·FireServer).
- 동작 요약: 로드는 비동기(`PlayerAdded` → UpdateAsync). 다른 서버 잠금이면 2초 간격 5번 기다린 뒤 가져옴. 미래 버전 데이터는 임시 프로필 + 잠금 즉시 해제. 저장은 사람마다 한 번에 하나(세대 번호), 나갈 때·BindToClose는 잠금 해제. 잠금을 뺏기면 쓰지 않고 그 사람은 `persistent = false`로 바뀌어 ProfileUpdated가 다시 감.
- Studio 확인:
  - AC8(기본): Play → Output에 DataService 경고/에러 없음. 커맨드 바(클라이언트)에서 `require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get().persistent` → `false`.
  - AC6·AC9: 퍼블리시 + Game Settings → Security → Enable Studio Access to API Services, `Config.DEBUG.persistDataInStudio = true`. Play → 서버 커맨드 바에서 `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.coins = 123 end)` → Stop → 다시 Play → 클라이언트 `ProfileStore.get().coins == 123`, `persistent == true`.
  - AC7: 음소거 버튼을 🔇까지 누르고 1초 기다린 뒤 Stop → 다시 Play → 버튼이 🔇로 시작.
  - AC8 두 번째: API 접근을 끈 채 `persistDataInStudio = true` → 경고 한 줄(`DataStore unavailable in Studio, using memory only`)만, 게임은 됨.
  - AC10: Team Test/실서버 2개(사용자).
  - 확인 뒤 `persistDataInStudio = false`로 되돌림.
- 남은 이슈: 로드 중에 BindToClose가 오면 그 사람의 잠금은 해제를 기다리지 않음(다음 서버가 10초 기다린 뒤 가져감). 로드가 이제 비동기라 `DataService.get`이 접속 직후 잠깐 nil일 수 있음 — 다른 스펙은 `waitForProfile`/`onLoaded`를 써야 함(m4-01 API 설명 그대로).