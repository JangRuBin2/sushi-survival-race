# QA — m5-11 관리자 명령 확장 (테스트 서버 전용)

- 스펙: `docs/specs/m5-11-admin-commands.md`
- 검증 커밋: `e605551` (브랜치 `m5-11-admin2`, origin/main `7714541` 병합 위)
- 결과: **통과** (P0/P1 없음, P3 3건)
- 메인 세션 결정 반영: 비관리자 문구는 m5-02 그대로 "권한이 없어요"(AC13 본문 "관리자만 쓸 수 있어요" 대신), `start`는 방장 검사 없음(Studio 전용).

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — **1302 passed, 0 failed** (개발 1286 + QA 16) |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 commandTier | 통과 | `admin-logic` "m5-11 AC1" |
| AC2 canRun 9칸 + resetprofile persist 거절 | 통과 | `admin-logic` "m5-11 AC2"(사용자 결정 반영: 실서버 켜는 설정 없음, `LiveTestCommands` 없음). QA: 실서버는 `persistDataInStudio = true`여도 Info만 (`m5-11-qa` "live admin: economy/judging commands never touch…") |
| AC3 parse | 통과 | `admin-logic` AC3 3개 + QA "parse edge cases from a hostile client"(빈 칸 있는 목록, 중첩 표, 1000칸, 대소문자·공백, `1e300`, `-0`, 대상 칸 없음) |
| AC4 applyCoins 0 하한 | 통과 | `admin-logic` "m5-11 AC4" |
| AC5 m5-02 테스트 | 통과 | `admin-logic`·`m5-02-qa` 전부 통과 (소스 금지어 검사 포함) |
| AC6 검증 5단계 | 통과 | 위 표 |
| AC7 패널 탭·info | 사용자 확인 필요 | 서버 문구는 `admin-logic` "infoLine", QA 전체 경로 로그 테스트 |
| AC8 start | 사용자 확인 필요 | 코드: `RoomService.forceStart` → 기존 `beginMatch` (`src/server/RoomService.luau:571-587`), 대기·카운트다운 아님만 |
| AC9 plan | 사용자 확인 필요 | 코드: `nextPlans` 한 번 쓰고 지움, `DEBUG.forceMapPlan`보다 우선 (`src/server/MatchService.luau:213-225, 252`). 로비 역할 거절 QA 테스트 |
| AC10 coins·tokens | 사용자 확인 필요 | 가짜 서버로 본인 프로필만 바뀜 확인(QA "Studio admin: … affect only the caller") |
| AC11 fx 미리보기 | 사용자 확인 필요 (m5-09 뒤) | 속성만 바뀌고 `equippedFx`·`ownedFx` 그대로 (QA 실서버 fx 테스트, `admin-logic` AC11) |
| AC12 resetprofile | 사용자 확인 필요 | 저장 켠 Studio 거절·잠금 중 거절 QA 테스트 |
| AC13 비관리자 거절 | 사용자 확인 필요 | 자동: 클라이언트가 단 `IsAdmin`/`AdminPreview` 속성 무시, 7개 명령+쓰레기 값 전부 "권한이 없어요", warn 1번, `AdminCommands` 모듈조차 안 불림 (QA 첫 테스트) |
| AC14 실서버 Info만 | 사용자 확인 필요 (퍼블리시 뒤 선택) | 자동: 실서버 관리자 Test·StudioOnly 5개 "Studio에서만 쓸 수 있는 명령이에요", 프로필·방·플랜 변화 없음 |

자동으로 확인할 수 있는 AC1~AC6 6/6 통과, AC7~AC14 8개는 Studio/실서버 사용자 확인 필요(코드·가짜 서버 테스트로는 이상 없음).

## 버그
### [P3] B1 저장을 켠 Studio(`persistDataInStudio = true`)에서 `coins`·`tokens`가 운영 프로필을 바꿈
- 재현: `Config.DEBUG.persistDataInStudio = true`(+ API 접근 허용) → Play Solo → "🛠 명령" → 코인 +1000.
- 기대(논의): 사용자 결정 "실서버 테스트 명령 없음"의 취지와 m4-14 QA R4 선례(`fakeRobuxInStudio`는 persist와 같이 켜면 꺼짐 — 운영 저장소에 가짜 기록 금지)대로라면 경제 명령도 거절.
- 실제: 스펙 표 그대로 Test 등급은 Studio에서 허용 → 관리자 본인의 **실제 저장된** 코인·재화가 바뀌고 `saveNow`로 저장됨. `resetprofile`만 persist에서 거절.
- 위치: `src/shared/AdminLogic.luau` `canRun` (Test + persistInStudio 통과), `src/server/AdminCommands.luau:120-150`
- 판단: 스펙대로라 반려 사유 아님. 본인 계정만이고 개발자가 일부러 켜야 함. planner 결정 필요 — 고치려면 `canRun`에서 `coins`·`tokens`도 persist면 `PersistOn`(start·plan은 판정이라 그대로 둬도 됨).

### [P3] B2 스펙 본문이 사용자 결정 전 내용 그대로
- `LiveTestCommands`·4인자 `canRun`·"테스트 명령이 꺼져 있어요"·AC13 "관리자만 쓸 수 있어요"·AC14 문구가 본문·수용 기준에 남아 있음. 결정 기록에는 대체됐다고 적혀 있지만 본문을 읽는 사람이 헷갈림.
- 위치: `docs/specs/m5-11-admin-commands.md` 규칙 표, AC13, AC14, "사용자 작업"
- 처리: planner/docs-writer가 본문 정리 (실서버 Test 문구 = "Studio에서만 쓸 수 있는 명령이에요", 비관리자 = "권한이 없어요", USER-TODO에 `LiveTestCommands` 항목 넣지 않기).

### [P3] B3 `plan`을 건 방이 매치 없이 닫히면 `nextPlans` 항목이 남음
- 개발 메모 N2와 같음. 방 id는 증가만 해서 다른 방에 잘못 쓰이지 않음, Studio 전용·작은 메모리. 기록만.
- 위치: `src/server/MatchService.luau:215`

## 서버 판정 · 보안 체크
- [x] 관리자 판단은 서버 표 `admins[UserId]`만 — 클라이언트 속성(`IsAdmin`·`AdminPreview`) 무시 (QA 테스트), 관리자 목록은 서버 전용 `AdminConfig`, 클라이언트 코드에 `AdminConfig` 언급 없음.
- [x] 검증 순서: 관리자 표 → 요청 간격(미리보기와 같은 간격 공유) → 모르는 명령 → `parse` → `canRun` → 실행 (`src/server/AdminService.luau:206-239`). 리모트 핸들러는 `pcall`로 감싸 실패 시 "다시 해 주세요".
- [x] 실서버: Test·StudioOnly는 `RunService:IsStudio()`가 아니면 무조건 거절, 켜는 설정 없음. `persistDataInStudio` 값과 무관.
- [x] 인자: 타입·정수·범위·NaN/inf·길이(맵 id 64자)·목록 모양·FxCatalog 칸 검사. 맵 id는 `Maps.allInfos()`로만 해석.
- [x] 본인 전용: `Parsed`에 대상 칸 없음, `AdminCommands`는 `player`만 씀(`GetPlayers`는 info 인원 세기 1곳), 다른 플레이어 프로필·속성 안 바뀜 (QA 두 명 테스트).
- [x] 로그: 모든 경로가 `[Admin] 이름(UserId) <command> <args> -> ok|<reason>` (인자 검사 실패는 args 자리 `?`, 모르는 명령은 args 생략).
- [x] m5-02 불변: `AdminService` 소스에 `DataService`·`ShopLogic`·`ReceiptLogic`·`PurchaseLog`·`RewardService` 없음, `AdminCommands`는 `runCommand` 안에서만 한 번 lazy require, 미리보기 경로(`onPreview`)는 `runCommand`를 안 부름. lazy require는 첫 명령 때(모든 서비스 init 이후)라 순환 require 위험 없음.
- [x] 경제 쓰기는 `DataService.update` 안에서만, 결제·구매 기록·보상 모듈 안 부름.
- [x] `resetprofile`: `canRun`(persist 거절) + `DataService.canPersist` 이중 확인 + 잠금 중 거절. 세션 잠금 정보는 프로필 밖이라 지워지지 않음.
- 맵 상태·Cleanup: 해당 없음 (맵 코드 변경 없음).

## 사용자 Studio 확인 체크리스트
`Config.DEBUG`는 커밋 값 그대로(`minPlayersToStart = 1`, `forceMapPlan = nil`)에서 시작.
1. **AC7** Play Solo → 왼쪽 "🛠" → 위쪽 탭 "👕 미리보기"/"🛠 명령"이 보이는지. "🛠 명령" → `ℹ info` → 결과 줄 "Single · 서버 … · 방 0 · 플레이어 1 · 내 방 없음 · 코인 0".
2. **AC8** 방 만들기(정원 아무거나) → "▶ 바로 시작" → 카운트다운 → 매치 시작. 방이 없을 때 누르면 "방에 들어가 있지 않아요".
3. **AC9** 맵 버튼 `dessert-fridge` → `tempura-pot` → `ikura-bombs` 순서로 누르기 → "다음 판에 쓰기" → 결과 줄(결승 자리가 Final이 아니면 "주의: …") → 바로 시작 → 그 순서로 도는지. 매치가 끝나고 다시 시작하면 랜덤으로 돌아오는지. "비우기"가 쌓은 목록을 비우는지.
4. **AC10** 코인 +1000 → 위쪽 코인 배지가 바로 오르는지 → 탈의실에서 코인 스킨 해금 가능한지. −1000을 여러 번 → 0 아래로 안 내려가는지. 이벤트 없을 때 재화 +80 → "진행 중인 이벤트가 없어요". `Config.DEBUG.eventNow = 1792108800 + 3600`(커밋 금지) → 재화 +80 → info에 이벤트 재화가 보이는지.
5. **AC11** 연출 "고양이 손님" → 결과 줄 "연출 미리보기: 고양이 손님 (저장 안 됨)". 매치 중(달리는 중)에 누르면 "라운드 중에는 바꿀 수 없어요". 실제 고양이 탈락 연출은 m5-09 들어온 뒤 확인.
6. **AC12** "프로필 초기화" 한 번 → 확인 문구, 3초 안에 한 번 더 → 코인 0·계란초밥. `persistDataInStudio = true`로 바꾸고 다시 → "저장을 켠 Studio에서는 쓸 수 없어요" (확인 뒤 false로).
7. **AC13** `AdminConfig.StudioAllAdmins = false` → Test → Clients and Servers 2명. 관리자 아닌 창(음수 UserId)에 "🛠"이 없는지. 그 창 Command Bar(Current: Client): `print(game.ReplicatedStorage.Remotes.AdminCommand:InvokeServer("coins", 1000))` → `false 권한이 없어요`, 서버 Output에 warn 1번, 코인 그대로. **확인 뒤 true로 되돌리기**.
8. 서버 Output에서 모든 명령이 `[Admin] 이름(UserId) <명령> <값> -> ok|<이유>`로 찍히는지.
9. **AC14 (선택, 퍼블리시 뒤)** 실서버 관리자 계정: `info`·연출 미리보기는 되고 코인·바로 시작·맵 순서는 "Studio에서만 쓸 수 있는 명령이에요". "프로필 초기화" 버튼은 아예 없음.

## 추가한 테스트
- `tests/m5-11-qa.spec.luau` (16개): 진짜 `AdminService` + `ShopService` + `AdminCommands`를 가짜 Roblox로 묶어 리모트부터 끝까지.
  - 비관리자(실서버, 클라이언트 속성 위조) 7개 명령+쓰레기 값 거절, 모듈 로드 0, warn 1
  - Studio `StudioAllAdmins = false` 목록 밖 거절 / `LiveEnabled = false` 소유자 거절
  - 실서버 관리자: Test·StudioOnly 거절(persist 켬/끔 모두), 프로필·방·플랜 변화 없음, info·fx만 동작·프로필 무기록
  - 실서버 잘못된 인자 미실행
  - Studio 두 명: 명령은 부른 사람에게만
  - 저장 켠 Studio `resetprofile` 거절, 잠금 중 거절
  - 요청 간격(같은 시각 거절, 미리보기와 공유)
  - 인자 극단값, 모르는 맵 id·개수, 로비 역할 `plan` 거절
  - 로그 형식 4경로, 실행기 오류 시 일반 문구
  - 소스: lazy require 1곳·미리보기 경로 분리·경제 모듈 금지어, `AdminCommands` 본인 전용·서버 위치, 클라이언트에 `AdminConfig` 없음

## 인계 메모
- 브랜치: QA worktree에서 `origin/main`(`7714541`) + `origin/m5-11-admin2`(`e605551`) 병합 → `m5-11-admin2`에 push.
- 끝난 것: 검증 5단계 전부 통과(1302 passed), AC1~AC6 자동 통과, AC7~AC14 사용자 확인 목록, QA 테스트 16개, 버그 P3 3건, 스펙 status `qa-passed`.
- 남은 것: 메인 세션이 `m5-11-admin2`를 main에 병합 → 검증 다시. 사용자 Studio 확인(위 1~9). B1은 planner 결정(persist Studio에서 경제 명령 거절할지), B2는 planner/docs-writer 본문 정리.
- 다음에 할 첫 단계: `git merge origin/m5-11-admin2` → 검증 5단계 → docs-writer가 DEV-SETUP 3-10 근처에 위 체크리스트 반영.
- 막힌 점: 없음.
