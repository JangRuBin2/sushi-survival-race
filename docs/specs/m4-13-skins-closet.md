status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-13 — 스킨 목록 · 탈의실(미리보기·장착) · 코인 해금

- 마일스톤: M4 (**스킨·상점은 가장 마지막** — CLAUDE.md)
- GDD 근거: `docs/GDD.md` §3.1(스킨 상점, 탈의실), §6(스킨은 토핑·색·액세서리만, 히트박스·속도 동일), §7(말풍선 대사는 내 스킨에 맞춰), §9.1(기본 계란초밥, 고르는 방식, 뽑기 없음, 일반 스킨 일부 코인 해금), §9.2(스킨 목록·가격), §9.4(일반 스킨 500 코인)
- 담당 개발 worktree: `main` (**순차, m4-12 다음**)
- 공용 파일 수정 담당: **이 스펙** (m4-12 다음 차례)
- 의존: m4-12 병합 (m4-07 저장, m4-08 코인, m4-09 화면 배율이 있어야 함)
- **이 스펙이 고치는 파일**: `src/shared/SushiBody.luau`(스킨 레이아웃 추가), `src/server/AppearanceService.luau`(장착 스킨 고르기), `src/shared/EliminationCutsceneLogic.luau`(스킨 대사를 카탈로그에서), 공용 파일(`Remotes.luau`, `Config.luau`), 새 파일 `src/shared/Skins.luau`, `src/shared/ShopLogic.luau`, `src/server/ShopService.luau`, `src/client/ui/ShopController.luau`, `src/client/ui/ShopScreen.luau`, `tests/skins.spec.luau`, `tests/shop-logic.spec.luau`

## 목표
로비에서 "🍣 스킨" 버튼을 누르면 초밥 스킨 16종이 3D로 빙글빙글 돌며 나온다. 가진 스킨은 바로 입고, 일반 스킨은 모은 밥알 코인 500개로 해금한다. 입은 스킨은 로비·매치·탈락 연출·우승 연출·단상 어디서나 보이고, 탈락 말풍선도 스킨에 맞춰 나온다. 모든 스킨은 크기·판정이 같다. (로벅스 구매 버튼은 m4-14가 켠다 — 이 스펙에서는 "곧 열려요"로 비활성)

## 범위
- 포함:
  1. **스킨 카탈로그** `shared/Skins.luau` (순수 데이터, 가격은 GDD 9.2 그대로, 시즌 한정은 M5):

     | id | 이름 | 등급 | 로벅스 | 코인 |
     |---|---|---|---|---|
     | `tamago` | 계란초밥 | 기본 | — | 무료 |
     | `salmon` | 연어 | 일반 | 49 | 500 |
     | `tuna` | 참치 | 일반 | 49 | 500 |
     | `shrimp` | 새우 | 일반 | 49 | 500 |
     | `inari` | 유부 | 일반 | 49 | 500 |
     | `kappa-maki` | 오이마키 | 일반 | 49 | 500 |
     | `eel` | 장어 | 레어 | 99 | — |
     | `uni` | 성게 | 레어 | 99 | — |
     | `ikura` | 연어알 군함 | 레어 | 99 | — |
     | `octopus` | 문어 | 레어 | 99 | — |
     | `rainbow-roll` | 무지개 롤 | 에픽 | 199 | — |
     | `aburi-salmon` | 불꽃 연어 | 에픽 | 199 | — |
     | `california-roll` | 아보카도 캘리포니아롤 | 에픽 | 199 | — |
     | `golden-otoro` | 황금 참치 뱃살 | 전설 | 399 | — |
     | `diamond-uni` | 다이아 성게 | 전설 | 399 | — |
     | `dragon-roll` | 용 롤 | 전설 | 399 | — |

     항목: `id, displayName, tier, robux: number?, coins: number?, productId: number?(m4-14, 지금 nil), speech: { string }(1~2줄), order`.
  2. **생김새** (`SushiBody.layout`에 15종 추가): 계란초밥과 같은 밥 몸통·눈·입·발 위에 **토핑만 바꾼다**(GDD 6). 예: 연어 = 주황 + 흰 줄무늬 토핑, 참치 = 진빨강, 새우 = 주황·흰 줄 + 꼬리, 유부 = 밥을 감싼 갈색 주머니, 오이마키 = 김으로 감싼 원통 + 초록 단면, 장어 = 갈색 + 소스 광택, 성게 = 노랑 알갱이(작은 Ball), 연어알 = 김 띠 + 주황 구슬, 문어 = 연보라 + 빨간 테두리 빨판, 무지개 롤 = 여러 색 띠, 불꽃 연어 = 그을린 연어 + 작은 불꽃(ParticleEmitter, 한 개), 캘리포니아 = 초록 아보카도 + 주황 날치알, 황금 참치 = `Foil` 금색 + 반짝이(Sparkles 한 개), 다이아 성게 = 하늘색 `Glass` 알갱이 + 반짝이, 용 롤 = 초록 비늘 + 머리·꼬리 파츠(움직이는 꼬리 애니메이션은 M5).
     - **모든 스킨의 외곽 상자가 계란초밥 외곽의 ±15% 안**(연출·이름표 높이 일정), 효과(파티클·조명)는 스킨당 1개 이하.
     - `PartSpec`에 선택 필드 `shape`(Block/Ball/Cylinder)와 `effect`("Fire"|"Sparkles"|nil)를 추가해도 된다(기존 테스트 유지).
  3. **외형 적용 = `AppearanceService.applyAppearance` 한 곳**: `appearanceId`가 nil이면 `DataService.get(player)`의 `equippedSkin`(없으면 `Config.Appearance.Default`). 프로필이 캐릭터보다 늦게 로드되면 로드된 뒤 다시 입힌다. 장착을 바꾸면 그 자리에서 다시 입힌다(아래 4).
  4. **서버** `ShopService` + 리모트(RemoteFunction, 서버 검증):
     - `EquipSkin(skinId: string)` — 카탈로그에 있고 보유 중이어야 함. 출발한 라운드의 레이서이거나 연출 중이면 거절("매치가 끝나면 바꿀 수 있어요") — 로비·방 대기실·관전 중·대기석에서는 됨. 성공하면 `equippedSkin` 저장(dirty) + 캐릭터에 바로 다시 입힘. 요청 간격 0.3초.
     - `BuyWithCoins(skinId: string)` — `coins` 가격이 있는 스킨만, 미보유, `coins ≥ 가격`이면 차감 + 보유 + 자동 장착. 판단은 `ShopLogic`(순수). 임시 프로필(`canPersist = false`)이면 Studio 메모리 모드에서는 허용, 실제 서버 로드 실패 상태에서는 거절("저장이 안 되는 상태예요").
  5. **클라이언트** `ShopController` + `ShopScreen` (자기 ScreenGui `ShopGui`, `UiScaleController.attach`):
     - 로비에서만 보이는 "🍣 스킨" 버튼(코인 배지 아래, 방 대기실에서도 보임, 매치 중 숨김).
     - 창: 등급 탭(전체/일반/레어/에픽/전설) + 스킨 카드 격자(이름, 등급 색 테두리, 상태: "입는 중" / "입기" / "🍚 500으로 해금" / "R$ 99 — 곧 열려요"(비활성)). 카드를 누르면 왼쪽 큰 미리보기(`ViewportFrame` + `SushiBody.build`, 천천히 회전)와 말풍선 대사 한 줄.
     - 코인이 모자라면 해금 버튼에 "🍚 n개 더 필요해요". 결과는 버튼 아래 짧은 글씨.
     - 휴대폰 compact에서 카드 2열, 미리보기는 위쪽.
  6. **탈락 대사** (`EliminationCutsceneLogic.SKIN_LINES`): `Skins.luau`의 `speech`에서 만든다(계란초밥 대사는 지금 것 유지).
  7. **로벅스 자리**: `Skins` 항목에 `robux`·`productId`가 있지만 이 스펙의 버튼은 비활성. m4-14가 켠다.
- 제외:
  - 로벅스 결제(m4-14), 시즌 한정 스킨, 탈락·우승 연출 팩, VIP 패스, 스타터 번들(M5)
  - 다른 사람 스킨 구경하기(탈의실은 내 것만)
  - 용 롤 꼬리 애니메이션(M5)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/skins.spec.luau`, `tests/shop-logic.spec.luau`)
- [ ] AC1: 카탈로그에 위 16종이 있고 id가 겹치지 않으며 등급·로벅스·코인 가격이 표와 같다. 레어 이상은 `coins = nil`.
- [ ] AC2: 16종 모두 `SushiBody.layout(id)`가 `Body`를 갖고, 외곽 상자가 계란초밥 외곽의 ±15% 안이며, 효과가 1개 이하다. 모르는 id는 계란초밥.
- [ ] AC3: `ShopLogic.canBuyWithCoins`: 일반·미보유·코인 500 → ok, 코인 499 → "부족(1)", 보유 중 → "이미 있음", 레어 → "코인으로 못 삼". `canEquip`: 보유 → ok, 미보유 → 거절, 모르는 id → 거절.
- [ ] AC4: 각 스킨 `speech`가 1~2줄이고 `linesFor(id, variant)`에 그 줄이 들어간다.
- [ ] AC5: 검증 명령 5개 통과.

### Studio 확인
- [ ] AC6: 로비에서 "🍣 스킨"을 누르면 16종이 나오고 카드를 누르면 3D 미리보기가 돈다. 휴대폰 에뮬레이터에서도 잘리지 않는다.
- [ ] AC7: 코인이 500 이상일 때(콘솔로 코인을 넣어 시험) "연어"를 해금하면 코인이 500 줄고 바로 연어초밥이 된다. 나갔다 들어와도(저장 켬) 연어를 입고 있다.
- [ ] AC8: 연어를 입고 한 판: 매치 캐릭터·탈락 연출 인형·우승 연출·로비 단상이 모두 연어이고, 탈락 말풍선에 연어 대사가 나올 수 있다.
- [ ] AC9: 라운드 중 장착을 바꾸려 하면 거절 문구가 나오고, 관전·대기석에서는 바뀐다.
- [ ] AC10: 2명: 내 스킨이 다른 사람 화면에도 같은 모습이다. 스킨을 바꿔도 키·이름표 높이·꼬치 맞는 높이가 같다.
- [ ] AC11: 로벅스 버튼은 비활성 "곧 열려요"이고 눌러도 아무 일 없다.

## 공용 파일 변경
- `shared/Remotes.luau`: RemoteFunction `EquipSkin`, `BuyWithCoins`
- `shared/Config.luau`: `Config.Shop = { RequestCooldown = 0.3 }` (가격은 `Skins.luau`에)
- `shared/Types.luau`: 필요하면 `SkinTier`
- `init.server.luau`·`init.client.luau`: `ShopService`, `ShopController` 등록

## 사용자 작업
- 스킨 모양 확인(AC6 스크린샷) — 바꾸고 싶은 색·토핑을 알려 주면 `SushiBody` 레이아웃만 고침.
- (선택) 더 정교한 스킨은 메시로 M5에.

## 결정 기록
- 2026-10-08 · M4 스킨 범위 · GDD 9.2의 시즌 한정 제외 16종 전부를 코드 레이아웃(토핑만 다름)으로. 가격 GDD 그대로. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 코인 해금 = 일반 등급만(GDD 9.4) · planner
- 2026-10-08 · 라운드 중 장착 변경 금지, 관전·대기석·로비는 허용 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 효과는 스킨당 1개(불꽃·반짝이) · 모바일 성능 · planner
- 2026-10-08 · BuyWithCoins도 라운드·연출 중이면 거절 (해금하면 바로 입혀야 해서, 장착과 같은 문구) · 스펙에 없던 경우, 기본값으로 진행 · developer
- 2026-10-08 · "🍣 스킨" 버튼은 매치 중에도 관전·대기석(통과 후·라운드 결과 사이)에서는 보임, 시작 카운트다운·소개·달리는 중·우승 연출에서는 숨김 (범위 5 "매치 중 숨김"과 AC9 "관전·대기석에서는 바뀐다"를 함께 만족) · developer
- 2026-10-08 · 불꽃 효과는 Fire 오브젝트(최소 크기 2) 대신 작은 ParticleEmitter (스펙 범위 2 "ParticleEmitter, 한 개") · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 2026-10-08 · developer · 구현 완료 → in-qa
**바뀐 파일**
- 새 파일: `src/shared/Skins.luau`(카탈로그 16종·등급 정보·`validate`·`forProduct`), `src/shared/ShopLogic.luau`(장착·코인 해금·지급·카드 상태 판단), `src/server/ShopService.luau`(리모트 2개, 잠금 판단, `grantSkin`), `src/client/ui/ShopController.luau`, `src/client/ui/ShopScreen.luau`, `tests/skins.spec.luau`, `tests/shop-logic.spec.luau`
- `src/shared/SushiBody.luau`: 스킨 15종 레이아웃(계란초밥과 같은 Body·눈·입·발 + 토핑), `PartSpec`에 선택 필드 `shape`·`rotation`(도)·`effect`·`effectColor`, `bounds`가 회전 반영, `hasLayout`, `effectCount`, `setEffectsEnabled`. 계란초밥 레이아웃은 그대로.
- `src/server/AppearanceService.luau`: `setResolver`(appearanceId가 nil이면 ShopService가 고른 장착 스킨), `refresh(player)`. 외형을 입히는 곳은 여전히 `applyAppearance` 하나.
- `src/server/MatchService.luau`: 매치 시작·라운드마다·우승 판정 직전에 생존자 스킨을 `ctx.appearances`에 기억 → 우승자가 쇼케이스 전에 나가도 단상 인형이 입던 스킨 (m4-06 QA L2의 외형 부분).
- `src/shared/EliminationCutsceneLogic.luau`: `SKIN_LINES`를 `Skins.speech`에서 만듦 (계란초밥 대사 그대로).
- `src/client/fx/EliminationCutsceneController.luau`: 진짜 캐릭터를 숨길 때 스킨 효과(불꽃·반짝이)도 끔.
- 공용: `Remotes.luau`(RemoteFunction `EquipSkin`, `BuyWithCoins` → 리모트 19개), `Config.luau`(`Config.Shop.RequestCooldown = 0.3`), `init.server.luau`(ShopService), `init.client.luau`(ShopController). `Types.luau`·`default.project.json` 변경 없음 (`Skins.Tier` 타입은 Skins에).
- `tests/m4-foundation.spec.luau`: 리모트 개수 17 → 19.

**서버 검증 (ShopService)**: 인자 타입(문자열), 카탈로그, 보유, 가격(일반만 코인), 코인, 요청 간격 0.3초(두 리모트 공용), 잠금 = `RoundService.placedRoomOf`(소개 포함 이번 라운드 레이서) 또는 탈락 연출(3초)·우승(VictoryDuration + 1초). 코인 해금은 `DataService.update` 한 번 안에서 `ShopLogic.buyWithCoins`(재판단 → 차감 + 보유 + 장착), 저장 가능하면 바로 `saveNow`. `canPersist = false`는 Studio면 허용, 실제 서버면 "저장이 안 되는 상태예요".

**Studio 확인 방법**
1. AC6: Play → 왼쪽 위(코인 배지 아래) "🍣 스킨" → 16종 카드(등급 색 테두리), 탭 전환, 카드를 누르면 왼쪽 미리보기가 돌고 말풍선 대사. Device 에뮬레이터(휴대폰 가로)에서 카드 2열·미리보기 위쪽, 잘리지 않는지.
2. AC7: 서버 Command Bar에서 코인 넣기 — `local D=require(game.ServerScriptService.Server.DataService) for _,p in game.Players:GetPlayers() do D.update(p,function(x) x.coins+=600 end) end` → "연어" 카드 → "🍚 500으로 해금" → 코인 100, 바로 연어초밥. 저장 확인은 `Config.DEBUG.persistDataInStudio = true`(API 접근 허용) 후 나갔다 들어오기.
3. AC8: 연어를 입고 `forceMapPlan`으로 한 판 → 매치 캐릭터·탈락 인형·우승 인형·로비 단상이 연어, 탈락 말풍선에 "연어는 언제나 옳아!" 등이 나올 수 있음.
4. AC9: 라운드 중 거절은 클라이언트 Command Bar로 — `game.ReplicatedStorage.Remotes.EquipSkin:InvokeServer("tamago")` → `false 매치가 끝나면 바꿀 수 있어요`. 달리는 동안 버튼은 숨겨지고, 탈락해 관전 중이거나 통과해 대기석에 있을 때 버튼이 다시 보이고 장착이 바뀜.
5. AC10: Clients and Servers 2명 → 서로 스킨이 같은 모습, 스킨을 바꿔도 이름표 높이·키가 같음 (Body가 같아서).
6. AC11: 레어 이상 카드의 버튼 "R$ 99 — 곧 열려요"가 회색이고 눌러도 아무 일 없음.

**남은 이슈**
- 단상 이름표의 칭호·승수는 우승자가 쇼케이스 전에 나가면 여전히 없음 (L2의 나머지, 프로필이 내려가서). 외형만 해결.
- 우승 연출 인형(클라이언트)은 우승자가 연출 시작 전에 나가면 기본 계란초밥 (Victory 방송에 외형을 싣지 않음).
- 스킨 모양은 코드 회색 박스 수준. 사용자 스크린샷을 보고 색·토핑만 `SushiBody` 레이아웃에서 고치면 됨.
