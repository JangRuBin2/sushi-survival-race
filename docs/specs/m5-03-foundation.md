status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-03 — M5 두 번째 묶음 기반: 공용 파일·프로필 v2·카탈로그·껍데기

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.3(추가 맵), §9.1~9.5(상품 원칙·시즌 한정·코드), §10(UI), §11.4(맵 인터페이스), §11.5(저장), §11.7(관리자). **GDD는 사용자 확정 전이라 고치지 않았어요** — 바뀔 절은 `docs/planner/m5-plan.md`.
- 레퍼런스: [`docs/REFERENCE-m5-maps.md`](../REFERENCE-m5-maps.md), [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) 8절, [`docs/REFERENCE-console-ui.md`](../REFERENCE-console-ui.md)
- 담당 개발 worktree: **main (순차, 단계 0)**. 이 스펙이 머지·push된 뒤에 단계 1 worktree를 만들어요 (m4-01과 같은 방식).
- 공용 파일 수정 담당: **이 스펙** — `shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/Attributes.luau`, `shared/maps/init.luau`, `shared/maps/MapTypes.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`. 단계 1 스펙들은 이 파일들을 **고치지 않아요**(필요하면 결정 기록에 적고 사용자에게 알림).
- **이 스펙이 고치는 파일**
  - 공용: 위 8개
  - 서버 한두 줄: `src/server/MatchService.luau`(강제 플랜 풀 = `Maps.allInfos()`, 201행 근처 한 줄), `src/server/DataService.luau`(`setViewExtra` 추가), `src/server/RobuxShopService.luau`(`canRequest`에 `now` 넘기기 한 줄)
  - 공유 순수 로직·데이터: `src/shared/ProfileSchema.luau`, `src/shared/ProfileLogic.luau`, `src/shared/Skins.luau`, `src/shared/SushiBody.luau`(자리 표시 생김새만), `src/shared/ShopLogic.luau`(새 스킨에서 에러 안 나게만, 필요하면), `src/shared/ReceiptLogic.luau`(`canRequest`에 판매 기간 확인만), `src/shared/RewardLogic.luau`(새 이유의 토스트 문구만), `src/shared/SfxCues.luau`, `src/shared/SfxLibrary.luau`
  - 새 파일: `src/shared/Seasons.luau`, `src/shared/FxCatalog.luau`, `src/client/PriceCache.luau`, 맵 껍데기 3개 `src/shared/maps/IkuraBombs.luau`·`TempuraPot.luau`·`DessertFridge.luau`, 서비스 껍데기 `src/server/OfferService.luau`·`src/server/CodeService.luau`, 컨트롤러 껍데기 `src/client/ui/OfferController.luau`·`src/client/ui/CodeController.luau`·`src/client/ui/ChatTagController.luau`·`src/client/input/IceController.luau`
  - 테스트: `tests/profile-logic.spec.luau`(추가), `tests/skins.spec.luau`(개수·새 규칙), `tests/seasons.spec.luau`(새), `tests/fx-catalog.spec.luau`(새), `tests/maps.spec.luau`(풀 9개·`inPool`), 그 밖에 스킨 개수·cue 목록을 고정해 둔 기존 테스트의 기대값

## 목표
M5 두 번째 묶음(새 맵 3개, 시즌 이벤트, 상품, 연출 팩, 코드, 관리자 명령, 콘솔 UI)이 **서로 다른 파일만 고치며 병렬로** 개발될 수 있게, 여러 스펙이 같이 쓰는 공용 파일·프로필 모양·카탈로그·빈 껍데기를 한 번에 만든다. 플레이어가 보기에 달라지는 것은 거의 없다(새 맵은 아직 랜덤 판에 안 나옴).

## 범위
- 포함:
  1. **맵 풀 `inPool` 플래그** (`MapTypes`, `maps/init`)
     - `MapModule.inPool: boolean?` — `false`면 랜덤 판(`Maps.infos()`)에 안 나오고, `Maps.get`·디버그 강제 플랜(`forceMapPlan`)으로만 돌아요. nil·true면 지금처럼 풀에 들어가요.
     - `MapTypes.validate`: `inPool`이 nil도 boolean도 아니면 `"{id}: inPool must be a boolean"`.
     - `Maps.infos()`는 `inPool ~= false`인 맵만. `Rules.resolveForcedPlan`에 넘기는 풀은 **모든 맵**(껍데기 포함) — `Maps.allInfos()`를 추가해 MatchService가 강제 플랜에 그걸 쓰게(이 한 줄은 MatchService 수정이지만 m5-11과 겹치지 않게 이 스펙에서 해요).
     - 왜: 단계 1 동안 main을 퍼블리시해도 미완성 맵이 랜덤 판에 안 나오게. 각 맵 스펙이 끝나면 **자기 맵 모듈의 `inPool = false` 줄만 지워요**(공용 파일 수정 없음).
  2. **새 맵 껍데기 3개** (`inPool = false`, m4-01 껍데기처럼 회색 박스로 끝까지 돌 수 있게)
     | id | 모듈 | kind | displayName | rule (라운드 소개 한 줄) |
     |---|---|---|---|---|
     | `ikura-bombs` | `IkuraBombs.luau` | Final | 연어알 폭탄 접시 | 떨어지는 연어알 폭탄을 피해 마지막까지 버텨요! |
     | `tempura-pot` | `TempuraPot.luau` | Survival | 튀김 냄비 탈출 | 차오르는 기름을 피해 위로! 튀는 기름도 조심! |
     | `dessert-fridge` | `DessertFridge.luau` | Race | 디저트 냉장고 | 미끄러운 얼음을 건너 냉장고 문까지 달려요! |
     - 껍데기 build: 평평한 판 + `Spawns` 24개(+ Race는 `FinishLine`). start: 낙하 판정(판 아래 25), Race는 결승선 통과. **`ikura-bombs`는 Final이라 `overtime`이 필수** — 껍데기 overtime은 판을 `collapseDuration`에 한 번에 없애요(CanCollide false + 투명).
     - id·kind·displayName·rule은 이 스펙이 확정(맵 스펙은 안 바꿈). 문구 수정이 필요하면 맵 스펙 결정 기록에.
  3. **프로필 v2** (`ProfileSchema.VERSION = 2`, `ProfileLogic.migrate`)
     ```lua
     -- Profile에 추가 (v1 프로필은 migrate가 빈 값으로 채움)
     redeemedCodes: { [string]: number },   -- 정규화한 코드 → 쓴 시각(os.time) (m5-10)
     eventTokens: { [string]: number },     -- 이벤트 id → 모은 이벤트 재화 (m5-07)
     ownedFx: { [string]: boolean },        -- 가진 연출 id (m5-08/m5-09)
     equippedFx: { Elimination: string?, Victory: string? }, -- 입은 연출 (가진 것만)
     boughtOffers: { [string]: number },    -- 한 번만 사는 상품 id → 산 시각 (스타터 팩·세트, m5-08)
     ```
     - migrate 정리 규칙: 키는 문자열, 값은 0 이상 유한 숫자(코드·토큰·시각)는 정수로 내림, 잘못된 항목은 버리고 notes에 한 줄. `ownedFx` 값은 `true`만. `equippedFx`의 각 칸은 **가진 연출이면서 `FxCatalog`에서 그 칸(slot)의 연출**일 때만 남기고 아니면 nil. `redeemedCodes`는 최근 200개만(오래된 것부터 지움, 상수 `ProfileSchema.MAX_REDEEMED_CODES = 200`). 모르는 칸 보존·미래 버전 저장 안 함은 지금 그대로.
     - v1 → v2 마이그레이션은 칸 추가뿐(기존 값 그대로). `version = 2`로 저장.
  4. **ProfileView 확장** (`Types.ProfileView`, `ProfileSchema.toView(profile, persistent, extra?)`)
     ```lua
     eventTokens: { [string]: number },     -- 그대로 복사
     ownedFx: { string },                   -- 이름순
     equippedFx: { Elimination: string?, Victory: string? },
     boughtOffers: { string },              -- 이름순
     vip: boolean,                          -- extra.vip (게임 패스 확인 결과, 저장 안 함 — m5-08이 채움). 없으면 false
     ```
     `toView`의 셋째 인자 `extra: { vip: boolean }?`를 추가하고, 지금 호출하는 곳(DataService)은 그대로 두면 `vip = false`. m5-08이 VIP 확인 결과를 넘기게 바꿔요(그 호출 수정은 m5-08 범위 — DataService에 `setViewExtra(player, extra)` 같은 작은 API를 이 스펙이 만들어 두면 m5-08은 DataService를 안 고쳐도 돼요. **기본값: 이 스펙이 `DataService.setViewExtra(player, { vip = boolean })`를 만들고, 호출하면 ProfileUpdated를 다시 보냄**).
  5. **스킨 카탈로그 확장** (`Skins.luau`)
     - `Skin`에 선택 필드: `season: string?`(이벤트 id), `tokens: number?`(이벤트 재화 가격), `vipOnly: boolean?`.
     - `Skins.validate` 규칙 추가: 기본 스킨이 아니면 `robux`·`tokens`·`vipOnly` 중 **정확히 하나**의 얻는 길(코인은 지금처럼 일반·레어에 추가로 가능). `tokens`가 있으면 `season`이 있어야 하고 `Seasons.get(season)`이 있어야 함. `season`이 있으면 `coins`는 없어야 함. `vipOnly`면 `season`·`coins`·`robux` 없음.
     - 새 스킨 5종 (생김새는 m5-07이 만들고, 이 스펙은 자리 표시만):
       | id | 이름 | tier | 얻는 길 | season | order |
       |---|---|---|---|---|---|
       | `pumpkin-sushi` | 호박 초밥 | Epic | robux 99 | `halloween-2026` | 17 |
       | `ghost-tamago` | 유령 계란초밥 | Rare | tokens 80 | `halloween-2026` | 18 |
       | `santa-shrimp` | 산타 새우 | Epic | robux 99 | `christmas-2026` | 19 |
       | `tree-maki` | 트리 마키 | Rare | tokens 80 | `christmas-2026` | 20 |
       | `vip-gold-tamago` | 금박 계란초밥 | Legendary | vipOnly | — | 21 |
       대사(`speech`)는 각 2줄 — 호박 "호박 맛이 달콤해~"/"트릭 오어 트릿!", 유령 "부우~ 놀랐지?"/"계란도 유령이 될 수 있어", 산타 새우 "메리 크리스마스!"/"선물 배달 왔어요~", 트리 마키 "반짝반짝 트리 마키!"/"오이가 트리가 됐어", 금박 "반짝이는 VIP 계란!"/"금박이 살살 녹아~".
     - 탈의실이 새 스킨(로벅스·코인 가격이 없는 재화·VIP 스킨)에서 에러 없이 열리게만: `ShopLogic.cardState`가 얻는 길이 없는 미보유 스킨을 비활성 "곧 열려요"로 돌려주게(필요하면 최소 수정 — 진짜 카드 상태는 m5-07). 관리자 미리보기 패널은 스킨 목록을 그대로 따라감.
     - `SushiBody`: 새 id 5개에 **자리 표시 레이아웃**(계란초밥과 같은 모양, 토핑 색만 다르게: 주황·흰색·빨강·초록·금색)을 넣어 "모든 스킨에 레이아웃이 있다" 테스트가 통과하게. 진짜 생김새는 m5-07.
  6. **시즌 카탈로그 `Seasons.luau`** (순수, Roblox API 없음)
     ```lua
     export type Event = { id: string, name: string, startsAt: number, endsAt: number, -- UTC unix 초, [startsAt, endsAt)
         token: { name: string, icon: string } }
     Seasons.LIST: { Event }
     Seasons.get(id): Event?
     Seasons.current(now): Event?            -- now에 진행 중인 이벤트 (겹치면 startsAt이 늦은 것)
     Seasons.isActive(id, now): boolean
     Seasons.skinOnSale(skin, now): boolean  -- season 없는 스킨은 true, 있으면 그 이벤트가 진행 중일 때만
     Seasons.daysLeft(id, now): number?      -- 끝까지 남은 날(올림, 진행 중일 때만) — 화면은 날짜로만 보여요
     Seasons.validate(list): (boolean, { string })  -- id 겹침 없음, startsAt < endsAt, 토큰 이름·아이콘 있음
     ```
     | id | name | 기간 (UTC) | token |
     |---|---|---|---|
     | `halloween-2026` | 할로윈 초밥 축제 | 2026-10-16 00:00 ~ 2026-11-06 00:00 (`1792108800` ~ `1793923200`) | `{ name = "사탕", icon = "🍬" }` |
     | `christmas-2026` | 크리스마스 초밥 축제 | 2026-12-11 00:00 ~ 2027-01-08 00:00 (`1796947200` ~ `1799366400`) | `{ name = "별", icon = "⭐" }` |
     - "지금 시각"은 서버 `os.time()`. Studio에서 기간 밖을 시험할 수 있게 `Config.DEBUG.eventNow`(unix 초, Studio에서만 적용)를 둬요. 순수 함수는 now를 인자로 받아요.
  7. **연출 카탈로그 `FxCatalog.luau`** (순수)
     ```lua
     export type Slot = "Elimination" | "Victory"
     export type Fx = { id: string, slot: Slot, displayName: string, order: number }
     FxCatalog.LIST = {
         { id = "cat-customer", slot = "Elimination", displayName = "고양이 손님", order = 1 },
         { id = "fireworks", slot = "Victory", displayName = "불꽃놀이", order = 2 },
     }
     FxCatalog.get(id): Fx?    FxCatalog.bySlot(slot): { Fx }    FxCatalog.validate(list)
     ```
     가격·상품 id는 여기 두지 않아요(m5-08 `Offers.luau`).
  8. **판매 기간 확인** (`ReceiptLogic.canRequest`): `opts.now: number?`를 받아, 스킨에 `season`이 있고 `Seasons.skinOnSale(skin, now)`가 false면 `false, "OffSale"`(문구 "판매 기간이 아니에요"). `tokens`·`vipOnly` 스킨은 로벅스로 못 사요(`robux == nil`이라 지금도 `UnknownSkin` — 문구를 "로벅스로 살 수 없는 스킨이에요"인 `NotRobux`로). RobuxShopService가 `now = os.time()`(Studio면 `DEBUG.eventNow` 우선)을 넘기게 한 줄 고쳐요. **영수증 처리(`process`)는 기간을 보지 않아요** — 기간 끝 직전에 산 결제는 늦게 와도 지급.
  9. **리모트** (`Remotes.luau`, 전부 RemoteFunction, 반환 `ok: boolean, err: string?`; 핸들러는 각 스펙이 만들어요)
     | 이름 | 인자 | 담당 스펙 | 서버 파일 |
     |---|---|---|---|
     | `BuyWithTokens` | `skinId: string` | m5-07 | ShopService |
     | `RequestOfferPurchase` | `offerId: string` | m5-08 | OfferService |
     | `EquipFx` | `slot: string, fxId: string?` (nil·""면 벗기) | m5-08 | OfferService |
     | `RedeemCode` | `code: string` | m5-10 | CodeService |
     | `AdminCommand` | `command: string, args: { any }?` | m5-11 | AdminService |
     머리 주석에 위 줄을 추가. 핸들러가 아직 없는 동안은 껍데기 서비스가 `OnServerInvoke = function() return false, "준비 중이에요" end`.
  10. **Types** — `ProfileView`(4번), `RewardReason`에 `"Code" | "MatchPlayed"` 추가, `RewardGrant`에 `tokens: number?`(이번에 받은 이벤트 재화), `tokenTotal: number?`, `eventId: string?` 추가(`amount`는 코인이고 0일 수 있음), `RoundProgress` 그대로.
  11. **Attributes** (Player, 서버만 달아요): `Vip`(boolean, VIP면 true — 이름표 👑·채팅 태그용, m5-08), `EliminationFx`(string, 입은 탈락 연출 id), `VictoryFx`(string, 입은 우승 연출 id) — 모든 클라이언트가 그 사람의 탈락·우승 연출을 고를 때 읽어요(m5-09). 머리 주석에 "권한·소유 판단에는 쓰지 않음".
  12. **Config**
      ```lua
      -- 이벤트 재화 (m5-07, GDD 9.2 시즌 한정). 이벤트 기간에만 지급
      Config.Events = {
          Tokens = { MatchPlayed = 1, RoundPass = 1, FinalQualify = 2, Win = 5, DailyFirstMatch = 3 },
      }
      -- 코드 보상 (m5-10)
      Config.Codes = {
          RequestCooldown = 2,   -- RedeemCode 요청 간격(초)
          MaxFailures = 8,       -- 이 시간 동안 틀린 코드를 이만큼 넣으면
          FailureWindow = 600,   -- (초) 잠시 막아요
          MaxLength = 20,
      }
      -- Config.DEBUG에 추가 (커밋할 때는 nil / false)
      eventNow = nil :: number?,   -- Studio에서 이벤트 기간 확인용 "지금 시각"(UTC unix 초)
      fakeVipInStudio = false,     -- Studio에서 게임 패스 없이 VIP로 (m5-08)
      ```
      상품 가격은 Config가 아니라 `Offers.luau`(m5-08), 코드 목록은 서버 전용 `CodeConfig.luau`(m5-10).
  13. **효과음 cue** (`SfxCues`·`SfxLibrary`, id 없음 = 무음, 사용자가 고를 때까지): `IkuraPop`(연어알 폭탄 터짐), `OilSplash`(기름 튐), `FanGust`(냉장고 송풍구), `JellyBoing`(젤리 튕김) — 이 넷은 맵 소리(`MapSfx`)로 쓸 수 있게 기존 맵 cue와 같은 목록에. `TokenGet`(이벤트 재화 받음), `CodeRedeemed`(코드 성공), `CatMeow`(고양이 손님 탈락 연출), `Fireworks`(불꽃놀이 우승 연출)은 일반 효과음 목록에.
  14. **토스트 문구** (`RewardLogic` 이유 → 글씨): `Code` = "코드 보상", `MatchPlayed` = "판 참가". 이벤트 재화는 코인 토스트 옆에 "+N 🍬" 식으로(아이콘은 `Seasons.get(eventId).token.icon`) — 표시 코드 수정은 m5-07(CoinController)이에요. 이 스펙은 문구 표만.
  15. **가격 캐시 `client/PriceCache.luau`** (지역 가격 준비, 참고 REFERENCE 8.4)
      ```lua
      PriceCache.product(productId: number, fallback: number): number   -- MarketplaceService:GetProductInfo(id, Enum.InfoType.Product).PriceInRobux
      PriceCache.pass(passId: number, fallback: number): number         -- InfoType.GamePass
      PriceCache.changed: RBXScriptSignal-like                           -- 값을 받아 오면 알림 (화면 다시 그리기)
      ```
      처음 부르면 fallback을 돌려주고 백그라운드로 한 번 받아 와서 캐시(실패하면 fallback 유지, 다시 시도 안 함). 쓰는 곳은 m5-07(탈의실)·m5-08(상품 창). 이 스펙은 모듈만.
  16. **껍데기 서비스·컨트롤러 등록**
      - 서버 `init.server.luau`: `OfferService`(m5-08), `CodeService`(m5-10)를 `AdminService` 앞에 등록. 둘 다 `init()`에서 자기 리모트에 "준비 중이에요" 핸들러, `start()` 빈 함수.
      - 클라이언트 `init.client.luau`: `ui.OfferController`, `ui.CodeController`, `ui.ChatTagController`, `input.IceController`를 등록(빈 `start(gui)`). `BuyWithTokens`·`EquipFx`·`AdminCommand`는 기존 컨트롤러(Shop·Admin)가 m5-07·m5-11에서 붙여요.
- 제외:
  - 각 기능의 실제 동작(맵 규칙, 이벤트 재화 지급, 상품 판매, 코드 검증, 관리자 명령, 콘솔 UI) — m5-04~m5-12.
  - 새 스킨의 진짜 생김새, 연출 비주얼.
  - GDD 수정.

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `MapTypes.validate`가 `inPool = "x"`인 맵에 에러 문자열, `inPool = false`·nil인 맵에 nil. 맵 9개 전부 validate 통과, `ikura-bombs`는 `overtime`이 함수다.
- [ ] AC2: `Maps.infos()`에 껍데기 3개가 **없고**(6개), `Maps.allInfos()`에는 9개. `Rules.resolveForcedPlan({ "dessert-fridge", "tempura-pot", "ikura-bombs" }, Maps.allInfos())`가 그 순서의 플랜을 돌려준다. `Rules.buildRoundPlan`을 `Maps.infos()`로 1,000번 돌려도 껍데기 id가 안 나온다.
- [ ] AC3: `ProfileLogic.migrate`에 v1 프로필(새 칸 없음)을 넣으면 version 2, 새 칸 5개가 빈 표, 기존 코인·스킨·결제 id 그대로. 잘못된 값(`eventTokens = { a = -1, [5] = 3, b = "x", c = 2.7 }`)은 `{ c = 2 }`만 남고 notes가 생긴다. `equippedFx = { Elimination = "fireworks" }`(칸이 다름)·가지지 않은 연출은 nil이 된다. `redeemedCodes` 250개는 시각이 큰 200개만 남는다.
- [ ] AC4: `ProfileSchema.toView(p, true)`에 새 칸이 있고 `vip == false`, `toView(p, true, { vip = true })`면 `vip == true`. `ownedFx`·`boughtOffers`는 이름순 목록.
- [ ] AC5: `Skins.validate(Skins.LIST)`가 통과하고 스킨이 21개(order 1~21). 규칙 위반 표본 — `tokens`인데 `season` 없음, `season` 스킨에 `coins`, `vipOnly`에 `robux`, 얻는 길이 둘(robux + tokens), 모르는 season — 이 각각 문제 목록에 잡힌다.
- [ ] AC6: `Seasons.validate(Seasons.LIST)` 통과. `Seasons.current(1792108800)`는 할로윈, `current(1793923200)`(끝 시각)은 nil, `current(1796947200)`은 크리스마스. `skinOnSale(pumpkin, 1792108799) == false`, `(pumpkin, 1792108800) == true`, 시즌 없는 스킨은 언제나 true. `daysLeft("halloween-2026", 1792108800) == 21`.
- [ ] AC7: `FxCatalog.validate` 통과, `bySlot("Elimination")`은 `cat-customer`만.
- [ ] AC8: `ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true, now = 1792108799 })`는 `false, "OffSale"`, `now = 1792108800`이면 true. `canRequest("ghost-tamago", ...)`는 `false, "NotRobux"`. 기존 canRequest 테스트(now 없음)는 그대로 통과.
- [ ] AC9: `SfxCues`에 새 cue 8개가 있고, `SfxLibrary`의 모든 cue가 `SfxCues`에 있다(기존 테스트 방식). `RewardLogic` 문구 표에 `Code`·`MatchPlayed`가 있다.
- [ ] AC10: 검증 5단계 통과 (rojo build, stylua, selene, lune run tests, luau-lsp 타입 검사). 못 돌린 단계는 보고에 적는다.

### Studio 확인 (사용자 확인 필요)
- [ ] AC11: Play Solo로 로비에 들어가면 지금과 똑같이 보이고(새 버튼 없음), 탈의실에 새 스킨 5개가 자리 표시 모양으로 보인다(시즌 스킨은 m5-07 전까지 "곧 열려요"/비활성이어도 됨). Output에 에러 없음.
- [ ] AC12: `Config.DEBUG.forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }`로 혼자 한 판이 껍데기 맵 3개를 끝까지 돈다(결승 껍데기는 연장전에 판이 사라져 떨어지고 우승). **확인 뒤 nil**.
- [ ] AC13: 저장 켠 Studio(`persistDataInStudio = true`, API 접근 허용)에서 M4 때 저장한 v1 프로필이 코인·스킨을 그대로 가진 채 v2로 저장된다 (사용자 작업 C1 뒤, 선택).

## 공용 파일 변경
- `shared/Config.luau`: `Config.Events`, `Config.Codes`, `DEBUG.eventNow`, `DEBUG.fakeVipInStudio`.
- `shared/Remotes.luau`: RemoteFunction 5개 (`BuyWithTokens`, `RequestOfferPurchase`, `EquipFx`, `RedeemCode`, `AdminCommand`) + 머리 주석.
- `shared/Types.luau`: `ProfileView` 새 칸, `RewardReason` 2개, `RewardGrant`의 `tokens?`·`tokenTotal?`·`eventId?`.
- `shared/Attributes.luau`: `Vip`, `EliminationFx`, `VictoryFx`.
- `shared/maps/MapTypes.luau`: `inPool?` + validate.
- `shared/maps/init.luau`: 껍데기 3개 등록, `Maps.infos()` 필터, `Maps.allInfos()`.
- `src/server/init.server.luau`: `OfferService`, `CodeService`.
- `src/client/init.client.luau`: `OfferController`, `CodeController`, `ChatTagController`, `IceController`.
- `default.project.json`, `rokit.toml`: 바꾸지 않음.

## 사용자 작업 (스펙을 막지 않음)
- 효과음 8개 id 고르기 (USER-TODO A2에 추가): `IkuraPop`, `OilSplash`, `FanGust`, `JellyBoing`, `TokenGet`, `CodeRedeemed`, `CatMeow`, `Fireworks`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · 단계 1 동안 미완성 맵이 랜덤 판에 나오는 문제 · **`inPool = false` 껍데기**로 등록하고 각 맵 스펙이 자기 모듈의 그 줄만 지움 → 공용 파일(`maps/init`)을 병렬로 안 고침. m4-01은 껍데기를 풀에 바로 넣었지만, 이번엔 사용자가 퍼블리시를 시작할 수 있는 시점이라 막아 둠 · planner
- 2026-10-08 · 새 스킨·시즌·연출 데이터를 기반 스펙에서 · 탈의실(m5-07)·상품(m5-08)·연출(m5-09)·관리자(m5-11)가 모두 같은 id를 읽어서, 데이터(카탈로그)는 한 곳이 먼저 확정. 생김새·비주얼은 각 스펙 · planner
- 2026-10-08 · 이벤트 기간 기본값 · 할로윈 **10/16~11/6(3주)**, 크리스마스 **12/11~1/8(4주)**, UTC. 근거: 로블록스 시즌 이벤트 3~5주, 할로윈 10월 초~중순 시작(MM2 10/18, Adopt Me 10/3, Epic Minigames 번들 10/17 생성), 크리스마스 번들 11월 말 생성 — REFERENCE-roblox-monetization 8.1·8.2. 지금(10/8)부터 개발·퍼블리시 시간을 고려해 할로윈 시작을 10/16으로. **기본값으로 진행, 사용자 수정 가능** (`Seasons.luau` 숫자만) · planner
- 2026-10-08 · 시즌 무료 스킨 등급·가격 · Rare 색, 이벤트 재화 80개(약 25~30판). 근거: 레어 코인 해금 900코인 ≈ 30판(GDD 9.4)과 비슷한 노력, MM2·Adopt Me의 이벤트 재화 교환 구조 — REFERENCE 8.2·8.6. **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · VIP 상태 저장 · 저장하지 않음(게임 패스는 Roblox가 소유를 기억). 화면 표시용으로 ProfileView에만 넣고 `DataService.setViewExtra`로 m5-08이 채움 · planner
- 2026-10-08 · 기간 판매 확인 위치 · 결제 창을 **열 때만**(`canRequest`), 영수증 처리 때는 안 봄 — 기간 끝 직전 결제가 늦게 와도 돈만 빠지고 스킨이 안 들어오는 일이 없게(GDD 13 "결제했는데 스킨이 안 들어옴") · planner
- 2026-10-08 · 코드 목록 위치 (공개 저장소라서) · GitHub 저장소가 공개라서 실제 코드 목록은 **커밋하지 않음**. 서버 전용 로더 `src/server/CodeConfig.luau`(커밋)가 같은 폴더의 로컬 파일 `src/server/CodeList.luau`(`.gitignore`)를 읽고, 없으면 빈 목록 + 경고. 커밋되는 건 빈 예시 `src/server/CodeList.example.luau`뿐. 테스트는 가짜 목록. 키·토큰 같은 비밀 값도 저장소에 넣지 않음(UserId·상품 id·가격은 공개 가능) · developer (메인 세션 지시)
- 2026-10-08 · 실서버 관리자 테스트 명령 · **사용자 결정: 실서버에는 경제·판정 명령이 없음(설정으로도 못 켬)**. `LiveTestCommands` 같은 설정을 만들지 않음. `AdminLogic.commandTier`·`canRun(tier, isStudio, persistInStudio)`(실서버 = Info만)과 AdminService `AdminCommand` 핸들러 틀(관리자 → 간격 → 등급 → Studio 확인 뒤에만 `runCommand`)을 이 스펙이 만들어 둠 — m5-11은 `runCommand`만 채움 · 사용자 (메인 세션 전달)
- 2026-10-08 · 할로윈 기간 · 사용자 확정: 10/16 시작 그대로 · 사용자
- 2026-10-08 · 서버 "지금 시각" · `Seasons.now(isStudio, Config.DEBUG.eventNow, os.time())` 순수 함수로 한 곳에 둠 (RobuxShopService가 쓰고, m5-07·m5-10도 같은 함수를 쓰면 됨) · developer
- 2026-10-08 · 탈의실의 재화·VIP 스킨 카드 · `ShopLogic.cardState`에 `kind = "Soon"`(비활성 "곧 열려요") 추가 — 로벅스 가격이 없는 미보유 스킨. 진짜 카드는 m5-07·m5-08 · developer
- 2026-10-08 · 새 테스트 위치 · 스펙이 적은 기존 테스트 파일(profile-logic·maps 등) 대신 새 `tests/m5-03-foundation.spec.luau`에 모음 (단계 1 worktree와 겹치지 않게). `seasons.spec`·`fx-catalog.spec`은 스펙대로 새 파일 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 2026-10-08 — 구현 완료 (main, 커밋 6c7db78 · 222e99e · f53c7c1)
**검증 5단계 통과**: rojo build OK, stylua --check OK, selene 0 errors / 0 warnings, lune 1133 passed / 0 failed (기존 1090 + 새 43), luau-lsp 타입 검사 오류 0.

**바뀐 파일**
- 공용: `shared/Config.luau`(Events, Codes, DEBUG.eventNow·fakeVipInStudio), `shared/Remotes.luau`(RemoteFunction 5개 + 머리 주석), `shared/Types.luau`(ProfileView 새 칸, RewardReason Code·MatchPlayed, RewardGrant tokens·tokenTotal·eventId), `shared/Attributes.luau`(Vip, EliminationFx, VictoryFx), `shared/maps/MapTypes.luau`(inPool), `shared/maps/init.luau`(껍데기 3개, infos 필터, allInfos), `server/init.server.luau`, `client/init.client.luau`
- 서버: `MatchService`(강제 플랜 = allInfos 한 줄), `DataService`(setViewExtra), `RobuxShopService`(canRequest에 now), `AdminService`(AdminCommand 틀 — 사용자 결정, 아래)
- 공유: `ProfileSchema`(VERSION 2, MAX_REDEEMED_CODES, ViewExtra, toView extra), `ProfileLogic`(v2 정리), `Skins`(season·tokens·vipOnly, 새 5종, 규칙), `SushiBody`(자리 표시 5개), `ShopLogic`(카드 "Soon"), `ReceiptLogic`(OffSale·NotRobux, opts.now), `RewardLogic`(문구), `SfxCues`·`SfxLibrary`(cue 8개, 무음), `AdminLogic`(commandTier·canRun)
- 새 파일: `shared/Seasons.luau`(+ `Seasons.now`), `shared/FxCatalog.luau`, `client/PriceCache.luau`, `shared/maps/IkuraBombs.luau`·`TempuraPot.luau`·`DessertFridge.luau`, `server/OfferService.luau`·`CodeService.luau`·`CodeConfig.luau`·`CodeList.example.luau`, `client/ui/OfferController.luau`·`CodeController.luau`·`ChatTagController.luau`, `client/input/IceController.luau`
- 테스트: 새 `tests/m5-03-foundation.spec.luau`·`seasons.spec.luau`·`fx-catalog.spec.luau`, 기대값 갱신 `skins`·`shop-logic`·`m4-foundation`(리모트 26개, VERSION 2)·`m4-14-qa`(Seasons 의존)·`m4-07-data-qa`(미래 버전 표본 2.5)·`camera-priority`(속성 16·cue 41)·`m4-12-hardening`(PriceCache 표는 카탈로그 크기)
- `.gitignore`: `src/server/CodeList.luau`

**단계 1 스펙이 쓸 인터페이스**
- 맵: 각 맵 모듈의 `inPool = false` 줄만 지우면 랜덤 풀에. 강제 플랜은 `Maps.allInfos()`.
- 프로필 v2 칸: `redeemedCodes`, `eventTokens`, `ownedFx`, `equippedFx`, `boughtOffers` (`ProfileSchema.Profile`). 화면용 VIP는 `DataService.setViewExtra(player, { vip = bool })`.
- `Seasons.get/current/isActive/skinOnSale/daysLeft/now/validate`, `FxCatalog.get/bySlot/isSlot/SLOTS/validate`, `PriceCache.product/pass/changed:Connect`.
- 리모트 핸들러: `RequestOfferPurchase`·`EquipFx`(OfferService 껍데기, "준비 중이에요"), `RedeemCode`(CodeService 껍데기), `AdminCommand`(AdminService `runCommand`만 채우면 됨), `BuyWithTokens`는 **아직 핸들러 없음**(m5-07 ShopService가 붙임 — 그 전까지 클라이언트가 부르지 않음).
- 코드 목록: `CodeConfig.load()` → `{ CodeConfig.CodeEntry }` (CodeService.init에서 이미 읽음). 검증은 m5-10 `CodeLogic.validateConfig`.

**Studio 확인 방법**
- AC11: Play Solo → 로비가 전과 같고 새 버튼 없음. 탈의실에 새 스킨 5개(호박·유령·산타 새우·트리 마키·금박 계란)가 계란초밥 모양 + 토핑 색만 다르게 보임. 유령·트리·금박은 "곧 열려요"(비활성), 호박·산타 새우는 "R$ 99 — 곧 열려요". Output 에러 없음 (`[CodeConfig] no src/server/CodeList.luau ...` 경고 한 줄은 정상 — 목록 파일을 만들면 사라짐).
- AC12: `Config.DEBUG.forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }` → 혼자 Play: 회색 판 Race(결승선 통과) → Survival(60초 버팀) → Final(90초에 연장전, 20초 뒤 판이 사라져 떨어지고 우승). 확인 뒤 nil.
- AC13 (선택, 저장 켠 Studio): M4 때 프로필이 코인·스킨 그대로 v2로 저장.
- 덤: `Config.DEBUG.eventNow = 1792108800` + `fakeRobuxInStudio = true`면 호박 초밥 결제 흐름이 열리고, `eventNow = 1792108799`면 서버가 "판매 기간이 아니에요"(m5-07 전에는 탈의실 버튼이 꺼져 있어 명령줄로만 확인 가능). 확인 뒤 되돌리기.

**남은 이슈**
- `BuyWithTokens` 핸들러 없음(m5-07). 클라이언트가 지금 부르는 곳 없음.
- 껍데기 Final의 연장전은 `collapseDuration` 끝에 판을 한 번에 없앰(스펙대로). m5-04가 고리 단위 붕괴로 바꿈.
