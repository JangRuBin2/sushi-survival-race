# REFERENCE — 로블록스 코스메틱 가격·수익화 시세 (참고용, 결정 아님)

- 작성: planner, 2026-10-08 (모든 출처 확인 날짜 = 2026-10-08)
- 목적: 스킨 가격(GDD 9.2·9.4, m4-13·m4-14)을 로블록스 시세와 문화에 맞게 다시 정하기 위한 근거. 사용자가 "스킨이 너무 비싸다, 시세를 모르고 정한 것 같다"고 지적.
- 이 문서는 **참고 자료**다. 가격 결정은 스펙 결정 기록(m4-13·m4-14)과 사용자 확정 뒤 GDD에 들어간다.
- 표기: **[원문]** = WebFetch로 원문(공식 API·공식 문서 포함)을 직접 확인, **[검색]** = 검색 결과 요약만 확인(원문 미확인), **확인 못 함** = 찾지 못함. 추정은 "추정"이라고 쓴다.

---

## 1. 로블록스 이용층과 구매 문화

| 항목 | 내용 | 근거 |
|---|---|---|
| 일일 이용자 | 2025년 4분기 DAU 1억 4,400만 | [원문] [Outlook Respawn](https://respawn.outlookindia.com/gaming/gaming-news/roblox-daily-users-jump-69-to-record-144-million-in-q4-2025) |
| 연령 | 2026년 1월 나이 인증을 한 이용자 중 **13세 미만 35%, 13~17세 38%, 18세 이상 27%** (인증자는 DAU의 45%뿐이라 일부 표본) → **약 4분의 3이 미성년** | [원문] 같은 기사 |
| 연령 (다른 수치) | 2025년 2분기 13세 미만 DAU 약 3,970만(전체의 약 36%) | [검색] [Exploding Topics](https://explodingtopics.com/blog/roblox-stats), [Statista](https://www.statista.com/statistics/1190309/daily-active-users-worldwide-roblox) |
| 결제자 1인당 | 2025년 월 결제자 3,670만 명, 결제자 1인당 평균 약 $20 (연간 추정치로 보도) | [원문] Outlook Respawn (기사 계산값이라 정확도 낮음) |
| 보호자 통제 | 13세 미만은 보호자가 **월 결제 한도**를 걸 수 있고 결제마다 알림을 받을 수 있다 (2025년 1분기부터 원격 관리) | [검색] [Rowatcher 2026 가이드](https://rowatcher.com/news/roblox-parental-controls-2026-the-complete-setup-guide), [PocketGamer.biz](https://www.pocketgamer.biz/new-roblox-safety-features-give-parents-more-control) |
| 용돈 단위 | 아이들은 한 달에 400~800 R$(기프트 카드·Premium)를 쓰는 경우가 많다는 가격 가이드 서술 | [원문] [creation.dev 가격 가이드](https://www.creation.dev/learn/how-to-price-game-passes-roblox) (업계 블로그, 통계 아님) |

**정리**: 주 이용층은 미성년(특히 13세 미만이 3분의 1 이상), 한 번에 쓰는 돈은 **기프트 카드 한 장(약 $5~$10) 안**이다. 비싼 한 개보다 **싼 여러 개**가 맞는 시장이다.

## 2. 로벅스의 실제 돈 가치

| 묶음 (미국 기준) | 모바일 | PC·웹 | 근거 |
|---|---|---|---|
| $4.99 | 400 R$ | 500 R$ | [검색] [Rowatcher Robux 가격 2026](https://rowatcher.com/news/robux-prices-bundles-2026-guide) |
| $9.99 | 800 R$ | 1,000 R$ | 같음 |
| $19.99 | 1,700 R$ | 2,000 R$ | 같음 |
| 가장 작은 묶음 | 80 R$ = $0.99 | | [검색] [generalistprogrammer](https://generalistprogrammer.com/tutorials/roblox-game-pass-pricing-guide) |

| 한국 원화 (devcomma 표, 수집 날짜 표기 없음) | 웹·PC·기프트 | 모바일·콘솔 |
|---|---|---|
| 4,400원 | 270 R$ (16.3원/R$) | 240 R$ |
| 7,500원 | 500 R$ (15원/R$) | 400 R$ (18.75원/R$) |
| 15,000원 | 1,000 R$ | 800 R$ |
| 30,000원 | 2,000 R$ | 1,700 R$ |

근거: [원문] [devcomma 로벅스 계산기](https://tools.devcomma.com/calculators/robux-calculator) — "플랫폼·지역·계정·프로모션에 따라 달라짐"이라고 적혀 있음.

- **환산 기준(이 문서)**: 1 R$ ≈ **15~19원** ≈ **$0.0100~$0.0125** (아이 입장 = 사는 가격). 만든 사람이 받는 돈은 수수료 30% 뒤 DevEx 약 $0.0038/R$ [원문 아님, 검색].
- 그래서 지금 전설 스킨 **399 R$ ≈ 6,000~7,500원 ≈ $5** = 아이가 가장 흔히 받는 **기프트 카드 한 장 전부**.

## 3. 비슷한 로블록스 게임의 실제 가격

공식 Roblox API(`apis.roblox.com/game-passes/v1/universes/<id>/game-passes`)로 **판매 중인 게임 패스 가격을 직접 확인**했다 [원문]. 개발자 상품 목록은 공개 API가 없어 확인 못 함 → 위키·기사 [검색]으로 보충.

| # | 게임 (장르) | 코스메틱·관련 상품과 가격 (R$) | 무료(플레이)로 얻는 길 | 판매 방식 | 근거 |
|---|---|---|---|---|---|
| A | **Epic Minigames** (파티 미니게임 — 우리와 가장 비슷) | Second Effect **99**, Second Pet **99**, Starter Pack(기어+칭호) **99**, Illumina(효과) **149**, x4 Controller Chance 249, Double Coins 299, Play Rewards Plus 299, Party Premium 349, VIP(기어+펫+효과+칭호) **499**, 계절 번들(이스터·발렌타인·크리스마스·할로윈) 기간 한정 | 우승 10코인(Pro 서버 +5)으로 기어·효과·칭호·펫을 상점에서 삼. 코드로 코스메틱 지급 | 게임 패스 + 계절 한정 번들 | [원문] API (universe 110181652), [검색] [Typical Games 위키](https://typical-games.fandom.com/wiki/Epic_Minigames?oldid=3058), [Dexerto 코드](https://www.dexerto.com/roblox/epic-minigames-codes-3302130/) |
| B | **Speed Run 4** (레이스 오비) | Sparkles Effect(트레일) **50**, Fire Effect(트레일) **55**, 2x Luck 99, Speed Coil 170, VIP 599, Fly on a Cloud 800 | 코스, 레벨팩 | 게임 패스 | [원문] API (universe 83858907) |
| C | **Hide and Seek Extreme** (파티 술래잡기) | The Yeti(캐릭터 겉모습) **50**, Triple Coin Value 30, Seeker chance 100, Boombox 300 | 코인 | 게임 패스 | [원문] API (universe 93740418) |
| D | **Natural Disaster Survival** (서바이벌 라운드) | Yellow Compass **60**, Red Apple **80**, Green Balloon **95** (기어) | — | 게임 패스, 3개뿐 | [원문] API (universe 65241) |
| E | **Tower of Hell** (오비) | Double Coins **195**, Summer Bundle 349. 코인 묶음 200코인 25 R$ ~ 10,000코인 1,100 R$ | 탑을 깨면 코인 → 기어·뮤테이터 | 게임 패스 + 코인 판매(개발자 상품) | [원문] API (universe 703124385), [검색] [Pro Game Guides](https://progameguides.com/roblox/how-to-get-coins-fast-in-tower-of-hell-roblox/) |
| F | **Super Bomb Survival** (서바이벌 라운드) | Map Vote Priority 35, Bloxgiving Skills 39, Triple Coin Value 65, +10 Max HP 95, Second Skill Slot 249, VIP 400 | 코인 | 게임 패스 (능력치 판매 포함 — 우리는 금지) | [원문] API (universe 78351145) |
| G | **Piggy** (호러 라운드) | 스킨은 대부분 **Piggy Token**으로 삼: 50~725토큰. 토큰은 탈출 15, 처치 5. 토큰도 R$로 판매(1,000토큰 ≈ 786 R$). 게임 패스는 x2 Tokens 300, x2 Piggy Chance 150 | **스킨 대부분이 플레이 재화로 해금** (탈출 4~50번) | 재화(토큰) + 게임 패스 | [원문] API (universe 1516533665), [검색] [Piggy 위키](https://piggy.fandom.com/wiki/Piggy_Tokens), [Pro Game Guides](https://progameguides.com/roblox/how-to-get-piggy-tokens-in-roblox-piggy/) |
| H | **Arsenal** (FPS, 10대) | Primus the Knight Bundle(캐릭터+근접 스킨) **245**, VIP 395, Day of the Dead Bundle 395, Bugs & Beasts 495, Nexus Bundle 725 | Bucks(플레이 재화)·코드로 스킨 | **번들** 게임 패스 | [원문] API (universe 111958650) |
| I | **Rivals** (FPS, 10대) | Starter Bundle **59**, RPG Bundle 95, Medkit 289, Exogun 649, Standard Weapons 849, Classic 865, Energy 975, Heavy Duty 1,425. 스킨 상자 249(3개 724), 일일 상점 스킨 일반 299 / 레어 449 / 전설 599 | 무료 시즌 패스로 스킨 티켓(시즌당 상자 1개 분량) | 번들 게임 패스 + **확률형 상자**(확률 공개) + 일일 상점 | [원문] API (universe 6035872082), [원문] [Eldorado 가이드](https://www.eldorado.gg/blog/roblox-en/how-to-get-roblox-rivals-skins-cheaper/) (일일 상점 가격은 [검색]만) |
| J | **Murder Mystery 2** (라운드 추리, 대형 고참 게임) | Elite 499, Radio 475, BUNDLE: Beach 3,399. Godly 무기 패스는 과거 1,699 R$ | 상자·거래 | 게임 패스, 대부분 기간 한정 후 판매 종료 → 거래 시장 | [원문] API (universe 66654135), [검색] [Sportskeeda](https://sportskeeda.com/roblox-news/plasmablade-roblox-murder-mystery-2-how-obtain-price-rarity) |
| K | **BedWars** (PvP, 10대) | 키트(능력, 코스메틱 아님) 대부분 **399**, 2키트 번들 799. 키트 스킨 799(검색) | 배틀 패스·매주 무료 키트 | 게임 패스 + 배틀 패스 | [원문] API (universe 2619619496), [검색] [Scribd 위키 사본](https://www.scribd.com/document/854519267/Kit-BedWars-Wiki-Fandom-5) |
| — | DOORS (호러) | 노브 250 = 49 R$ … 2,800 = 399 R$, 부활 5개 120 R$ | 판을 끝내면 노브 | 재화 판매 | [검색] [DOORS 위키](https://doors-game.fandom.com/wiki/Knobs) (원문 402로 확인 못 함) |

### 사례에서 읽히는 것
1. **어린 층·캐주얼 라운드 게임(A~D)의 단품 코스메틱은 50~150 R$**다. 트레일·효과 50~55(B), 캐릭터 겉모습 50(C), 효과 99~149(A). 300 R$ 이상은 VIP·배수·번들 같은 "여러 개 묶음"이다.
2. **300~800 R$ 단품·번들은 10대 대상 대형 PvP(H~K)**의 가격이다. 이 게임들은 수년간 신뢰가 쌓였고, 경쟁 게임이라 "멋있어 보이기" 가치가 크다. 새 파티 게임이 그대로 따라 할 근거가 아니다.
3. **무료로 얻는 길이 넓다.** Piggy(G)는 스킨 대부분을 플레이 재화로, Epic Minigames(A)는 코스메틱 상점을 코인으로, Rivals(I)는 무료 시즌 패스로 스킨을 준다. 유료는 "빨리·특별하게"다.
4. **코드·이벤트 무료 보상 문화**: Epic Minigames·Arsenal·DOORS 등 대부분 인기작이 SNS 코드로 코스메틱·재화를 준다 [검색] (A, H 근거 링크, [Doors 코드](https://sportskeeda.com/roblox-news/doors-codes)).
5. **번들·계절 한정**이 흔하다: Epic Minigames 계절 번들, Arsenal·Rivals 번들, MM2 기간 한정. 가장 싼 번들은 입문용(Rivals Starter 59, Epic Minigames Starter Pack 99).
6. 대부분 **영구 코스메틱을 게임 패스로** 판다(A·B·C·H). 우리는 GDD 9.5대로 개발자 상품 + DataStore(스킨 수가 많아 관리 쉬움) — 정책상 문제 없음. 차이: 게임 패스는 지역 가격이 기본으로 켜지고, 개발자 상품은 `GetUsersPriceLevelsAsync`를 스크립트에 넣어야 지역 가격을 쓸 수 있다(6절).

## 4. 가격 책정 가이드 (업계·공식)

| 내용 | 근거 |
|---|---|
| 가격대: **25~75 R$ = 반사적 구매**(관심만 있어도 누름, 코스메틱·첫 상품에 적합), **100~250 R$ = 고민하는 구매**, **400~1,000+ R$ = 게임을 믿어야 사는 구매** | [원문] [generalistprogrammer 가격 가이드 2026](https://generalistprogrammer.com/tutorials/roblox-game-pass-pricing-guide) |
| "**검증 안 된 새 게임은 신뢰가 없어서 비싼 가격은 거의 안 팔린다.** 반사적 구매 구간으로 출시하고, 플레이어가 쌓인 뒤 올려라." | 같음 |
| 작은 코스메틱 **25~75 R$**, 편의 49~149, 배수 99~249, VIP 묶음 199~499. 많이 팔리는 구간 49~199. 끝자리 9(49·99·149·249)가 둥근 수보다 잘 팔림 | [원문] [creation.dev](https://www.creation.dev/learn/how-to-price-game-passes-roblox) |
| 로블록스 공식 문서는 **권장 가격을 주지 않는다.** 대신 **가격 최적화**(A/B 테스트, 최근 30일 거래 6만 건 이상 필요)와 **지역 가격**(기본가의 30~100%, 구매력에 따라 자동)을 제공 | [원문] [Price optimization](https://create.roblox.com/docs/en-us/production/monetization/price-optimization.md), [Regional pricing](https://create.roblox.com/docs/en-us/production/monetization/regional-pricing.md), [Managed pricing](https://create.roblox.com/docs/en-us/production/monetization/managed-pricing.md) |
| 개발자 포럼의 전환율 수치 | **확인 못 함** (포럼 글을 찾지 못함, 위 두 블로그도 전환율 숫자는 없음) |

## 5. 확률형(뽑기) 규제 경향
- 로블록스 정책: R$(또는 R$로 산 재화)로 사는 **랜덤 상품은 모든 결과와 확률(합 100%)을 구매 전에 공개**해야 한다. `PolicyService`의 `ArePaidRandomItemsRestricted`가 true인 사용자에게는 유료 랜덤을 막고 무료 경로·고정 순서·직접 구매 같은 대안을 줘야 한다. [원문] [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- 한국 확률형 아이템 규제가 로블록스 전체의 확률 공개를 밀어붙였다는 보도(2026-06). [검색] [Tech Times](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)
- → GDD 9.1 "유료 랜덤 뽑기 없음, 골라서 산다"는 시세·규제 양쪽에서 맞다. 유지.

## 6. 우리 게임에 대한 시사점 (요약)
1. 지금 표(일반 49 / 레어 99 / 에픽 199 / 전설 399, 15종 전부 2,435 R$ ≈ $30 ≈ 3.7~4.6만 원)는 **10대 PvP 대형작의 가격대**에 가깝고, 우리 같은 새 캐주얼 파티 게임(사례 A~D: 단품 50~150)보다 **약 2배** 높다. 전설 1개 = 기프트 카드 한 장 전부.
2. 반사적 구매 구간(25~75)에 일반·레어를, 고민 구간(100~250)에 에픽·전설을 두는 게 맞다.
3. 무료 경로는 일반만이 아니라 **레어까지** 넓혀야 "꾸준히 할 이유"가 길어진다(Piggy·Epic Minigames).
4. 번들(스타터 팩·세트 할인)·코드 보상·계절 한정은 로블록스에서 흔한 관행 → M5.
5. 출시 뒤 거래가 많아지면 지역 가격(개발자 상품은 `GetUsersPriceLevelsAsync` 필요)·가격 최적화(30일 6만 건)를 검토 → M5 이후.

---

## 7. 가격 제안 (2026-10-08, planner — 추천안 A를 m4-13·m4-14의 **기본값**으로 둠, 사용자 확정 전, GDD 미반영)

### 7.1 코인 벌이 계산 (지금 보상: 라운드 통과 +10, 결승 출발 +30, 우승 +100, 하루 첫 판 +50 — m4-08)
`Rules.qualifyCount`(math.round) 기준으로 한 판에 나오는 코인 총합을 인원수로 나눈 **1인 평균**(하루 첫 판 50 제외):

| 시작 인원 | 라운드별 통과 | 판 전체 코인 | 1인 평균 / 판 | 우승자 / 판 |
|---|---|---|---|---|
| 4명 (3라운드, R2 건너뜀) | 2 → 결승 2 | 20 + 60 + 100 = 180 | **45** | 140 |
| 8명 (3라운드) | 5, 3 → 결승 3 | 80 + 90 + 100 = 270 | **34** | 150 |
| 16명 (4라운드) | 10, 6, 3 → 결승 3 | 190 + 90 + 100 = 380 | **24** | 160 |
| 24명 (4라운드) | 16, 9, 5 → 결승 5 | 300 + 150 + 100 = 550 | **23** | 160 |

→ **대표값: 1판 평균 약 30코인**(한 판 4~5분). 하루 5판(약 25분) 하는 아이 = 5 × 30 + 50 = **약 200코인/일**.

### 7.2 추천안 A — "반값 사다리 + 레어까지 코인" (기본값)

| 등급 | 개수 | R$ (지금 → 제안) | 원화 (15~19원/R$) | 코인 (지금 → 제안) | 해금 판수 (평균 30/판) | 하루 5판이면 |
|---|---|---|---|---|---|---|
| 기본 | 1 | 무료 | — | 무료 | — | — |
| 일반 | 5 | 49 → **29** | 약 450~550원 | 500 → **300** | **10판** (약 45분) | 2일째 |
| 레어 | 4 | 99 → **59** | 약 900~1,100원 | 없음 → **900** | **30판** (약 2시간 15분) | 5일 |
| 에픽 | 3 | 199 → **99** | 약 1,500~1,900원 | 없음 (로벅스만) | — | — |
| 전설 | 3 | 399 → **199** | 약 3,000~3,800원 | 없음 (로벅스만) | — | — |
| **15종 전부** | | 2,435 → **1,275 R$** (약 $16) | 약 1.9~2.4만 원 | 무료로 일반+레어 9종 = 5,100코인 | 약 170판 | 약 26일 |

- 기프트 카드 한 장(400 R$)으로 **전설 1 + 에픽 1 + 레어 1 + 일반 1**(386 R$)을 살 수 있다. 지금은 전설 1개(399)로 끝.
- 우승 한 번(150~210)이면 일반 스킨이 거의 손에 들어온다 → 첫 판들에서 "얻는 맛".
- 근거:
  - 일반 29 / 레어 59 = 반사적 구매 구간 25~75, 캐주얼 게임 단품 50~55 — 사례 B(트레일 50·55)·C(Yeti 50)·I(Starter 59), 4절 가이드.
  - 에픽 99 / 전설 199 = 고민 구간 100~250, 파티 게임 효과 99~149 — 사례 A(Second Effect 99·Illumina 149)·H(가장 싼 스킨 번들 245)·4절 "새 게임은 반사적 구간으로 출시".
  - 등급마다 약 2배 사다리(29→59→99→199)는 지금 구조(49→99→199→399)를 유지 — 사례 I(일일 상점 등급별 가격 사다리)·끝자리 9 가이드(4절).
  - 레어까지 코인 해금 = 무료 경로를 넓게 — 사례 G(스킨 대부분 토큰 해금)·A(코스메틱 상점 코인)·I(무료 시즌 패스 스킨).
  - 에픽·전설은 로벅스만 = "특별한 것은 유료"를 남겨 수익 확보, 능력치는 그대로(GDD 9.1) — 사례 A(VIP 효과)·H·I.

### 7.3 대안 B — "가격만 내리기" (코드 변경 최소)

| 등급 | R$ | 코인 | 해금 판수 |
|---|---|---|---|
| 일반 | **39** | **400** | 약 14판 (하루 5판이면 2일째) |
| 레어 | **79** | 없음 | — |
| 에픽 | **149** | 없음 | — |
| 전설 | **249** | 없음 | — |
| 15종 전부 | 1,705 R$ (약 $21) | 일반 5종 2,000코인 ≈ 67판 ≈ 10일 | |

- 장점: `Skins.validate`의 "코인은 일반만" 규칙과 GDD 9.4 구조를 그대로 둠(숫자만 바꿈). 단점: 무료 경로가 10일 만에 끝나 꾸준히 할 이유가 짧고, 전설 249는 여전히 새 게임엔 고민 구간 위쪽.
- 근거: 사례 A(149)·H(245)·4절 "많이 팔리는 구간 49~199".

### 7.4 구조 제안 (전부 **M5**, 지금 개발 안 함)
| 제안 | 내용 | 근거 |
|---|---|---|
| 스타터 팩 | 일반 3종 + 레어 1종, **R$ 79**, 계정당 1번 (GDD 9.3 "스타터 번들 149"를 새 가격 사다리에 맞춰 낮춤. 따로 사면 146) | 사례 I(Starter 59)·A(Starter Pack 99)·H(번들) |
| 등급 세트 | 전설 3종 R$ 499(따로 597), 에픽 3종 R$ 249(따로 297) | 사례 H·I(번들 할인), J(번들) |
| 코드 보상 | SNS 코드로 코인 100~300 | 3절 4번(사례 A·H·DOORS 코드 문화) |
| 계절 한정 | GDD 9.2 시즌 한정(할로윈 호박 초밥 등) = 에픽 가격대 99, 기간 뒤 판매 종료 | 사례 A(계절 번들)·J(기간 한정) |
| 코인 R$ 판매 | **하지 않는 것을 추천** — 무료 재화의 의미가 흐려짐. 필요하면 사용자 결정 | 사례 E·G·DOORS는 하지만 모두 오래된 대형작 |
| 지역 가격 | 개발자 상품에 `GetUsersPriceLevelsAsync` 연결 | 4절 공식 문서 |
| GDD 9.3 다른 상품 | 탈락·우승 연출 팩(79~199), VIP 249도 새 사다리에 맞춰 다시 볼 것 (예: 연출 팩 49~99, VIP 199) | 사례 A(VIP 499지만 여러 혜택)·C·4절 |
