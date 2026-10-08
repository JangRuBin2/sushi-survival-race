status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-08 — 밥알 코인 보상 · 승수 · 우승 칭호

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §8(우승 횟수 칭호 1승 "탈출 초밥", 10승 "전설의 참치", 100승 "바다의 왕"), §9.4(라운드 통과 +10, 결승 진출 +30, 우승 +100, 하루 첫 판 +50), §10(로비 코인 표시, 결과 화면 보상 정산)
- 담당 개발 worktree: `m4-rewards` (Rojo 포트 34878)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작** (`MatchEvents`, `DataService` API, `RewardGranted`, `ProfileStore`, `Attributes.Title`). 진짜 저장(m4-07)과 병렬 가능 — 같은 API만 씀.
- **이 스펙이 고치는 파일**: `src/server/RewardService.luau`, `src/client/ui/CoinController.luau`, `src/client/fx/CharacterFxController.luau`(이름표에 칭호 한 줄만), 새 파일 `src/shared/RewardLogic.luau`, `src/client/ui/CoinScreen.luau`, `tests/reward-logic.spec.luau`

## 목표
판을 할수록 밥알 코인이 쌓이고(스킨 해금용, m4-13), 이기면 승수와 칭호가 생겨 머리 위 이름표와 로비 단상에 보인다. 코인을 받는 순간 "+10 🍚"가 떠서 보상이 바로 느껴진다.

## 범위
- 포함:
  1. **지급 규칙** (`RewardLogic`, 순수, 값은 `Config.Rewards`):
     - **라운드 통과 +10**: 결승이 아닌 라운드에서 `Passed`를 받을 때마다 (결승 진출 2명 보장으로 구제된 통과 포함).
     - **결승 진출 +30**: 결승 라운드(`roundIndex == roundCount`)가 출발할 때(`MatchEvents.onRoundStart`) 그 라운드 레이서 전원. 결승으로 바로 건너뛴 경우도 포함.
     - **우승 +100**: `Won`을 받을 때 (부전승 포함).
     - **하루 첫 판 +50**: 매치 승부가 정해질 때(`onMatchEnd` — m4-01에서 Victory 방송 직후에 불림) `participants`에 있고 아직 서버에 있는 플레이어 중 `lastDailyBonusDay ~= 오늘(UTC)`인 사람. 받으면 `lastDailyBonusDay = 오늘`.
     - 중간에 나간 사람: 이미 받은 코인은 그대로(지급 즉시 프로필에 반영), 하루 첫 판 보너스는 없음.
     - Studio `forceMapPlan` 판도 똑같이 준다(디버그용).
  2. **승수·판 수**: `Won`이면 `wins += 1`, 매치가 끝날 때 남아 있는 참가자 `matchesPlayed += 1`.
  3. **지급 방법** (`RewardService`): `DataService.update`로 즉시 반영 → 본인에게 `RewardGranted({ reason, amount, total })`. 프로필이 아직 없으면(로드 중) `waitForProfile`로 최대 10초 기다렸다가 지급, 그래도 없으면 버림(경고 로그).
  4. **칭호**: 캐릭터가 생길 때와 승수가 바뀔 때 서버가 캐릭터 Model에 `Title` 속성(= `ProfileSchema.titleFor(wins)`, 없으면 속성 제거)을 단다. `CharacterFxController`의 머리 위 이름표에 이름 위 작은 금색 글씨로 칭호를 보여 준다(속성 변경을 따라감). 내 이름표는 지금처럼 안 보임.
  5. **코인 UI** (`CoinController` + `CoinScreen`, 자기 ScreenGui `CoinGui`, `ResetOnSpawn = false`, `ScreenInsets = TopbarSafeInsets`의 **왼쪽**, 음소거 버튼(오른쪽)과 반대편):
     - "🍚 {coins}" 배지. 로비·매치·관전 모두 보임. `ProfileStore.changed`로 갱신.
     - `RewardGranted`가 오면 배지 아래에 "+10 🍚 라운드 통과" 같은 토스트가 1.5초 떠올랐다 사라진다(여러 개면 줄 세움). 이유 글씨: RoundPass "라운드 통과", FinalQualify "결승 진출", Win "우승!", DailyFirstMatch "오늘 첫 판".
     - **매치 정산**: `MatchPhase = Victory`가 오면 순위표 시간(우승 연출 6초 뒤 4초) 동안 화면 아래 가운데에 "이번 판 +{합계} 🍚 (총 {coins})" 한 줄. 합계는 이 매치 동안 받은 `RewardGranted`를 클라이언트가 더한 값. 순위표(VictoryCutsceneScreen)와 겹치지 않게 화면 아래 15% 안.
     - `persistent = false`이면 배지 옆에 작게 "(저장 안 됨)" — Studio에서 헷갈리지 않게.
     - `CoinGui`를 만들면 `UiScaleController.attach(gui)`를 부른다 (m4-01 껍데기, m4-09가 채우면 휴대폰에서 크기가 맞춰짐).
  6. **순수 로직** `RewardLogic`: `forPass(isFinalRound) -> amount?`, `forRoundStart(roundIndex, roundCount) -> amount?`, `forWin()`, `dailyBonus(lastDay?, today) -> amount?`, `matchTotal(grants)`, 그리고 한 판 시나리오를 넣으면 사람별 총 코인을 돌려주는 `simulate(events)`(테스트용).
- 제외:
  - 코인 사용처(스킨 해금, m4-13), VIP 1.5배(M5, 게임 패스)
  - 우승 단상(m4-06), 저장(m4-07)
  - 칭호 고르기·숨기기

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/reward-logic.spec.luau`)
- [ ] AC1: 8명 3라운드 시나리오(R1 통과 5명, R2 통과 3명, 결승 우승 1명)에서 우승자 = 10 + 10 + 30 + 100 = 150 (하루 첫 판이면 +50 = 200), R1에서 탈락한 사람 = 0 (하루 첫 판이면 50).
- [ ] AC2: 4명이라 R2를 건너뛰고 바로 결승이면 R1 통과 2명이 각각 10 + 30을 받는다.
- [ ] AC3: 결승 라운드의 `Passed`(있을 수 없지만)나 `Eliminated`에는 0, 결승 전 라운드의 구제 통과는 10.
- [ ] AC4: `dailyBonus(nil, d) = 50`, `dailyBonus(d, d) = nil`, `dailyBonus(d - 1, d) = 50`.
- [ ] AC5: 검증 명령 4개 통과.

### Studio 확인
- [ ] AC6: 혼자 `forceMapPlan` 4라운드 판을 이기면 라운드 통과마다 "+10 🍚 라운드 통과", 결승 출발 때 "+30 🍚 결승 진출", 우승 때 "+100 🍚 우승!", 끝날 때 "+50 🍚 오늘 첫 판"이 뜨고, 순위표 아래에 "이번 판 +210 🍚 (총 …)"이 나온다 (중간 통과 3번 30 + 결승 30 + 우승 100 + 오늘 첫 판 50).
- [ ] AC7: 같은 Studio 세션에서 한 판 더 하면 "오늘 첫 판"이 다시 나오지 않는다.
- [ ] AC8: 왼쪽 위 코인 배지가 로비·매치·관전 모두 보이고 음소거 버튼·HUD·로비 패널과 겹치지 않는다 (PC 창 폭 800~1920, 휴대폰 에뮬레이터).
- [ ] AC9: 2명(Clients and Servers): 1승한 사람의 머리 위 이름표에 다른 클라이언트에서 "탈출 초밥"이 보이고, 로비 단상(m4-06이 있으면)에도 같은 칭호가 보인다.
- [ ] AC10: 매치 중 방을 나가도 이미 받은 코인이 남고, 에러가 없다.
- [ ] AC11: (m4-07이 머지된 뒤, 저장 켬) 다시 접속해도 코인·승수·칭호가 남는다.

## 공용 파일 변경
- 없음

## 결정 기록
- 2026-10-08 · 지급 시점 · 그때그때 바로(라운드 통과 순간) 지급 + 매치 끝 합계 표시. 나가도 받은 건 유지, 하루 첫 판 보너스는 끝까지 남은 사람만. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · "결승 진출"은 결승 출발 순간의 레이서 전원 · 결승으로 건너뛴 경우 포함 · planner
- 2026-10-08 · "하루"는 UTC 기준 · 서버 시간대 차이 없이 단순하게 (한국 오전 9시에 바뀜). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 코인 배지 위치 · 위쪽 바 줄 왼쪽(음소거 버튼 반대편) · planner
- 2026-10-08 · 매치 정산 한 줄은 위쪽 바 칸(TopbarSafeInsets) 밖이라 두 번째 ScreenGui `CoinSummaryGui`(DisplayOrder 60, 우승 연출 위)에 둠. 배지·토스트는 스펙대로 `CoinGui`. 둘 다 `UiScaleController.attach` · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 · developer (브랜치 `m4-08-rewards`)
- **바뀐 파일**
  - 새 `src/shared/RewardLogic.luau` — forPass/forRoundStart/forWin/dailyBonus/dayNumber/matchTotal, 방 하나의 라운드 추적(`newTracker`/`onRoundStart`/`onResult` → Grant 목록), `toastText`/`summaryText`, 테스트용 `simulate(events)`.
  - `src/server/RewardService.luau` — MatchEvents 4훅 구독. 결승 출발 +30, 결승 아닌 Passed +10, Won +100(+wins, 칭호 갱신), 매치 끝 남은 참가자 matchesPlayed +1과 하루 첫 판 +50(`os.time() // 86400`, update 안에서 검사·기록). `DataService.get` → 없으면 `waitForProfile(10초)` → 없으면 경고 후 버림. 지급 후 `RewardGranted({reason, amount, total})`. 칭호는 CharacterAdded·onLoaded·우승 때 캐릭터에 `Attributes.Title`(0승이면 제거). 클라이언트에서 받는 리모트 없음.
  - 새 `src/client/ui/CoinScreen.luau`, `src/client/ui/CoinController.luau` — 왼쪽 위 "🍚 N" 배지(+ "(저장 안 됨)"), 배지 아래 토스트 1.5초, Victory 6초 뒤 4초 동안 화면 아래 가운데 "이번 판 +N 🍚 (총 M)". 합계는 Starting부터 받은 RewardGranted 합.
  - `src/client/fx/CharacterFxController.luau` — 이름표에 칭호 줄(이름 위, 금색 13px). BillboardGui를 40px로 키우고 SizeOffset으로 올려 이름 자리는 그대로.
  - 새 `tests/reward-logic.spec.luau` (14개).
- **Studio 확인**: `Config.DEBUG.forceMapPlan`에 4개 맵(예: `{"rotating-belt","hot-plate","soy-swamp","skewer-showdown"}`)을 넣고 혼자 Play → 라운드 통과 토스트 3번, 결승 출발 "+30 🍚 결승 진출", 우승 "+100 🍚 우승!", 끝 "+50 🍚 오늘 첫 판", 순위표 아래 "이번 판 +210 🍚 (총 210)" (AC6). 한 판 더 하면 오늘 첫 판 없음(AC7). 배지 위치는 창 폭 800~1920·휴대폰 에뮬레이터(AC8). 2명 Clients and Servers로 1승 뒤 다른 창에서 "탈출 초밥"(AC9). 매치 중 방 나가기(AC10). **커밋 전 forceMapPlan은 nil로**.
- **남은 이슈**: AC11은 m4-07 머지 뒤. 이름표 칭호 줄의 SizeOffset 방향(이름 자리 유지)은 Studio에서 눈으로 확인 필요. 매치 정산 줄은 순위표 패널 아래 여백(약 88px)에 들어가게 아래에서 20px·높이 36px로 둠.
