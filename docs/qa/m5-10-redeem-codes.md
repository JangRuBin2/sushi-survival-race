# QA — m5-10 코드 보상 (코드 입력 창·서버 검증·남용 방지)

- 스펙: `docs/specs/m5-10-redeem-codes.md`
- 검증 커밋: `a1a263b` (`origin/m5-10-codes`) + `origin/main` `3b20944` 병합(`9bb2fab`) 위에서 검증
- 결과: **통과** (P0/P1 없음, P3 4건) → 스펙 `qa-passed`

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — 1291 passed, 0 failed (code-logic 13 + m5-10-qa 31) |
| `luau-lsp analyze …` (타입 검사) | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 normalize | 통과 | `code-logic.spec` "AC1 …" 2건, `m5-10-qa` "QA remote: huge / control-char / unicode …", "lowercase + surrounding whitespace" |
| AC2 check 순서·Reason | 통과 | `code-logic.spec` AC2, `m5-10-qa` "real-code outcomes never count", "QA event: tokens only while …"(시작 포함·끝 제외) |
| AC3 실패 기록·잠금 | 통과 | `code-logic.spec` AC3, `m5-10-qa` "lockout: 7 failures do not lock, the 8th locks…", "lasts until the oldest failure leaves the 600s window…", "pure: … failNow" |
| AC4 rewardFor | 통과 | `code-logic.spec` AC4, `m5-10-qa` "event: tokens only while the event runs", "existing tokens are added to" |
| AC5 validateConfig | 통과 | `code-logic.spec` AC5(가짜 두 코드 — D4 결정대로 실제 목록 없음), `m5-10-qa` "config: invalid entries are skipped with a warn" |
| AC6 message | 통과 | `code-logic.spec` AC6, `m5-10-qa` 서비스 경유 문구 확인 전부 |
| AC7 검증 5단계 | 통과 | 위 표 |
| AC8 창·200 코인·토스트 | 사용자 확인 필요 | 서버 쪽 지급·`RewardGranted` 모양은 `m5-10-qa` "once: coins, redemption mark and tokens are written in ONE update" 로 확인 |
| AC9 이미 받음·없음·잠금 10분 | 사용자 확인 필요 | 서버 로직은 `m5-10-qa` lockout·once 테스트로 확인 |
| AC10 eventNow 할로윈 | 사용자 확인 필요 | 서버 로직은 "Studio uses DEBUG.eventNow…", "DEBUG.eventNow is ignored on a live server" |
| AC11 재접속 뒤 이미 받음 | 사용자 확인 필요 (선택) | 로직은 "rejoin on another server with the saved profile is AlreadyRedeemed" |
| AC12 매치 중 숨김·휴대폰 | 사용자 확인 필요 | 코드 읽기: `CodeController.luau:25-38` (InMatch·매치 서버면 숨기고 창 닫음) |
| AC13 로그·목록 서버 전용 | 일부 통과 + 사용자 확인 필요 | 로그 문자열·코드 미노출은 lockout 테스트, 소스 검사 "nothing outside src/server requires CodeConfig/CodeList", "CodeService prints the code only on success". Explorer 확인은 사용자 |

요약: 자동 확인 가능한 AC1~AC7 **7/7 통과**, Studio AC8~AC13 6개는 사용자 확인 필요 (서버 쪽 로직은 가짜 환경 테스트로 미리 확인).

## 보안 검토 (요청 항목)
- **리모트 인자 검증**: `RedeemCode`는 `unknown`을 받아 `CodeLogic.normalize`가 문자열이 아니거나 100바이트 넘으면 nil → "없는 코드예요" + 실패 +1 (`CodeLogic.luau:77-87`). nil·숫자·불리언·표·NaN·1MB 문자열·NUL·전각 숫자·줄바꿈 가운데 낀 값 모두 지급 없음 (테스트).
- **요청 간격**: 2초, 거절은 실패로 안 세고 `lastAt`도 갱신하지 않음(`CodeService.luau:70-74`) → 스팸해도 잠금이나 간격 연장이 안 생김. 경계 2.0초 허용.
- **잠금**: 플레이어별, 실제 `os.time()` 기준(Studio `eventNow`와 무관), 8번째 실패 순간 로그 한 줄, 잠금 중 진짜 코드도 거절. 슬라이딩 창이라 첫 실패가 600초 지나면 풀리고, 다시 한 번 틀리면 바로 재잠금.
- **한 번 지급**: `redeem`은 체크부터 `DataService.update`까지 yield가 없고(`get`·`canPersist`·`update` 모두 동기), `update` 안에서 `redeemedCodes[code]`를 다시 확인한 뒤 기록·코인·재화를 한 번에 씀(`CodeService.luau:100-114`). 같은 서버 동시 요청은 간격에 막히고, 끼어들어도 재확인이 막음(테스트 "race"). 서버 간은 세션 잠금으로 한 서버만 프로필을 쓰고, 코인과 받음 표시가 같은 프로필 기록이라 퇴장 저장이 실패해도 "코인만 남고 표시가 사라지는" 중복은 생기지 않음(둘 다 함께 유실 — m4-07 D6과 같은 한계).
- **저장 불가 프로필**: 실서버 `canPersist == false`면 거절(테스트), Studio 메모리 모드는 허용하되 `saveNow` 안 부름.
- **진짜 코드 커밋 없음**: `src/server/CodeList.luau`는 `.gitignore`·`git ls-files` 비어 있음(테스트가 `git` 으로 확인), 예시 파일 `Codes = {}`(테스트), `shared`·`client`에서 `CodeConfig`/`CodeList`를 참조하지 않음(테스트). 리모트·이벤트로 목록을 보내는 곳 없음.
- **이벤트 재화**: `Seasons.isActive(eventId, now)`가 참일 때만(시작 포함, 끝 제외 — 테스트). 실서버에서 `DEBUG.eventNow` 무시(테스트).
- **로그**: 코드 문자열은 성공 로그 한 곳에만(소스 검사 + 실행 검사). 실패·잠금·오류 warn에는 없음. 핸들러 오류는 pcall로 "다시 해 주세요"만 클라이언트에 감.

## 버그
P0/P1/P2 없음.

### [P3] R1 — 같은 서버에 다시 들어오면 실패 횟수가 0부터 (잠금 우회)
- 재현: 틀린 코드 8번 → 잠김 → 나갔다가 같은 서버(또는 다른 서버)에 다시 접속 → 다시 8번 시도 가능.
- 기대: 스펙 "나가면 지움"대로라 스펙 위반은 아님. 다만 무차별 대입 방지 목적상 재접속 한 번(수십 초)마다 8번씩 더 시도할 수 있음(시간당 수백 번 수준).
- 실제: `states[player] = nil` on PlayerRemoving (`src/server/CodeService.luau:163-165`). 테스트 "state is cleared on leave"가 현재 동작을 고정.
- 제안(후속, 기획 판단): 같은 서버 안에서는 `UserId` 키로 두고 창이 지나면 지우기. 코드가 사전 단어형(`SUSHI2026`)이면 무차별 대입보다 추측이 쉬워 실효는 작음.
- 위치: `src/server/CodeService.luau:35,163-165`

### [P3] R2 — 문서에 나온 예시 코드를 실제 코드로 쓰면 공개 유출
- 재현: 스펙·개발 메모가 Studio 확인용으로 `SUSHI2026`·`SPOOKYSUSHI`를 `CodeList.luau`에 넣으라고 안내 → 사용자가 그대로 퍼블리시.
- 기대: 실제 출시 코드는 공개 저장소 문서에 없는 문자열.
- 실제: 두 예시가 `docs/specs/m5-10-redeem-codes.md`, `tests/m5-03-foundation.spec.luau:221`에 공개돼 있음. 코드 쪽 결함은 아님.
- 제안: USER-TODO A1(docs-writer)에 "실제 코드는 문서 예시와 다른 문자열로" 한 줄. 
- 위치: 문서

### [P3] R3 — 이벤트 기간보다 긴 이벤트 코드는 기간 밖에서 재화 없이 "받음" 처리
- 재현: `tokens`·`eventId`가 있고 기간이 이벤트보다 긴 코드를 이벤트 밖에 넣음 → "🍚 50 받았어요!", 다시 넣으면 "이미 받은 코드예요"(재화 영영 못 받음). `coins = 0`이면 "🍚 0 받았어요!".
- 기대: 스펙대로(재화는 이벤트 중에만, 기간 일치 권장). 
- 제안: `validateConfig`가 코드 기간이 이벤트 기간 밖으로 나가면 warn(빼지는 않고). 
- 위치: `src/shared/CodeLogic.luau:186-243`, 테스트 "event: tokens only while the event runs"

### [P3] R4 — 서버가 매치 중 코드 사용을 막지 않음
- 버튼은 매치 중 숨지만, 서버 `RedeemCode`는 방 상태를 보지 않아 조작 클라이언트는 매치 중에도 받을 수 있음. 보상·판정에 영향 없음(코인 토스트만 뜸). 스펙에 서버 차단 요구는 없어 기록만.
- 위치: `src/server/CodeService.luau:68`

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 (타입, 길이, 요청 간격, 잠금) — 방 소속·방장 해당 없음
- [x] 지급 판단이 서버에만 있다 (클라이언트는 문구만 받음)
- [x] 맵 상태 — 해당 없음
- [x] 정리: 플레이어 상태는 PlayerRemoving에서 지움, `byCode`는 init에서 한 번 채움. UI는 자기 ScreenGui(ResetOnSpawn false)

## 사용자 Studio 확인 체크리스트
준비: `src/server/CodeList.example.luau`를 같은 폴더 `CodeList.luau`로 복사하고 Codes에 테스트 코드 두 개를 넣는다(커밋 안 됨). **실제 출시 코드는 이 문서 예시와 다른 문자열로**(R2).
```lua
{ code = "SUSHI2026", coins = 200, expiresAt = 1798761600 },
{ code = "SPOOKYSUSHI", coins = 100, tokens = 10, eventId = "halloween-2026", startsAt = 1792108800, expiresAt = 1793923200 },
```
1. (AC8) Play → 로비 왼쪽 위 "🍣 스킨" 아래(한 칸 띄고) "🎟 코드" 버튼이 있다. 누르면 "코드 넣기" 창. `  sushi2026 ` 입력 → "받기" → 초록 "🍚 200 받았어요!", 코인 토스트 "+200 🍚 코드 보상", 코인 배지 +200, 효과음(무음 id면 소리 없음). 서버 Output `[Code] 이름(UserId) redeemed SUSHI2026 +200`.
2. (AC9) 같은 코드 다시 → 빨강 "이미 받은 코드예요". `NOPE123` → "없는 코드예요". 2초 안에 다시 누르면 "잠시 뒤에 다시 해 주세요". 2초 넘게 간격 두고 틀린 코드 8번 → 8번째까지 "없는 코드예요", Output `[Code] … locked after 8 failures` 한 줄(틀린 코드 문자열은 Output에 없음). 그 뒤 진짜 코드도 "잠시 뒤에 다시 해 주세요"(10분).
3. (AC10) `Config.DEBUG.eventNow = 1792108800` → 새 세션에서 `spookysushi` → "🍚 100 + 🍬 10 받았어요!". `eventNow = 1793923200` → "기간이 끝난 코드예요". **확인 뒤 `eventNow = nil`로 되돌리기.**
4. (AC11, 선택) `persistDataInStudio = true`(API 접근 허용)로 1번 → Stop → 다시 Play → 같은 코드 "이미 받은 코드예요". 확인 뒤 false.
5. (AC12) 방 만들고 시작 → 매치 중 "🎟 코드" 버튼이 사라지고 열려 있던 창도 닫힌다. 로비로 돌아오면 다시 보인다. Device 에뮬레이터(휴대폰 가로)에서 창이 위쪽에 붙고, 텍스트 칸을 누르면 키보드가 뜨며 다른 UI와 겹치지 않는다. 21자 넘게 붙여 넣으면 20자로 잘린다. Enter로도 보내진다.
6. (AC13) Play 중 Explorer: `ServerScriptService.Server` 아래 `CodeConfig`·`CodeList`, `ReplicatedStorage.Shared`에는 `CodeLogic`만(목록 없음). 클라이언트 시점(Client 뷰)의 ReplicatedStorage에 코드 문자열이 없다.
7. `CodeList.luau`를 지우고 Play → Output `[CodeConfig] no src/server/CodeList.luau …` 경고 한 줄, 어떤 코드든 "없는 코드예요".

## 추가한 테스트
- `tests/m5-10-qa.spec.luau` (31개) — 가짜 Roblox 환경으로 `src/server/CodeService.luau`를 직접 실행:
  리모트 인자(비문자열·1MB·NUL·전각·줄바꿈), 요청 간격(스팸 50번 무실패·2초 경계·거절이 간격을 늘리지 않음), 잠금(7/8번째·로그 한 번·코드 미노출·600초 창·재잠금·플레이어별·나가면 초기화), 한 번 지급(재요청·update 직전 끼어들기·다른 서버 재접속·한 번의 update + saveNow·RewardGranted 모양·재화 누적), 저장(실서버 NotSaved·Studio 메모리·프로필 없음·나간 뒤 FireClient 없음·redeemedCodes 200개 상한), 이벤트(시작 포함·끝 제외·실서버 eventNow 무시·Studio eventNow), 설정(잘못된 항목 warn 후 제외·빈 목록·오류 시 일반 문구), 소스(CodeList 추적 안 됨·gitignore·예시 비어 있음·shared/client가 목록 참조 안 함·코드 로그는 성공만).

## 인계 메모
- **브랜치**: 작업 worktree `worktree-agent-a39f25e849751e412` → push 대상 `origin/m5-10-codes`.
- **끝난 것**: 5단계 검증 통과, QA 테스트 31개 추가, 리포트, 스펙 status `qa-passed`.
- **남은 것**: 사용자 Studio 확인(위 체크리스트 1~7), docs-writer가 USER-TODO A1에 "로컬 CodeList.luau + 실제 코드는 문서 예시와 다르게"(R2) 추가, P3 R1·R3·R4는 planner 판단(후속).
- **다음에 할 첫 단계**: main에 병합 뒤 검증 5단계 다시 → 문서 반영(docs-writer).
- **막힌 점**: 없음.
