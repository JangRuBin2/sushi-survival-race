# QA — m4-08 밥알 코인 보상 · 승수 · 우승 칭호

- 스펙: `docs/specs/m4-08-rewards-titles.md`
- 검증 커밋: `b2c690c` (브랜치 `m4-08-rewards`, `origin/main` f33086b 기반 — `git merge origin/main`은 "Already up to date")
- QA 브랜치: `m4-08-qa`
- 결과: **통과** (P0/P1 없음, P2 1건·P3 3건) → `qa-passed`

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 543 passed / 0 failed (개발 533 + QA 10) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `reward-logic.spec` "AC1: 8 players 3 rounds…" 3개. QA 보강: `reward-logic-qa.spec` "24 players 4 rounds, winner 160 and final losers 60" (Rules.qualifyCount로 통과 인원을 만든 시나리오) |
| AC2 | 통과 | `reward-logic.spec` "AC2…", QA "minimum 4 players skip to final", "final qualify paid exactly once per racer even when skipping to final" (시작 4~24명 전부) |
| AC3 | 통과 | `reward-logic.spec` "AC3…" 2개, QA "Eliminated never pays (any round)", "non-final round start gives nothing" |
| AC4 | 통과 | `reward-logic.spec` "AC4…", QA "dayNumber boundary is exactly UTC midnight", "second match on the same UTC day…" |
| AC5 | 통과 | 위 자동 검증 4개 |
| AC6 | 사용자 확인 필요 | 순수 로직 합계 210은 `reward-logic.spec` "AC6: forced 4-round solo win totals 210"로 확인. 토스트·정산 화면은 Studio |
| AC7 | 사용자 확인 필요 | 코드상 `lastDailyBonusDay` 판정·기록이 `DataService.update` 안 (`src/server/RewardService.luau:124-131`) |
| AC8 | 사용자 확인 필요 | 배지 위치·겹침 |
| AC9 | 사용자 확인 필요 | 이름표 칭호. 로비 단상은 m4-06 미머지라 해당 없음 |
| AC10 | 사용자 확인 필요 | 코드상 지급 즉시 프로필 반영, 나간 뒤 `GetPlayerByUserId == nil`이면 지급 생략 (`RewardService.luau:75-79`). 단 방만 나간 경우 B1 참고 |
| AC11 | 보류 | m4-07 머지 뒤 |

## 버그
### [P2] B1 매치 중 방만 나가고 서버에 남은 사람이 매치 끝에 "오늘 첫 판" +50과 matchesPlayed +1을 받는다
- 재현: 3명 이상 방에서 매치 시작 → A가 1라운드 중 "방 나가기"(게임은 계속) → 나머지가 판을 끝냄.
- 기대: 스펙 범위 1("중간에 나간 사람: … 하루 첫 판 보너스는 없음"), 범위 2("매치가 끝날 때 남아 있는 참가자 matchesPlayed += 1"), 결정 기록("하루 첫 판 보너스는 끝까지 남은 사람만")대로 A는 받지 않는다.
- 실제: `onMatchEnd`가 `info.participants`(매치를 시작한 전원, `MatchService.luau:150-153`) 중 **서버에 있는** 사람에게 모두 준다. 방만 나간 A는 서버에 있으므로 +50 토스트와 matchesPlayed +1을 받는다. A가 그새 다른 방에서 판을 하고 있으면 그 판의 토스트·정산 합계에도 섞인다(B3).
- 영향: 하루 보너스는 `lastDailyBonusDay`로 하루 한 번이라 코인을 더 벌 수는 없다. 규칙 불일치 + matchesPlayed 부풀림(방에 들어갔다 바로 나가기를 반복하면 판 수만 늘어남).
- 참고: 스펙 범위 1의 문장 "`participants`에 있고 아직 서버에 있는 플레이어"는 코드와 맞지만, 같은 줄의 "중간에 나간 사람"·결정 기록과 충돌한다. 기획 의도는 "방에 끝까지 남은 사람"으로 읽힌다.
- 고칠 방향(제안): `onMatchEnd` 시점은 아직 `RoomService.endMatch` 전이라 `RoomService.getPlayers(roomId)`가 끝까지 남은 멤버(관전 중인 탈락자 포함)다. 이것과 `participants`의 교집합에만 주거나, `MatchEndInfo`에 남은 사람 목록을 추가(공용 아님, m4-01 파일).
- 위치: `src/server/RewardService.luau:118-133`

### [P3] B2 `onResult` 주석과 동작이 다름 (매치 끝 뒤 늦게 온 결과)
- 주석은 "빈 상태로 계산 (Won만 지급 대상)"이지만, 새 tracker는 결승이 아니라고 보므로 늦게 온 `Passed`는 +10을 준다. 지금 흐름에서는 `fireMatchEnd` 뒤에 `Passed`가 나올 길이 없어 실제 영향은 없음. 주석을 고치거나 tracker가 없으면 `Won`만 처리.
- 위치: `src/server/RewardService.luau:112-116`

### [P3] B3 클라이언트 정산 합계에 다른 매치의 지급이 섞일 수 있음
- B1의 결과. A가 방 1을 나가 방 2에서 판을 하는 중에 방 1이 끝나면 "+50 오늘 첫 판"이 방 2의 `matchGrants`에 더해진다. B1을 고치면 사라진다.
- 위치: `src/client/ui/CoinController.luau:58-70`

### [P3] B4 (확인 필요) 우승 순간 토스트가 우승 연출 큰 글씨와 겹칠 수 있음
- "+100 🍚 우승!"·"+50 🍚 오늘 첫 판" 토스트는 `CoinGui`(DisplayOrder 5)에, 우승 큰 글씨는 `VictoryCutscene`(DisplayOrder 50, 화면 세로 14~30%, 가로 90%)에 뜬다. 작은 창(세로 720 이하)·휴대폰에서 토스트 2~3개가 쌓이면 큰 글씨 아래에 가려질 수 있다. Studio 체크리스트 3에서 확인.
- 위치: `src/client/ui/CoinScreen.luau:80-87`, `src/client/fx/VictoryCutsceneScreen.luau:30-31`

## 집중 점검 결과
- **코인 지급은 서버만**: 클라이언트→서버 리모트 없음. `RewardGranted`는 `FireClient`만 쓰고 `OnServerEvent` 연결이 저장소 어디에도 없다. 지급 근거(통과·우승·출발·매치 끝)는 전부 서버 `MatchEvents` 훅. 클라이언트는 `RewardGranted`를 표시만 하고 `amount`/`total` 타입을 확인한다.
- **중복 지급**:
  - 하루 첫 판: 판정과 기록이 같은 `DataService.update` 콜백 안이라(동기) 동시에 끝난 두 방에서도 한 번만. QA 테스트 "second match on the same UTC day…".
  - 결승 진출: `fireRoundStart`는 `RoundActive` 직후 한 번(`MatchService.luau:253`), 소개 중 취소된 결승은 `continue`로 다시 소개부터라 출발 전에 불리지 않음. 시작 4~24명 전부 결승 레이서 수만큼 정확히 한 번(QA 테스트).
  - 결과 이벤트 재전송: `MatchEvents.fireResult`는 `EliminationService.broadcast`당 한 번. `Won`은 `decideWinner`의 `needsWon`으로 매치당 한 번. 결과가 두 번 오면 두 번 주는 구조이므로 이 보장은 MatchService/EliminationService에 의존한다.
  - 방 이탈·재참가: 지급은 userId 기준이고 tracker는 roomId 기준이라 다른 방의 지급과 섞이지 않는다(QA "trackers of two rooms are independent"). 다만 B1.
- **리셋·퇴장자**: 리셋은 `Eliminated`라 0. 퇴장 후 이후 지급 없음, 이미 받은 것은 유지 — 스펙대로. 방만 나간 경우의 하루 보너스는 B1.
- **DataService 공개 API만 사용**: `get`/`waitForProfile`/`update`/`onLoaded`만. `DataService.luau` 미수정 → m4-07과 충돌 없음.
- **스펙 지정 외 파일 수정**: 없음. 바뀐 `src/`는 스펙 목록의 6개 파일뿐(+ 스펙·개발 기록 문서). 공용 파일 미수정.
- **CoinSummaryGui 별도 ScreenGui**: 타당. `CoinGui`는 `ScreenInsets = TopbarSafeInsets`라 위쪽 바 줄 영역 기준으로 배치되어 화면 아래 가운데에 둘 수 없다. 정산 줄은 우승 연출(50) 위에 보여야 하므로 DisplayOrder 60도 맞다. 두 Gui 모두 `UiScaleController.attach`. 스펙 결정 기록에 남겨 둠.
- **CharacterFxController 칭호 줄**: 칭호 라벨은 같은 `SushiNameTag` BillboardGui 안이라 탈락 연출로 숨김(`tag.Enabled = not hidden`)·내 이름표 안 보임 동작을 그대로 따른다. 속성 변경은 매 프레임 `updateTitle`로 따라감. `SizeOffset` 방향(이름 줄 자리 유지)은 Studio 확인 필요(체크리스트 4).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙에는 클라이언트→서버 리모트가 없음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 코인·승수·칭호도 서버
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음. 방별 상태는 `trackers[roomId]`, 매치 끝에 지움
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 서비스 수명 연결뿐. `CharacterAdded` 연결은 Player가 사라지면 같이 정리됨. 토스트 라벨은 1.8초 뒤 Destroy

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }` (커밋 전 `nil`로 되돌리기). `rojo serve --port 34878` 후 Studio 연결.

1. **AC6 한 판 보상** — Play(혼자) → 방 만들기 → 시작.
   - 왼쪽 위 배지 "🍚 0 (저장 안 됨)"이 보이는지.
   - 1·2·3라운드 통과마다 배지 아래 "+10 🍚 라운드 통과"가 1.5초 떴다 사라지는지.
   - 결승 출발(카운트다운 끝) 때 "+30 🍚 결승 진출".
   - 우승 순간 "+100 🍚 우승!", 이어서 "+50 🍚 오늘 첫 판".
   - 우승 큰 글씨 6초 뒤, 순위표 아래(화면 아래 가운데)에 "이번 판 +210 🍚 (총 210)"이 4초 동안 보이고 순위표와 겹치지 않는지.
   - 출력 창에 `[RewardService]` 경고·에러가 없는지.
2. **AC7** — 같은 Play 세션에서 한 판 더 → "오늘 첫 판" 토스트가 없고 정산이 "+160 🍚 (총 370)"인지.
3. **AC8 배치** — 로비, 매치 중, 탈락 후 관전(2명 테스트에서) 각각에서 배지가 보이고 오른쪽 위 음소거 버튼·HUD·로비 패널과 겹치지 않는지. Studio 창 폭 800 / 1280 / 1920, 기기 에뮬레이터(휴대폰 가로)로 반복. 우승 순간 토스트가 우승 큰 글씨에 가려지는지도 확인(B4).
4. **AC9 칭호** — Test → Clients and Servers 2명, `forceMapPlan`은 `nil`로 두고 최소 인원 디버그로 시작해 한 명이 우승. 다음 판(또는 로비)에서 다른 클라이언트 창으로 우승자 머리 위를 보면 이름 위에 작은 금색 "탈출 초밥". 이름 줄 높이가 칭호 없는 사람과 같은 자리인지(SizeOffset 방향), 칭호가 이름 아래로 가거나 몸에 파묻히지 않는지. 우승자 본인 화면에는 자기 이름표가 안 보이는지.
5. **이름표 회귀(m3)** — 위 2명 판에서 한 명이 탈락할 때 탈락 연출 동안 그 사람의 이름표·칭호가 함께 사라지는지.
6. **AC10** — 2명 판에서 1라운드를 통과(+10)한 뒤 "방 나가기" → 배지 코인이 그대로인지, 출력 창에 에러가 없는지. (B1 확인: 남은 사람이 판을 끝내면 나간 사람에게 "+50 오늘 첫 판"이 뜨는지 — 지금 코드로는 뜬다.)
7. **AC11** — m4-07 머지 뒤: 저장 켠 상태에서 이긴 뒤 나갔다 다시 접속 → 코인·승수·칭호 유지, "(저장 안 됨)" 없음.

## 추가한 테스트
- `tests/reward-logic-qa.spec.luau` (10개)
  - 24명 4라운드 Rules 시나리오: 우승 160, 결승 탈락 60, 1라운드 탈락 0
  - 최소 4명 → 결승 건너뛰기 합계
  - 시작 4~24명 전부에서 결승 진출 지급이 결승 레이서 수만큼 정확히 한 번
  - 결승 아닌 라운드 출발은 0, `Eliminated`는 어느 라운드든 0
  - 두 방 tracker 독립
  - 같은 UTC 날 두 번째 판은 하루 보너스 없음, 다음 날은 있음
  - `dayNumber` UTC 자정 경계(한국 오전 9시)
  - 지급 값이 `Config.Rewards`(GDD 9.4)와 일치, 모든 이유에 토스트 글씨

## 인계 메모
### 2026-10-08 · qa (최신)
- **브랜치**: `m4-08-qa` (`origin/m4-08-rewards` b2c690c + QA 커밋), push 완료.
- **끝난 것**: 코드 리뷰, 자동 검증 4개 통과(543/0), QA 테스트 10개 추가, 리포트, 스펙 `qa-passed`.
- **남은 것**: B1(P2)은 개발이 다음 손볼 때 고칠 것 — 기획이 "끝까지 남은 사람 = 방에 남은 사람"을 확인해 주면 좋음. B2·B3 P3. Studio 체크리스트 1~6 사용자 확인, 7(AC11)은 m4-07 머지 뒤.
- **다음에 할 첫 단계**: 사용자가 위 체크리스트 1~6 실행. 이상이 없으면 docs-writer가 문서 반영(`done`).
- **막힌 점**: 없음.
