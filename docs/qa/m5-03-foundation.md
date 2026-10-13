# QA — m5-03 M5 기반 (공용 파일·프로필 v2·카탈로그·껍데기)

- 스펙: `docs/specs/m5-03-foundation.md`
- 검증 커밋: `c4ca608`
- 결과: **진행 중** (세션 종료로 중단 — 판정 전, 스펙 status는 `in-qa` 그대로)

## 자동 검증 (c4ca608, QA가 직접 실행)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 (1133 passed, 0 failed) |
| `luau-lsp analyze ...` (타입 검사) | 통과 (종료 코드 0, 오류 출력 없음) |

## 지금까지 코드로 확인한 것 (테스트 추가 전)
- **프로필 v1→v2** (`src/shared/ProfileLogic.luau`): 기존 칸(coins/wins/matchesPlayed/ownedSkins/equippedSkin/settings/receipts)은 v1 정리 로직 그대로, v2 칸 5개는 `countMap`/`keepNewest`/ownedFx·equippedFx 정리로 채움. 미래 버전(`version > 2`)은 `persistable = false` 유지. 두 번 마이그레이션 안전성은 **아직 테스트로 확인 안 함**.
- **코드 목록 비밀**: `.gitignore`에 `src/server/CodeList.luau` 있음. `CodeConfig.load()`는 모듈이 없거나 require 실패·모양이 틀리면 빈 목록 + 경고(`CodeConfig.resolve`). 로더·목록 모두 `src/server`(ServerScriptService) 아래라 클라이언트 복제 없음. 커밋된 `CodeList.example.luau`는 `Codes = {}`(예시 문자열은 주석만). git 기록 전체에서 실제 코드 문자열 검색은 **아직 안 함**.
- **실서버 관리자 테스트 명령 없음**: `LiveTestCommands` 설정 없음(src 검색). `AdminLogic.canRun`은 `isStudio = false`면 Info 외 무조건 `StudioOnly` 거절, StudioOnly는 persistInStudio면 `PersistOn`. `AdminService.onCommand` 순서 = 관리자 표 → `allowRequest` 간격 → `commandTier`(문자열 아니면 nil) → `canRun` → `runCommand`(지금은 NotReady). 순서 스펙과 일치.
- **맵 풀**: `Maps.infos()`는 `inPool ~= false`만, `Maps.allInfos()`는 9개, MatchService 강제 플랜만 `allInfos`, 랜덤 판(`MatchService.luau:253`)은 `infos`. 껍데기 3개 모두 `inPool = false`, `ikura-bombs`에 `overtime` 있음.
- **리모트 껍데기**: `RequestOfferPurchase`·`EquipFx`(OfferService), `RedeemCode`(CodeService)는 "준비 중이에요". `AdminCommand`는 AdminService 틀.

## 발견한 문제 (잠정, 판정 전)
### [P3 잠정] `BuyWithTokens`에 서버 핸들러가 없음
- 재현: 클라이언트(익스플로잇 포함)가 `Remotes.fn("BuyWithTokens"):InvokeServer("ghost-tamago")` 반복 호출.
- 기대: 스펙 범위 9 "핸들러가 아직 없는 동안은 껍데기 서비스가 `return false, "준비 중이에요"`".
- 실제: `OnServerInvoke`를 아무도 달지 않음 → 호출이 서버에서 대기열에 쌓이고 클라이언트는 영원히 기다림. m5-07이 ShopService에 붙이기 전까지 남음. 개발 메모에 "클라이언트가 부르지 않음"으로 적혀 있어 위험은 낮음.
- 위치: `src/shared/Remotes.luau:54`, `src/server/ShopService.luau`(핸들러 없음)

### [P3 잠정] Studio 가짜 결제에서 기간 밖 시즌 로벅스 스킨 카드가 켜져 보임
- 재현: `fakeRobuxInStudio = true`, `eventNow = nil`(오늘 10/8, 할로윈 전) → 탈의실 호박 초밥 카드.
- 기대: 서버가 `OffSale`로 막는 스킨은 카드도 비활성.
- 실제: `ShopLogic.cardState`는 기간을 보지 않아 "R$ 99" 활성 → 누르면 "판매 기간이 아니에요". 실서버는 productId가 없어 "곧 열려요". 진짜 카드 상태는 m5-07 범위.
- 위치: `src/shared/ShopLogic.luau:191-217`

### 메모 (버그 아님)
- `docs/specs/m5-11-admin-commands.md` 본문(19·25·38·47·77행)은 아직 `LiveTestCommands`·`canRun(tier, isStudio, liveTestCommands, persistInStudio)` 4인자를 적고 있음. 85행 사용자 결정으로 대체됐지만 본문·AC2(9칸 표)가 남아 있어 m5-11 개발자가 헷갈릴 수 있음 → 기획 담당이 본문 정리 필요.
- `docs/specs/m5-10-redeem-codes.md` 본문(12·18·31·64·80행)도 "새 `CodeConfig.luau`에 코드 목록"으로 남아 있음(90행 결정이 대체). 같은 정리 필요.

## 남은 것
1. 수용 기준 AC1~AC9를 하나씩 대조(개발자 테스트 `tests/m5-03-foundation.spec.luau`, `seasons.spec`, `fx-catalog.spec` 읽기).
2. QA 테스트 `tests/m5-03-qa.spec.luau` 추가: v1→v2 손실 없음(coins·ownedSkins·wins·receipts·settings·모르는 칸), migrate 두 번(idempotent), 미래 버전 3 → persistable false, `canRun` 9칸, `commandTier` 비문자열, `CodeConfig.resolve`(파일 없음/모양 틀림/정상), 랜덤 판 1,000번에 껍데기 없음(3·4라운드 둘 다), `cardState` Soon.
3. `git log -p`로 저장소 기록에 실제 코드 문자열이 없는지 확인.
4. 기존 테스트 7개 기대값 변경(`skins`, `shop-logic`, `m4-foundation`, `m4-14-qa`, `m4-07-data-qa`, `camera-priority`, `m4-12-hardening`) 타당성 확인.
5. 인터페이스 대조표 완성(m5-04~m5-12), 서버 판정·보안 체크, Studio 체크리스트(AC11~AC13), 판정 → 스펙 status 변경.

## 사용자 Studio 확인 체크리스트 (초안, 사용자 확인 필요)
1. AC11: Play Solo → 로비 버튼이 전과 같음. 탈의실에 새 스킨 5개(계란초밥 모양, 토핑 색만 다름). 유령·트리·금박은 "곧 열려요". Output에 `[CodeConfig] no src/server/CodeList.luau` 경고 한 줄 외 에러 없음.
2. AC12: `Config.DEBUG.forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }` → 혼자 Play로 끝까지(결승은 연장전에 판이 사라져 떨어지고 우승). 확인 뒤 `nil`.
3. AC13 (선택): 저장 켠 Studio에서 M4 프로필이 코인·스킨 그대로 v2로 저장.

## 인계 메모
- 브랜치: `m5-03-qa` (origin/main `c4ca608`에서 분기). main은 건드리지 않음.
- 끝난 것: 검증 5단계 실행(전부 통과), 주요 코드 읽기(프로필 v2, 코드 목록 로더, 관리자 등급, 맵 풀, 리모트 껍데기), 잠정 P3 2건.
- 남은 것: 위 "남은 것" 1~5.
- 다음 첫 단계: `tests/m5-03-foundation.spec.luau`를 읽고 빠진 경계값만 `tests/m5-03-qa.spec.luau`로 추가 → `lune run tests`.
- 막힌 점: 없음 (세션 종료로 중단).
