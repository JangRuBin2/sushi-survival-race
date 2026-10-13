# QA — m5-08 특별 상품: 스타터 팩·세트·연출 팩·VIP 패스 (🎁 상점)

- 스펙: `docs/specs/m5-08-offers-shop.md`
- 검증 커밋: `origin/main` `e772d23` + `origin/m5-08-offers` `9a723e3` 병합 (QA 브랜치 병합 커밋 `21c3516`). QA는 `tests/`·`docs/`만 바꿈.
- 결과: **통과** (P0/P1 없음, P2 1건, P3 2건) → 스펙 status `qa-passed`

## 자동 검증 (QA가 Windows 로컬에서 직접 실행, 병합 뒤 HEAD)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 파일 포맷 후) |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **1430 passed, 0 failed** (병합 직후 1406 passed / 1 failed → 아래 "m5-03-qa 껍데기 테스트" 정리 + QA 24개) |
| `luau-lsp analyze ...` (타입 검사) | 통과 (종료 코드 0, 오류 출력 없음) |

### 병합 직후 실패 1건 — m5-03-qa 껍데기 테스트 (버그 아님, 테스트 정리)
`tests/m5-03-qa.spec.luau` "QA 껍데기 서비스: RequestOfferPurchase·EquipFx는 어떤 인자에도 false, '준비 중이에요'"는 m5-03 때의 **껍데기 상태**를 고정한 테스트예요. m5-08이 스펙대로 OfferService를 채워서 더는 맞지 않아요(가짜 환경에 MarketplaceService가 없어 로드 실패). RedeemCode를 m5-10이 채웠을 때(`c4659bd`)와 같은 방식으로 그 케이스와 전용 로더를 빼고, 인자 검증은 **실제 OfferService로** `tests/m5-08-qa.spec.luau`에서 확인해요(아래 "RequestOfferPurchase", "EquipFx" 테스트). 기대값을 구현에 맞춰 바꾼 것이 아니라, 대상이 사라진 테스트를 옮긴 것이에요.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `offer-logic.spec` "AC1" 3개 + QA "validate: 시즌·기본 스킨 묶음, 패스에 productId, 연출에 gamePassId, 상품 id 겹침, 가격 0·소수"(11가지 위반 각각 잡힘), "카탈로그: 가격이 A안과 맞고…" |
| AC2 | 통과 | `offer-logic.spec` "AC2" + QA "화면: 일부 가진 묶음은 숨김, 산 묶음·연출·VIP는 아래 회색…"(목록 모양 보기) |
| AC3 | 통과 | `offer-logic.spec` "AC3" + QA "canRequest: 이상한 id·없는 프로필, 가짜 로벅스는 VIP를 열지 않음, 가짜 결제는 CannotSave 무시" |
| AC4 | 통과 | `offer-logic.spec` "AC4" + QA 카탈로그 테스트(146/297/597, 묶음 가격 < 따로 사는 합) |
| AC5 | 통과 | `receipt-logic.spec` m5-08 10개(가짜 port) + QA **실제 서비스** "live: 스타터 팩 영수증 → 저장된 프로필에 4종 + boughtOffers, 기록 offerId, 장착 그대로, Notice 한 번", "프로필 저장 실패 → NotProcessedYet·기록 없음…", "기록 쓰기 실패 → … retry로 기록만", "다른 서버의 프로필이 되돌려짐 → AlreadyRecorded로 묶음 복원", "연출 영수증 → 보유 + 그 칸 장착 + 속성…". m4-14 스킨 영수증 테스트(`receipt-logic`, `m4-14-qa`) 전부 그대로 통과 |
| AC6 | 통과 | `receipt-logic.spec` + QA "결제 창 중 연어를 먼저 얻음 → 나머지 3개 지급 + warn (already owned: salmon)" |
| AC7 | 통과 | 위 자동 검증 5단계 |
| AC8 | 사용자 확인 필요 | 체크리스트 1 |
| AC9 | 사용자 확인 필요 | 체크리스트 2·3 (서버 흐름은 QA 가짜 환경에서 확인함) |
| AC10 | 사용자 확인 필요 | 체크리스트 4 (판단은 `visible`/`screenList` 테스트로 확인함) |
| AC11 | 사용자 확인 필요 | 체크리스트 5 (서버 EquipFx·속성은 QA 테스트로 확인함) |
| AC12 | 사용자 확인 필요 | 체크리스트 6 |
| AC13 | 사용자 확인 필요 | 체크리스트 7 |
| AC14 | 사용자 확인 필요 | 체크리스트 8 |
| AC15 | 사용자 확인 필요 (실서버, 상품 만든 뒤) | 체크리스트 9 |

자동 확인 가능한 AC1~AC7: **7/7 통과**. Studio·실서버 확인 AC8~AC15: **8개 사용자 확인 필요**.

## 결제 안전 확인 (실제 서비스 소스를 가짜 환경에서 돌림 — `tests/m5-08-qa.spec.luau`)
- **ProcessReceipt는 한 곳**: `src/` 전체에서 `.ProcessReceipt =` 대입은 `RobuxShopService.luau` 하나뿐(정적 테스트). OfferService는 `setOfferPort`로 "무엇을 주는지"만 등록하고 `PromptProductPurchaseFinished`로 지급하지 않음.
- **순서**: 지급(메모리) → `saveNow` true → 구매 기록 true → PurchaseGranted. 저장 실패면 기록을 쓰지 않고 NotProcessedYet, 저장소가 회복된 뒤 같은 영수증이 오면 한 번만 지급. 기록 실패면 NotProcessedYet, 다시 오면 프로필 receipts로 "retry"(지급·안내 한 번).
- **같은 PurchaseId**: 두 번째는 AlreadyRecorded(스킨 수 그대로, 안내 다시 안 함). 다른 PurchaseId로 같은 묶음이 또 오면 RecordOnly + 운영 warn(m4-14와 같은 처리, 환불은 운영 판단).
- **되돌려진 프로필**: 기록이 있는데 다른 서버에서 프로필이 결제 전으로 돌아가 있으면 AlreadyRecorded 경로에서 묶음(남은 스킨 + boughtOffers)을 다시 넣고 저장된 뒤에만 Granted.
- **묶음 일부 보유**: 남은 것만 지급, Granted, warn `already owned: salmon, gave the rest` (스펙 D5).
- **모르는 상품**(게임 패스 id로 온 영수증 포함)·모양이 틀린 영수증: NotProcessedYet, 기록 없음.
- **기록 모양**: `{ userId, productId, offerId, at }`, `skinId` 없음, UserId 메타데이터.
- **가짜 결제·가짜 VIP**: 실서버(IsStudio false)에서 `fakeRobuxInStudio`·`fakeVipInStudio`를 켜 둬도 무시 — 실제 `PromptProductPurchase`/`PromptGamePassPurchase`만 부르고, 결제 창을 연 것만으로 지급·VIP 되지 않음. 커밋 값은 둘 다 `false`, 상품·패스 id는 전부 `nil`.
- **경제 규칙**: 상품표에 코인·능력치·랜덤 칸 없음(허용 칸 목록 테스트), 코인을 로벅스로 파는 상품 없음, VIP 코인 배수 없음, VIP 스킨은 로벅스(`NotRobux`)·코인 해금 둘 다 불가. 가격은 A안(일반 29·레어 59·에픽 99·전설 199)과 맞고 묶음은 따로 사는 값보다 쌈(79<146, 249<297, 499<597).
- **VIP 확인**: 보유 → 속성 `Vip`, 보기 `vip`, 금박 계란초밥 지급(장착 안 함)·저장. 실패 1번 → 5초 뒤 다시 → VIP. 2번 실패 → 이번 접속 VIP 아님 + warn(`UserOwnsGamePassAsync` 정확히 2번씩). 다른 패스 id·`purchased = false` 이벤트 무시. 패스가 없어져도 받은 스킨은 남음.
- **m5-09 속성 계약**: `EliminationFx`/`VictoryFx` 값 = FxCatalog id, 없으면 속성 없음(벗기면 nil로 지움). 다른 서버에서 접속·프로필 로드 때 프로필대로 다시 달림. m5-09 스펙("탈락한 사람의 `EliminationFx`를 읽음, 없으면 기본")과 맞음.

## 버그
### [P2] B1 VIP 구매 이벤트만 믿고 영구 스킨까지 지급 — `UserOwnsGamePassAsync`로 다시 확인하지 않음
- 재현(코드 읽기): `MarketplaceService.PromptGamePassPurchaseFinished(player, passId, true)`가 오면 `setVip` → `grantVipSkins`가 프로필에 `vip-gold-tamago`를 넣고 `saveNow`. 패스 보유를 서버가 다시 묻지 않아요.
- 기대: 이 이벤트는 서버 신호라 일반 클라이언트가 RemoteEvent처럼 보낼 수는 없지만, 결제의 근거는 Roblox 서버의 소유 기록이어야 해요. 커뮤니티에서는 익스플로잇 도구가 내부 `Signal…PurchaseFinished` 계열로 이 이벤트를 흉내 낸 사례가 보고돼 왔고, 일반적인 권장은 "이벤트를 받으면 `UserOwnsGamePassAsync`로 확인한 뒤 지급"이에요. (QA가 지금 Roblox에서 위조가 되는지는 확인하지 못했어요 — 방어적 권장.)
- 실제: 위조에 성공하면 R$ 149 패스 없이 **영구 저장되는** VIP 전용 스킨을 얻어요(👑·[VIP]는 그 접속에만). 능력치 영향은 없고 매출 손실만이라 P2.
- 권장 수정: 이벤트를 받으면 이번 접속 표시(속성 `Vip`, 보기 `vip`)는 바로 켜도 되지만, **프로필에 스킨을 넣는 것은 `UserOwnsGamePassAsync`가 true일 때만**(예: 2~3번, 몇 초 간격으로 다시 묻기). 끝까지 false면 다음 접속 때 `checkVip`가 다시 확인해서 넣으면 돼요. 개발 메모 N3의 캐시 걱정은 이 재시도로 덮을 수 있어요.
- 위치: `src/server/OfferService.luau:313-319` (이벤트), `:119-127` (`setVip`), `:95-117` (`grantVipSkins`)

### [P3] B2 상품 획득 안내가 로비·방 화면에 빨간 오류색으로 보임 (개발 메모 N1 판정)
- 재현: 로비에서 (가짜 결제로) 스타터 팩 또는 연출을 산다.
- 기대: "탈의실에서 새 스킨을 입어 보세요" / "🎉 탈락 연출: 고양이 손님 획득!"은 성공 안내라 일반(오류가 아닌) 색.
- 실제: `LobbyController`가 Notice 문구에 "…"가 없으면 오류로 보고 빨간색으로 보여 줘요. 상점 창 결과 줄은 초록이라 같은 성공이 두 색으로 보여요. 결제 직후 빨간 글씨는 "결제가 잘못됐나?" 하는 오해를 부를 수 있어요(결제 문의 늘어남). 기능·지급에는 영향 없음.
- 권장 수정(개발 판단): Notice에 종류를 싣거나(공용 `Remotes` 인자 — 공용 파일 담당 확인 필요), `LobbyController`의 판정에 "🎉" 시작·특정 문구를 성공으로 더하거나, OfferService가 로비 Notice를 보내지 않고 상점 결과 줄(이미 초록으로 같은 문구)만 쓰기. 마지막이 가장 작아요 — 다만 상점 창을 닫은 뒤 영수증이 늦게 오면 안내가 안 보여요.
- 위치: `src/client/ui/LobbyController.luau:151`, `src/server/OfferService.luau:217-227`

### [P3] B3 `fakeVipInStudio`는 `persistDataInStudio`와 같이 켜도 꺼지지 않음 → 진짜 DataStore 프로필에 VIP 스킨이 저장됨
- 재현: Studio에서 `persistDataInStudio = true`, `fakeVipInStudio = true`로 Play.
- 기대: 가짜 로벅스(`ShopLogic.fakeRobuxActive`, m4-14 QA R4)처럼 진짜 저장소를 쓰는 동안에는 가짜 VIP도 꺼지고 warn.
- 실제: `fakeVip()`는 `IsStudio() and fakeVipInStudio`만 봐서, 금박 계란초밥이 진짜 저장소의 그 계정 프로필에 영구 저장돼요(그 뒤 실서버에서도 보유). Studio·개발자 계정만 해당이라 P3.
- 위치: `src/server/OfferService.luau:51-53` (클라이언트 `src/client/ui/OfferController.luau:49`도 같은 조건)

### 판정한 개발 메모 항목
- **N1** (로비 Notice 빨간색): 버그로 봄 → B2 (P3).
- **N2** (산 연출 카드): 스펙은 "산 상품 카드는 회색 아래(묶음·VIP) 또는 사라짐"이라 연출은 정하지 않았어요. 묶음·VIP와 같이 "산 상품" 회색으로 아래에 두고 "✨ 내 연출"에도 보이는 것은 일관되고 다시 살 수 없으니(서버 `AlreadyOwned`) **버그 아님**. QA 테스트로 순서 확인.
- **N3** (`PromptGamePassPurchaseFinished`를 믿음): 표시만이면 괜찮지만 영구 스킨 지급까지 믿는 것은 B1 (P2).
- **N4** (자기 이름표엔 👑 안 보임): 기존 구조(자기 이름표 없음) 그대로라 버그 아님. AC12는 2명 테스트로.
- **m5-09 속성 계약**: 맞음(위 "결제 안전 확인" 마지막 줄, QA 테스트 "속성 계약(m5-09)").

### 참고 (버그 아님, 알려진 한계)
- 다른 PurchaseId로 같은 묶음·연출이 또 결제되면(동시에 두 창 등) RecordOnly로 받고 아무것도 더 주지 않아요 — m4-14 스킨과 같은 정책(운영 warn, 환불은 운영 판단).
- 결제 창 중에 묶음 안 스킨을 코인으로 해금하면 남은 것만 받고 가격은 그대로(스펙 D5, warn). 묶음 스킨 전부를 그 사이 얻었다면 0개를 받고 R$ 79를 낸 셈 — 확률은 낮지만 운영 warn을 보면 환불 판단.
- VIP 확인이 두 번 다 실패한 접속에서는 패스를 가진 사람에게도 VIP 카드가 "사기"로 보여요. 누르면 Roblox가 "이미 보유" 창을 띄우고 결제는 안 돼요(무해).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteFunction 인자를 서버에서 검증한다 — `RequestOfferPurchase(offerId)`: 간격 1초 → 문자열·카탈로그·프로필·한 번만/일부 보유/VIP·상품 id·저장 가능. `EquipFx(slot, fxId)`: 간격 0.3초 → 칸 이름·연출 id 타입·카탈로그·칸 일치·보유 → 라운드/연출 잠금(`ShopService.isLocked`). 숫자·표·1만 자 문자열·대소문자 다른 id 모두 거절(QA 테스트). 방 소속·방장은 해당 없음.
- [x] 지급·소유·VIP 판단이 서버에만 있다 — 클라이언트는 카드 그리기·요청만. 클라이언트의 `PromptGamePassPurchaseFinished`/`PromptProductPurchaseFinished` 연결은 "기다리는 중" 표시만 지움.
- [x] 맵 상태 — 해당 없음.
- [x] 정리 — `PlayerRemoving`에서 `lastPurchaseAt`·`lastEquipAt`·`vipOf` 지움. VIP 재확인 스레드는 나간 사람이면 멈춤.
- [x] `Vip`·`EliminationFx`·`VictoryFx`는 서버만 다는 Player 속성 — 다른 클라이언트의 👑·[VIP]·연출 선택은 이것만 읽어요. 클라이언트가 자기 속성을 바꿔도 서버·다른 클라이언트에 복제되지 않아요.
- [x] `TextChatService.OnIncomingMessage` 대입은 `ChatTagController` 한 곳(grep).

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.fakeRobuxInStudio = true` (VIP 항목은 `fakeVipInStudio = true`도). `persistDataInStudio`는 **false로 둔 채** 하세요(B3). **끝나면 둘 다 false로 되돌리고 커밋하지 마세요.**

1. (AC8) Play → 왼쪽 위 "🍣 스킨" 바로 아래 "🎁 상점" 버튼. 눌러서 카드 6개(스타터 팩·에픽 세트·전설 세트·고양이 손님·불꽃놀이·VIP — `fakeVipInStudio`가 꺼져 있으면 VIP는 "곧 열려요")와 스타터 팩의 "따로 사면 R$ 146", 에픽 297·전설 597이 보이는지.
2. (AC9) 스타터 팩 "R$ 79로 사기" → 상점 결과 줄 "🎉 스타터 팩 획득! 탈의실에서 새 스킨을 입어 보세요"(초록), Output에 `[Shop] receipt studio-… offer starter-pack -> PurchaseGranted (GrantAndRecord: granted)`. 로비 아래 안내가 **빨간색**이면 B2(알려진 P3). 탈의실에 연어·참치·새우·장어 보유, 입고 있던 스킨 그대로. 상점에서 스타터 팩은 아래 회색 "산 상품"이 되고 누를 수 없음.
3. (AC9 중복) 명령줄(Server): `game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("<내 이름>", "starter-pack", "studio-test-1")`를 두 번 → 두 번째 Output에 `AlreadyRecorded`, 스킨 개수 그대로.
4. (AC10) Stop → 다시 Play(메모리 프로필이라 새 프로필) → 탈의실에서 연어를 먼저 얻기(코인 해금 또는 "R$ 29로 사기") → 상점에서 스타터 팩 카드가 **아예 없음**(산 상품 줄에도 없음).
5. (AC11) 고양이 손님 사기 → "✨ 내 연출"에 "입는 중 · 벗기". Explorer → Players → 내 플레이어 → Attributes에 `EliminationFx = cat-customer`. "벗기" → 속성이 사라짐, "입기" → 다시 생김. 방을 만들고 시작한 직후(소개 중) 서버 명령줄에서 거절 확인: `game.ReplicatedStorage`의 리모트를 직접 부를 수 없으니 상점 버튼이 숨겨지는 것(7번)으로 대신 확인해도 돼요.
6. (AC12) `fakeVipInStudio = true` → Test → Clients and Servers 2명. 상대 화면에서 내 이름표가 "👑 이름", 채팅에 금색 "[VIP]", 내 탈의실에 금박 계란초밥이 보유로 있고 장착은 안 됨, 상점 VIP 카드는 "산 상품" 회색. (자기 이름표는 원래 안 보여요.) 채팅이 예전 채팅(LegacyChatService)이면 [VIP]는 안 나와요 — `TextChatService.ChatVersion`이 `TextChatService`인지 확인.
7. (AC13) 방에서 매치 시작 → "🎁 상점" 버튼이 사라짐(소개·달리기·대기석·관전 모두). 매치가 끝나 로비로 돌아오면 다시 보임. 창을 연 채로 시작되면 창도 닫힘.
8. (AC14) Test → Device(휴대폰) → 상점 카드가 1열로 스크롤되고 버튼끼리 겹치지 않음, 버튼 높이 44px 이상. "🍣 스킨"·"🎁 상점" 버튼이 코인 배지·음소거 등 다른 로비 UI와 겹치지 않음(화면 배율이 바뀌어도).
9. (AC15, 실서버) 아래 상품 5개·패스 1개를 만들고 id를 `src/shared/Offers.luau`에 넣은 뒤 퍼블리시 → 실제 결제 창 → 지급, Output(개발자 콘솔 F9 → Server)에 `PurchaseGranted`. VIP 패스를 산 뒤 다시 접속해도 👑. 결제 테스트는 비공개 서버·테스트 계정으로.

## 사용자가 만들 상품 (USER-TODO C3에 더할 것 — 문서 담당)
Creator Dashboard → 이 게임 → Monetization.

**Developer Products 5개** → id를 `src/shared/Offers.luau`의 각 상품 `productId = <id>,`에
| offer id | 상품 이름 | 가격(R$) | 주는 것 |
|---|---|---|---|
| starter-pack | 스타터 팩 | 79 | 연어·참치·새우·장어 |
| epic-set | 에픽 세트 | 249 | 무지개 롤·불꽃 연어·아보카도 캘리포니아롤 |
| legendary-set | 전설 세트 | 499 | 황금 참치 뱃살·다이아 성게·용 롤 |
| fx-cat-customer | 탈락 연출: 고양이 손님 | 59 | 탈락 연출 `cat-customer` |
| fx-fireworks | 우승 연출: 불꽃놀이 | 99 | 우승 연출 `fireworks` |

**Passes 1개** → id를 `src/shared/Offers.luau`의 `vip` 상품 `gamePassId = <id>,`에
| offer id | 패스 이름 | 가격(R$) | 혜택 (겉모습만, 코인 배수 없음) |
|---|---|---|---|
| vip | VIP 패스 | 149 | 금박 계란초밥 스킨 · 이름표 👑 · 채팅 [VIP] |

주의: 상품 id는 스킨 상품 id(C3의 15개)와 겹치면 안 돼요 — 서버 시작 때 `Offers.validate`가 Output에 `[Offer] offer catalog problems`로 알려 줘요. 결정할 것(스펙 사용자 작업): VIP 149·코인 배수 없음 확정(D1), 스타터 팩 조건, 지역 가격(대시보드).

## 추가한 테스트
- `tests/m5-08-qa.spec.luau` (24개): 실제 `DataService`·`PurchaseLog`·`ShopService`·`RobuxShopService`·`OfferService` 소스를 가짜 Marketplace·DataStore·스케줄러로 함께 돌림 (상품 id·패스 id를 채운 카탈로그를 새로 불러서 공유 캐시는 안 건드림).
  - 순수: 카탈로그 가격·허용 칸·커밋 값, validate 위반 11가지, VIP 스킨 판매 경로 없음, canRequest 경계, canEquipFx 이상한 인자·잠금, applyGrant 두 번·equip false·패스·음수 시각, 화면 순서.
  - 영수증: 정상·같은 id·다른 id 두 번 결제·이미 산 뒤 요청, 프로필 저장 실패, 기록 실패, 되돌려진 프로필 복원, 묶음 일부 보유, 연출(잠금 중 포함), 모르는 상품·패스 id·모양 틀림, 실서버에서 가짜 플래그 무시.
  - 리모트: RequestOfferPurchase 이상한 인자·간격·OwnsSome·준비 중, EquipFx 이상한 인자·잠금·입기/벗기·간격, m5-09 속성 계약(서버 이동 뒤 다시 달림).
  - VIP: 보유·이미 VIP, 실패 1번/2번, 패스 없음·이벤트 무시, 패스가 없어져도 스킨 유지, Studio 가짜 결제·가짜 VIP.
  - 정적: ProcessReceipt 대입 한 곳, OfferService에 PromptProductPurchaseFinished·coins 없음.
- `tests/m5-03-qa.spec.luau`: OfferService 껍데기 케이스와 전용 로더 제거(위 "병합 직후 실패 1건").

## 인계 메모
- **브랜치**: QA worktree `worktree-agent-a0e19a8d28e2b853c` → `origin/m5-08-offers`로 push (main `e772d23` + m5-08 `9a723e3` 병합 위).
- **끝난 것**: 자동 검증 5단계(1430 passed), AC1~AC7 통과, 결제 안전 확인, QA 테스트 24개, 리포트, 스펙 status `qa-passed`.
- **남은 것**: 사용자 Studio 확인 AC8~AC14(체크리스트 1~8), 실서버 AC15(상품 5개·패스 1개 만든 뒤). 개발: B1(P2)·B2·B3(P3)는 다음 수정 때. 문서 담당: USER-TODO C3에 위 상품표 추가, DEV-SETUP에 체크리스트 반영.
- **다음에 할 첫 단계**: main 병합 담당이 `m5-08-offers`를 main에 병합하고 5단계를 다시 돌림(m5-09가 같은 속성을 읽으니 m5-09 병합 뒤에도 다시).
- **막힌 점**: 없음. B1의 "위조가 지금 실제로 되는가"는 QA가 확인할 수 없어 방어적 권장으로 둠.
