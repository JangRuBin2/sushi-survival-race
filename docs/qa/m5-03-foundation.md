# QA — m5-03 M5 기반 (공용 파일·프로필 v2·카탈로그·껍데기)

- 스펙: `docs/specs/m5-03-foundation.md`
- 검증 커밋: `origin/main` `4192744` + `m5-03-qa` 병합 (src는 `4192744`와 같음 — QA는 `tests/`·`docs/`만 바꿈). 첫 세션은 `c4ca608`에서 시작했고, 그 뒤 main에 m5-13~m5-22가 병합된 상태에서 다시 확인함.
- 결과: **통과** (P0/P1 없음, P3 3건) → 스펙 status `qa-passed`

## 자동 검증 (QA가 직접 실행, 병합 뒤 HEAD)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 파일 포맷 후) |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **1249 passed, 0 failed** (main 1233 + QA 16) |
| `luau-lsp analyze ...` (타입 검사) | 통과 (종료 코드 0, 오류 출력 없음) |

참고: 첫 세션(`c4ca608`)에서도 5단계 모두 통과(1133 passed).

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m5-03-foundation.spec` "AC1: validate — inPool…", "AC1: 맵 15개 전부 validate 통과…" (main이 맵 15개로 늘어난 뒤에도 껍데기 3개는 표 그대로·`inPool = false`, `ikura-bombs.overtime` 함수). QA: 껍데기 3개를 가짜 환경에서 실제로 build·start·overtime |
| AC2 | 통과 | "AC2: infos()는 12개…", "AC2: 강제 플랜은 allInfos로…", "AC2: buildRoundPlan을 1,000번…"(3·4라운드 번갈아), "MatchService 강제 플랜은 Maps.allInfos()를 써요" (`MatchService.luau` 랜덤 판은 `Maps.infos()`). 스펙 숫자(6/9)는 m5-14~19 졸업으로 12/15가 됨 — 규칙(껍데기는 랜덤 판에 없음)은 그대로 |
| AC3 | 통과 | foundation "AC3" 7개 + QA "v1을 두 번 migrate", "모양이 틀린 v2 칸", "equippedFx의 모르는 칸 이름", "redeemedCodes 정확히 200개·201개", "미래 버전(3)…" |
| AC4 | 통과 | foundation "AC4: toView 새 칸…", "DataService.setViewExtra가 있고…" + QA "setViewExtra: vip가 바뀔 때만 ProfileUpdated 한 번", "로드 전에 부르면 기억…, 나간 뒤에는 무시" (가짜 DataService 실제 실행) |
| AC5 | 통과 | foundation "AC5: 31종(m5-22 10종 포함)…", "규칙 위반 표본…", "자리 표시 레이아웃", "탈의실 카드…". 스펙의 "21개"는 m5-21·m5-22가 10종을 더해 31개가 됨(그 스펙 범위) — 새 5종 order 17~21·얻는 길·시즌은 그대로 |
| AC6 | 통과 | `seasons.spec` 8개 (경계 `[startsAt, endsAt)`, 겹침, `daysLeft == 21`, `Seasons.now`) |
| AC7 | 통과 | `fx-catalog.spec` 4개 |
| AC8 | 통과 | foundation "AC8: canRequest…"(1792108799 OffSale, 1792108800 통과, 끝 시각 거절, NotRobux 3종, now 없으면 기간 안 봄), "RobuxShopService가 now…" |
| AC9 | 통과 | foundation "AC9: 새 cue 8개…"(무음, 맵 cue 4개는 장애물 목록 뒤), "AC9: 토스트 문구…" |
| AC10 | 통과 | 위 자동 검증 5단계 |
| AC11 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC12 | 사용자 확인 필요 | 아래 체크리스트 2 (코드·가짜 환경으로는 확인함: 껍데기 start/overtime) |
| AC13 | 사용자 확인 필요 (선택) | 아래 체크리스트 3 (순수 migrate는 테스트로 확인함) |

자동 확인 가능한 AC1~AC10: **10/10 통과**. Studio 확인 AC11~AC13: 3개 사용자 확인 필요.

## 버그
### [P3] B1 디저트 냉장고 껍데기: 스폰 19~24번이 바닥 밖, 13~18번은 바닥 끝 걸침 (m4-01 B1과 같은 실수)
- 재현: `Config.DEBUG.forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }`로 13명 이상 방에서 시작 (혼자·12명 이하는 문제 없음).
- 계산 (origin 기준 로컬 z, 코스는 -Z): `Floor` 길이 `LENGTH + 20 = 180`, 중심 z = `-80` → z ∈ [-170, +10]. 스폰 z = `row × 5`, row 0~3 → 0, 5, 10, **15**. `Spawn19`~`Spawn24`는 바닥 뒤 허공, `Spawn13`~`Spawn18`은 발판 절반이 바닥 밖.
- 기대: CLAUDE.md 맵 계약 "Spawns 24개 모두 판정 바닥 위".
- 실제: 배치 잠금은 앵커가 아니라 소개 중에 떨어져 리셋 탈락. 다만 `inPool = false`라 **랜덤 판에는 안 나오고** Studio 강제 플랜에서만 생김 → P3.
- 처리 제안: m5-06이 이 파일을 덮어쓰고, m5-06 AC1이 이미 "스폰은 A 구간(0 ~ −16) 안, 서로 3 이상"을 요구하므로 별도 수정 없이 m5-06에서 닫힘. m5-06 QA가 24개 전부를 확인할 것. `tests/m5-03-qa.spec.luau`는 지금 맞는 1~12번만 고정함.
- 위치: `src/shared/maps/DessertFridge.luau:33-40`(바닥), `:42-59`(스폰). `TempuraPot`·`IkuraBombs`는 24개 모두 바닥 안(QA 테스트로 확인).

### [P3] B2 `BuyWithTokens`에 서버 핸들러가 없음
- 재현: 클라이언트(익스플로잇 포함)가 `Remotes.fn("BuyWithTokens"):InvokeServer("ghost-tamago")` 호출.
- 기대: 스펙 범위 9 "핸들러가 아직 없는 동안은 껍데기 서비스가 `return false, "준비 중이에요"`".
- 실제: `OnServerInvoke`를 다는 곳이 없어 호출이 서버 대기열에 쌓이고 그 클라이언트는 응답을 못 받음(Roblox 대기열 한도가 있어 서버 위험은 작음). 정상 클라이언트는 부르는 곳이 없음(개발 메모에 명시). m5-07이 ShopService에 붙이면 닫힘.
- 위치: `src/shared/Remotes.luau`(FUNCTIONS의 `BuyWithTokens`), `src/server/ShopService.luau`(핸들러 없음).

### [P3] B3 Studio 가짜 결제에서 판매 기간 밖 시즌 로벅스 스킨 카드가 켜져 보임
- 재현: `fakeRobuxInStudio = true`, `eventNow = nil`(오늘 2026-10-13, 할로윈 10-16 시작 전) → 탈의실 "호박 초밥" 카드.
- 기대: 서버가 `OffSale`로 막는 스킨은 카드도 비활성.
- 실제: `ShopLogic.cardState`는 기간을 보지 않아 "R$ 99" 활성 → 누르면 "판매 기간이 아니에요". 실서버는 productId가 없어 "곧 열려요"라 플레이어 영향 없음. 스펙이 진짜 카드 상태를 m5-07로 넘겼으므로 m5-07에서 `Seasons.skinOnSale`을 카드에 반영하면 닫힘.
- 위치: `src/shared/ShopLogic.luau:190-217`.

### 메모 (버그 아님, 기획 정리 필요)
- `docs/specs/m5-11-admin-commands.md` 본문 19·25·47행 등이 아직 `AdminConfig.LiveTestCommands`·4인자 `canRun`을 적음. m5-03 결정 기록(사용자 결정: 실서버에 테스트 명령 없음, 설정도 없음)이 대체함 → planner가 m5-11 본문·AC를 정리해야 m5-11 개발자가 헷갈리지 않음.
- `docs/specs/m5-10-redeem-codes.md` 12·18·31행이 "새 `CodeConfig.luau`에 코드 목록 커밋"으로 남음. 지금은 `CodeConfig.luau`(로더, 커밋) + `CodeList.luau`(.gitignore) → planner 정리 필요.
- 스펙의 숫자(맵 6/9, 스킨 21)는 이후 스펙(m5-13~19, m5-21·22)이 늘림. 개발 테스트가 새 숫자로 따라감 — 규칙은 그대로라 문제 없음.

## main 변화(m5-13~m5-22) 뒤에도 기반이 그대로인지
- 맵: 15개 전부 `MapTypes.validate` 통과, 껍데기는 m5-03 원래 3개만 `inPool = false`, 졸업한 6개는 풀에 있음. 강제 플랜만 `allInfos`.
- 프로필: `ProfileSchema.VERSION = 2` 그대로, `KNOWN_FIELDS`에 v2 칸 5개, 마이그레이션 손실 없음.
- 스킨: 31종 `Skins.validate` 통과(시즌·토큰·VIP 규칙 유지), 새 5종 자리 표시 레이아웃 유지.
- 리모트·속성·Config·init 등록: foundation 계약 테스트 모두 통과.
- 코드 목록 비밀: `git log --all -- src/server/CodeList.luau` 결과 없음(한 번도 커밋 안 됨). `CodeList.example.luau` 기록에는 주석 속 `EXAMPLE2026`·`EXAMPLESPOOKY` 예시만 있음(실제 코드 아님).

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자 검증: 새 리모트 5개 중 4개는 인자를 쓰지 않고 바로 거절(QA 테스트: 잘못된 타입·빈 인자·1만 자 문자열에도 `false, "준비 중이에요"`). `AdminCommand`는 관리자 표 → 요청 간격 → `commandTier`(문자열 아니면 nil, 대소문자·`__index` 같은 키도 nil) → `canRun`(실서버 Info만) → `runCommand` 순서, pcall로 감쌈(`AdminService.luau:193-240`). `BuyWithTokens`는 B2.
- [x] 판정은 서버에만: 판매 기간은 서버 `Seasons.now(IsStudio, eventNow, os.time())`로 `canRequest`에서, 영수증 처리는 기간을 보지 않음(결정 기록대로). VIP·연출 속성은 "권한·소유 판단에 쓰지 않음" 주석(`Attributes.luau:28`).
- [x] 맵 상태는 `ctx`/`start` 지역 변수: 껍데기 3개 모두 모듈 수준 상태 없음, `origin`은 `ctx.origin`.
- [x] Cleanup: 껍데기 Heartbeat 연결과 ikura 연장전 `task.delay` 스레드가 `ctx.cleanup`에 들어감(QA 테스트), 연장전 훅은 기다리지 않고 바로 돌아옴, 라운드가 먼저 끝나면 판을 건드리지 않음. `DataService.viewExtra`는 퇴장 때 지움(QA 테스트: 나간 뒤 `setViewExtra` 무시).
- [x] 비밀: 관리자 목록·코드 목록 모두 `src/server`(ServerScriptService) — 클라이언트 복제 없음.

## 사용자 Studio 확인 체크리스트
1. **AC11 — 로비·탈의실**
   1. Rojo 연결 후 Play Solo.
   2. 로비 버튼이 전과 같은지 본다(새 버튼 없음 — "🎟 코드"·상품 버튼은 아직 없어야 정상).
   3. 탈의실을 연다. 호박 초밥·유령 계란초밥·산타 새우·트리 마키·금박 계란초밥 5개가 계란초밥 모양 + 토핑 색만 다르게(주황·흰색·빨강·초록·금색) 보이는지.
   4. 유령·트리·금박은 "곧 열려요"(비활성), 호박·산타 새우는 "곧 열려요"(상품 id 없음)인지.
   5. Output에 빨간 에러가 없는지. `[CodeConfig] no src/server/CodeList.luau ...` 경고 한 줄은 정상.
2. **AC12 — 껍데기 맵 3개 한 판**
   1. `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }`.
   2. Play Solo → 방 만들기 → 시작.
   3. 1라운드 회색 바닥(Race): 앞으로 달려 노란 결승선 통과 → 통과.
   4. 2라운드 회색 판(Survival): 60초 버티면 통과.
   5. 3라운드 회색 접시(Final): 90초에 "연장전" 배너, 그 20초 뒤 접시가 사라져 떨어지고 우승 연출. (빨리 보려면 `DEBUG.overtimeAt = 10`.)
   6. 끝나면 `forceMapPlan = nil`, `overtimeAt = nil`로 되돌린다.
   7. (선택, B1 확인) Test → Clients and Servers 13명 이상이면 디저트 냉장고에서 13~24번 자리 사람이 떨어짐 — m5-06 전까지 알려진 P3.
3. **AC13 (선택) — v1 → v2 저장**
   1. 사용자 작업 C1(API 접근 허용) 뒤 `DEBUG.persistDataInStudio = true`.
   2. M4 때 저장한 계정으로 Play → 코인·스킨이 그대로인지.
   3. 나간 뒤 다시 Play → 그대로인지(이제 v2로 저장됨). 끝나면 `persistDataInStudio = false`.
4. (선택) **판매 기간**: `DEBUG.eventNow = 1792108800`, `fakeRobuxInStudio = true` → 탈의실 호박 초밥 "R$ 99" 버튼 → 가짜 결제 창. `eventNow = 1792108799`면 "판매 기간이 아니에요". 확인 뒤 둘 다 되돌리기.

## 추가한 테스트
- `tests/m5-03-qa.spec.luau` (16개, 전부 통과)
  - 가짜 지오메트리(회전 없는 CFrame)로 껍데기 맵 실제 실행: tempura-pot·ikura-bombs 스폰 24개 바닥 안 / dessert-fridge 결승선 위치·1~12번 스폰 / 낙하 25 경계(24.9 생존, 25.1 탈락)·끝난 라운드 무시 / 결승선 159.9·160 경계 / ikura overtime 바로 돌아옴·`collapseDuration` 뒤 판 제거·cleanup 등록·끝난 라운드 무시.
  - 껍데기 서비스(OfferService·CodeService)를 가짜 Remotes로 실행: 어떤 인자에도 `false, "준비 중이에요"`, 코드 목록 한 번 읽음.
  - 가짜 DataService(메모리)로 `setViewExtra`: 바뀔 때만 한 번 전송, 같은 값 재전송 없음, 비-boolean은 false, 다른 저장 변경에도 vip 유지, 로드 전 값 기억, 나간 뒤 무시.
  - 프로필 경계: v1 두 번 migrate 같음·notes 없음, 모양 틀린 v2 칸, equippedFx 모르는 칸, redeemedCodes 200/201, 미래 버전.
  - `canRun` 12칸 전부, `commandTier` 대소문자·공백·`__index`·비문자열, 실서버 통과 명령은 Info뿐.

## 인계 메모
- 브랜치: `m5-03-qa` (origin/main `4192744` 병합 위). main은 건드리지 않음.
- 끝난 것: 검증 5단계(전부 통과, 1249 passed), AC1~AC10 대조(10/10 통과), QA 테스트 16개 추가, 버그 3건(P3), 스펙 status `qa-passed`.
- 남은 것: 메인 세션이 `m5-03-qa`를 main에 병합. 사용자 Studio 확인 AC11~AC13(위 체크리스트). planner가 m5-10·m5-11 본문 정리(메모). B1은 m5-06, B2·B3은 m5-07에서 닫힘 — 각 QA가 확인.
- 다음에 할 첫 단계: `git merge origin/m5-03-qa` → 검증 5단계 다시 → docs-writer가 DEV-SETUP에 체크리스트 반영.
- 막힌 점: 없음.
