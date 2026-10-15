# CLAUDE.md — Sushi Survival Race

로블록스 라운드제 서바이벌 레이스 게임. 플레이어는 초밥이 되어 젓가락을 피해 달리고, 3~4라운드 뒤 1명만 우승한다.

- **기획서(단일 진실 공급원): `docs/GDD.md`** — 작업 전에 관련 섹션을 먼저 읽는다. 기획과 다르게 구현해야 하면 사용자에게 먼저 묻는다.
- 사용자와는 **한국어**로 대화한다. 코드 식별자·커밋 메시지는 영어.

## 현재 상태
- 기획서 **v0.7**(무료 뽑기·고등어 전설·맵 3차 배치·맵 길이·버튼 위치 편집, 2026-10-14). M0~M4 개발 완료. 마일스톤별 내역·알려진 한계는 **`docs/CHANGELOG.md`**, 진행 상황은 `grep -H "^status:" docs/specs/*.md`.
- **M5 (운영 업데이트) 진행 중**
  - `done`: m5-01 결승 연장전, m5-02 관리자 스킨 미리보기, m5-03 기반(프로필 v2·시즌·상품·코드 틀), m5-04~06 새 맵 3개, m5-07 시즌 이벤트, m5-08 특별 상품·VIP, m5-09 연출 팩, m5-10 코드 보상, m5-11 관리자 명령, m5-13~19 맵 확장 6개, m5-20 기존 맵 장식 다듬기, m5-21 스킨 기반 v2, m5-22 스킨 10종, m5-24 맵 12개 아트 패스 v2, m5-25 캐릭터 퀄리티(새 기준 몸·얼굴·움직임), m5-28·m5-29 콘셉트 몸 스킨 8종(+ m5-27 견본 연어), m5-30 콘셉트 토핑 퀄리티(상한 70), m5-31 우승자 뽑기권(🎫, 프로필 v3), m5-32 고등어 초밥 [신선](전설·팔딱), **m5-33~39 맵 3차 배치 6개**(기반 + 새 맵, 풀 21개), **m5-40 맵 길이**(Race 6개 코스 연장, Survival 75초 + 60초 서든데스), m5-41 터치 버튼 위치·크기 편집.
  - `done`(추가): m5-23 맵 비주얼 키트·미리보기 렌더러(재QA 통과, 2026-10-15 — 예산이 거의 찬 맵: 튀김 냄비 장식 1495·회전 벨트 1492·등불 다리 조명 24/24).
  - `ready`(기획만): m5-26 현지화(작업 브랜치 `m5-26-i18n-p2` 등 main 미병합 — 병합 때 새 맵 6개 `name|rule` 수집 필요), m5-12 콘솔 UI.
- **사용자 차례**: Studio 확인(`docs/DEV-SETUP.md` 3-7~3-13), Future 조명·R15 고정 확인, 기본값 결정, 소리 고르기, Race 완주·한 판 시간 실측(m5-40 AC9·AC12), 코드 목록, 퍼블리시·Match 플레이스·상품 만들기(고등어 R$ 199 포함), 비공개 테스트. 전체는 **[`docs/USER-TODO.md`](docs/USER-TODO.md)**(결정은 그 파일 "답변 기록").
- **다음 단계**: m5-26 현지화 병합 → m5-12 콘솔 UI. 그사이 m5-23 재QA, 사용자 Studio 확인·플레이테스트 결과 반영(planner가 스펙·GDD, developer가 Config·코드) → 비공개 테스트 → 공개.
- 들어간 것: 방 시스템, 한 판 흐름, 관전, 계란초밥 캐릭터(새 기준 몸·작은 움직임), 탈락·우승·소개 연출, 다이브·잡기, 소리(대부분 무음 — 사용자가 id를 고름), 회전초밥집 로비·우승자 단상, DataStore 저장(세션 잠금, 프로필 v3), 밥알 코인·승수·칭호, 휴대폰 UI(터치 버튼 위치 편집), 서버 이동 감시, 로비/매치 플레이스 분리, 스킨 41종·탈의실, 🎫 우승자 뽑기(무료), 로벅스 결제, 결승 연장전, 맵 21개(기존 12개 아트 패스 v2, Race 45~55초 길이), 맵별 조명(Future), 시즌 이벤트·이벤트 재화, 🎁 특별 상품·VIP 패스, 연출 팩 2종, 🎟 코드 보상, 관리자 "🛠" 패널(미리보기·명령).
- 검토 대기 제안서는 `docs/proposals/`(사용자 승인 전, GDD 미반영). 참고 자료 `docs/REFERENCE-*.md` — 맵 아트는 **`docs/REFERENCE-map-art-direction.md`(필수)**, 그 밖에 map-production·m5-maps·party-royale·roblox-monetization·final-overtime·console-ui·emotes.

## 맵 풀 (21개, 전부 랜덤 판 풀)
| 종류 | id |
|---|---|
| Race (8) | `rotating-belt` 회전 벨트 · `soy-swamp` 간장 늪 & 와사비 산 · `ramen-rapids` 라멘 국물 급류 · `dessert-fridge` 디저트 냉장고 · `bouncy-castle-maze` 방방 미로 · `lantern-bridge` 등불 다리 건너기 · `dish-sink` 깨끗하게! 설거지통 · `space-conveyor` 우주 회전초밥 |
| Survival (7) | `hot-plate` 뜨거운 철판 · `chef-board` 셰프의 도마 · `tempura-pot` 튀김 냄비 탈출 · `giant-jenga` 와르르 나무 블록 · `cat-cafe-shelves` 고양이 카페 캣타워 · `rice-cooker` 초대형 밥솥 · `fish-market` 수산시장 |
| Final (6) | `skewer-showdown` 회전 꼬치 쇼다운 · `ikura-bombs` 연어알 폭탄 접시 · `tug-of-war-platform` 줄다리기 발판 · `claw-machine-prize` 인형뽑기 기계 속 · `tea-garden` 찻잎 정원 · `onsen-claw` 온천탕 인형뽑기 |

- 시간 제한(m5-40): Race 90초·Final 90초(+연장전)는 `Config.TimeLimit` 그대로. **Survival 7개는 맵 모듈의 `timeLimit = 75`**(보통 `Logic.TIME_LIMIT`, 수산시장은 숫자 그대로. 기존 5개는 `Logic.SUDDEN_DEATH_AT = 60`부터 서든데스, 새 2개는 자기 일정) — `Config.TimeLimit.Survival` 60은 바꾸지 않았고 지금 그 값을 쓰는 Survival 맵은 없다. 새 Survival 맵도 `timeLimit`을 직접 둔다. Race는 빠른 사람 45~55초 목표(코스 약 240~470 studs, 맵별 `Logic.estimateClearTime`).

## 스킨 · 상점 규칙
- 스킨은 **겉모습만** 바꾼다. 크기·히트박스·속도는 모두 같다(히트박스·발바닥 `SushiBody.GROUND_OFFSET` 하나). 능력치 판매 없음. 초밥이 아닌 음식·캐릭터도 세계관에 맞으면 된다(v0.6).
- **유료 뽑기 없음, 무료 뽑기만**(GDD v0.7 9.1·9.6, m5-31): 🎫 우승자 뽑기권은 **우승(`Won`)으로만** 얻고(1장, 상한 99) Robux·코인·이벤트 재화·코드·특별 상품·VIP로 **팔거나 주지 않는다**. 뽑기 자체를 돈·재화로 할 수 없고, 확률을 올리는 상품·보장권·천장도 없다. 꽝 없음 — 등급 확률 전설 1 / 영웅 5 / 희귀 15 / 고급 30 / 일반 49%(`Config.Draw.GradeWeights`, 등급 안에서 균등), 이미 가진 스킨이면 등급별 🍚 20/40/80/150/300. 확률은 뽑기 화면에 공개(화면 = 서버 `DrawLogic.grades`, 빈 등급은 나머지에 비율대로). 판단은 순수 `DrawLogic`, 지급은 `ShopService`의 `DrawTicket`이 `DataService.update` 한 번(`saveNow` 안 함 — 무료 보상).
- **등급별 한도**(m5-21, `SushiBody.EFFECT_BUDGET`·`BOUNDS_TOLERANCE`, `Skins.validate`가 서버 시작 때 검사): 효과 일반·레어 1개 / 에픽·전설 2개(종류 Fire·Sparkles·Smoke·Glow), 외곽 상자 일반·레어 ±15% / 에픽·전설 ±25%. 몸 파츠 모양에 Wedge 허용. 일반 스킨은 기준 몸(`SushiBody.BASE_NAMES` 22개, m5-25)을 그대로 쓰고 파츠 ≤ `SushiBody.PART_BUDGET`(40).
- **콘셉트 몸 예외**(`Skin.conceptBody`, `Skins.CONCEPT_BODY_IDS` = `SushiBody.CONCEPT_BODY` 10종): 넓은 밥 + 작은 눈·팔·다리 몸(`SushiConceptSample`, 표정 6종 Default·Happy·Flustered·Hurt·Angry·Sad). 파츠 상한 **70**(m5-30), **`fresh-mackerel`만 80**·외곽은 concept-salmon 기준 ±25%·이름표 높이 **4.8**(`SushiBody.nameTagHeight(id)`, 나머지 3.6 — Body `NameTagHeight` 속성은 클라이언트 이름표 위치에만 쓰고 권한 판단에 안 씀). 스킨 id 분기 없이 이 표로만 다르게 한다.
- **특 스킨**(뽑기 전용 9종 `concept-*`, 이름 "○○ (특)"): `drawGrade`가 있고 다른 얻는 길(robux·coins·tokens·season·vipOnly·productId)이 없다(`Skins.isDrawOnly`), 내부 `tier = "Basic"`, **무료 아님**(`Skins.isFree`는 계란초밥만). 뽑기 풀 = `drawGrade`가 있는 스킨(`Skins.DRAW_IDS` 10). **고등어 초밥 [신선](`fresh-mackerel`)**은 유일한 "`drawGrade` + `robux`" 스킨 — 전설 R$ 199 판매와 뽑기 전설이 같이 있고 보통 판매 규칙(`Skins.TIER_ROBUX`)을 따른다. 뽑기 등급(일반·고급·희귀·영웅·전설)은 상점 등급과 다른 말이다.
- 캐릭터 외형은 **`AppearanceService.applyAppearance` 한 곳**에서만 입힌다. `Attributes.AppearanceId`를 쓰는 곳도 여기뿐. 인형(탈락·우승 연출·단상·탈의실·뽑기 화면)은 `SushiBody.build`로 따로 만든다. 캐릭터 움직임(숨쉬기·깜빡임·걸음·고등어 팔딱 `CharacterAnimLogic.fishPose`)은 클라이언트 로컬(`CharacterFxController`, 인형은 `DollAnimator`)이고 판정과 무관.
- 카탈로그 `shared/Skins.luau` **41종**: 기본 1(계란초밥) + 판매 26(일반 8·레어 7·에픽 5·전설 6 — 고등어 포함) + 시즌 4(`season`, 기간에만 — 호박 초밥·산타 새우 R$ 99, 유령 계란초밥·트리 마키 이벤트 재화 80) + VIP 전용 1(`vip-gold-tamago`, `vipOnly`) + 특 9(뽑기 전용). **가격 A안**: 로벅스 29/59/99/199, 코인 일반 300 / 레어 900, 에픽·전설은 로벅스만. 코인을 로벅스로 파는 상품은 만들지 않는다.
- **Studio 전부 입기**(`Config.DEBUG.unlockAllSkinsInStudio`, 커밋 값 `true`): Studio에서 보유와 상관없이 모든 스킨을 입을 수 있다. `ownedSkins`에는 아무것도 넣지 않고 뽑기·구매 판단은 저장된 보유만 본다. 실서버에서는 무시, `persistDataInStudio = true`면 꺼짐(경고 한 줄).
- 로벅스 결제는 `RobuxShopService`의 `ProcessReceipt` **하나**(특별 상품도 `OfferService`가 `setOfferPort`로 "무엇을 주는지"만 등록). 프로필 `saveNow` 성공 → 구매 기록(`Purchases_v1`, 키 PurchaseId) 성공일 때만 `PurchaseGranted`. 판단은 순수 `ReceiptLogic`·`OfferLogic`. 상품 id는 사용자가 만든 뒤 `Skins.luau`·`Offers.luau`에.
- **특별 상품**(m5-08, `shared/Offers.luau`): 스타터 팩·에픽/전설 세트·연출 2종(개발자 상품), VIP 패스(게임 패스). **VIP 영구 스킨은 `UserOwnsGamePassAsync`가 true일 때만** 지급(구매 이벤트만 믿지 않음). VIP 혜택은 겉모습뿐(👑·[VIP]·금박 스킨, 코인 배수 없음). `Attributes.Vip`·`EliminationFx`·`VictoryFx`는 서버만 달고 권한 판단에 쓰지 않는다.
- 이벤트 재화(🍬/⭐)는 `Shared.Seasons` 기간에만 서버가 지급·차감(`BuyWithTokens`). "지금 시각"은 서버 `Seasons.now` — `DEBUG.eventNow`는 Studio에서만.
- 달리는 중(소개 포함)·탈락 연출·우승 연출 중에는 장착·해금·연출 장착·뽑기를 거절한다(`ShopService.isLocked`). 터치 버튼 위치 편집(m5-41)도 레이서로 배치된 동안은 클라이언트가 막는다.
- Studio 가짜 결제(`fakeRobuxInStudio`)·가짜 VIP(`fakeVipInStudio`)는 `persistDataInStudio`와 같이 켜면 꺼진다(운영 저장소에 가짜 기록 금지).

## 코드 보상 규칙 (m5-10)
- **진짜 코드는 커밋하지 않는다**(저장소 공개). 서버 전용 로더 `src/server/CodeConfig.luau`(커밋)가 로컬 `src/server/CodeList.luau`(`.gitignore`, 형식은 `CodeList.example.luau`)를 읽는다. 없으면 빈 목록 + 경고. 문서·테스트의 예시 코드(`SUSHI2026`, `SPOOKYSUSHI`, `EXAMPLE2026` 등)는 실제 코드로 쓰지 않는다.
- 판단은 순수 `CodeLogic`, 지급은 `CodeService`가 `DataService.update` 한 번. 남용 방지: 요청 간격 2초, 10분 안 실패 8번이면 잠금(`Config.Codes`).

## 관리자 (테스트 도구) 규칙 (m5-02, m5-11)
- 관리자 판단은 **서버만**, 접속할 때 `AdminLogic.isAdmin`으로 한 번 계산해 `AdminService`의 표(`admins[UserId]`)에 두고 리모트마다 다시 본다. 입력은 `player.UserId`, `RunService:IsStudio()`, `game.CreatorType/CreatorId`, 서버 전용 `src/server/AdminConfig.luau`뿐. 이름·클라이언트 속성으로는 판단하지 않는다. 규칙: Studio + `StudioAllAdmins`면 누구나, 실서버는 `LiveEnabled`이고 `UserId > 0`이고 (`UserIds` 목록 또는 `IncludeOwner` + 개인 계정 소유자). 지금 목록 `{ 11402290839 }`.
- **비밀번호·PIN·키 입력 방식은 금지**(계정 탈취 위험, Roblox 커뮤니티 기준 위반). 관리자 목록은 `Shared.Config`에 두지 않는다. `Attributes.IsAdmin`은 패널을 만들지 말지만 정하고 권한이 아니다.
- 미리보기(스킨·연출)는 **경제에 기록하지 않는다**: `ShopService`의 메모리 슬롯(`setPreview`/`getPreview`)과 Player 속성만. 외형 순서는 `AdminLogic.pickAppearance`(미리보기 > 장착 > 계란초밥). 서버 간 유지는 MemoryStore `AdminPreview_v1`(키 `u_<UserId>`, 1시간). `AdminService` 소스에는 `DataService`·`ShopLogic`·`ReceiptLogic`·`PurchaseLog`·`RewardService`가 없어야 한다(테스트가 고정) — 경제를 건드리는 명령은 `AdminCommands`(첫 명령 때 lazy require).
- **명령 등급**(`AdminLogic.commandTier`/`canRun`): `Info`(`info`, `fx` 미리보기) = 실서버에서도 됨 / `Test`(`start`, `plan`) = Studio만 / `StudioOnly`(`coins`, `tokens`, `tickets`, `resetprofile`) = Studio만이고 **`persistDataInStudio = true`면 거절**("저장을 켠 Studio에서는 쓸 수 없어요"). 실서버에서 Test·StudioOnly를 켜는 설정은 없다(사용자 결정). 명령은 부른 사람 본인에게만. 로그 `[Admin] 이름(UserId) <명령> <값> -> ok|<이유>`.

## 역할 분담 (에이전트 협업)
기획 `planner` · 개발 `developer` · QA `qa` · 문서화 `docs-writer` 서브에이전트가 `.claude/agents/`에 있다.
작업은 **스펙 파일(`docs/specs/`) → 구현 → QA 리포트(`docs/qa/`) → 문서 반영** 순서로 파일을 통해 넘긴다.
흐름, 상태값, 파일 소유권, 실행 방법은 **`docs/WORKFLOW.md`**를 따른다. 역할별 작업 기록은 `docs/<역할>/`.
- **세션이 끝날 수 있으니 커밋할 때마다 자기 브랜치를 push하고 인계 메모를 남긴다.** 로컬 세션이 끝나면 클라우드 세션(`claude --cloud`)이 이어받는다 — `docs/WORKFLOW.md` "클라우드 세션으로 인계".

## 확정된 기획 요약 (자세한 건 GDD)
- **방 시스템**: 방장이 최대 인원(4/8/12/16/24), 공개/비공개(4자리 코드)를 설정. 최소 4명이면 방장이 시작, 정원이 차면 자동 시작.
- **라운드 수**: 시작 인원 4~8명 → 3라운드, 9~24명 → 4라운드. 한 판 4~5분.
- **통과 인원**: `clamp(round(시작 × 비율), 2, 시작 - 1)`. 비율 3라운드 [0.60, 0.50, 결승], 4라운드 [0.65, 0.55, 0.50, 결승]. 결승 전 남은 인원 ≤ 2면 바로 결승. 코드(`Rules.qualifyCount`)는 "시작"을 **그 라운드를 시작할 때 살아 있는 인원**으로 계산한다.
- **맵**: 라운드마다 맵이 바뀐다. 첫 라운드는 항상 Race, 마지막은 항상 Final, 한 판에 같은 맵 중복 없음, 4라운드면 Survival 최소 1번.
- **결승**: 생존형. 1명이 남는 순간 우승, 같은 순간 다 떨어지면 더 높이 버틴 사람(리셋·퇴장이 섞이면 그쪽이 더 나쁜 등수). **연장전**(결승 = 마지막 라운드에서만): 90초에 맵의 `overtime` 훅 → `Config.Final.CollapseDuration`(20초) 안에 설 곳이 모두 사라짐 → 늦게 떨어진 사람 우승. 안전 상한 150초(+`HardCapMargin` 40)에 가장 높이 있는 1명 우승. **Survival** 시간 종료(75초)면 버틴 사람 전원 통과. Race 통과자는 대기석(로비 스폰)으로.
- **결승 진출 2명 보장**: 결승 전 라운드에서 낙하로 살아남을 사람이 2명 아래가 되면 더 멀리/높이 간 사람부터 구제. 리셋·퇴장은 구제 없음. 혼자 남으면 바로 부전승. 우승자는 항상 `Won`을 받은 사람이다.
- **보상**: 라운드 통과 +10, 결승 출발 +30, 우승 +100 + 🎫 뽑기권 1장(`Config.Draw`), 하루 첫 판 +50(UTC). 이벤트 기간에는 재화도(`Config.Events.Tokens`). 칭호 1승 "탈출 초밥", 10승 "전설의 참치", 100승 "바다의 왕".
- **판정은 전부 서버**(결승선, 탈락, 순위, 코인, 구매, 코드, 이동 감시). 클라이언트는 입력·UI·연출만(얼음 관성 이동처럼 판정 없는 이동 보정 포함).

## 기술 스택과 구조
- Roblox Studio + **Rojo**, 언어 **Luau** (`src/`는 전부 `--!strict`, 타입 검사는 luau-lsp 새 검사기). 조명은 **Future**(`default.project.json` Lighting, Studio에서 한 번 확인 — USER-TODO B1-1).
- 맵 판정은 **코드로 생성한 지오메트리**, 아트도 코드 장식(`MapKit`) + 선택적인 사용자 Studio 장식(`assets/map-art/<id>.rbxm`).
- **플레이스**: `PlaceService.role()` = `"Single"`(Studio 또는 `Config.Places` 비어 있음) / `"Lobby"` / `"Match"`. 한 플레이스 모드에서는 방마다 아레나를 좌표를 띄워 따로 생성(`Config.Arena`: 높이 300, 슬롯 간격 2000). 분리 모드는 MemoryStore 매니페스트(키 PrivateServerId)를 믿는다.

```
default.project.json     # Rojo 트리, Lighting(Future), Baseplate·LobbySpawn, ServerStorage.MapArt ← assets/map-art
rokit.toml               # rojo 7.7.1, stylua 2.5.2, selene 0.32.0, lune 0.10.5, luau-lsp 1.70.1
types/                   # luau-lsp Roblox 정의(커밋), README.md
assets/map-art/          # 사용자 Studio 장식 <맵 id>.rbxm (장식 전용)
tools/                   # render-map.luau(맵, m5-23) · render-character.luau(캐릭터, m5-25 — --sample·--pose·sheet-compare)
                         # + render/(Shims, Scene, Raster, Materials, Png, Sheet, LayoutCheck)
src/
  server/            -> ServerScriptService.Server
    init.server.luau     # 모든 서비스 init() 다음 start()
    DataService          # 프로필 DataStore(PlayerData_v1), 세션 잠금, update/saveNow/onLoaded/setViewExtra, SaveSettings(칸별 간격)
    PlaceService  PlaceBackend  RoomDirectory  RoomService(forceStart)  MatchService(setNextPlan)  MatchEvents
    RoundService         # prepareRound → run/cancel. 맵 Model에 Arena 태그, 결승 연장전 루프
    EliminationService  CharacterUtil  AppearanceService  GrabService  MovementGuardService
    LobbyService         # 로비 건물·조명·단상·시즌 장식 (Match 역할이면 안 지음)
    RewardService        # 코인·승수·칭호·이벤트 재화 (MatchEvents 구독)
    ShopService          # EquipSkin, BuyWithCoins, BuyWithTokens, DrawTicket(🎫 뽑기, m5-31), 장착 resolver, 미리보기 슬롯, isLocked, Studio 전부 입기
    RobuxShopService  PurchaseLog          # ProcessReceipt(유일), 구매 기록 Purchases_v1
    OfferService         # RequestOfferPurchase, EquipFx, VIP 확인 (m5-08)
    CodeService  CodeConfig  CodeList.example   # RedeemCode, 코드 로더 (CodeList.luau는 .gitignore)
    AdminConfig  AdminService  AdminCommands    # 관리자 목록(서버 전용)·판단 표·리모트, 명령 실행
  client/            -> StarterPlayerScripts.Client
    init.client.luau  CameraDirector  ProfileStore  PriceCache(지역 가격 캐시)  Sfx
    ui/                  # Lobby*, Room*, Hud*, Spectate*, Coin*, Shop*(탈의실·이벤트·🎫 특 탭), DrawScreen(🎫 뽑기 화면, m5-31),
                         # Offer*(🎁 상점), Code*(🎟 코드), Admin*(🛠 미리보기·명령 탭), ChatTagController([VIP]), UiScaleController,
                         # SettingsButton(⚙ 메뉴)·TouchLayoutEditor(버튼 위치 편집, m5-41)
    fx/                  # CharacterFxController(캐릭터 움직임·이름표), FishRig·DollAnimator(고등어 관절·인형 움직임, m5-32),
                         # EliminationCutscene*, Intro*, VictoryCutscene*, CutsceneProps, VictoryProps,
                         # LobbyFxController, MapLightingController(맵별 조명), MapDecorFxController(장식 움직임)
    input/               # Dive*, Grab*, IceController(얼음 관성, m5-06), TouchLayoutController(점프·다이브·잡기 배치, m5-41)
  shared/            -> ReplicatedStorage.Shared
    Config  Remotes(RemoteFunction 16 + RemoteEvent 11 = 27)  Types  Attributes   # 공용 파일
    Rules  RoundLogic  RoomLogic  SpectateLogic  Cleanup  CameraPriority
    SushiBody  SushiConceptSample(콘셉트 몸)  ConceptMackerel  SushiPose  PartMath  CharacterAnimLogic   # 캐릭터 몸·움직임
    Skins  ShopLogic  DrawLogic  DrawScreenLayout  ReceiptLogic  Seasons  Offers  OfferLogic  FxCatalog  CodeLogic  AdminLogic
    ProfileSchema(v3)  ProfileLogic  RewardLogic  PlaceRole  PlacePayload  RoomDirectoryLogic  MoveExempt  MovementGuardLogic
    LobbyLayout  UiLayout  TouchLayoutLogic  IntroLayout  EliminationCutsceneLogic  IntroCameraLogic  VictoryCutsceneLogic
    DiveLogic  GrabLogic  GrabInputLogic  IceLogic  SfxCues  SfxLibrary
    maps/
      init.luau  MapTypes.luau                     # 맵 풀(ALL), 공통 인터페이스 + validate
      MapKit  MapKitLogic  MapKitShapes  MapFxPresets  MapDecorAnimLogic  MapDecorTags  MapLighting  MapLightingLogic  MapSfx  MapSfxLogic
      <Map>.luau (+ <Map>Layout / <Map>Logic / <Map>Art)   # 맵 21개 (위 표). 판정 상수는 Layout, 순수 계산은 Logic, 장식은 Art
tests/               # 순수 로직·가짜 Roblox 테스트 (156개 파일 2282개, 2026-10-15 main 8750ee6). init.luau 실행기, lib/, fixtures/
docs/
  GDD.md  WORKFLOW.md  CHANGELOG.md  DEV-SETUP.md  USER-TODO.md  REFERENCE-*.md
  specs/  qa/  proposals/  renders/<mapId>/·renders/characters/(커밋한 before/after PNG)
  planner/  developer/  docs-writer/  playtest/
```

### 맵 모듈 공통 인터페이스 (`shared/maps/MapTypes.luau`)
```lua
export type MapModule = {
  id: string, kind: "Race" | "Survival" | "Final", displayName: string,
  rule: string,                              -- 라운드 소개 한 줄 규칙
  timeLimit: number?,                        -- 없으면 Config.TimeLimit[kind]
  build: (origin: CFrame) -> Model,          -- 판정 지오메트리 + 장식 (Spawns 폴더 필수)
  start: (ctx: RoundContext) -> (),          -- 장애물 가동, 판정 → ctx.pass / ctx.eliminate
  cleanup: ((ctx: RoundContext) -> ())?,     -- ctx.cleanup에 안 넣은 것만
  overtime: ((ctx: RoundContext, info: OvertimeInfo) -> ())?,  -- 결승 연장전. kind == "Final"이면 필수
  inPool: boolean?,                          -- false면 랜덤 판에서 빠짐(강제 플랜·Maps.get만). 지금 21개 모두 풀
  lighting: MapLighting.MapLighting?,        -- 맵 조명 분위기 (m5-23). 보통 Art.LIGHTING
}
export type OvertimeInfo = { collapseDuration: number }
export type RoundContext = {
  model: Model, origin: CFrame, rng: Random, targetCount: number,
  cleanup: Cleanup.Cleanup, isActive: () -> boolean,
  getRacers: () -> { Player },               -- 스폰에 배치된, 아직 통과/탈락하지 않은 플레이어
  pass: (player: Player) -> (), eliminate: (player: Player) -> (),
}
```
- `Spawns` 폴더에 24개 BasePart, **24개 모두 판정 바닥 위**(테스트로 확인). 코스는 `origin`의 앞쪽(로컬 -Z)으로 — 시간 종료 때 Race 순위 축.
- 라운드 종료 판정은 `RoundLogic`(순수). 맵은 `ctx.pass`/`ctx.eliminate`만 부르고, 한 판정 틱의 탈락은 한 묶음. 결승 여부는 "마지막 라운드인가"로 정한다. 점수: Race 진행도(로컬 -Z), Survival·Final 높이.
- 맵 상태는 모듈이 아니라 `ctx`/`start` 지역 변수(또는 `ctx` 키 표)에 둔다 — 한 서버에서 여러 방이 같은 맵을 동시에 돌린다. 장애물은 `CollectionService` 태그로, `start`에서 **`ctx.model` 하위의 태그 파츠만** 동작시킨다. 태그 이름은 각 맵 모듈 상단(예: `Conveyor`, `HotTile`, `IkuraTile`, `Ice`·`Jelly`·`ColdFan`, `BounceFloor`, `TugOfWarPlatform` …).
- **이동 감시 면제**: 서버가 캐릭터를 순간적으로 튕기거나 옮기면(넉백, 와사비·젤리·방방 바닥 튕김, 폭탄·기름·고양이·수세미·운석·밥솥 끓어오름·증기·얼음 블록·생선·찻잔·충격파 넉백, 젓가락 집기·놓기) `MoveExempt.mark(character, seconds?)`. 벨트·급류·기울기·바람(송풍구)·접시 회전·우주 레일 같은 **연속 밀기에는 달지 않는다**.
- **연장전 훅**: 결승에서 시간 제한이 되면 `RoundService`가 별도 스레드로 **한 번** 부른다. 맵은 `collapseDuration`초 안에 **어떤 레이서도 안전하게 설 수 없게**(바닥 제거·충돌 끄기 — 매달리기·턱·높은 곳 버티기 자리도 없게, m5-18 B1 교훈) 만든다. 훅 안에서 `task.wait` 금지, 일정은 `task.delay`/`task.spawn`을 `ctx.cleanup`에. 훅이 실패해도 안전 상한이 마무리한다.
- GDD 11절의 인터페이스 표기는 개요이고, 실제 계약은 `MapTypes.luau`다.

### 맵 장식 · 아트 규칙 (m4-01, m5-23)
- 아트 작업 전 **`docs/REFERENCE-map-art-direction.md`**(세계 컨셉 "작은 초밥, 거대한 주방", 색·재질·조명·밀도·가독성, 11절 체크리스트 18개)를 읽는다. **렌더 → 글로 비평 → 고침 → 다시 렌더를 최소 3회**(12절), 첫/마지막 렌더는 `docs/renders/<mapId>/before-*.png`·`after-*.png`로 커밋.
- 장식은 `<Map>Art.luau`의 `DecorSpec` 목록(순수 데이터) → `MapKit.buildDecor`(Anchored, 충돌·쿼리·터치 없음). 판정 파츠의 크기·위치·CanCollide는 아트 때문에 바꾸지 않는다. 목록에 하나라도 틀린 항목이 있으면 **그 맵 장식 전체를 건너뛴다**.
- 조명·파티클·움직임은 **선언형**: `light = { kind = "Point"|"Spot"|"Surface", … }`, `particle = "<MapFxPresets 이름>"`(+`particleRate`), `anim = { kind = "Spin"|"Bob"|"Sway"|"Pulse", period, amount?, axis? }`(클라이언트 로컬 — 판정 파츠·판정 파츠와 같이 움직이는 장식에는 금지). 모양은 `MapKitShapes`(roundedBox·bevelBox·rimDisc·ring·capsule·lipTrim·scatter·transform), 색은 `MapKitLogic.PALETTE`·`shades`.
- **SurfaceLight range ≤ 16**(Roblox가 자름, Point·Spot ≤ 60). 그림자 조명은 좁은 SpotLight에만. 빛은 보이는 원인 파츠(등·램프)에 붙인다.
- **예산** `MapKitLogic.BUDGETS`: Standard 파츠 600·파티클 8·조명 12·그림자 조명 1·움직임 40(기본), **Extended 1500·16·24·2·80**(아트 패스 맵이 `Art.BUDGET = "Extended"`로 고르고 맵 테스트가 `checkBudget(Art.decor(), "Extended")`). 런타임 경고는 Extended 기준.
- **맵별 조명**: 맵 모듈의 `lighting`(보통 `Art.LIGHTING`, 기존 맵은 `MapLighting.PRESETS[id]`) → 클라이언트 `MapLightingController`가 카메라가 있는 아레나(판정 파츠 상자 + 40, `IntroCamera` 점 포함) 조명으로 1.2초 섞어 바꾸고, 나오면 로비 조명. 서버 `Lighting`은 로비 값만. **소개 카메라 점은 아레나 상자 + 40 안**에 두고 지오메트리를 뚫지 않게.
- 새 맵은 안개 패널(큰 반투명 판)을 쓰지 않는다 — Atmosphere는 `lighting`으로. `build` 끝에서 `MapKit.introCamera`와 `MapKit.attachStudioArt(model, id, origin)`.

## 규칙
- **공용 파일**(`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/Attributes.luau`, `shared/maps/init.luau`, `shared/maps/MapTypes.luau`, `default.project.json`, `src/server/init.server.luau`, `src/client/init.client.luau`, `rokit.toml`)은 **병렬 작업 중에는 스펙에 지정된 한 에이전트만 수정**한다.
- 순수 로직은 Roblox API에 의존하지 않게 분리하고 `tests/`에 테스트를 둔다.
- 클라이언트에서 온 리모트 인자는 서버에서 항상 검증한다 (타입, 범위, 길이, 방 소속, 방장 여부, 요청 간격). 서버 → 클라이언트 이벤트는 서버가 `OnServerEvent`를 듣지 않는다.
- 데이터 변경은 `DataService.update`(동기) 안에서만. 결제처럼 "저장된 뒤에만" 끝나야 하는 일은 `saveNow`의 결과를 본다. Studio는 기본으로 메모리 저장이다.
- **디버그 설정** (`Config.DEBUG`, 서버는 `RunService:IsStudio()`일 때만 적용). **커밋할 때는 아래 기본값** — 테스트가 커밋 값을 고정한다. 사용법은 `docs/DEV-SETUP.md` 3-9·3-10.
  - `minPlayersToStart = 1`, `forceMapPlan = nil`, `forceMapPlans = nil`, `persistDataInStudio = false`, `simulateMatchServer = false`, `logArenaStats = false`, `fakeRobuxInStudio = false`, `overtimeAt = nil`, `eventNow = nil`(UTC 초, 시즌 확인), `fakeVipInStudio = false`, **`unlockAllSkinsInStudio = true`**(Studio 전부 입기 — 구매·뽑기 흐름을 볼 때만 false).
  - 관리자 설정 `src/server/AdminConfig.luau`: 커밋 값 `StudioAllAdmins = true`(비관리자 화면 확인 때만 false), `LiveEnabled = true`(사용자 확정, 공개 출시 전 재확인).

## 검증 (작업 끝내기 전에 반드시, 5단계)
도구는 `rokit.toml`에 버전이 고정돼 있다. 처음 한 번(그리고 도구가 추가되면) `rokit install` (Windows: `~/.rokit/bin`이 PATH에 있어야 함).
```bash
rojo build -o build.rbxl       # 1. 프로젝트 구조 확인 (build.rbxl은 커밋하지 않음)
stylua --check src tests tools # 2. 포맷/문법 (고칠 때는 stylua src tests tools)
selene src                     # 3. 린트
lune run tests                 # 4. 테스트 — 마지막 줄 "N passed, 0 failed"를 읽는다 (실패가 있으면 끝 코드 1)
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src   # 5. 타입 검사 (끝 코드 0)
```
- `lune run tests`는 실패가 하나라도 있으면(또는 spec 파일이 없으면) 끝 코드 1이다(`tests/init.luau`). 끝 코드만 믿지 말고 마지막 요약 줄의 `0 failed`도 확인한다(예전 문서의 "실패가 있어도 끝 코드 0"은 틀린 설명이었음).
- 캐릭터 모습 확인(Studio 없이): `lune run tools/render-character <skinId|all> [--view …] [--light studio|lobby|both]` → `build/renders/characters/`(DEV-SETUP 2-2).
- 맵 모습 확인(Studio 없이): `lune run tools/render-map <mapId|all> [--view intro|overview|eye|top|mobile|all] [--quality fast|high]` → `build/renders/<mapId>/*.png` + `stats.txt`(예산·`void%`). 근사 렌더러라 최종 판단은 Studio. 사용법·한계는 `docs/DEV-SETUP.md` 2-1.
- **도구를 받을 수 없는 환경(클라우드 세션 등)에서는 돌리지 못한 단계를 "타입 검사 못 함"처럼 보고에 분명히 적는다.** 돌려 보지 않은 것을 통과로 적지 않는다.
- 스튜디오에서 직접 확인이 필요한 부분은 **사용자에게 무엇을 어떻게 테스트하면 되는지** 구체적으로 알려준다. 마일스톤별 확인 목록은 `docs/DEV-SETUP.md`, 사용자가 손으로 할 일은 `docs/USER-TODO.md`.

## 병렬 개발
서로 다른 파일을 건드리는 스펙은 worktree를 나눠 동시에 개발한다 (`claude --worktree <이름>`, Rojo 포트는 worktree마다 34872, 34873, ...). 자세한 건 `docs/WORKFLOW.md`.
공용 파일을 바꾸는 기반 스펙(m4-01, m5-03, m5-13 등)은 `main`에서 먼저 하고, 맵·기능 스펙은 worktree로 나눈다. 따로 QA를 통과한 브랜치가 병합에서 처음 만나 깨질 수 있으니(m4-09 B1, m5-08 병합 뒤 m5-03-qa) 병합 뒤에도 검증을 다시 돌린다.
