status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-26 — 다국어(현지화): 키 기반 번역 + 영어

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §11.8 "현지화"(이 스펙과 함께 추가), §10 UI 목록
- 담당 개발 worktree: `m5-i18n` (Rojo 포트 34887)
- 공용 파일 수정 담당: **이 스펙** — `shared/Types.luau`, `shared/Remotes.luau`(주석·반환 계약만, 리모트 추가 없음), `src/client/init.client.luau`. `default.project.json`·`Config.luau`·`Attributes.luau`(1단계)는 바꾸지 않는다.
- 의존·조율: m5-25(캐릭터 스펙, 병렬)가 `src/client/fx/CharacterFxController.luau`·`src/shared/SushiBody.luau`를 고친다 → 이 두 파일은 **1단계에서 건드리지 않는다**(2단계). m5-24(맵 아트, 병렬)가 맵 모듈을 고친다 → 이 스펙은 맵 파일을 고치지 않고 CSV만 맞춘다(아래 "데이터 동기화").

## 목표
로블록스 언어가 영어인 플레이어는 게임의 모든 화면·안내·서버 메시지를 **자연스러운 영어**로 보고, 그 밖의 언어 플레이어는 Roblox 자동 번역(우리가 올린 키 문구 기준)으로, 그것도 없으면 영어로 본다. 한국어 플레이어 화면은 지금과 똑같다.

## 배경 (Roblox 사실 — 2026-10-13 확인, 출처는 결정 기록)
- 게임마다 **원본 언어는 하나** — 우리는 한국어(`ko`).
- 자동 텍스트 수집(ATC) + 자동 번역은 `AutoLocalize`가 켜진 GUI 글씨를 18개 언어로 번역한다. 직접 넣은 번역이 자동 번역보다 우선하고, `AutoLocalize = false`인 객체는 빠진다.
- 키 기반 번역: `LocalizationService:GetTranslatorForPlayerAsync(player)`(비동기, 실패할 수 있어 `pcall` 권장) → `Translator:FormatByKey(key, args)`. 인자는 `{이름}` 자리표시자 + 테이블.
- 클라우드 현지화 표에 CSV를 올리면(Key·Context·Example 열 포함) **번역이 없는 언어는 자동 번역 대상**이 되고, 우리가 적은 번역은 수동 번역으로 잠긴다.
- Rojo는 `.csv` 파일을 `LocalizationTable`로 만든다(Roblox 내보내기 형식: `Key,Source,Context,Example,<언어>…`).
- **확인 못 함**: 플레이스 안 `LocalizationService` 아래 표와 클라우드 표에 같은 키가 있을 때 어느 쪽이 이기는지, `LocalizationService` 자식이 클라이언트에 복제되는지(API 문서에 서비스가 "Not Replicated"로 표기), 자동 번역이 `{자리표시자}`를 항상 보존하는지, `FormatByKey`가 없는 키에서 오류를 내는지 원본을 돌려주는지. → 아래 설계는 이 넷 중 어느 쪽이어도 깨지지 않게 했다.

## 설계

### 1. 문구 카탈로그 한 곳: `src/shared/Localization/Strings.csv`
- Rojo가 `ReplicatedStorage.Shared.Localization.Strings`(`LocalizationTable`)로 만든다. `default.project.json`은 바꾸지 않는다(`src/shared`가 이미 매핑됨).
- 열: `Key,Source,Context,Example,en`. `Source` = 한국어 원문, `en` = 우리가 쓴 영어. 다른 언어 열은 만들지 않는다(자동 번역 몫).
- `Context`: 어디에 보이는 글씨인지 짧게(예: `lobby button`, `server error toast`) — 자동 번역 품질에 쓰인다. `Example`: 자리표시자가 있으면 예시 값(예: `name=Mina; count=3`).
- **왜 `LocalizationService` 밑이 아니라 `ReplicatedStorage`인가**: (1) ReplicatedStorage는 클라이언트 복제가 확실하다 — 번역기를 못 받을 때 쓰는 폴백 카탈로그를 클라이언트가 반드시 읽어야 한다. (2) 같은 키가 플레이스 표·클라우드 표에 둘 다 있을 때의 우선순위가 문서에 없다 — 키는 클라우드 표(사용자가 CSV 업로드)에만 두고 플레이스 안 표는 폴백 전용으로 쓰면 충돌이 없다. (3) lune 테스트가 같은 파일을 직접 읽는다.
- 같은 CSV 파일을 사용자가 Creator Dashboard → 현지화 → **Upload CSV**로 클라우드 표에 올린다(USER-TODO). 그러면 `GetTranslatorForPlayerAsync` 번역기가 키를 알게 되고, 영어는 우리 번역(수동, 잠김), 나머지 언어는 자동 번역이 된다. 업로드 전·Studio에서는 폴백 카탈로그가 한국어·영어를 맡는다.

### 2. 키 규칙
- 형식: 점으로 나눈 영어 id, 정규식 `^[a-z][a-z0-9]*(\.[A-Za-z0-9][A-Za-z0-9_-]*)+$`. 첫 마디는 영역: `common`, `lobby`, `room`, `hud`, `spectate`, `shop`, `offer`, `code`, `coin`, `reward`, `notice`, `place`, `intro`, `cutscene`, `input`, `sfx`, `date`, `map`, `skin`, `tier`, `fx`, `season`, `title`.
- 오류 이유 enum은 그대로 붙인다: `shop.err.NotOwned`, `offer.err.AlreadyVip`, `receipt.err.OffSale`, `code.err.Expired`, `room.err.Full`.
- 데이터에서 나오는 키(동적 키)는 정해진 모양만: `map.<mapId>.name|rule`, `skin.<skinId>.name`, `skin.<skinId>.speech.<n>`(1부터), `tier.<Tier>`, `offer.<offerId>.name|blurb|perk.<n>`, `fx.<fxId>.name`, `season.<eventId>.name|token`, `title.w<wins>`, `reward.reason.<RewardReason>`, `date.month.<1~12>`, `cutscene.line.<group>.<n>`. 동적 키는 `Loc`의 이름 붙은 도우미(`Loc.mapName(id)` 등)만 만든다.
- 키는 **바꾸지 않는다**(클라우드 번역이 키에 붙는다). 문구를 고치면 같은 키의 `Source`/`en`만 고친다. 다른 뜻이 되면 새 키.
- 자리표시자 이름 `{[A-Za-z][A-Za-z0-9]*}`. 서식 지정자(`{n:int}` 등)는 쓰지 않는다 — 숫자는 코드가 문자열로 만들어 넘긴다.

### 3. 순수 모듈 `src/shared/LocalizeLogic.luau` (Roblox API 없음, lune 테스트)
- `isValidKey(key) -> boolean`
- `placeholders(text) -> { string }`(이름순, 중복 제거), `checkRow(row) -> { string }`(문제 목록: 빈 Source·빈 en·자리표시자 불일치·괄호 짝 안 맞음)
- `parseCsv(text) -> ({ Row }, { string })` — 따옴표·쉼표·줄바꿈이 든 칸을 처리. 테스트와 도구 전용(실행 중에는 `LocalizationTable:GetEntries()`를 쓴다).
- `buildCatalog(entries) -> Catalog` — `GetEntries()` 모양(`{ Key, Source, Values = { en = … } }`)에서 키 → `{ ko, en }`.
- `languageOf(localeId) -> string` — `"en-us" → "en"`, `"ko-kr" → "ko"`, 빈 값 → `"ko"`, 소문자.
- `format(template, args) -> (string, boolean)` — `{이름}`을 바꾼다. 없는 인자는 빈 문자열로 바꾸고 둘째 값 `false`. 남는 인자는 무시. 숫자 인자는 `formatNumber`. 인자가 `LocText`면 먼저 같은 언어로 풀어 넣는다(깊이 2까지, 더 깊으면 빈 문자열).
- `choose(input) -> string` — 폴백 사슬(아래 표). 입력: `language`, 번역기 결과(`translated: string?`, `translatorError: boolean`), 카탈로그 행, args.
- `formatNumber(n) -> string` — 정수로 반올림, 1000 이상은 세 자리마다 `,` (`1234567 → "1,234,567"`, `-1500 → "-1,500"`).
- `ordinal(n, language) -> string` — `en`이면 `1st 2nd 3rd 4th 11th 12th 13th 21st 22nd 101st 111th`, 그 밖은 숫자 그대로.
- `isLocText(value) -> boolean` — 서버에서 온 값 검사: `key`가 올바른 문자열이고 `args`가 없거나 `{ [string]: string | number | LocText }`(값 20개 이하, 문자열 200자 이하).
- `text(key, args?) -> LocText` — 서버·순수 로직이 문장 대신 돌려줄 값을 만든다.

**폴백 사슬 (`choose`)**

| 플레이어 언어 | 번역기 결과 | 보이는 글씨 |
|---|---|---|
| `ko` | 무엇이든 | 카탈로그 `Source`를 format |
| `en` | 정상 | 번역기 결과 |
| `en` | 오류·없음·`{…}` 남음 | 카탈로그 `en` → 없으면 `Source` |
| 그 밖(`de` 등) | 정상이고 한국어 원문 format 결과와 **다름** | 번역기 결과 (자동 번역) |
| 그 밖 | 오류·없음·원문과 같음·`{…}` 남음 | 카탈로그 `en` → 없으면 `Source` |
| 아무 언어 | 카탈로그에도 없는 키 | 키 문자열 그대로 + 키마다 한 번 `warn` (테스트가 막으므로 실제로는 안 나와야 함) |

### 4. 클라이언트 `src/client/Loc.luau` (클라이언트 문구의 유일한 출입구)
- `Loc.init()` — `init.client.luau`가 **맨 먼저** 부른다(ProfileStore보다 앞). 카탈로그 표(`Shared.Localization.Strings`)를 `GetEntries()`로 읽어 `LocalizeLogic.buildCatalog`. 그다음 `pcall(GetTranslatorForPlayerAsync, LocalPlayer)`를 최대 3초 기다린다. 실패하면 배경에서 1·2·4초 간격으로 3번 더 시도(그 사이와 그 뒤는 폴백 카탈로그). 언어는 번역기의 `LocaleId`, 없으면 `LocalPlayer.LocaleId`.
- `Loc.t(key, args?) -> string` — `FormatByKey`를 `pcall`로 부르고 `LocalizeLogic.choose`로 고른다.
- `Loc.text(value: LocText | string) -> string` — 서버에서 온 값. `isLocText`면 `t`, 그냥 문자열이면(플레이스 버전이 잠깐 어긋날 때) 그대로.
- 도우미: `Loc.number(n)`, `Loc.place(n)`(`ordinal`), `Loc.mapName(id)`, `Loc.mapRule(id)`, `Loc.skinName(id)`, `Loc.skinSpeech(id, n)`, `Loc.tierName(tier)`, `Loc.offerName/offerBlurb/offerPerk`, `Loc.fxName(id)`, `Loc.seasonName/tokenName(eventId)`, `Loc.titleName(wins)`, `Loc.titleFromName(koName)`(속성에 든 한국어 칭호 → 키, 2단계용), `Loc.date(timestamp)`(`date.monthDay` + `date.month.<n>`, UTC), `Loc.rewardReason(reason)`.
- 언어를 게임 중에 바꾸는 경우는 다루지 않는다(Roblox가 다시 접속시킴). 화면은 만들 때·값이 바뀔 때 `Loc`을 부른다.

### 5. 서버 메시지는 문장이 아니라 `LocText`
- `Types.luau`에 추가:
  ```lua
  export type LocText = { key: string, args: { [string]: string | number | LocText }? }
  export type NoticeKind = "success" | "info" | "error"
  ```
- **리모트 계약 변경** (`Remotes.luau` 주석, 리모트 수 21개 그대로):
  - `CreateRoom`·`JoinRoom`·`JoinByCode`·`QuickJoin`·`LeaveRoom`·`StartRoom`·`EquipSkin`·`BuyWithCoins`·`RequestRobuxPurchase`·`BuyWithTokens`·`RequestOfferPurchase`·`EquipFx`: 오류 자리 `err: string?` → `err: LocText?`(다른 반환값은 그대로).
  - `RedeemCode`: `(ok, message: LocText)`.
  - `Notice(message: LocText, kind: NoticeKind)` — `kind`를 **항상** 보낸다(문구로 색 고르기 폐지).
  - `RewardGranted`는 그대로(`reason` enum → 클라이언트가 `reward.reason.<reason>`).
  - `MatchPhase`의 `mapName`·`rule`은 그대로 두되(한국어, 폴백) 클라이언트는 `mapId`로 `Loc.mapName/mapRule`을 쓴다.
  - **예외**: `AdminPreviewSkin`·`AdminCommand`는 그대로 한국어 문자열(아래 "제외").
- 순수 로직의 문구 표(`ShopLogic`·`OfferLogic`·`ReceiptLogic`·`CodeLogic`·`RoomLogic`의 `MESSAGES`/`message(reason)`)는 `LocText`를 돌려준다(`shop.err.<Reason>`, 모르는 이유는 `common.err.retry`). 화면용 문구 함수(`RewardLogic.toastText/summaryText`, `ShopLogic` 버튼 글씨·`lastDayText`·`EVENT_NOTE`, `OfferLogic` 버튼·알림, `CodeLogic.successMessage`, `VictoryCutsceneLogic` 제목, `EliminationCutsceneLogic` 대사)도 `LocText`를 돌려주고 클라이언트가 `Loc.text`로 푼다.
- 서버 서비스(`RoomService`·`RoomDirectory`·`PlaceService`·`ShopService`·`OfferService`·`RobuxShopService`·`CodeService`)의 `return false, "…"`·`notice(player, "…")`는 전부 `LocalizeLogic.text(key, args)`.
  - 오류 안에 오류가 들어가는 곳(`PlaceService` "원래 방에 들어가지 못했어요: {why}")은 `args = { reason = <LocText> }`.
  - `player:Kick(...)` 2곳: 서버가 같은 카탈로그(`GetEntries`)와 `player.LocaleId`로 영어·한국어 중 하나를 고른다(번역기 호출 없음 — Kick 직전이라 기다리지 않음).
- **기본 방 이름**: 지금은 서버가 `"{DisplayName}의 초밥집"`을 만들어 모두에게 보낸다. 바꿈: `RoomSnapshot`·`RoomListing`에 `nameIsDefault: boolean?` 추가, 기본 이름이면 `name` = 방장 DisplayName, 클라이언트가 `room.defaultName` "{name}의 초밥집" / "{name}'s Sushi Bar"로 보여 준다. 방 만들기 창의 이름 칸 기본값도 같은 키. 다른 서버 방 목록(`RoomDirectoryLogic`)도 같은 필드를 나른다.

### 6. 문장 쓰는 규칙 (한국어 원문 · 영어)
- **조사를 인자에 붙이지 않는다**: `{price}으로 해금`, `R$ {price}로 사기`, `{name}이(가)`처럼 인자 뒤 조사가 인자에 따라 바뀌는 문장은 고쳐 쓴다 — `"🍚 {price} · 해금"`, `"R$ {price} · 사기"`, `"{name}님 우승!"`. `의`·`님`처럼 받침과 무관한 말은 괜찮다.
- **숫자·날짜는 코드가 만든다**: `Loc.number`, `Loc.date`, `Loc.place`. 영어 등수는 서수(`1st`), 한국어는 `{place}등`.
- **복수형 엔진은 만들지 않는다**: 영어도 단수/복수가 갈리지 않게 쓴다 — `"Players left: {count}"`, `"{count}/{max} players"`(최소 4명이라 항상 복수), `"Need {count} more 🍚"`. 1일 수 있는 수에 `player(s)`가 필요하면 문장을 바꾼다.
- 이모지는 문구 안에 그대로 둔다(번역이 위치를 바꿀 수 있게).
- **영어 톤**: 미국 영어, 어린 플레이어가 읽기 쉬운 짧은 문장, 2인칭 현재형("You're out!", "Try again"). 버튼·탭·제목은 Title Case("Quick Join"), 안내·오류 문장은 Sentence case. "kill/die/dead" 같은 말은 쓰지 않는다("eaten", "out" 사용). 한국어를 직역하지 말고 같은 상황에서 영어 게임이 쓰는 말로.
- **길이**: 키에 `.btn`가 들어가면 `en` 16자 이하, `.tab`이면 10자 이하(휴대폰 버튼 폭). 더 긴 영어가 필요하면 그 UI가 `TextScaled`/줄바꿈을 쓰게 하고 길이 예외를 `Context`에 `long-ok`로 적는다.

### 7. 영어 용어집 (CSV `en`은 이 표를 따른다)
| 한국어 | 영어 | 한국어 | 영어 |
|---|---|---|---|
| 초밥 서바이벌 레이스 | Sushi Survival Race | 밥알 코인 🍚 | Rice Coins 🍚 |
| 방 / 방장 | room / host | 공개 / 비공개 | Public / Private |
| 방 코드 | room code | 빠른 참가 / 방 만들기 / 코드로 참가 | Quick Join / Create Room / Join with Code |
| 라운드 / 결승 / 연장전 | Round / Final / Overtime | 통과 / 탈락 / 우승 | qualified / out / win |
| 관전 / 로비로 | Spectate / Back to Lobby | 출발! / 먹혔다! / 잡혔다! | GO! / EATEN! / Grabbed! |
| 탈출 성공! | ESCAPED! | 스시집(우승 연출 간판) | Sushi Bar |
| 다이브 / 잡기 | Dive / Grab | 스킨 / 탈의실 | Skins / Wardrobe |
| 입기 / 입는 중 / 해금 / 한정 | Wear / Wearing / Unlock / Limited | 상점 / 내 연출 | Shop / My Effects |
| 탈락 연출 / 우승 연출 | Elimination Effect / Victory Effect | 코드 / 받기 | Codes / Redeem |
| 이벤트 재화 · 사탕 · 별 | event treats · Candy · Stars | 저장 안 됨 | Not saved |
| 등급 기본·일반·레어·에픽·전설 | Basic · Common · Rare · Epic · Legendary | 칭호 탈출 초밥·전설의 참치·바다의 왕 | Escaped Sushi · Legendary Tuna · King of the Sea |
| 할로윈 초밥 축제 / 크리스마스 초밥 축제 | Halloween Sushi Festival / Christmas Sushi Festival | 소리 켬 / 음악 끔 / 모두 끔 | Sound On / Music Off / All Off |

**맵 이름·규칙 (CSV `en` 확정 문구)**
| id | name | rule |
|---|---|---|
| `rotating-belt` | Spinning Belt | Run against the belt, dodge the chopsticks, and reach the finish! |
| `soy-swamp` | Soy Swamp & Wasabi Hill | Avoid the soy puddles, launch off wasabi pads, and reach the finish! |
| `ramen-rapids` | Ramen Rapids | Ride the broth rapids, hop across chashu and naruto, and reach the finish! |
| `dessert-fridge` | Dessert Fridge | Slide across the slippery ice and race to the fridge door! |
| `bouncy-castle-maze` | Bouncy Maze | Bounce across the squishy floor and find your way out! |
| `lantern-bridge` | Lantern Bridge | Cross the wobbly bridge past the paper lanterns. |
| `hot-plate` | Hot Plate | Tiles vanish after you step on them. Keep moving to survive! |
| `chef-board` | Chef's Cutting Board | Dodge the chopping knife and survive on the shrinking board! |
| `tempura-pot` | Tempura Pot Escape | Climb away from the rising oil! Watch out for splashes! |
| `giant-jenga` | Tumbling Blocks | The floor tips toward the missing blocks. Hang on to the end! |
| `cat-cafe-shelves` | Cat Café Tower | Hop between narrow shelves and hang on. Don't get pushed off! |
| `skewer-showdown` | Skewer Showdown | Jump over the spinning skewers! Only the last one standing escapes. |
| `ikura-bombs` | Roe Bomb Plate | Dodge the falling roe bombs and be the last one standing! |
| `tug-of-war-platform` | Tug-of-War Platform | The platform tips toward the crowd. Keep your balance and survive! |
| `claw-machine-prize` | Inside the Claw Machine | Survive inside the glass box while the claw sweeps by. |

**스킨 이름**: tamago Egg Sushi · salmon Salmon · tuna Tuna · shrimp Shrimp · inari Inari · kappa-maki Cucumber Roll · eel Eel · uni Sea Urchin · ikura Salmon Roe · octopus Octopus · rainbow-roll Rainbow Roll · aburi-salmon Flame Salmon · california-roll California Roll · golden-otoro Golden Tuna Belly · diamond-uni Diamond Urchin · dragon-roll Dragon Roll · pumpkin-sushi Pumpkin Sushi · ghost-tamago Ghost Egg Sushi · santa-shrimp Santa Shrimp · tree-maki Tree Roll · vip-gold-tamago Gold Leaf Egg Sushi · takoyaki Takoyaki · egg-toast Egg Toast · slider-burger Slider Burger · tonkatsu Tonkatsu · cat-sushi Cat Sushi · robo-roll Robo Roll · galaxy-roll Galaxy Roll · softserve-roll Soft Serve Roll · crown-tuna Crown Tuna · unicorn-roll Unicorn Roll.

**상품**: starter-pack Starter Pack / "A bundle for new players" · epic-set Epic Set / "3 Epic skins" · legendary-set Legendary Set / "3 Legendary skins" · fx-cat-customer "Elimination Effect: Cat Customer" / "A cat eats you instead of a customer" · fx-fireworks "Victory Effect: Fireworks" / "Fireworks burst when you win" · vip VIP Pass / "Looks only (no coin boost)", perks `Exclusive skin "Gold Leaf Egg Sushi"` · `👑 in front of your name` · `[VIP] chat tag`. 연출 fx: cat-customer Cat Customer · fireworks Fireworks.

나머지(UI·오류·대사)의 `en`은 개발이 위 규칙·용어집으로 쓴다. 스킨 대사(31종 × 2줄)·손님 대사는 말장난을 살려 의역한다(예: "폭신폭신 계란 최고!" → "Fluffy egg is the best!").

### 8. `AutoLocalize`
- `RoomUiKit`의 `Kit.label`·`Kit.button`·`Kit.textBox`(그리고 이 스펙이 바꾸는 화면에서 직접 만드는 `TextLabel`·`TextButton`·`TextBox`·`BillboardGui` 글씨)는 `AutoLocalize = false`가 기본. 이유: 글씨가 이미 `Loc`으로 번역돼 있어 자동 번역이 다시 손대면 안 되고, ATC가 **이미 번역된 영어·독일어 글씨를 새 원문으로 수집**해 클라우드 표를 더럽히지 않게.
- 반드시 꺼야 하는 것(사람이 쓴 값·이름): 플레이어 이름(방 멤버·순위표·관전 대상·우승 배너), 방 이름, 방 코드·코드 입력·방 이름 입력 `TextBox`, 숫자만 보이는 배지(코인·재화).
- `Kit`을 거치지 않고 만든 객체는 기본값(`true`) 그대로 → 놓친 글씨는 ATC + 자동 번역이 안전망. Studio 설정의 "자동 텍스트 수집"·"자동 번역"은 켜 둔다(USER-TODO).

## 범위
- **1단계 (이 스펙의 AC 대부분)**
  - 기반: `Strings.csv`, `LocalizeLogic`, `Loc`, `Types`·`Remotes` 계약, `init.client.luau`.
  - 클라이언트 UI 전부: `src/client/ui/*`(관리자 파일 제외), `src/client/input/*`, `src/client/Sfx.luau`, `src/client/fx/`의 `IntroScreen`·`IntroController`·`EliminationCutsceneScreen`·`EliminationCutsceneController`(대사)·`VictoryCutsceneScreen`·`VictoryCutsceneController`·`VictoryProps`(간판).
  - 서버 메시지: 위 5절의 서비스·순수 로직, Kick 2곳, 기본 방 이름.
  - 데이터 문구 CSV 행: 맵 15×2, 스킨 31 이름 + 대사, 등급 5, 상품·연출·시즌, 칭호 3, 보상 이유 6, 탈락 대사.
- **2단계 (m5-25가 `main`에 머지된 뒤, 같은 스펙·작은 후속)**
  - `CharacterFxController`: 이름표 위 칭호 `Loc.titleFromName(속성값)`, 이름표 `AutoLocalize = false`.
  - 로비 우승자 단상(`LobbyService`·`LobbyLayout`, 서버가 만드는 SurfaceGui): 서버는 이름·승수·칭호 승수를 속성으로 달고 클라이언트(`LobbyFxController`)가 `Loc`으로 글씨를 쓴다("다음 우승자는 누구?", "{wins}승"). 속성 이름 추가 시 이 스펙이 `Attributes.luau` 담당.
  - 간장 늪 "매워!!"(`SoySwampHazards`, 서버가 만드는 BillboardGui): 클라이언트에서 쓰거나 언어 무관 "🌶️!!"로 바꾸기 — 2단계 시작 때 결정 기록에.
- **제외**
  - 관리자 "🛠" 패널·관리자 명령·`AdminLogic` 문구(개발자 전용 도구, 한국어 유지). 대신 관리자 화면 객체는 `AutoLocalize = false`(ATC가 개발 도구 문구를 수집하지 않게).
  - 서버 `warn`/`print`/`error` 로그, Studio 전용 이름("Studio 매치").
  - 맵 장식에 구운 글씨(없음 확인 — 위 "매워!!"만 2단계), 소리, 스토어 페이지·게임 설명·상품 이름(사용자, USER-TODO), 채팅 태그 `[VIP]`(Roblox 채팅, 그대로).
  - `CharacterFxController`·`SushiBody`(m5-25 소유, 2단계까지 손대지 않음).
  - 영어 외 언어의 수동 번역, 오른쪽→왼쪽 언어 배치, 언어별 글꼴.

## 수용 기준

### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `tests/localization.spec.luau`가 `src/shared/Localization/Strings.csv`를 `LocalizeLogic.parseCsv`로 읽으면 문제 0개다. 머리줄은 정확히 `Key,Source,Context,Example,en`이다.
- [ ] AC2: CSV의 모든 행은 키가 `isValidKey`를 통과하고, 키가 중복되지 않고, `Source`(한국어)와 `en`이 비어 있지 않다.
- [ ] AC3: 모든 행에서 `placeholders(Source)`와 `placeholders(en)`이 같은 집합이고, `{`·`}` 짝이 맞는다. 자리표시자가 있는 행은 `Example`이 비어 있지 않다.
- [ ] AC4: 코드에 쓴 키가 모두 CSV에 있다 — 테스트가 `src/`(관리자 파일 제외)에서 `Loc.t("…"`, `LocalizeLogic.text("…"`, `key = "…"`(LocText 리터럴)의 문자열 키를 모아 CSV에 없는 키가 0개다. 반대로 CSV의 키 중 코드에서 안 쓰이고 동적 키 모양(2절 목록)에도 맞지 않는 키가 0개다.
- [ ] AC5 (데이터 동기화): `Maps`의 모든 맵에 `map.<id>.name`의 `Source` = `displayName`, `map.<id>.rule`의 `Source` = `rule`. `Skins`의 모든 스킨에 `skin.<id>.name` = `displayName`, `skin.<id>.speech.<n>` = `speech[n]`(개수 같음). `tier.<Tier>` = 등급 `displayName`. `Offers`의 이름·blurb·perk, `FxCatalog`, `Seasons` 이름·재화 이름, `Config.Titles`(`title.w<wins>`), `Types.RewardReason` 6개(`reward.reason.*`), `EliminationCutsceneLogic` 대사가 모두 같은 규칙으로 일치한다. (새 맵·스킨·상품을 추가하고 CSV를 안 고치면 이 테스트가 실패한다.)
- [ ] AC6: `ShopLogic`·`OfferLogic`·`ReceiptLogic`·`CodeLogic`·`RoomLogic`의 모든 이유 enum에 대해 `message(reason)`이 `isLocText`를 통과하는 값을 돌려주고 그 키가 CSV에 있다. 모르는 이유는 `{ key = "common.err.retry" }`.
- [ ] AC7: `format`: `("{a} + {b}", {a="1", b=2})` → `"1 + 2", true`; 빠진 인자 → 빈 문자열 + `false`; 남는 인자 무시; 숫자 `1234` → `"1,234"`; `LocText` 인자는 같은 카탈로그·언어로 풀린다; 깊이 3 이상의 중첩은 빈 문자열.
- [ ] AC8: `choose`가 3절 폴백 표의 모든 줄을 표 테스트로 만족한다(ko, en 정상, en 오류, en `{…}` 남음, de 정상, de 오류, de 원문과 같음, en 열 없음, 카탈로그에 없는 키).
- [ ] AC9: `languageOf`(`"en-us"`→`"en"`, `"ko-kr"`→`"ko"`, `"EN"`→`"en"`, `""`→`"ko"`), `formatNumber`(0, 999, 1000, 1234567, -1500, 2.6→"3"), `ordinal`(en 1·2·3·4·11·12·13·21·22·101·111, ko 3→"3")가 기대값과 같다.
- [ ] AC10: `isLocText`는 올바른 값은 통과, 키 형식 위반·`args`가 배열·값이 함수·문자열 201자·인자 21개는 거절한다.
- [ ] AC11 (한국어 리터럴 금지): 테스트가 `src/client/**`(관리자 파일·`CharacterFxController` 제외)와 `RoomService`·`RoomDirectory`·`PlaceService`·`ShopService`·`OfferService`·`RobuxShopService`·`CodeService`·`ShopLogic`·`OfferLogic`·`ReceiptLogic`·`CodeLogic`·`RoomLogic`·`RewardLogic`·`VictoryCutsceneLogic`에서 한글이 든 문자열 리터럴(`"…"`, `'…'`, `` `…` ``)을 찾으면 0개다. 주석과 `warn(`·`print(`·`error(`·`assert(` 줄은 빼고, 허용 목록(파일·줄 단위, 이유 필수)은 테스트 파일 맨 위에 둔다. 데이터 카탈로그(`Skins`·`Offers`·`Seasons`·`FxCatalog`·`Config`·`maps/*`·`EliminationCutsceneLogic` 대사 표)는 이 검사 대상이 아니라 AC5로 묶는다.
- [ ] AC12: 키에 `.btn`가 든 행은 `en` 16자 이하, `.tab`은 10자 이하다(`Context`에 `long-ok`가 있으면 예외).
- [ ] AC13: 원문 조사 규칙 — `Source`에서 `}` 바로 뒤에 `이 가 을 를 은 는 으로 로 과 와 이에요 예요`가 오는 행이 0개다(`의`·`님`은 허용).
- [ ] AC14: 서비스를 가짜 환경으로 돌리는 기존 테스트에서 오류·알림 문구를 비교하던 곳은 키 비교로 바뀌고 모두 통과한다(예: 꽉 찬 방에 `JoinRoom` → `err.key == "room.err.Full"`, 코드 기간 끝 → `message.key == "code.err.Expired"`, 텔레포트 실패 `Notice` → `kind == "error"`이고 `message`가 `isLocText`).
- [ ] AC15: 기본 방 이름 — `RoomLogic`/`RoomService`가 이름 없이 만든 방의 스냅샷·목록은 `nameIsDefault == true`, `name ==` 방장 DisplayName이고, 이름을 쓴 방은 `nameIsDefault`가 nil·false다. 다른 서버 목록 합치기(`RoomDirectoryLogic`)를 거쳐도 필드가 유지된다.
- [ ] AC16: 검증 명령 5단계(rojo build, stylua, selene, lune run tests, luau-lsp 타입 검사)가 통과한다. 도구를 못 받은 환경이면 보고에 "타입 검사 못 함"처럼 적는다.

### Studio 확인 (사용자 확인 필요)
<!-- 언어 바꾸기: Studio "Test" 탭 → Player Emulator(플레이어 에뮬레이터) 켜기 → Locale을 고르고 Play. 실서버는 Roblox 설정 → 언어. -->
- [ ] AC17 (한국어 그대로): 기본(한국어)으로 Play하면 로비·방·HUD·탈락·관전·우승·코인·탈의실·상점·코드 화면 글씨가 이 스펙 전과 같다(문장을 고친 곳 — 조사 규칙 때문에 바꾼 "🍚 300 · 해금" 같은 곳 — 만 다르다).
- [ ] AC18 (영어 전체 흐름): Locale English로 혼자 시작 한 판(`DEBUG.minPlayersToStart = 1`) — 로비 제목·버튼·방 만들기 창·빈 방 목록 안내·방 대기실·카운트다운·라운드 소개(맵 이름·규칙)·"GO!"·HUD 타이머·인원·통과/탈락 안내·"EATEN!"·등수 서수(`5th`)·관전·연장전 배너·우승 배너·"ESCAPED!"·순위표·코인 토스트·정산 줄에 **한글이 하나도 없다**(플레이어 이름 제외).
- [ ] AC19 (영어 서버 메시지): English에서 틀린 방 코드로 참가, 꽉 찬 방 참가, 방장 아닌 사람 시작(Clients and Servers 2명), 코인 모자란 스킨 해금, 없는 코드·이미 받은 코드 넣기를 하면 오류 줄이 영어다.
- [ ] AC20 (다른 언어 폴백): Locale을 독일어(또는 일본어)로 하고 Play하면 키 문구는 영어로 보인다(클라우드 업로드 전), 한국어·키 이름(`shop.err.…`)이 보이지 않는다.
- [ ] AC21 (번역기 실패): 퍼블리시 안 된 플레이스·오프라인 등 번역기를 못 받는 상황에서도 English에서 영어, 기본에서 한국어가 보이고 Output에 `[Loc]` 경고는 한 번만 나온다.
- [ ] AC22 (휴대폰 넘침): English + Device Emulator 가로 667×375(iPhone SE급)·844×390에서 로비·방 만들기 창·방 대기실·HUD·탈의실 카드·상점 카드·코드 창·관전 바·터치 버튼(Dive·Grab)·음소거 버튼 글씨가 칸 밖으로 잘리거나 겹치지 않는다(줄바꿈·글씨 줄임은 괜찮음).
- [ ] AC23 (이름 번역 안 함): DisplayName·방 이름에 "Win", "Shop"처럼 번역될 만한 영어 단어를 쓴 계정으로 해도 다른 언어 화면에서 그대로 보인다(방 이름 칸에 "Shop"이라고 써서 확인 가능).
- [ ] AC24 (실서버, 사용자 퍼블리시 뒤): CSV를 클라우드 표에 올린 다음 날 독일어 계정으로 접속하면 키 문구가 독일어(자동 번역)로 보이고 자리표시자(`{name}`)가 그대로 노출되지 않는다. 노출되면 결정 기록에 적고 그 언어는 영어 폴백으로 둔다.

### 2단계 수용 기준 (m5-25 머지 뒤)
- [ ] AC25: English에서 1승 이상 계정의 이름표 칭호가 "Escaped Sushi"로, 로비 단상 빈 상태가 영어("Who's the next winner?")로, 승수가 "{wins} wins"로 보인다. 이름표·단상 이름은 `AutoLocalize = false`.
- [ ] AC26: 간장 늪 와사비 글씨가 English에서 한글로 보이지 않는다(결정한 방식대로).

## 공용 파일 변경
- `shared/Types.luau`: `LocText`, `NoticeKind` 추가. `RoomSnapshot`·`RoomListing`에 `nameIsDefault: boolean?`.
- `shared/Remotes.luau`: 맨 위 주석의 반환·인자 계약만(5절). 리모트 이름·개수 그대로(21개).
- `src/client/init.client.luau`: 컨트롤러보다 먼저 `Loc.init()`.
- `default.project.json`: **변경 없음** (`src/shared/Localization/Strings.csv`는 기존 `Shared` 매핑으로 들어감).
- `shared/Config.luau`·`shared/Attributes.luau`·`shared/maps/*`: 1단계 변경 없음. 2단계에서 단상 속성이 필요하면 `Attributes.luau`(이 스펙 담당).

## 문서 반영 (docs-writer, done 단계)
- `CLAUDE.md` 규칙에 추가: "플레이어에게 보이는 새 문구는 `Strings.csv`에 키로 넣고 `Loc.t`로 쓴다. 서버는 문장 대신 `LocText`. 새 맵·스킨·상품·시즌은 CSV 행도 같이 추가(테스트가 막음)."
- `docs/DEV-SETUP.md`: Player Emulator로 언어 바꾸는 법, AC17~AC23 확인 목록.
- `docs/USER-TODO.md`: (1) Creator Dashboard → 현지화에서 원본 언어가 한국어인지 확인, 자동 텍스트 수집·자동 번역 켜기 (2) 업데이트마다 `src/shared/Localization/Strings.csv`를 **Upload CSV**로 올리기(처음엔 Download CSV로 백업 — 업로드가 기존 수집 항목을 지우는지 확인 못 함) (3) AC24 확인 (4) 스토어 페이지·게임 설명·상품 이름 영어(선택).

## 결정 기록
- 2026-10-13 · 키 기반으로 할지 자동 수집만 쓸지 · **키 기반(`GetTranslatorForPlayerAsync` + `FormatByKey`) + 자동 수집은 안전망**. 사용자 요청. 근거: 서버가 보내는 문구·인자가 든 문구(`{name}님 우승!`)는 자동 수집이 문장마다 따로 잡아 번역이 흩어지고, 문구를 고치면 번역이 끊긴다. 키는 문구를 고쳐도 유지된다. · 사용자 / planner
- 2026-10-13 · 카탈로그 위치 · **`src/shared/Localization/Strings.csv` → ReplicatedStorage**, 같은 파일을 클라우드 표에 업로드. 근거: 설계 1절(클라이언트 복제 확실, 플레이스 표·클라우드 표 키 충돌 회피, 테스트가 같은 파일을 읽음). 대안(LocalizationService 밑)은 `default.project.json` 수정 + 복제·우선순위 "확인 못 함". · planner
- 2026-10-13 · 영어 말고 다른 언어 · **우리 손 번역은 영어만**, 나머지는 클라우드 자동 번역, 그것도 없으면 영어 폴백(한국어 원문보다 영어가 더 많은 사람에게 읽힌다). · 사용자 / planner
- 2026-10-13 · 관리자 패널 · **제외(한국어 유지, `AutoLocalize = false`)**. 개발자 전용 도구라 영어 플레이어가 볼 일이 없고 문구가 약 60개라 1단계 크기를 줄인다. 영어가 필요하면 후속으로. · planner (사용자가 바꿀 수 있음)
- 2026-10-13 · 복수형·서수 · 복수형 엔진 없이 문장으로 피하고, 서수는 영어만 코드로. 근거: Roblox 자리표시자 서식에 복수형 규칙이 없다(서식 지정자는 int·fixed·num·datetime 등만). · planner
- 2026-10-13 · 이번 결정은 가격·난이도 같은 체감 수치가 아니라 기술 방향이라 비슷한 로블록스 게임 비교 표는 만들지 않았다. 출처(확인 2026-10-13): Roblox 문서 [Localize with scripting](https://create.roblox.com/docs/production/localization/localize-with-scripting)(번역기 비동기·실패 가능·pcall, 이름 인자 테이블), [Translate dynamic content](https://create.roblox.com/docs/production/localization/translate-dynamic-content)(자리표시자·서식 지정자 목록), [Add translations](https://create.roblox.com/docs/production/localization/add-translations)(CSV 업로드, 빈 언어는 자동 번역 대상, 고친 번역은 수동으로 잠김), [LocalizationTable](https://create.roblox.com/docs/en-us/reference/engine/classes/LocalizationTable.md)(키 조회 때 번역이 없으면 Source 사용), [LocalizationService](https://create.roblox.com/docs/reference/engine/classes/LocalizationService)("Not Replicated" 표기), [Rojo sync details](https://rojo.space/docs/v7/sync-details/)(`.csv` → LocalizationTable, Roblox 내보내기 형식). 확인 못 함: 배경 절 마지막 줄의 네 가지. · planner
- 2026-10-13 · 기획 질문 3개 (메인 세션 기본값, 사용자 위임) · (1) 관리자 "🛠" 패널은 한국어 유지, `AutoLocalize = false`(이번 범위에서 제외). (2) 영어 용어는 7절 용어집 그대로("Wardrobe", "Rice Coins", 맵 이름 7절). (3) 원어민 검토는 지금 안 함(나중에 CSV로 가능). · 메인 세션 기본값

- 2026-10-13 · 구현 중 정한 세부 (developer, 스펙 범위 안) · (1) `choose`: `en`도 번역기 결과가 한국어 원문과 같으면 "정상"으로 보지 않고 카탈로그 `en`을 써요(클라우드 표에 영어가 빠졌을 때 한국어가 보이지 않게, 표의 다른 줄은 그대로). (2) 숫자 인자는 한국어 화면에서도 천 단위 쉼표(`1,234`) — 코인 배지·정산 줄이 예전 `1234`와 달라요. (3) `.tab` 10자 제한 때문에 이벤트 탭 영어는 "🎃 Spooky"·"🎄 Holiday". (4) `RoomUiKit` label·button·textBox 기본 `AutoLocalize = false`라 관리자 패널(Kit 사용)도 자동으로 꺼져요. (5) m5-25가 main에 머지돼서 2단계 중 `CharacterFxController` 칭호·이름표는 1단계에 같이 했어요(메인 세션 허락). (6) `RoomService.forceStart`(관리자 명령 전용) 문구는 한국어 문자열 그대로 — AC11 허용 목록. · developer
- 2026-10-13 · QA 결과 · **반려(in-dev)**: P1 B1 — 확인 안 된 로비 복귀 티켓(TeleportData)의 `nameIsDefault = true`를 믿고 `RoomService.restoreRoom`이 방 이름 필터를 건너뜀(필터 안 된 이름이 로비 목록에). P3 B2~B5(영어 문구, 다른 언어 서수, 늦은 번역기, 2단계 범위). 자세한 건 `docs/qa/m5-26-localization.md`. · qa
- 2026-10-13 · 숫자 + 단위 문구 규칙 (사용자) · **보이는 문구는 단위 말까지 숫자 자리표시자를 가진 한 키**: "{wins}승" / "Wins: {wins}", "{n}명", "{n}초", "{rank}등"도 같게. 서버는 숫자만 보내고 코드·서버 데이터에서 한국어 단위를 붙이지 않는다. 그래서 AC25의 승수 영어는 "{wins} wins"가 아니라 **"Wins: {wins}"**(1승도 문법이 맞음). 테스트가 막음(`m5-26-phase2` "규칙" 2개). · 사용자
- 2026-10-13 · 2단계 방식 (developer) · (1) 단상: 서버는 `Attributes.WinnerName`(DisplayName)·`WinnerWins`(숫자)만 Podium 폴더에 달고, 클라이언트 `LobbyFxController`가 `PodiumLogic.view` → `Loc`으로 이름표 3줄(`lobby.podium.empty`·`lobby.podium.winner`·`lobby.podium.wins` + 칭호 `title.w*`)을 채운다. 이름표 TextLabel은 서버·클라이언트 모두 `AutoLocalize = false`. (2) 간장 늪 "매워!!": "🌶️!!"로 바꾸지 않고 **키로 클라이언트에서**(`map.soy-swamp.spicy` "So spicy!!"). 서버는 `WorldText.mark(label, key)`(빈 글씨 + `Attributes.LocKey` + 태그 `LocalizedWorldText`), 클라이언트 `WorldTextController`가 `Loc.t(키)`. 다른 서버 월드 글씨도 같은 방법(인자가 있는 문구는 단상처럼 숫자 속성 따로). (3) 칭호: 서버 `Attributes.Title`을 한국어 이름 대신 **기준 승수(1/10/100) 숫자**로(`ProfileSchema.titleWinsFor`), 클라이언트가 `Loc.titleName`. 옛 서버의 한국어 문자열도 `Loc.titleFromName`으로 계속 읽음. · developer
- 2026-10-13 · QA B4 (늦은 번역기) 처리 · **고침(작게)**: 화면마다 다시 그리기를 넣지 않고, ko·en 밖 언어에서 번역기가 오기 전 `Loc`이 만든 글씨(맨 바깥 문구)를 기록해 두었다가 번역기가 늦게 오면 PlayerGui의 TextLabel·TextButton 중 **글씨가 기록과 똑같은 것**만 새 번역으로 바꾸고 `Loc.onChanged` 구독자(단상·와사비 글씨)에 알린다. 한계: 두 문구를 이어 붙인 글씨·폴백 영어와 우연히 같은 플레이어 입력 글씨는 예외(앞은 다음에 다시 그릴 때 바뀜, 뒤는 극히 드묾). ko·en은 바뀌는 게 없어 기록하지 않는다. · developer
- 2026-10-13 · QA B3 (서수) · 영어만 서수("5th"), 한국어·그 밖은 숫자. 그 밖 언어가 번역기 없이 카탈로그 영어로 폴백하면 그때만 영어 서수(`choose`의 `englishArgs`) — "(5 place)" 같은 어색한 폴백이 없게. 등수 문구는 `Loc.tPlace(key, n)`. · developer
- 2026-10-13 · 관리자 명령 `start` 문구 · `RoomService.forceStart`는 이유 이름("MatchServer"·"NoRoom"·"InMatch"·"AutoStarting")만 돌려주고 한국어는 `AdminCommands`(관리자 파일)로 옮겼다. AC11 허용 목록은 Studio 전용 "Studio 매치" 1줄만 남음. AC11 검사 범위를 `src` 전체(관리자 파일 제외)로 넓히고, CSV와 같은 데이터 원문(스킨·상품·시즌·연출·칭호·손님 대사·맵 이름/규칙)은 이유와 함께 따로 허용. · developer


## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-14 · main 병합 (developer, 브랜치 `m5-26-i18n-p2`)
- `origin/main`(6b12976: m5-24 맵 아트 v2, m5-27/m5-28 콘셉트 스킨) 병합. git 충돌 없음. m5-24 아트 파일에 새 화면·월드 글씨(`.Text`/Gui) 없음.
- `Strings.csv`: 콘셉트 스킨 5종 키 15개 추가 — `skin.concept-{salmon,tuna,shrimp,tamago,ikura}.name` + `.speech.1`·`.speech.2` (ko 원문 = `Skins.luau`, en 번역).
- `tests/m5-27-concept-skin.spec.luau`·`tests/m5-28-concept-skins.spec.luau`: 카드 버튼 글씨가 키(`shop.btn.wear`)가 되어 `LocTest.ko(...)`로 비교.
- 검증 5단계 통과, 테스트 1903 passed, 0 failed.

### 2026-10-13 · QA 수정 (developer, 브랜치 `m5-26-i18n-p2`)

**B1 (P1) 복귀 티켓 방 이름**: `RoomService.restoreRoom`이 `filterWith`가 있으면(로비 복귀) 티켓의 `nameIsDefault`·`name`을 믿지 않아요.
- 기본 이름 표시 + 방장이 이 서버에 있음 → 방장 DisplayName으로 다시 만듦(`nameIsDefault` 유지).
- 기본 이름 표시 + 방장 없음 → 티켓 이름을 필터해서 **하나도 안 바뀌었을 때만** 기본 이름으로 둠. 걸리거나 필터 실패 → 돌아온 사람 DisplayName 기본 이름.
- 쓴 이름 → 항상 필터(실패하면 돌아온 사람 기본 이름). 매치 서버(`filterWith` 없음, MemoryStore 매니페스트)는 그대로.
- QA 재현 테스트 `m5-26-qa` "QA B1 (P1)"과 "정상 기본 이름 방은 복귀해도…" 둘 다 통과, 개발 테스트 6개 추가.

**B2 영어 문구**: QA 표 10줄을 `en`에 그대로 반영(키 그대로). `shop.btn.needCoins` "Need {count} more 🍚"는 코인 최대 900 기준 15자(.btn 16자 안).

**B3 서수**: `LocalizeLogic.placeValue`(영어만 서수), `choose`의 `englishArgs`(카탈로그 영어 폴백일 때만 서수), `Loc.tPlace(key, n)` — HUD 결과 2줄·순위표·탈락 연출 등수 4곳.

**B4 늦은 번역기**: `LocalizeLogic.needsLateRefresh`·`newLateMap`·`recordLate`·`lateEntryFor`(순수) + `Loc`이 ko·en 밖 언어에서 번역기 전 글씨를 기록 → 번역기가 늦게 오면 PlayerGui의 같은 글씨를 다시 쓰고 `Loc.onChanged`로 알림. 한계는 결정 기록.

**B5**: 아래 2단계.

### 2026-10-13 · 2단계 (developer, 브랜치 `m5-26-i18n-p2`)

**결과**: AC25·AC26 구현(자동 테스트 + Studio 확인 필요). 사용자 규칙(숫자 + 단위 = 한 키, 서버는 숫자만)을 테스트로 고정.

**바뀐 파일**
- 새 파일: `src/shared/PodiumLogic.luau`(순수, 단상 이름표 LocText), `src/shared/WorldText.luau`(서버 월드 글씨 표시: 키 속성 + 태그), `src/client/fx/WorldTextController.luau`, `tests/m5-26-phase2.spec.luau`(20개), `tests/lib/RoomServiceHarness.luau`(QA의 RoomService 가짜 환경을 같이 쓰려고 옮겨 둔 복사본 — QA 파일은 그대로).
- 공용(이 스펙 담당): `shared/Attributes.luau`(`WinnerName`·`WinnerWins`·`LocKey`, `Title`은 숫자로 설명 변경), `src/client/init.client.luau`(`WorldTextController`).
- 서버: `LobbyService`(단상 글씨를 만들지 않고 속성만, 이름표 AutoLocalize false), `RewardService`(`Attributes.Title` = 기준 승수), `RoomService`(B1, `forceStart`는 이유 이름만), `AdminCommands`(관리자 `start` 한국어 문구).
- 공유: `LobbyLayout`(`emptyText` 삭제, 이름표 이름 상수), `ProfileSchema.titleWinsFor`, `maps/SoySwampHazards`("매워!!" → `WorldText.mark`), `LocalizeLogic`(B3·B4).
- 클라이언트: `Loc`(`tPlace`, `onChanged`, 늦은 번역기 다시 쓰기, `place` = 영어만 서수), `LobbyFxController`(단상 이름표), `CharacterFxController`(칭호 숫자 → `Loc.titleName`), `HudController`·`HudScreen`·`EliminationCutsceneScreen`(`Loc.tPlace`).
- CSV: 새 키 4개 — `lobby.podium.empty` "Who's the next winner?", `lobby.podium.winner` "🏆 {name}", `lobby.podium.wins` "{wins}승" / "Wins: {wins}", `map.soy-swamp.spicy` "매워!!" / "So spicy!!". (401행)
- 테스트 수정: `localization.spec` AC4(`Loc.tPlace`·`WorldText.mark` 키도 사용으로 셈), AC11(검사 범위 `src` 전체 + 데이터 원문 허용 목록, 허용 줄 5 → 1), `camera-priority.spec` Attributes 개수 16 → 19.

**한국어 리터럴 남은 곳** (`src`, 주석 제외)
- 관리자 파일(`Admin*` — 패널·명령·`AdminLogic` 문구): m5-26 제외 범위.
- Studio 전용: `PlaceService` "Studio 매치"(simulateMatchServer 방 이름) — AC11 허용 목록 1줄.
- 데이터 원문(CSV Source와 같아야 함, AC5가 확인, 화면은 id → 키): `Skins`(이름·대사), `Offers`, `Seasons`, `FxCatalog`, `Config.Titles`, `EliminationCutsceneLogic`(손님 대사), 맵 모듈 `displayName`·`rule`(MatchPhase `mapName`·`rule` 한국어 폴백으로 서버가 보냄 — 클라이언트는 `mapId`로 Loc).
- 서버가 아직 한국어로 보내지만 화면에 안 쓰는 값: `ProfileView.title`(ProfileUpdated, 클라이언트 사용 없음), MatchPhase `mapName`·`rule`(폴백).
- `warn`/`print`/`error`/`assert` 안의 개발 로그(플레이어에게 안 보임).

**검증 (2026-10-13, 로컬 Windows, main 3ed86cb 기준)**: `rojo build` 성공 · `stylua --check` 통과 · `selene src` 0 errors 0 warnings · `lune run tests` **1828 passed, 0 failed**(m5-26-qa 21/21, m5-26-phase2 20/20) · `luau-lsp analyze` 끝 코드 0.

**Studio 확인 방법** (QA 체크리스트 1~9에 더해)
1. 단상(AC25): Locale English → Play → 로비 가운데 단상 이름표가 "Who's the next winner?". 혼자 한 판 이겨서 돌아오면 "🏆 <내 이름>", 칭호 "Escaped Sushi", "Wins: 1". 기본(한국어)에서는 "다음 우승자는 누구?" / "🏆 <이름>" / "탈출 초밥" / "1승". 이름이 번역되지 않는지(Deutsch에서도 그대로).
2. 이름표 칭호: English에서 1승 이상이면 머리 위 "Escaped Sushi"(10승 "Legendary Tuna").
3. 와사비(AC26): `Config.DEBUG.forceMapPlan = { "soy-swamp", "hot-plate", "skewer-showdown" }`(커밋 전 nil로) → English에서 와사비 패드를 밟으면 머리 위 "So spicy!!", 한국어 "매워!!". 2명(Clients and Servers)이면 다른 사람 머리 위 글씨도 내 언어로.
4. 등수(B3): English 탈락 "🥢 You're out! (5th place)", 통과 "✅ Qualified! (3rd place)", 순위표 "1st". 한국어 "(5등)", "3번째로 통과했어요!", "1등". Deutsch(업로드 전)도 영어 폴백이라 "5th".
5. B4는 클라우드 업로드 뒤 다른 언어 + 느린 번역기에서만 생겨 Studio에서 재현이 어려워요 — 코드 읽기·순수 테스트로 확인.

**남은 이슈**
- AC17~AC26 Studio·실서버 확인(사용자). docs-writer: CLAUDE.md 규칙(숫자 + 단위 한 키, 서버 월드 글씨는 `WorldText.mark`), DEV-SETUP, USER-TODO(CSV 업로드).
- B4 한계(결정 기록). `ProfileView.title`·MatchPhase `mapName`·`rule`의 한국어는 화면에 안 쓰지만 서버가 보냄 — 지우려면 `Types` 변경 + 옛 테스트 정리(후속 선택).

### 2026-10-13 · 1단계 구현 (developer, 브랜치 `m5-26-i18n`)

**결과**: 1단계 수용 기준 AC1~AC16 구현·자동 테스트, 검증 5단계 통과(아래). AC17~AC24는 Studio·실서버 확인 필요(사용자). 2단계 중 `CharacterFxController` 칭호·이름표(AC25 일부)는 m5-25가 main에 머지돼서 같이 했어요. 로비 단상·간장 늪 "매워!!"(AC25 나머지·AC26)는 남았어요.

**카탈로그**: `src/shared/Localization/Strings.csv` 397행 (UI·서버 문구 223 + 날짜 12 + 데이터 162: 맵 15×2, 등급 5, 스킨 31 이름 + 대사 62, 상품 이름·설명·혜택 15, 연출 2, 시즌 4, 칭호 3, 탈락 대사 10). Rojo가 `ReplicatedStorage.Shared.Localization.Strings`(LocalizationTable, 397 entries)로 만드는 것을 build.rbxl에서 확인했어요(`SourceLocaleId`는 Rojo 기본값 en-us — 이 표는 폴백 카탈로그로만 읽어서 상관없음). 머리줄 `Key,Source,Context,Example,en`.

**바뀐 파일**
- 새 파일: `src/shared/LocalizeLogic.luau`(순수), `src/client/Loc.luau`, `src/server/ServerLoc.luau`(Kick 문구만), `src/shared/Localization/Strings.csv`, `tests/localization.spec.luau`, `tests/lib/LocTest.luau`(CSV로 LocText를 한국어·영어로 풀기), `tests/lib/LuauStrings.luau`(문자열 리터럴 토크나이저, AC11).
- 공용(이 스펙 담당): `shared/Types.luau`(LocText, NoticeKind, RoomSnapshot·RoomListing.nameIsDefault), `shared/Remotes.luau`(주석 계약만, 21개 그대로), `src/client/init.client.luau`(맨 먼저 `Loc.init()`).
- 순수 로직 → LocText: `ShopLogic`(message·cardButtonText·robuxButtonText·탭 label·EVENT_NOTE·eventHeader·lastDayText, REASONS), `OfferLogic`(message·valueText·contentLines는 `{ { LocText } }`·buttonText·grantNotice, REASONS), `ReceiptLogic`·`CodeLogic`(message·successMessage, REASONS), `RoomLogic`(새 `Reason`·`MESSAGES`·`message(reason, args)`·REASONS, `defaultName`은 DisplayName만, `nameIsDefault`), `RewardLogic`(toastText·summaryText, `REASON_TEXT` → `REASONS`), `VictoryCutsceneLogic.titleText`, `EliminationCutsceneLogic`(+`lineTextsFor`·`pickLineText`, 기존 linesFor·pickLine은 그대로).
- 서버: `RoomService`(오류 전부 `RoomLogic.message`, 기본 이름 = `nameIsDefault`, 복원 때 기본 이름은 다시 필터하지 않음), `RoomDirectory`, `PlaceService`(notice = LocText + kind 항상, Kick 2곳은 `ServerLoc.render`), `ShopService`·`OfferService`·`RobuxShopService`·`CodeService`(반환 타입 LocText). `PlacePayload.Settings`·`RoomDirectoryLogic.Entry`에 `nameIsDefault`(서버 이동·다른 서버 목록에서도 유지).
- 클라이언트: `ui/*`(관리자 파일 제외), `input/*`, `Sfx`, `fx/`의 Intro·Elimination·Victory 화면·컨트롤러·VictoryProps 간판, `CharacterFxController`(칭호 `Loc.titleFromName`, 이름표 AutoLocalize false). `RoomUiKit`의 label·button·textBox는 `AutoLocalize = false`가 기본(관리자 패널도 Kit이라 함께 꺼짐).
- 테스트 수정(AC14): 문구를 비교하던 기존 테스트는 `LocTest.ko(...)`로 풀어 비교하거나 키로 비교(`code.err.Expired`, `room.err.Full`), 가짜 환경(`FakeSfxEnv`, m4-14·m5-08 하네스)에 Loc/LocalizeLogic 의존 추가. 조사 규칙으로 바뀐 기대값만 고쳤어요("🍚 300 · 해금", "R$ 29 · 사기", "🍬 80 · 받기", "(총 1,234)").

**검증 (2026-10-13, 로컬 Windows, main c65266a 머지 뒤)**: `rojo build` 성공 · `stylua --check` 통과 · `selene src` 0 errors 0 warnings · `lune run tests` 1787 passed 0 failed (localization.spec 20개 포함) · `luau-lsp analyze` 끝 코드 0, 오류 없음.

**Studio 확인 방법** (AC17~AC23, `DEV-SETUP`에 옮길 내용)
1. 한국어(AC17): 그냥 Play. 로비·방·HUD·탈락·관전·우승·코인·탈의실·상점·코드 화면이 예전과 같은지. 의도한 차이: "🍚 300 · 해금", "R$ 29 · 사기", "🍬 80 · 받기", 탭 이름 그대로, 천 단위 쉼표(코인 1,234), 등수는 "{n}등" 그대로.
2. 영어(AC18): Test 탭 → Player Emulator 켜기 → Locale **English** → Play, `DEBUG.minPlayersToStart = 1`로 혼자 한 판. 맵 소개 이름·규칙, "GO!", HUD, "EATEN!" + "5th", 관전 바, 연장전 배너, "ESCAPED!", 순위표("1st"), 코인 토스트·정산에 한글이 없는지(플레이어 이름 제외). 출력 창에 `[Loc]` 경고는 번역기 없음 한 줄 정도만.
3. 서버 오류(AC19): English에서 없는 방 코드, 꽉 찬 방, 방장 아닌 사람 시작(Clients and Servers 2명), 코인 모자란 스킨, 없는 코드·이미 받은 코드.
4. 다른 언어(AC20): Locale Deutsch/日本語 → 키 문구가 영어, 한글·키 이름(`shop.err.…`)이 안 보이는지.
5. 번역기 실패(AC21): 퍼블리시 안 한 플레이스면 번역기가 키를 몰라 폴백 — English 영어, 기본 한국어.
6. 휴대폰(AC22): English + Device Emulator 667×375·844×390에서 로비·방 만들기 창·대기실·HUD·탈의실·상점·코드 창·관전 바·Dive/Grab·음소거 버튼이 잘리거나 겹치지 않는지. 특히 "Join with Code", "Private (Code)", 탈의실 탭(이벤트 탭 "🎃 Spooky").
7. 이름(AC23): 방 이름 칸에 "Shop"이라고 쓰고 만들기 → 다른 언어 화면에서도 "Shop".

**남은 이슈 / 2단계**
- 로비 우승자 단상(`LobbyService`·`LobbyLayout` SurfaceGui의 "다음 우승자는 누구?", "{wins}승", 칭호)과 간장 늪 "매워!!"(`SoySwampHazards`) — 2단계. 단상은 `Attributes.luau` 속성 추가가 필요(이 스펙 담당).
- 관리자 "🛠" 패널·관리자 명령·`RoomService.forceStart` 문구는 한국어 그대로(제외, AC11 허용 목록 4줄 + PlaceService "Studio 매치" 1줄).
- 영어 원어민 검토 안 함(메인 세션 기본값). 바꾸려면 CSV `en` 열만 고치면 돼요(키는 그대로).
- 사용자 할 일(docs-writer가 USER-TODO에): Creator Dashboard 현지화에서 원본 언어 한국어 확인·자동 수집·자동 번역 켜기, 업데이트마다 `Strings.csv` Upload CSV(처음엔 Download CSV로 백업), AC24.
