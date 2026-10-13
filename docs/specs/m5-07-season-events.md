status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-07 — 시즌 이벤트: 한정 스킨·이벤트 재화(🍬/⭐)·탈의실 이벤트 탭

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1(뽑기 없음, 골라서 삼, 코인 로벅스 판매 없음), §9.2 "시즌 한정 — 할로윈 호박 초밥, 크리스마스 산타 새우 등, 기간 한정 판매, 에픽 가격대", §9.4(코인 지급 시점), §10(탈의실·코인 배지·토스트), §6("모든 스킨은 히트박스·속도 같음, 외곽 ±15%")
- 레퍼런스: [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) 8.1·8.2·8.6절
- 담당 개발 worktree: `m5-season` (Rojo 포트 34875)
- 공용 파일 수정 담당: 없음 (리모트 `BuyWithTokens`, `Config.Events`, `Types.RewardGrant.tokens`, 스킨·시즌 카탈로그, `TokenGet` cue는 m5-03)
- 의존: **m5-03 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/SushiBody.luau`(새 스킨 5종 진짜 생김새 — VIP 금박 계란초밥 포함), `src/shared/Skins.luau`(새 스킨 대사·상품 id 칸만), `src/shared/Seasons.luau`(숫자 조정만), `src/shared/ShopLogic.luau`, `src/client/ui/ShopScreen.luau`, `src/client/ui/ShopController.luau`, `src/server/ShopService.luau`(`BuyWithTokens`), `src/shared/RewardLogic.luau`, `src/server/RewardService.luau`, `src/client/ui/CoinScreen.luau`, `src/client/ui/CoinController.luau`, `src/server/LobbyService.luau`(이벤트 장식만), 테스트 `tests/shop-logic.spec.luau`(추가), `tests/reward-logic.spec.luau`(추가), `tests/sushi-body.spec.luau`(새 스킨), 새 `tests/season-shop.spec.luau`

## 목표
할로윈·크리스마스처럼 **기간 동안만 열리는 축제**가 있다. 축제 동안 플레이하면 코인과 함께 **사탕 🍬(크리스마스는 별 ⭐)**이 모이고, 80개를 모으면 **무료 한정 스킨**(유령 계란초밥 / 트리 마키)을 받는다. 같은 기간에만 **유료 한정 스킨**(호박 초밥 / 산타 새우, R$ 99)을 골라서 살 수 있다. 축제가 끝나도 받은 스킨은 영원히 내 것.

## 규칙 (기본값, 사용자 수정 가능)
### 이벤트 기간·재화 (데이터는 m5-03 `Seasons.luau`)
| 이벤트 | 기간 (UTC) | 재화 | 무료 스킨 (재화) | 유료 스킨 (로벅스, 개발자 상품) |
|---|---|---|---|---|
| 할로윈 초밥 축제 `halloween-2026` | 10/16 ~ 11/6 (3주) | 🍬 사탕 | 유령 계란초밥 — 🍬 80 | 호박 초밥 — R$ 99 |
| 크리스마스 초밥 축제 `christmas-2026` | 12/11 ~ 1/8 (4주) | ⭐ 별 | 트리 마키 — ⭐ 80 | 산타 새우 — R$ 99 |
- "지금 시각" = 서버 `os.time()` (Studio는 `Config.DEBUG.eventNow`가 있으면 그 값). 클라이언트 표시는 `workspace:GetServerTimeNow()`.

### 재화 지급 (서버, `RewardLogic` 순수 + `RewardService`)
- **이벤트가 진행 중일 때만**, 코인 보상과 같은 순간에 `Config.Events.Tokens`만큼 그 이벤트 재화를 줘요:
  | 언제 | 코인 (지금) | 재화 |
  |---|---|---|
  | 라운드 통과 | +10 | **+1** |
  | 결승 진출(결승 출발) | +30 | **+2** |
  | 우승 | +100 | **+5** |
  | 매치 끝 (끝까지 방에 남은 참가자, 탈락 관전자 포함) | 하루 첫 판이면 +50 | **+1** (판 참가) + 하루 첫 판이면 **+3** |
- 매치 끝 지급은 한 번에 보내요: 하루 첫 판이면 이유 `DailyFirstMatch`(코인 50 + 재화 4), 아니면 `MatchPlayed`(코인 0 + 재화 1). 코인도 재화도 0이면 보내지 않아요.
- `RewardGrant`에 `tokens`·`tokenTotal`·`eventId`를 채워요(m5-03 타입). 프로필 `eventTokens[eventId]`에 더해요.
- 한 판 평균 약 3개(+ 하루 첫 판 3) → 80개 ≈ 25~30판, 하루 5판이면 약 5일(3주 이벤트 안에 여유). 첫 라운드에 매번 떨어지는 사람도 판마다 1 + 하루 3 → 하루 5판이면 약 10일.

### 무료 한정 스킨 받기 (`BuyWithTokens(skinId)`, ShopService)
- 서버 검증 순서: 요청 간격(`Config.Shop.RequestCooldown`, 기존 장착·해금과 같이) → 카탈로그(`skin.tokens`가 있음) → 그 이벤트가 **지금 진행 중**(끝나면 교환 불가) → 아직 없음 → 잠금(라운드 중·연출 중, 기존 `isLocked`) → 저장 가능(`canPersist`, Studio 메모리 모드는 허용) → 재화 ≥ 가격 → 재화 차감 + 스킨 지급 + **자동 장착** + 저장 요청.
- 순수 함수 `ShopLogic.canBuyWithTokens(skinId, wallet, now, canSave)`·`buyWithTokens(...)`(코인 해금과 같은 모양, Reason에 `EventEnded`·`NeedTokens` 추가).
- 남은 재화는 이벤트가 끝나도 프로필에 남지만 쓸 곳도 보여 줄 곳도 없어요(코인으로 바꿔 주지 않음 — 결정 기록 D3).

### 유료 한정 스킨
- 기존 로벅스 스킨 흐름(m4-14) 그대로 + m5-03의 판매 기간 확인. 상품 id는 사용자가 만들어 `Skins.luau`의 `productId`에(USER-TODO).
- 기간이 끝나면 결제 창을 못 열고(`OffSale` "판매 기간이 아니에요"), 늦게 온 영수증은 정상 지급(m5-03).

### 탈의실 (ShopScreen·ShopController·ShopLogic)
- **이벤트 탭**: 이벤트 진행 중이면 등급 탭 맨 앞에 "🎃 할로윈"(크리스마스 "🎄 크리스마스") 탭이 생기고, 탈의실을 열면 이 탭이 먼저 선택돼요. 그 이벤트 스킨 2종만 보여요. 진행 중 이벤트가 없으면 탭 없음.
- **이벤트 머리줄**(이벤트 탭에서): "할로윈 초밥 축제 · 11월 5일까지 · 🍬 32" + 작은 글씨 "이벤트가 끝나면 받을 수 없어요. 다음 해에 다시 올 수도 있어요." 남은 기간은 **날짜로만**(마지막 날 = `endsAt − 1초`의 UTC 날짜) — 초 단위 카운트다운·"마지막 기회!"·깜빡임 없음(결정 기록 D4).
- 카드 상태(`ShopLogic.cardState` 확장):
  | 스킨 | 상태 글씨 / 버튼 |
  |---|---|
  | 재화 스킨, 기간 중, 미보유, 재화 충분 | "🍬 80으로 받기" (누르면 `BuyWithTokens`) |
  | 재화 스킨, 기간 중, 재화 부족 | "🍬 32 / 80" (비활성) |
  | 유료 한정, 기간 중, 미보유 | 지금 로벅스 카드와 같음 "R$ 99로 사기" (가격은 `PriceCache`) |
  | 한정 스킨, 기간 끝, 미보유 | **목록에서 숨김** (어느 탭에도 안 보임) |
  | 한정 스킨, 보유 | 일반 보유 스킨과 같음(입기/입는 중) + 카드 구석에 "한정" 표시, 원래 등급 탭에도 보임 |
  | VIP 전용(`vipOnly`), 미보유 | "👑 VIP 전용" (비활성, 에픽·전설과 같은 칸에 — 전설 탭) |
  | VIP 전용, 보유 | 입기/입는 중 |
- 로벅스 가격 표시는 모든 스킨에서 `PriceCache.product(productId, skin.robux)`로(지역 가격 준비, REFERENCE 8.4). 상품 id가 없으면 지금처럼 카탈로그 가격.

### 코인 배지·토스트 (CoinScreen·CoinController)
- 이벤트 진행 중이면 코인 배지 옆에 "🍬 32"(내 이번 이벤트 재화). 이벤트가 없으면 숨김.
- 토스트: 코인과 재화를 한 줄로 "+10 🍚 +1 🍬 라운드 통과", 재화만이면 "+1 🍬 판 참가". 재화를 받을 때 효과음 `TokenGet`(코인만이면 지금 소리).
- 우승 화면의 "이번 판 +N 🍚"에 재화도 "+M 🍬"(이번 판 합계).

### 새 스킨 생김새 (SushiBody, 외곽 상자 계란초밥 ±15% 안, 효과 1개까지, GDD 6·9.2)
| id | 생김새 |
|---|---|
| `pumpkin-sushi` | 밥 위에 주황 호박 조각(골 무늬), 잭오랜턴 눈·입(검은 파츠), 초록 꼭지 |
| `ghost-tamago` | 계란초밥 위에 반투명 흰 천(투명도 0.25)과 둥근 검은 눈, 효과: 은은한 흰 빛(PointLight 약하게) |
| `santa-shrimp` | 새우 초밥 + 빨간 산타 모자(흰 털 방울) |
| `tree-maki` | 오이마키가 원뿔 트리 모양(초록 층 3개), 꼭대기 노란 별, 효과: 별 반짝이 |
| `vip-gold-tamago` | 계란초밥 + 금박(금속 재질 금색 얇은 판), 효과: 금색 반짝이 |

### 로비 이벤트 장식 (LobbyService, 선택이지만 기본 포함)
- 서버 시작 때와 10분마다 진행 중 이벤트를 확인해 로비 카운터 주변에 장식(할로윈: 호박 등 6개·보라 조명 2 / 크리스마스: 작은 트리 2·눈 입자 1·선물 상자 4)을 켜고 끄기. 충돌 없음, 파츠 40개 이하.

## 범위
- 포함: 위 규칙 전부.
- 제외: 이벤트 전용 맵·미니게임, 배틀 패스, 이벤트 퀘스트, 재화 → 코인 교환, 유료 랜덤(뽑기) — GDD 9.1, 이벤트 코드(m5-10이 코드 보상에 재화 지급을 지원).

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1: `RewardLogic`: 이벤트 진행 중(`now` = 할로윈 기간) 라운드 통과 지급이 코인 10 + 재화 1(eventId `halloween-2026`), 결승 출발 30 + 2, 우승 100 + 5. 기간 밖이면 재화 nil(코인은 그대로).
- [ ] AC2: 매치 끝: 하루 첫 판 + 이벤트 중 → `DailyFirstMatch` 코인 50 + 재화 4, 하루 첫 판이 아님 + 이벤트 중 → `MatchPlayed` 코인 0 + 재화 1, 하루 첫 판이 아님 + 이벤트 밖 → 지급 없음.
- [ ] AC3: `ShopLogic.canBuyWithTokens`: 재화 80 이상·기간 중·미보유·잠금 아님·저장 가능이면 ok, 각 조건이 빠지면 맞는 Reason(`NeedTokens`·`EventEnded`·`AlreadyOwned`·`Locked`·`CannotSave`). 성공하면 재화 −80, 스킨 보유 + 장착.
- [ ] AC4: `ShopLogic.cardState`: 위 표의 7가지 경우가 맞는 상태·글씨를 돌려준다. 기간 끝 + 미보유 한정 스킨은 `visibleSkins(view, tier, now)`에서 빠진다.
- [ ] AC5: `ShopLogic.eventHeader(event, now)`가 "할로윈 초밥 축제 · 11월 5일까지"를 만든다(끝 시각 11/6 00:00 UTC → 11월 5일).
- [ ] AC6: 새 스킨 5종 `SushiBody.layout`이 자리 표시가 아니고(계란초밥과 다름), 외곽 상자가 계란초밥 ±15% 안, 효과 1개 이하.
- [ ] AC7: 검증 5단계 통과.

### Studio 확인 (사용자 확인 필요 — `Config.DEBUG.eventNow = 1792108800`(할로윈 첫날), 끝 확인은 `1793923200`, **확인 뒤 nil**)
- [ ] AC8: 할로윈 시각으로 Play Solo → 코인 배지 옆 "🍬 0", 탈의실을 열면 "🎃 할로윈" 탭이 먼저 열리고 머리줄에 "11월 5일까지"(카운트다운 없음).
- [ ] AC9: 강제 플랜으로 한 판 하면 라운드 통과 때 "+10 🍚 +1 🍬 라운드 통과" 토스트와 소리, 매치 끝 "+50 🍚 +4 🍬 오늘 첫 판"(첫 판일 때), 우승 화면에 이번 판 재화 합계.
- [ ] AC10: 재화가 80이 되면(관리자 명령 m5-11 또는 Studio 명령줄로 채워도 됨) "🍬 80으로 받기" → 유령 계란초밥이 바로 입혀지고 재화 0. 라운드 중에는 거절된다.
- [ ] AC11: 호박 초밥 "R$ 99로 사기"가 가짜 결제(`fakeRobuxInStudio`)로 지급된다. `eventNow`를 끝 시각으로 바꾸면 호박 초밥·유령 계란초밥(미보유)이 탈의실에서 사라지고 이벤트 탭·배지도 없다. 가진 것은 등급 탭에 "한정" 표시로 남는다.
- [ ] AC12: 할로윈 시각에 로비 장식(호박·보라 조명)이 보이고, 기간 밖에는 없다.
- [ ] AC13: 새 스킨 5종이 탈의실 미리보기와 게임 속에서 이상하게 겹치거나 크지 않다(관리자 미리보기 m5-02로 금박 계란초밥도 확인).
- [ ] AC14: 휴대폰 에뮬레이터에서 이벤트 탭·머리줄·배지가 다른 UI와 안 겹친다.

## 공용 파일 변경
- 없음 (m5-03이 리모트·Config·Types·카탈로그를 확정. 이벤트 재화 수치를 바꾸려면 `Config.Events` — 결정 기록에 적고 사용자에게 알림)

## 사용자 작업
- **개발자 상품 2개 만들기**: "호박 초밥" R$ 99, "산타 새우" R$ 99 → id를 `src/shared/Skins.luau`의 `productId`에 (USER-TODO C3에 추가 — 크리스마스 상품은 12월 전에 만들어도 됨).
- 이벤트 기간·재화 가격·"다음 해에 다시 올 수도 있어요" 문구를 그대로 쓸지 확인.
- `TokenGet` 소리 id(USER-TODO A2).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 시즌 구조 · **무료 한정 1종(이벤트 재화) + 유료 한정 1종(R$ 99)**을 이벤트마다. 이벤트 재화는 플레이 보상에 얹어서 주고(따로 줍기·퀘스트 없음), 기간 중에만 교환. 뽑기·배틀 패스 없음. 근거: MM2 할로윈 사탕·Adopt Me Candy Corn(이벤트 재화로 한정 아이템), Epic Minigames 연도 붙은 계절 번들(기간 뒤 판매 종료), GDD 9.2 "에픽 가격대" — REFERENCE-roblox-monetization 8.1·8.2·8.6. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · D2 재화 양 · 판 참가 1·통과 1·결승 2·우승 5·하루 첫 판 3, 스킨 80 → 약 25~30판(레어 코인 해금 30판과 비슷), 매번 떨어지는 아이도 기간 안에 받을 수 있게 "판 참가 +1"을 넣음. **기본값, 플레이테스트 후 조정** · planner
- 2026-10-08 · D3 남은 재화 · 코인으로 바꿔 주지 않음(MM2는 바꿔 주지만, 우리는 코인 경제를 단순하게) · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D4 압박 판매 피하기 · 남은 기간은 날짜로만, 초 단위 카운트다운·"마지막 기회"·깜빡임 없음, "다음 해에 다시 올 수도 있어요" 안내. 근거: 인기 로블록스 게임의 기만적 수익화 관행 연구(2025~2026)·TINA 2022, 이용층 대부분 미성년 — REFERENCE 1·8.2-4. 다시 올지는 확정이 아니라 "올 수도"로 · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D5 VIP 금박 계란초밥의 생김새를 이 스펙에서 · SushiBody를 한 스펙만 고치게(m5-08은 소유만 다룸) · planner
- 2026-10-13 · DEV1 목록 밖 테스트 2개 수정 · 새 스킨에 효과가 붙고 재화·VIP 카드가 진짜 상태가 되면서 기존 테스트가 옛 기대값을 고정하고 있었어요. `tests/skins.spec.luau`의 효과 표에 `ghost-tamago`(Glow)·`tree-maki`·`vip-gold-tamago`(Sparkles)를 넣고, `tests/m5-03-foundation.spec.luau` "AC5 탈의실 카드"를 `Soon` → `NeedTokens`("🍬 0 / 80")·`Vip`("👑 VIP 전용")로 바꿨어요. 테스트 파일이라 공용 파일은 아니에요 · developer
- 2026-10-13 · DEV2 스펙 해석(등급 탭) · "보유 → 원래 등급 탭에도 보임"을 **받기 전 한정 스킨은 등급 탭에 안 보이고 이벤트 탭·"전체" 탭에만** 보이는 것으로 해석했어요(`ShopLogic.visibleSkins`). 기간이 끝난 미보유 한정 스킨은 전체 포함 어느 탭에도 없어요. 다르게 원하면 `visibleSkins`의 tier 분기 한 줄 · **QA·기획 확인 부탁** · developer
- 2026-10-13 · DEV3 유령 빛 · "PointLight 약하게"를 m5-21의 `Glow` 효과(PointLight, Range 8·Brightness 2, 흰색)로 했어요(효과 1개 예산 안). 더 약하게 하려면 SushiBody에 효과 세기 칸이 필요해요 · developer
- 2026-10-13 · DEV4 생김새 크기 · 5종 모두 등급 허용치(에픽·전설 ±25%)보다 좁은 스펙 값 **±15%** 안으로 맞췄어요. 산타 모자는 높이 상한(계란초밥 4.7 × 1.15) 때문에 낮게 접힌 모양이에요 · developer
- 2026-10-13 · DEV5 로벅스 카드 글씨 · 유료 한정 카드는 "지금 로벅스 카드와 같음"을 따라 기존 글씨(`R$ 99`, 상품 id 없으면 `R$ 99 — 곧 열려요`)를 그대로 써요. 표의 "R$ 99로 사기"로 바꾸려면 `ShopLogic.cardButtonText` 한 줄 · developer
- 2026-10-13 · DEV6 로비 장식 데이터 위치 · 장식 숫자는 공용이 아닌 `LobbyLayout`이 아니라 수정 목록에 있는 `LobbyService` 안에 두었어요(파츠: 할로윈 20, 크리스마스 23). 순수 테스트는 소스 검사로만 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-13 구현 (브랜치 `m5-07-season`)
**바뀐 파일** (공용 파일 수정 없음)
- `src/shared/RewardLogic.luau` — `tokensFor(reason, now)`, `onRoundStart`/`onResult` 마지막 인자 `now?`(nil이면 예전처럼 재화 없음), `matchEndPayout(lastDay, today, now)` → DailyFirstMatch(50 + 재화 4) / MatchPlayed(0 + 1) / nil, `matchTokenTotal`, `toastText`·`summaryText`에 재화 인자, `simulate`가 (코인, 재화) 두 표.
- `src/server/RewardService.luau` — 지급 하나에 코인·재화를 한 `update`로, `eventTokens[eventId]`에 더하고 `RewardGranted`에 `tokens`·`tokenTotal`·`eventId`. 매치 끝은 `matchEndPayout` 한 번(코인·재화 0이면 안 보냄). 시각은 `Seasons.now(Studio, Config.DEBUG.eventNow, os.time())`.
- `src/shared/ShopLogic.luau` — Reason `NotForTokens`·`EventEnded`·`NeedTokens`, `canBuyWithTokens`/`buyWithTokens`, `tokensOf`·`isLimited`·`onSale`, `cardState(skin, view, robux?, now?)`에 `Tokens`·`NeedTokens`·`Vip`·`OffSale`·`limited`, `tabs`/`defaultTab`/`eventTab`/`visibleSkins`, `eventHeader`·`lastDayText`(os.date 없이 UTC 날짜 계산), `EVENT_TAB_LABEL`·`EVENT_NOTE`. `Wallet`·`ViewLike`에 `eventTokens`.
- `src/server/ShopService.luau` — `BuyWithTokens` 리모트(요청 간격 공유, Studio 메모리 모드 허용, 성공 시 미리보기 끄기 + 다시 입히기 + `saveNow`).
- `src/shared/SushiBody.luau` — PartSpec `transparency` 칸, 새 스킨 5종 진짜 생김새(호박 초밥, 유령 계란초밥 Glow, 산타 새우, 트리 마키 Sparkles, 금박 계란초밥 Sparkles).
- `src/client/ui/ShopScreen.luau`·`ShopController.luau` — 데이터 탭(이벤트 탭 맨 앞·열 때 먼저), 이벤트 머리줄 + 안내 문구, `visibleSkins`로 카드 숨김, 보유 한정 카드 "한정" 표시, 재화 받기 → `BuyWithTokens`, 가격은 `PriceCache.product`(직접 `GetProductInfoAsync` 하던 반복 제거).
- `src/client/ui/CoinScreen.luau`·`CoinController.luau` — 배지 옆 재화 "🍬 32"(이벤트 없으면 숨김, 1분마다 다시 봄), 토스트 "+10 🍚 +1 🍬 라운드 통과"/"+1 🍬 판 참가" + `TokenGet` 소리, 우승 정산 "+M 🍬".
- `src/server/LobbyService.luau` — 시즌 장식(할로윈 호박 6·보라 조명 2 / 크리스마스 트리 2·눈 1·선물 4), 로비 지은 뒤와 10분마다, MapKit 장식 규칙.
- 테스트: `tests/reward-logic.spec.luau`·`shop-logic.spec.luau`·`sushi-body.spec.luau`에 추가, 새 `tests/season-shop.spec.luau`(ShopService·RewardService를 가짜 환경으로 직접 돌림 + 클라이언트·로비 소스 검사). 목록 밖 수정 `tests/skins.spec.luau`·`tests/m5-03-foundation.spec.luau`(결정 기록 DEV1).
- 사용하지 않은 것: `Skins.luau`(상품 id는 사용자 몫이라 그대로), `Seasons.luau`(숫자 그대로).

**검증 5단계** (Windows 로컬, 2026-10-13): `rojo build` 통과, `stylua --check` 통과, `selene src` 0 errors 0 warnings, `lune run tests` 1258 passed 0 failed, `luau-lsp analyze` 끝 코드 0.

**Studio 확인 방법** (AC8~AC14)
1. `src/shared/Config.luau`의 `DEBUG.eventNow = 1792108800`(할로윈 첫날). 필요하면 `forceMapPlan`, `fakeRobuxInStudio = true`. **확인 뒤 모두 커밋 값(nil/false)으로 되돌리기.**
2. Play Solo → 왼쪽 위 코인 배지 옆 "🍬 0", 로비 카운터 둘레에 호박 6개와 보라 조명 2개(AC8·AC12).
3. "🍣 스킨" → "🎃 할로윈" 탭이 먼저 선택, 머리줄 "할로윈 초밥 축제 · 11월 5일까지 · 🍬 0"과 안내 문구, 카드 2개(호박 초밥 R$ 99, 유령 계란초밥 "🍬 0 / 80")(AC8).
4. 한 판 하기 → 통과 때 "+10 🍚 +1 🍬 라운드 통과"(TokenGet은 소리 id 전이라 무음), 매치 끝 "+50 🍚 +4 🍬 오늘 첫 판"(그날 첫 판), 우승 화면 "이번 판 +N 🍚 +M 🍬 (총 …)"(AC9).
5. 재화 80 채우기: Studio 명령줄(서버)에서 `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.eventTokens["halloween-2026"] = 80 end)` → 탈의실 "🍬 80으로 받기" → 유령 계란초밥이 바로 입혀지고 재화 0. 라운드 중에는 버튼이 숨거나 "매치가 끝나면 바꿀 수 있어요"(AC10). (ProfileUpdated가 늦으면 탈의실을 닫았다 열기)
6. `fakeRobuxInStudio = true`로 호박 초밥 R$ 99 → 가짜 결제 지급(AC11). 그다음 `eventNow = 1793923200`(끝) → 미보유 한정 스킨이 어느 탭에도 없고 이벤트 탭·재화 배지·호박 장식도 없음, 가진 호박 초밥은 에픽 탭에 "한정" 표시(AC11·AC12).
7. 크리스마스 `eventNow = 1796947200` → "🎄 크리스마스" 탭, ⭐ 배지, 트리·선물·눈 장식.
8. 생김새: 탈의실 미리보기 + 관리자 "🛠" 미리보기로 5종(금박 계란초밥 포함)을 게임 속에서 확인(AC13). 휴대폰 에뮬레이터에서 이벤트 탭·머리줄·배지가 안 겹치는지(AC14).

**남은 이슈 · 확인 필요**
- 결정 기록 DEV2(등급 탭 해석)·DEV5(로벅스 카드 글씨) 확인.
- 클라이언트 시각은 `GetServerTimeNow()`라 이벤트 경계에서 배지·탭이 서버보다 최대 1분(배지)/탈의실을 다시 그릴 때까지 늦게 바뀔 수 있어요. 교환·판매 판단은 서버라 결과는 맞아요.
- 로비 장식은 로비를 지은 뒤 10분마다 확인 — 경계 직후 최대 10분 늦게 켜지고 꺼져요(스펙대로).
- `TokenGet` 소리 id 없음(무음, USER-TODO A2), 상품 id 2개 없음(USER-TODO C3).
