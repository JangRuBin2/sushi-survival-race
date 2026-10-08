# QA — m4-14 로벅스 스킨 구매 (개발자 상품 · ProcessReceipt · 구매 기록)

- 스펙: `docs/specs/m4-14-robux-shop.md`
- 검증 커밋: `6f2c002` (main), QA 브랜치 `m4-14-qa`
- 결과: **통과** (P0/P1 없음) → 스펙 `qa-passed`. Studio·실서버 확인(AC6~AC9)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 1012 passed / 0 failed (QA 추가 22개 포함) |
| `rojo sourcemap …` + `luau-lsp analyze … src` | 에러 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 decide 6가지 | 통과 | `tests/receipt-logic.spec.luau` + `src/shared/ReceiptLogic.luau:81` |
| AC2 저장 실패 → NotProcessedYet, 기록 없음, 재시도 시 한 번만 | 통과 | 실제 서비스로 다시 확인: `m4-14-qa` "profile save fails → …", "server move: profile save failed on A …" |
| AC3 기록 실패 → NotProcessedYet, 재시도 RecordOnly → Granted, 중복 없음 | 통과 | `m4-14-qa` "purchase log write fails → …", "server move: record write failed on A …" |
| AC4 productId 겹침 없음 | 통과 | `tests/skins.spec.luau` (지금은 전부 nil. 사용자가 id를 넣은 뒤 `lune run tests` 다시) |
| AC5 검증 명령 5개 | 통과 | 위 표 |
| AC6 Studio 가짜 결제로 성게 | 사용자 확인 필요 | 가짜 환경에서 흐름은 확인 (`m4-14-qa` "Studio + fakeRobuxInStudio …"). 화면은 아래 1번 |
| AC7 실제 결제 창 (Studio 테스트 구매) | 사용자 확인 필요 (C3 선행) | 아래 4번 |
| AC8 보유 스킨에 로벅스 버튼 없음, 저장 불가 거절 | 사용자 확인 필요 | 서버 거절은 가짜 환경에서 확인 ("Studio without fakeRobuxInStudio …", "lock lost → 저장 거절"). 화면은 아래 3번 |
| AC9 `[Shop] receipt` 로그, 같은 영수증 두 번 → 스킨 하나 | 사용자 확인 필요 | 가짜 환경에서 ReplayReceipt 두 번 → 두 번째 AlreadyRecorded, 스킨 하나. 아래 2번 |

통과 5 / 실패 0 / 사용자 확인 필요 4.

## 결제 안전 점검 (실제 `RobuxShopService`·`PurchaseLog`·`DataService`·`ShopService` 소스를 가짜 MarketplaceService·DataStore로 실행)
| 점검 | 결과 |
|---|---|
| Granted면 저장소 프로필에 스킨 + `Purchases_v1` 기록 (모든 Granted 테스트에서 불변식 검사) | 확인 |
| 프로필 저장이 먼저, 기록은 저장 성공 뒤 (`ReceiptLogic.luau:171-180`) | 확인 |
| saveNow false 경로 = NotProcessedYet: 잠금 상실(임시 프로필), BindToClose 뒤(해제·closing), 로드 중, 플레이어 없음, 기록 읽기 실패, 기록 쓰기 실패 | 확인 (각각 테스트) |
| 기록 읽는 동안 퇴장 → NotProcessedYet (`ReceiptLogic.luau:123-127` 재확인) | 확인 |
| 저장이 느린 동안 퇴장 → Granted면 실제로 저장소에 스킨 있음 | 확인 |
| 같은 PurchaseId 재전송 → AlreadyRecorded, 스킨·receipts·기록 그대로 | 확인 |
| 같은 서버 동시 콜백 → 두 번째 NotProcessedYet (`inFlight`) | 확인 |
| 서버 이동(A에서 기록 실패 / 저장 실패 → B에서 재전송) → B에서 Granted, 스킨 하나 | 확인 |
| receipts 50개 상한으로 밀려난 옛 PurchaseId 재전송 → `Purchases_v1`이 막음(AlreadyRecorded, 되돌려진 프로필이면 복구만) | 확인. `Purchases_v1`은 지우지 않으므로 상한과 무관 |
| "로벅스는 빠졌는데 스킨 없음" 경로 | 못 찾음. 실패는 전부 NotProcessedYet → 다음 시도에서 RecordOnly/GrantAndRecord로 결국 지급 |
| `PurchaseLog`: 실서버에서 메모리 대체 없음(`isMemory`는 Studio만), 읽기 실패 nil, 이미 있으면 덮어쓰지 않음, UserId 메타데이터 | 확인 |
| RequestRobuxPurchase: 타입(nil·숫자·불리언·표), 없는 스킨, 계란초밥, 보유, productId nil, 저장 불가, 1초 간격 | 확인. 통과해도 `PromptProductPurchase`만 부르고 지급하지 않음 |
| 클라이언트가 지급을 유도할 수 없음 | 확인. 지급은 ProcessReceipt(Roblox가 부름)뿐. 가짜 영수증 경로는 `fakeMode()`(Studio + 설정)일 때만 |
| `fakeRobuxInStudio = true`가 실서버에서 무시됨 | 확인 (요청은 실제 결제 창, 지급 없음) |
| `ServerStorage.ShopDebug.ReplayReceipt`가 Studio + fake일 때만 생김 | 확인 (실서버·Studio fake 꺼짐 → Instance 0개). ServerStorage라 클라이언트는 원래 못 봄 |
| Pay-to-Win 없음 | 확인. 상품 → 스킨만, 결제가 바꾸는 프로필 칸은 `ownedSkins`·`equippedSkin`·`receipts`뿐. 랜덤 상품 없음 |
| m4-13 N1 (탈락 3초 스킨 버튼) | 수정 확인 (`ShopController.luau` `hiddenUntil`, 서버 잠금과 같은 `Config.Match.EliminationCutscene`). 화면은 사용자 확인 |
| m4-12 N3 (`logArenaStats` Studio 가드) | 수정 확인 (`MatchService.luau:148`) |
| 기존 테스트 기대 변경 | 타당. 리모트 19 → 20(`RequestRobuxPurchase` 하나 추가 맞음). 누수 예외 `PurchaseLog.luau:memory`는 Studio 메모리 모드에서만 쓰이고 실서버에서는 비어 있음 |
| 커밋된 디버그 값 | `fakeRobuxInStudio = false`, `persistDataInStudio = false`, `logArenaStats = false`, `forceMapPlan = nil` |

## 버그
P0/P1 없음.

### [P2] R1 개인정보 삭제 절차에 `Purchases_v1`이 빠져 있음
- 재현: `docs/USER-TODO.md` C4 "개인정보 삭제 요청" 줄을 읽는다.
- 기대: `PlayerData_v1`의 `u_<UserId>`와 함께 `Purchases_v1`에서 그 사용자의 기록도 지우는 방법이 있다.
- 실제: `PlayerData_v1`만 적혀 있다. `Purchases_v1`은 키가 PurchaseId라 대시보드에서 UserId로 바로 찾을 수 없고, 값에 `userId`가 들어 있다. 키 메타데이터(UserIds)는 달려 있으니 `ListKeysAsync` + `GetAsync`의 `KeyInfo:GetUserIds()`로 찾는 짧은 스크립트(Studio Command Bar)를 적어 두면 된다.
- 위치: `docs/USER-TODO.md:125`, `src/server/PurchaseLog.luau:107`
- 담당: docs-writer (공개 전에). 코드 수정은 필요 없음.

### [P3] R2 로벅스 결제 창이 열린 동안 같은 일반 스킨을 코인으로 해금할 수 있음
- 재현: 일반 스킨(예: 연어)에서 "R$ 49로 사기" → 결제 창이 뜬 상태에서(창 뒤 버튼이 눌리는 환경이면) 또는 결제 직후 영수증이 오기 전에 "🍚 해금" → 결제 확인.
- 기대: 하나만 성공하거나, 로벅스가 빠지면 그만한 것을 받는다.
- 실제: 서버는 영수증을 RecordOnly(이미 보유)로 처리해 Granted + 경고 로그. 로벅스는 빠지고 얻는 것 없음(스펙 결정대로 환불은 운영 판단). 요청이 끝나면 `busy`가 풀리고, 서버도 결제 대기 중인 스킨의 코인 해금을 막지 않는다.
- 위치: `src/client/ui/ShopController.luau:106`, `src/server/ShopService.luau:102`
- 제안: `PromptProductPurchaseFinished`까지 그 스킨의 행동 버튼을 잠그거나, 서버가 결제 창을 띄운 스킨을 몇 초 동안 코인 해금 거절.

### [P3] R3 결제 창을 취소해도 `pending`이 남아, 나중에 코인으로 해금하면 "🎉 획득!"이 나옴
- 재현: "R$ 49로 사기" → 결제 창 취소 → 같은 스킨을 코인으로 해금.
- 기대: 코인 해금 문구.
- 실제: `ProfileUpdated`에서 `pending`에 있던 스킨이 보유로 들어와 "🎉 {스킨} 획득!".
- 위치: `src/client/ui/ShopController.luau:109`, `:178`
- 제안: `MarketplaceService.PromptProductPurchaseFinished`(클라이언트)에서 `isPurchased = false`면 `pending`에서 뺀다.

### [P3] R4 Studio 가짜 결제 + `persistDataInStudio = true`면 실제 저장소에 가짜 기록·무료 스킨이 써짐
- 재현: 퍼블리시된 게임, API 접근 켬, `persistDataInStudio = true`, `fakeRobuxInStudio = true`로 로벅스 버튼.
- 실제: 가짜 영수증(`studio-…`)이 운영 `Purchases_v1`에 기록되고 운영 `PlayerData_v1` 프로필에 스킨이 저장된다. Studio 접근 권한이 있는 개발자만 가능하지만, 운영 구매 기록이 가짜 줄로 섞인다.
- 위치: `src/server/RobuxShopService.luau:87-97`, `src/server/PurchaseLog.luau:95`
- 제안: 가짜 영수증이면 `PurchaseLog`를 메모리로만 쓰거나, 두 설정을 같이 켜면 경고. 최소한 Config 주석에 "둘 다 켜지 말 것".

### [P3] R5 `Remotes.luau` 주석의 담당 서비스 이름
- `RequestRobuxPurchase` 줄이 "ShopService: …"라고 하지만 실제 등록은 `RobuxShopService`.
- 위치: `src/shared/Remotes.luau:15`

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 (타입, 카탈로그, 보유, productId, 저장 가능, 1초 간격)
- [x] 지급 판정이 서버에만 있다 (ProcessReceipt, `ReceiptLogic.process`)
- [x] 상태가 서비스 모듈 표에 있지만 플레이어/PurchaseId별이고 퇴장 시 정리됨 (`lastPurchaseAt`, `fakeReceipts`, `inFlight`는 처리 끝에 지움)
- [x] 디버그 훅은 Studio 전용

## 사용자 Studio 확인 체크리스트
(1~3, 5~6은 지금 바로 가능. 4는 **사용자 작업 C3(상품 15개 + id 입력) 선행**, 7은 **퍼블리시 + 실서버**)
1. **AC6** `Config.DEBUG.fakeRobuxInStudio = true` → Play → "🍣 스킨" → 레어 탭 "성게" → "R$ 99" → 결제 창 없이 성게를 입고, 카드가 "입는 중", 결과 줄 "🎉 성게 획득!". 서버 Output에 `[Shop] receipt studio-… skin uni -> PurchaseGranted (GrantAndRecord: granted)` 한 줄. 일반 스킨(연어)은 "R$ 49로 사기"로 같은 결과. 끝나면 false로 돌려 "R$ 99 — 곧 열려요"(회색) 확인. **커밋 전 false.**
2. **AC9** (fake = true, Play 중) Server Command Bar: `print(game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("<내 이름>", "eel", "studio-test-1"))`를 두 번 → 둘 다 `PurchaseGranted`, Output 두 번째 줄이 `AlreadyRecorded`, 탈의실 장어 카드 하나. fake = false로 Play하면 `game.ServerStorage:FindFirstChild("ShopDebug")`가 `nil`.
3. **AC8** 가진 스킨은 로벅스 버튼 없이 "입기"/"입는 중". fake = false + `persistDataInStudio = false`에서 클라이언트 Command Bar `print(game.ReplicatedStorage.Remotes.RequestRobuxPurchase:InvokeServer("eel"))` → `false 준비 중이에요`(상품 id 없을 때). 상품 id를 넣은 뒤 같은 상태로 로벅스 버튼 → "저장이 안 되는 상태라 지금은 살 수 없어요".
4. **AC7 (C3 선행)** 상품 15개 id를 `Skins.luau`에 넣고 `lune run tests`(AC4) → 퍼블리시 → 게임 설정 Security "Enable Studio Access to API Services" 켬 → `persistDataInStudio = true`, `fakeRobuxInStudio = false` → 로벅스 버튼 → Roblox 결제 창(테스트 구매, 청구 없음)의 가격이 버튼 가격과 같은지 → 확인 → 스킨이 들어오고 입혀짐, Output `[Shop] receipt <PurchaseId> … PurchaseGranted`. Stop 후 다시 Play해도 남음. 결제 창 "취소"하면 아무것도 안 바뀜(R3: 이후 코인 해금 문구가 "획득!"으로 나와도 알려진 P3). **이 확인 때는 fake를 켜지 말 것 (R4).**
5. **N1** 매치에서 탈락 → 탈락 연출 3초 동안 "🍣 스킨" 버튼이 안 보이고, 관전 화면으로 넘어가면 보임. 그때 장착 바꾸기가 거절 없이 됨.
6. **휴대폰 배치** Studio 기기 에뮬레이터(iPhone SE 같은 작은 가로 화면)에서 탈의실 → 일반 스킨 선택 → 정보 칸에 "🍚 해금" 버튼 + "R$ 49로 사기" 버튼 + 결과 줄이 잘리지 않고 겹치지 않는지, 두 버튼이 손가락으로 따로 눌리는지(잘못 누르기 쉬우면 알려 주기). 레어 스킨은 버튼 하나.
7. **실서버 (퍼블리시 후, C3 선행)** 실제 계정으로 가장 싼 일반 스킨 하나 구매 → 들어오는지, 다른 서버로 옮겨도(m4-11 매치 이동) 남는지. Creator Dashboard → Data Stores → `Purchases_v1`에 PurchaseId 키 한 줄.

## 추가한 테스트
- `tests/m4-14-qa.spec.luau` (22개): 실제 `DataService`·`PurchaseLog`·`ShopService`·`RobuxShopService` 소스를 가짜 MarketplaceService·DataStore(실패·지연 주입, 서버 두 개가 저장소 공유)·스케줄러로 실행.
  - 정상 지급(저장 → 기록 순서, UserId 메타데이터, 로그 한 줄), 같은 id 재전송, 같은 서버 동시 콜백
  - 프로필 저장 실패 / 기록 쓰기 실패 / 기록 읽기 실패 → NotProcessedYet → 회복 뒤 한 번만
  - 플레이어 없음 / 모르는 상품 / 로드 중 / 이상한 영수증 모양, 잠금 상실, BindToClose 뒤, 저장 중 퇴장, 기록 읽는 중 퇴장
  - 서버 이동 두 경우, receipts 50개 상한 뒤 옛 id 재전송
  - RequestRobuxPurchase 인자·카탈로그·보유·productId·저장 불가·1초 간격·결제 창만 띄움
  - 실서버에서 fake 무시 + 디버그 훅 없음, Studio fake 꺼짐 거절, Studio fake 지급 + ReplayReceipt 두 번
  - 결제가 바꾸는 프로필 칸 (Pay-to-Win 없음)

## 인계 메모
- 브랜치: `m4-14-qa` (origin/main `6f2c002`에서). main에는 손대지 않음.
- 끝난 것: 자동 검증 5개, AC1~AC5 통과, 결제 안전 점검, QA 테스트 22개, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 체크리스트 1~7 (4·7은 C3 선행). docs-writer: R1(USER-TODO C4에 `Purchases_v1` 삭제 방법), 체크리스트를 DEV-SETUP에. 개발(급하지 않음): R2~R5.
- 다음에 할 첫 단계: 메인 세션이 `m4-14-qa`를 main에 병합 → docs-writer가 R1과 M4 완료 문서 반영.
- 막힌 점: Studio·실제 결제 창 없음 (화면·결제 창은 확인 못 함).
