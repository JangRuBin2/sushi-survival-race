status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-10 — 코드 보상: 코드 입력 창·서버 검증·남용 방지

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.3 아래 "SNS 코드 보상(코인 100~300)은 M5 제안", §9.4(밥알 코인, 코인은 서버만 지급), §11.4(판정·지급은 서버), §11.5(저장)
- 레퍼런스: [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) 8.3절(코드 관행), 8.5절(어린 이용층), 7.1(1판 평균 약 30코인)
- 담당 개발 worktree: `m5-codes` (Rojo 포트 34878)
- 공용 파일 수정 담당: 없음 (리모트 `RedeemCode`, `Config.Codes`, 프로필 `redeemedCodes`, `RewardReason "Code"`, `CodeRedeemed` cue, 껍데기 등록은 m5-03)
- 의존: **m5-03 머지 후 시작**. 이벤트 재화를 주는 코드는 `Seasons`(m5-03)만 쓰고 m5-07 파일은 안 건드려요.
- **이 스펙이 고치는 파일**: 새 `src/server/CodeConfig.luau`(서버 전용 코드 목록), 새 `src/shared/CodeLogic.luau`(순수), `src/server/CodeService.luau`(껍데기 채우기), 새 `src/client/ui/CodeScreen.luau`, `src/client/ui/CodeController.luau`(껍데기 채우기), 새 `tests/code-logic.spec.luau`

## 목표
게임 설명·업데이트 소식에 올라온 코드(예: `SUSHI2026`)를 로비의 **"🎟 코드"** 창에 넣으면 밥알 코인 100~300(이벤트 코드는 이벤트 재화도)을 **계정당 한 번** 받는다. 기간이 끝난 코드는 안 되고, 마구 넣어 보는 것도 막는다.

## 규칙 (기본값, 사용자 수정 가능)
### 코드 목록 (`src/server/CodeConfig.luau` — **서버 전용**, ReplicatedStorage에 안 둠)
```lua
-- 코드는 대문자·숫자만 (입력은 대소문자 무시). 시각은 UTC unix 초, nil이면 제한 없음.
return {
    Codes = {
        { code = "SUSHI2026", coins = 200, startsAt = nil, expiresAt = 1798761600 }, -- 2027-01-01 00:00 UTC
        { code = "SPOOKYSUSHI", coins = 100, tokens = 10, eventId = "halloween-2026",
          startsAt = 1792108800, expiresAt = 1793923200 }, -- 할로윈 기간
    },
}
```
- 각 코드: `coins`(0~300 정수, GDD 9.3 범위), `tokens?`+`eventId?`(이벤트 재화, 1~30, 그 이벤트가 **진행 중일 때만** 지급 — 코드 기간을 이벤트 기간과 같게 두는 것을 권장), `startsAt?`, `expiresAt?`.
- 실제로 쓸 코드·보상·기간은 사용자가 정해요(아래 사용자 작업). 위 두 개는 예시 기본값.
- 저장소가 공개라면 코드가 미리 보일 수 있어요 → 공개 저장소면 출시 직전에 넣거나 `CodeConfig.luau`를 `.gitignore` + 예시 파일로(결정 기록 D4 — 지금은 그대로 커밋).

### 입력 정리 (`CodeLogic.normalize(raw)`)
- 앞뒤 공백 제거 → 대문자 → 결과가 `^[A-Z0-9]+$`이고 길이 3~`Config.Codes.MaxLength`(20)이면 그 문자열, 아니면 nil.

### 서버 검증 (`RedeemCode(code)`, CodeService) — 순서
1. 요청 간격 `Config.Codes.RequestCooldown`(2초) — 어기면 "잠시 뒤에 다시 해 주세요"(실패로 세지 않음).
2. **잠금**: 최근 `FailureWindow`(600초) 안 실패가 `MaxFailures`(8)번 이상이면 "잠시 뒤에 다시 해 주세요" (서버 메모리, 플레이어별. 나가면 지움).
3. `normalize` 실패 → "없는 코드예요" (**실패 +1**).
4. 목록에 없음 → "없는 코드예요" (**실패 +1**).
5. 시작 전 → "아직 쓸 수 없는 코드예요" / 만료 → "기간이 끝난 코드예요" (실패로 세지 않음 — 진짜 코드라서).
6. 이미 받음(`profile.redeemedCodes[code]`) → "이미 받은 코드예요".
7. 프로필 없음 → "프로필을 불러오는 중이에요", 저장 불가(`DataService.canPersist` false, Studio 메모리 모드는 허용) → "저장이 안 되는 상태라 지금은 쓸 수 없어요".
8. 지급: 한 번의 `DataService.update`에서 `redeemedCodes[code] = os.time()`, 코인 +coins, (이벤트 진행 중이면) `eventTokens[eventId] += tokens`. 그 뒤 저장 요청(`DataService` 기존 자동 저장 + 가능하면 바로 저장). `RewardGranted { reason = "Code", amount = coins, total, tokens?, tokenTotal?, eventId? }`를 본인에게. 성공 반환 문구 "🍚 200 받았어요!"(재화도면 "🍚 100 + 🍬 10 받았어요!").
- 순수 함수: `CodeLogic.check(code, entry?, now, redeemed, failures) -> (ok, reason)`, `CodeLogic.rewardFor(entry, now, activeEvent?)`, `CodeLogic.message(reason)`, `CodeLogic.recordFailure(list, now, window)`, `CodeLogic.isLocked(list, now, window, max)`, `CodeLogic.validateConfig(codes)`(중복·형식·범위 — 서버 시작 때 한 번, 문제가 있으면 그 코드만 빼고 warn).
- 로그: 성공 `[Code] 이름(UserId) redeemed SUSHI2026 +200`, 잠금 걸릴 때 `[Code] 이름(UserId) locked after 8 failures`(코드 문자열은 실패 로그에 안 남김).
- 클라이언트가 보낸 값은 문자열이 아니면 거절(실패 +1). 코드 목록은 클라이언트로 보내지 않아요.

### "🎟 코드" 창 (`CodeScreen`/`CodeController`, 자기 ScreenGui `CodeGui`, `UiScaleController.attach`)
- 열기 버튼 "🎟 코드": "🎁 상점" 아래(오프셋 12, 110, 크기 110 × 44). **로비·방 대기실에서만** 보임.
- 창: 제목 "코드 넣기", 텍스트 칸(자리 표시 "코드를 넣어 주세요", 최대 20자, 붙여 넣기 가능), "받기" 버튼, 결과 한 줄(성공 초록 / 실패 빨강), 작은 안내 "코드는 게임 설명과 업데이트 소식에서 찾을 수 있어요". 보내는 동안 버튼 비활성. 성공하면 효과음 `CodeRedeemed` + 코인 토스트(기존 RewardGranted 흐름).
- 텍스트 칸은 Roblox 기본 텍스트 입력(휴대폰 키보드·콘솔 화면 키보드) 그대로.

## 범위
- 포함: 위 전부.
- 제외: 코드로 스킨·연출 주기(지금은 코인·이벤트 재화만 — 필요하면 `CodeConfig`에 `skin` 칸을 후속으로), 채팅으로 코드 넣기(Tower of Hell 방식), 그룹 가입·좋아요 조건 코드(로블록스 보상 정책 주의 — REFERENCE 8.5), 운영 중 코드 추가(DataStore·MemoryStore로 퍼블리시 없이 — 후속), 관리자 코드 만들기.

## 수용 기준
### 순수 로직 (lune 테스트, `tests/code-logic.spec.luau`)
- [ ] AC1: `normalize`: `"  sushi2026 "` → `"SUSHI2026"`, `"ab"`·`"SUSHI 2026"`·`"코드"`·21자·숫자 아닌 값 → nil.
- [ ] AC2: `check` 순서대로 Reason: 없는 코드 `Unknown`, 시작 전 `NotStarted`, 만료(`now == expiresAt`) `Expired`, `now == expiresAt − 1`은 통과, 이미 받음 `AlreadyRedeemed`.
- [ ] AC3: 실패 기록: 600초 안 8번이면 `isLocked == true`, 601초 지난 실패는 세지 않음. `Unknown`·형식 오류만 실패로 기록되고 `Expired`·`NotStarted`·`AlreadyRedeemed`는 기록되지 않음(`check`가 돌려주는 `countsAsFailure`).
- [ ] AC4: `rewardFor`: 이벤트 코드가 이벤트 진행 중이면 coins + tokens(eventId), 이벤트 밖이면 coins만.
- [ ] AC5: `validateConfig`: 코드 중복(대소문자 무시), 소문자·공백 코드, coins 301 이상·음수·소수, tokens인데 eventId 없음, 모르는 eventId, `startsAt ≥ expiresAt`를 각각 잡는다. 기본 `CodeConfig`의 두 코드는 통과.
- [ ] AC6: `message`가 Reason마다 위 한국어 문구를 돌려준다.
- [ ] AC7: 검증 5단계 통과.

### Studio 확인 (사용자 확인 필요)
- [ ] AC8: 로비에 "🎟 코드" 버튼("🎁 상점" 아래), 창에 `sushi2026`(소문자·앞뒤 공백)을 넣으면 "🍚 200 받았어요!" + 코인 토스트 "+200 🍚 코드 보상" + 코인 배지 증가.
- [ ] AC9: 같은 코드를 다시 넣으면 "이미 받은 코드예요", 없는 코드는 "없는 코드예요". 틀린 코드를 빠르게 8번 넣으면(2초 간격) "잠시 뒤에 다시 해 주세요"가 10분 동안 계속.
- [ ] AC10: `Config.DEBUG.eventNow = 1792108800`(할로윈)이면 `SPOOKYSUSHI`가 "🍚 100 + 🍬 10 받았어요!", `eventNow = 1793923200`이면 "기간이 끝난 코드예요". **확인 뒤 nil**.
- [ ] AC11: 저장 켠 Studio(사용자 작업 C1 뒤, 선택)에서 받은 뒤 다시 접속해도 "이미 받은 코드예요".
- [ ] AC12: 매치 중에는 버튼이 안 보인다. 휴대폰 에뮬레이터에서 텍스트 칸을 누르면 키보드가 뜨고 창이 다른 UI와 안 겹친다.
- [ ] AC13: 서버 Output에 성공·잠금 로그 한 줄씩, 클라이언트 쪽(ReplicatedStorage)에 코드 목록이 없다(Explorer에서 `CodeConfig`가 ServerScriptService 아래에만).

## 공용 파일 변경
- 없음

## 사용자 작업
- **쓸 코드 정하기**: 코드 문자열·코인(100~300)·기간 → `src/server/CodeConfig.luau` (USER-TODO A1에 추가). 예: 출시 기념 `SUSHI2026` 200, 할로윈 `SPOOKYSUSHI` 100 + 🍬 10.
- 코드 알리는 곳: 게임 설명·업데이트 로그(모든 나이에 보임), (선택) 그룹 공지·Discord(13세 이상).
- `CodeRedeemed` 소리 id(USER-TODO A2).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 보상 크기 · 코인 100~300(1판 평균 약 30 → 3~10판 분량, 300이면 일반 스킨 1개), 이벤트 코드는 재화 10(80의 1/8). 근거: Arsenal 코드 1,200~2,500 Bucks(재화 몇 판 분량)·Epic Minigames 겉모습 코드, GDD 9.3 범위 — REFERENCE 8.3. **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D2 남용 방지 · 계정당 1번(프로필에 기록, 저장 안 되는 프로필이면 거절 — 다시 받는 것 방지), 2초 간격, 10분에 틀린 코드 8번이면 잠시 막기(무차별 대입 방지), 코드 목록은 서버 전용 모듈(클라이언트가 못 읽음 — m5-02 AdminConfig와 같은 이유). 진짜 코드의 만료·시작 전·이미 받음은 실패로 안 셈(아이가 억울하지 않게) · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D3 대소문자 · 무시(어린 이용층 — Arsenal·Tower of Hell은 구분해서 자주 헷갈림). 공백은 앞뒤만 지우고 가운데 공백은 오류 · planner
- 2026-10-08 · D4 코드를 저장소에 · 지금은 `CodeConfig.luau`에 커밋(간단). 저장소가 공개면 코드가 미리 새므로 사용자에게 확인. 운영 중 퍼블리시 없이 코드를 바꾸는 방식(DataStore)은 후속 · **사용자 확인 필요(기본값으로 진행)** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
