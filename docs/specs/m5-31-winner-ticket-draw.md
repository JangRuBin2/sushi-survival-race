status: in-dev
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-31 — 우승자 뽑기 티켓 (🎫 무료 등급별 뽑기 · 특 스킨 9종 · Studio 전부 입기)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1 (원칙 — v0.7 "무료 뽑기" 규칙), §9.2 (특 스킨 9종·뽑기 등급), §9.4 (중복 코인), §9.6 (우승자 뽑기 티켓), §10 (탈의실·뽑기 화면), §11.5 (프로필 v3), §11.7 (관리자 `tickets`, Studio 전부 입기)
- 조사: [`docs/REFERENCE-winner-ticket-draw.md`](../REFERENCE-winner-ticket-draw.md) (§1 정책, §4 등급별 확률 개정), [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) §5
- **화면 샘플(사용자, 2026-10-14)**: `docs/귀여운 초밥 스킨 뽑기 UI.png` — 뽑기 화면은 이 그림을 직접 열어 보고 그 구성을 따른다(아래 "UI").
- 담당 개발 worktree: 브랜치 `m5-31-winner-ticket-draw` — m5-29·m5-30이 main에 병합된 뒤 그 main에서 시작(`Skins.luau`·`SushiBody.luau`·`tests/m5-27~29-*.spec.luau`를 같이 건드림).
- 공용 파일 수정 담당: **이 스펙의 developer 한 명** (`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`). 이 작업 중에는 다른 에이전트가 이 세 파일을 고치지 않는다. `Attributes`·`maps/*`·`default.project.json`·init 스크립트·`rokit.toml`은 안 건드린다(새 서비스 없이 `ShopService` 안에 둔다 — 아래 "구조").
- 개정: 2026-10-14 2차(사용자 결정 — 샘플 화면, **꽝 없는 등급별 확률**, 뽑기 등급, 고등어 전설). 1차의 "스킨 10% / 꽝 90%(🍚 +20)", "9종 다 가지면 🍚 +100", "가진 스킨은 후보에서 뺌"은 **폐기**(결정 기록).

## 목표
결승에서 1등(`Won`)을 하면 🎫 뽑기권 1장을 받고, 뽑기 화면에서 뽑기권으로 뽑는다. **꽝은 없다** — 매번 등급(전설 1% / 영웅 5% / 희귀 15% / 고급 30% / 일반 49%)을 먼저 뽑고 그 등급의 스킨 중 하나가 나온다. 이미 가진 스킨이 나오면 등급별 🍚 코인으로 바뀐다. 특 스킨 9종은 **뽑기로만** 얻는 스킨이 되고, 영웅·전설은 "자랑할 만한" 스킨이 된다. 개발자는 Studio에서 저장 없이 모든 스킨을 입어 볼 수 있다.

## 범위
- 포함
  1. **특 스킨 9종으로 바꾸기**: 콘셉트 스킨 9종(`concept-salmon`·`tuna`·`shrimp`·`tamago`·`ikura`·`unagi`·`uni`·`tako`·`inari`)을 무료 실험 스킨에서 **뽑기 전용**으로. 이름 변경(아래 표), `Skins.isFree`는 계란초밥만 true, 저장 `ownedSkins`에 들어가는 진짜 보유. 모양·대사·order는 그대로.
  2. **뽑기 등급 `drawGrade`** (상점 `tier`와 별개, 아래 표). 뽑기 풀 = `drawGrade`가 있는 스킨.
  3. **티켓 지급**: `RewardService`가 `Won`(부전승 포함)에서 티켓 +1. 이벤트·VIP 배수 없음. 상한 99.
  4. **뽑기**: RemoteFunction `DrawTicket` 하나. 서버 RNG, 판단은 순수 `DrawLogic`, 지급은 `DataService.update` 한 번(티켓 −1 + 스킨 또는 중복 코인).
  5. **뽑기 화면 UI** (샘플 구성, 아래 "UI"): 간판·뽑기권 수·대표 스킨 단상·"뽑기 시작하기"·등급별 확률표·결과 "스킨 획득!"·보유 스킨 목록과 상세. 탈의실 "🎫 특" 탭, 미보유 특 스킨 카드 "🎫 뽑기로 얻기", 🍣 스킨 버튼 티켓 배지.
  6. **Studio 전부 입기**: `Config.DEBUG.unlockAllSkinsInStudio`(커밋 기본 `true`).
  7. **관리자 명령 `tickets <n>`** (StudioOnly 등급).
  8. 프로필 v3(`drawTickets`), 마이그레이션.
  9. 기존 m5-27/28/29/30 테스트 중 "무료·모두 보유·이름 (테스트)"를 고정한 기대값을 새 규칙에 맞게 바꾸기.
  10. m5-26 현지화가 main에 있으면 문자열 키(AC17).
- 제외
  - 티켓을 Robux·코인·이벤트 재화·코드·특별 상품·VIP로 주거나 파는 것 (**금지**, GDD 9.1). **뽑기 자체는 어떤 돈·재화로도 할 수 없다** — 뽑기권은 우승으로만.
  - 확률을 올려 주는 아이템·상품, 등급 보장권 (만들지 않음)
  - 천장(몇 번 뽑으면 보장) — 열린 질문 1
  - 한 번에 여러 장 뽑기(10연차) — 한 번에 1장만
  - 스킨 교환·거래, 특 스킨 판매
  - 전설 스킨 — m5-31에는 없다. 고등어 초밥 [신선](`fresh-mackerel`, `drawGrade = "Legendary"`)은 **m5-32**가 넣는다. m5-31은 "빈 등급" 처리만 한다.
  - 특 스킨 모양 변경(m5-30 몫), 새 특 스킨 추가
  - 뽑기 소리 id(사용자가 고름 — `SfxCues`에 이름만, 무음)
  - 이미지 에셋(Decal·ImageLabel 이미지 업로드) — 샘플은 Roblox 기본 UI 요소로 흉내 낸다(아래 "UI")

## 정한 값 (`Config.Draw`)
| 키 | 값 | 뜻 | 근거 |
|---|---|---|---|
| `TicketsPerWin` | 1 | 우승 1번에 뽑기권 | 사용자 결정 1 |
| `MaxTickets` | 99 | 최대 장수. 가득이면 우승해도 안 늘어남(토스트로 알림) | 기본값, REFERENCE §3 |
| `GradeWeights` | `{ Legendary = 0.01, Epic = 0.05, Rare = 0.15, Uncommon = 0.30, Common = 0.49 }` | 등급 기본 확률(합 1) | 사용자 결정 2(샘플, 일반 48 → 49는 메인 세션) |
| `DuplicateCoins` | `{ Common = 20, Uncommon = 40, Rare = 80, Epic = 150, Legendary = 300 }` | 이미 가진 스킨이 나왔을 때 대신 주는 🍚 | 사용자 결정 2 |
| `RequestCooldown` | 1 | `DrawTicket` 요청 간격(초) | 결과 연출(약 1.5초)보다 짧게, 연타 방지 |

- 1차의 `SkinChance`·`ConsolationCoins`·단일 `DuplicateCoins`(100)는 **없앤다**.

### 뽑기 등급 (`drawGrade`, 사용자 결정 3 — 상점 `tier`와 별개)
| 등급 키 | 화면 이름 | 기본 확률 | 중복 🍚 | 스킨 (m5-31) | 색 (예시 — 샘플 기준, developer가 정함) |
|---|---|---|---|---|---|
| `Legendary` | 전설 (Legendary) | 1% | 300 | **없음** — m5-32에서 `fresh-mackerel` | 금색·노랑 (예 255, 196, 50) |
| `Epic` | 영웅 (Epic) | 5% | 150 | `concept-salmon` 연어초밥 (특) | 보라 (예 155, 90, 230) |
| `Rare` | 희귀 (Rare) | 15% | 80 | `concept-uni` 성게 군함 (특), `concept-tako` 문어초밥 (특), `concept-ikura` 연어알 군함 (특) | 파랑 (예 60, 130, 235) |
| `Uncommon` | 고급 (Uncommon) | 30% | 40 | `concept-inari` 유부초밥 (특), `concept-unagi` 장어초밥 (특), `concept-tuna` 참치초밥 (특) | 초록 (예 55, 170, 85) |
| `Common` | 일반 (Common) | 49% | 20 | `concept-shrimp` 새우초밥 (특), `concept-tamago` 계란초밥 (특) | 회색 (예 140, 145, 155) |

- 배정: 샘플에 있는 것(연어 영웅, 우니·문어 희귀, 유부·장어 고급, 새우·계란 일반) + 샘플에 없는 참치(고급)·연어알(희귀)은 메인 세션이 정함.
- 뽑기 등급 이름(일반·고급·희귀·영웅·전설)은 상점 등급(일반·레어·에픽·전설)과 다른 말이다(샘플 그대로). 뽑기 화면과 특 스킨 카드는 **뽑기 등급**을, 상점 탭은 상점 등급을 쓴다.

### 실제 확률 — 빈 등급 나누기 (사용자 결정 5)
- 스킨이 하나도 없는 등급은 확률 0이 되고, 그 몫을 **남은 등급에 기본 확률 비율대로** 나눈다: `실제 = 기본 / (스킨이 있는 등급들의 기본 합)`.
- m5-31(전설 없음): 영웅 5/99 = **5.0505%**, 희귀 15/99 = **15.1515%**, 고급 30/99 = **30.3030%**, 일반 49/99 = **49.4949%**.
  - 스킨 하나당: 연어(특) 5.05%, 희귀 3종 각 5.05%, 고급 3종 각 10.10%, 일반 2종 각 24.75%.
- m5-32 병합 뒤(전설 1종): 전설 1% · 영웅 5% · 희귀 15% · 고급 30% · 일반 49% 그대로 — **코드 수정 없이** 카탈로그만으로 바뀐다.
- 확률은 **보유와 무관**하다(가진 스킨도 후보에 남고, 나오면 중복 코인). 그래서 사람마다 확률표가 같다.

### 특 스킨 이름 (사용자 결정 1차 3 — "콘셉트"·"(테스트)" 빼고 "(특)")
| id | 지금 이름 | 새 이름 | en (AC17) | 뽑기 등급 |
|---|---|---|---|---|
| `concept-salmon` | 콘셉트 연어초밥 (테스트) | **연어초밥 (특)** | Salmon Sushi (Special) | 영웅 |
| `concept-tuna` | 콘셉트 참치초밥 (테스트) | **참치초밥 (특)** | Tuna Sushi (Special) | 고급 |
| `concept-shrimp` | 콘셉트 새우초밥 (테스트) | **새우초밥 (특)** | Shrimp Sushi (Special) | 일반 |
| `concept-tamago` | 콘셉트 계란초밥 (테스트) | **계란초밥 (특)** | Tamago Sushi (Special) | 일반 |
| `concept-ikura` | 콘셉트 연어알 군함 (테스트) | **연어알 군함 (특)** | Salmon Roe Gunkan (Special) | 희귀 |
| `concept-unagi` | 콘셉트 장어초밥 (테스트) | **장어초밥 (특)** | Eel Sushi (Special) | 고급 |
| `concept-uni` | 콘셉트 성게 군함 (테스트) | **성게 군함 (특)** | Sea Urchin Gunkan (Special) | 희귀 |
| `concept-tako` | 콘셉트 문어초밥 (테스트) | **문어초밥 (특)** | Octopus Sushi (Special) | 희귀 |
| `concept-inari` | 콘셉트 유부초밥 (테스트) | **유부초밥 (특)** | Inari Sushi (Special) | 고급 |

- id는 바꾸지 않는다(저장·렌더 도구·테스트가 id를 씀). 판매 스킨과는 "(특)"과 뽑기 등급 배지로 구분.

## 구조 (개발 안내 — 바꿔도 되지만 결정 기록에 남긴다)
- **카탈로그** `shared/Skins.luau`
  - `Skin.drawGrade: DrawGrade?` (`"Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"`). **`drawGrade`가 있으면 뽑기 풀**에 들어간다. 9종에 위 표대로.
  - `Skins.DRAW_IDS`(명시 목록) = `drawGrade`가 있는 id 전부. m5-31에서는 9종 = `Skins.EXPERIMENTAL_IDS`(테스트로 고정). m5-32가 `fresh-mackerel`을 더하면 10.
  - `Skins.DRAW_GRADES`: 등급 순서(Legendary → Common)와 화면 이름(ko/en)·색. `Skins.isDraw(id)` = `drawGrade` 있음, `Skins.isDrawOnly(id)` = `drawGrade`가 있고 다른 얻는 길(robux·coins·tokens·season·vipOnly)이 없음 — 특 9종.
  - `experimental = true`는 **몸 모양 예외 표시로 남긴다**(m5-32가 `conceptBody`로 이름을 바꿈). 주석의 "무료 테스트" 설명은 "뽑기 전용 특 스킨"으로.
  - 내부 `tier`는 특 9종 `"Basic"` 그대로(등급별 효과·외곽 표를 안 건드림). 화면 배지는 뽑기 등급.
  - `Skins.isFree(id)` = 계란초밥만 true.
  - validate:
    - `drawGrade` 값은 5개 중 하나, `drawGrade`가 있는 id = `DRAW_IDS`.
    - 뽑기 전용(robux 없음) 스킨: `coins`·`tokens`·`season`·`vipOnly`·`productId` 모두 nil, tier `Basic` 허용("기본 스킨이 아닌 Basic은 뽑기 전용만" — 1차의 experimental 예외를 여기로 옮김).
    - `drawGrade` + `robux`가 같이 있는 스킨(m5-32 고등어)은 **보통 판매 규칙**(tier별 가격표, 에픽·전설 coins 금지)을 그대로 따르고 `tokens`·`season`·`vipOnly`는 금지. m5-31에는 이런 스킨이 없지만 validate는 지금부터 받아 준다(가짜 카탈로그 테스트).
    - "얻는 길 정확히 하나" 규칙: 뽑기 전용은 뽑기를 길 하나로 센다. 뽑기 + 로벅스는 이 규칙의 **유일한 예외**(뽑기는 무료 획득이라 "돈으로 고르는 길"과 "운으로 얻는 무료 길"이 같이 있어도 됨).
- **순수 로직** `shared/DrawLogic.luau` (Roblox API 없음, 테스트용으로 카탈로그 목록을 인자로 받을 수 있게 — 기본은 `Skins.LIST`)
  - `DrawLogic.grades(list?) -> { { grade, skinIds: {string}, chance: number, duplicateCoins: number } }`: Legendary → Common 순 5줄. `skinIds`는 그 등급 스킨 order 순. 빈 등급은 chance 0, 나머지는 위 "빈 등급 나누기". chance 합 = 1(±1e-9). **보유를 받지 않는다**.
  - `DrawLogic.roll(ownedSkins, rng, list?) -> DrawOutcome`: `rng:NextNumber()` 한 번 → Legendary → Epic → Rare → Uncommon → Common 순 **누적 구간**(`r < 누적`이면 그 등급, chance 0인 등급은 건너뜀) → `rng:NextInteger(1, n)`로 그 등급 `skinIds`에서 하나. 안 가졌으면 kind `"Skin"`, 가졌으면 kind `"Duplicate"`(coins = `DuplicateCoins[grade]`). rng는 `NextNumber`·`NextInteger`가 있는 표(테스트는 가짜 rng·고정 시드). 풀이 아예 비면(스킨 0) 오류 대신 `nil`(서버는 `NoPool`로 거절 — 실제로는 validate가 막음).
  - `DrawLogic.canDraw(wallet, locked, canSave) -> (ok, reason?)`: 이유 `NoTickets` / `Locked` / `CannotSave`.
  - `DrawLogic.apply(wallet, outcome) -> DrawResult`: 티켓 −1, Skin이면 `ownedSkins[id] = true`(장착은 안 바꿈), Duplicate면 `coins += n`. `DataService.update` 안에서 부른다.
  - `DrawLogic.addTickets(current, n) -> (newValue, added)`: 0 ~ MaxTickets로 자름(우승 지급·관리자 명령이 같이 씀).
  - `DrawLogic.displayPercents(grades) -> { [grade]: string }`: 화면 등급별 퍼센트. **소수 1자리, 최대 나머지 방식으로 표시값 합이 정확히 100.0%**(m5-31: 영웅 5.0 / 희귀 15.2 / 고급 30.3 / 일반 49.5, 전설 줄은 "준비 중"). m5-32 뒤: 1.0 / 5.0 / 15.0 / 30.0 / 49.0.
  - `DrawLogic.perSkinPercent(grades) -> { [skinId]: string }`: ⓘ 상세용, 소수 2자리(각 5.05% 등). 반올림 안내 문구를 같이 보여 준다.
  - `DrawLogic.featured(ownedSkins, list?) -> skinId`: 단상 대표 스킨 = 아직 없는 스킨 중 **가장 높은 등급**(같은 등급이면 order 앞), 다 가졌으면 가장 높은 등급의 첫 스킨. m5-31 새 프로필 → `concept-salmon`.
  - 클라이언트 화면도 같은 `DrawLogic`(shared)로 확률을 그린다 — **화면 값 = 서버 판정 값**(테스트로 고정).
- **서버** `ShopService`에 `DrawTicket` 핸들러(새 서비스 파일 없음). 순서: 요청 간격(`Config.Draw.RequestCooldown`, `Config.Shop.RequestCooldown`과 **따로**) → 프로필 로드됨 → `ShopService.isLocked` → `canPersist`(실서버 임시 프로필이면 `CannotSave`, Studio 메모리 모드는 허용) → `DataService.update` 한 번 안에서 다시 `canDraw` + `roll`(서비스가 서버 `Random.new()` 하나를 들고 있음) + `apply` → `ProfileUpdated`. 반환 `(true, nil, DrawResult)` / `(false, reason)`. 서버 Output 로그 한 줄: `[Draw] 이름(UserId) -> skin concept-uni Rare (tickets 3)` / `-> duplicate concept-tamago Common +20 (tickets 2)` / `-> rejected NoTickets`.
  - 클라이언트 인자는 받지 않는다(있어도 무시). 확률·결과는 서버만 정한다.
  - `saveNow`는 부르지 않는다(무료 보상 — 평소 자동 저장·나갈 때 저장). 개발 메모에 이유.
- **지급** `RewardService`/`RewardLogic`: `onResult`의 `Won` 묶음에 `tickets = Config.Draw.TicketsPerWin`, 기존 코인 지급과 **같은 `DataService.update`** 안에서 `DrawLogic.addTickets`. 가득이면 `RewardGrant.tickets = 0`, `ticketsFull = true`. 이벤트 기간·VIP여도 1장.
- **Studio 전부 입기**: `unlockAll = RunService:IsStudio() and Config.DEBUG.unlockAllSkinsInStudio and not Config.DEBUG.persistDataInStudio` (순수 `ShopLogic.unlockAllActive(isStudio, flag, persist)`). 켜져 있으면 `EquipSkin`이 카탈로그의 모든 스킨(시즌·VIP·특 포함)을 보유 확인 없이 받고 resolver(`equippedOf`)도 보유를 안 본다. **`ownedSkins`에는 아무것도 넣지 않는다.** 뽑기(중복 판정·대표 스킨·보유 목록 n/총수)와 구매 판단은 저장된 `ownedSkins`만 본다. 클라이언트에는 `ProfileView.studioUnlockAll`. 실서버에서는 플래그와 상관없이 꺼짐. `persistDataInStudio = true`면 꺼지고 서버 시작 때 경고 한 줄.

## UI — 뽑기 화면 (샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png` 구성)
**이미지 에셋을 올리지 않고** Roblox 기본 UI 요소(Frame·TextLabel·TextButton·`UICorner`·`UIStroke`·`UIGradient`·`UIListLayout`/`UIGridLayout`·`UIScale`·`ViewportFrame`, 이모지)로 샘플의 느낌을 흉내 낸다. 3D 스킨은 모두 `SushiBody.build`로 만든 인형을 `ViewportFrame`에 넣는다. 열기: 탈의실 위쪽 **"🎫 뽑기"** 버튼(티켓 수 배지). 탈의실이 숨는 때(카운트다운·소개·달리는 중·연출 중)에는 뽑기 화면도 숨는다.

1. **배경**: 화면 전체에 반투명 어두운 막(게임이 비쳐 보임). 샘플의 시장 배경 그림은 쓰지 않는다.
2. **왼쪽 위 — 나무 간판**: 갈색 `UIGradient` + 진한 갈색 `UIStroke` + `UICorner`, 살짝 기울임(Rotation 약 −3°). 큰 글씨 "스킨 **뽑기**"(흰 글씨 + 두꺼운 테두리, "뽑기"는 노랑), 위에 "👑". 아래 작은 글씨 "지금, 특별한 스킨을 획득할 수 있는 기회!".
3. **왼쪽 — 뽑기권 상자**: 어두운 반투명 둥근 상자 "보유 중인 뽑기권" + 큰 "🎫 ×N". 그 아래 안내 상자 "1등만 뽑기권을 획득할 수 있어요! (확률에 따라 스킨이 지급됩니다.)".
4. **가운데 — 단상 위 대표 스킨**: `ViewportFrame` 안에 나무색 원기둥 단상 + 대표 스킨 인형(`DrawLogic.featured`), 천천히 돈다. 위쪽에 기울인 손글씨 느낌 말풍선 "**○○ 스킨 획득 가능!**"(○○ = 대표 스킨 이름, 예 m5-31 새 프로필 "연어초밥 (특)").
5. **가운데 아래 — "🎫 뽑기 시작하기 ›" 버튼**: 노랑→주황 `UIGradient`, 알약 모양, 진한 테두리. 뽑기권 0장이면 회색으로 꺼지고 아래에 "우승하면 🎫 뽑기권을 받아요". 누르는 동안·연출 중에는 다시 눌리지 않는다.
6. **오른쪽 — "스킨 등급별 확률 ⓘ" 표**: 흰 둥근 판. 등급 5줄(전설 → 일반), 줄마다 **등급색 왕관**(등급색 둥근 배지 안 "👑" 또는 색을 입힐 수 있는 글자 — developer가 렌더를 보고 정함) + "전설 (Legendary)" + 오른쪽 퍼센트(`DrawLogic.displayPercents`). 줄 배경은 등급색을 옅게(전설 줄이 가장 진하게 강조). **빈 등급 줄(m5-31의 전설)은 회색으로 "준비 중"**, 퍼센트 대신. 표 아래 안내 "뽑기권은 1등에게만 지급되며, 등급별 확률에 따라 스킨이 획득됩니다. 이미 가진 스킨이 나오면 🍚 코인으로 바뀌어요." ⓘ를 누르면 상세: 등급마다 스킨 이름 + "각 x.xx%" + "중복이면 🍚 +N", 맨 아래 "확률은 반올림한 값이라 합이 100%와 조금 다를 수 있어요."
7. **오른쪽 위 — 닫기 X**: 어두운 둥근 네모 버튼.
8. **결과 "스킨 획득!" 화면** (뽑기 응답 뒤, 약 1.5초 연출 → 결과): 연출 = 가운데 뚜껑 덮인 접시(돔)가 들썩이다가 **등급색 빛**이 새어 나오고 열린다(등급을 먼저 색으로 알려 줌). 결과 = 위 "👑 스킨 획득!" 제목, 등급색 빛줄기(돌아가는 얇은 Frame 여러 개 + 빛나는 `UIGradient`) 뒤로 새 스킨 인형(`ViewportFrame`), 이름판 "연어초밥 (특)" + 등급 배지, 노란 "확인" 버튼 + 작은 "· 확인 버튼을 눌러 주세요 ·". 새 스킨이면 "입기" 버튼도(누르면 바로 입힘, 자동 장착은 안 함). **중복**이면 같은 화면에 "이미 가진 스킨이에요 → 🍚 +N"(코인 배지가 N 늘어남), "입기" 없음. 전설·영웅은 빛을 더 크게(전설이 가장 화려).
9. **보유 스킨 목록** (뽑기 화면 안 "보유 스킨 목록 n/총수" 판 — 탭 또는 아래쪽 판, developer가 화면 크기로 정함): n = 가진 뽑기 스킨 수, 총수 = `#Skins.DRAW_IDS`(m5-31 9, m5-32 뒤 10). 격자 카드 = 인형 썸네일(`ViewportFrame`) + 이름 + 등급 배지, 등급 높은 순 → order 순. 안 가진 카드는 어둡게 + 🔒 "아직 없어요". 입는 중인 카드는 금색 테두리.
10. **스킨 상세** (카드를 누르면): 등급 배지, 이름, 설명 한 줄(그 스킨 대사 첫 줄), 큰 인형 미리보기, **표정 썸네일 4칸**(콘셉트 몸 표정 Default·Happy·Flustered·Hurt — 누르면 큰 미리보기 표정이 바뀜), 가진 스킨이면 "입기"/"입는 중", 안 가졌으면 "🎫 뽑기로 얻기"(m5-32 고등어는 "R$ 199로 사기"도 — m5-32 몫).
11. **휴대폰** (짧은 변 ≤ 500px): 왼쪽 열(간판·뽑기권)을 위쪽 한 줄로 접고("스킨 뽑기 · 🎫 ×N"), 가운데 단상 + 버튼, 오른쪽 확률표는 영어 괄호를 빼고 줄 높이를 줄인다. 안내 문구는 ⓘ 안으로. 결과 화면은 전체 화면. 보유 목록은 3열 격자, 상세는 겹치는 창. 모든 버튼 44px 이상, 글씨 잘림 없음.
- 탈의실 쪽: "🎫 특" 탭(전체 다음)에 특 9종, 카드 배지 = 뽑기 등급, 안 가진 카드 "🎫 뽑기로 얻기"(누르면 뽑기 화면). 🍣 스킨 버튼에 티켓 수 빨간 배지. 우승 토스트 "+1 🎫 우승 뽑기권".

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1 (카탈로그): 9종 이름이 위 표 "새 이름"과 같고 "(테스트)"·"콘셉트"가 없다. 9종의 `drawGrade`가 위 표와 같다(연어 Epic, 성게·문어·연어알 Rare, 유부·장어·참치 Uncommon, 새우·계란 Common). 가격·다른 얻는 길 없음, id·order·대사·`experimental` 그대로. `Skins.DRAW_IDS`(9) = `Skins.EXPERIMENTAL_IDS` = `SushiBody.EXPERIMENTAL`의 id(정확한 목록 비교). `Skins.validate` 통과. 가짜 카탈로그로: `drawGrade`에 모르는 값, 목록 밖 id의 `drawGrade`, 뽑기 전용 스킨에 `coins`·`tokens`·`season`·`vipOnly`·`productId`, `drawGrade` + `robux`인데 tier 가격표와 다른 값이거나 `tokens`·`season`·`vipOnly`가 붙음 → validate가 잡는다. `drawGrade = "Legendary"` + tier Legendary + robux 199(가짜 고등어)는 통과.
- [ ] AC2 (무료 아님): `Skins.isFree`는 계란초밥만 true. 새 프로필(`ProfileSchema.new`)에서 특 스킨 `ShopLogic.canEquip` → `NotOwned`, 코인 해금·로벅스 지급 판단·`BuyWithTokens` 판단은 모두 거절(기존 "팔지 않음" 계열). `ownedSkins[id] = true`면 장착 가능.
- [ ] AC3 (마이그레이션 v3): `ProfileSchema.VERSION = 3`, 새 프로필 `drawTickets = 0`. v2 → 0으로 이전, 다른 값 손실 없음. `drawTickets`가 음수·소수·NaN·문자열이면 0(노트), 99 초과면 99. v2에서 `equippedSkin`이 특 스킨이고 `ownedSkins`에 없으면 `tamago`(노트), 있으면 유지. `toView`에 `drawTickets` 포함.
- [ ] AC4 (등급 확률): 실제 카탈로그 `DrawLogic.grades()` → 전설 chance 0·skinIds 빈 목록, 영웅 5/99, 희귀 15/99, 고급 30/99, 일반 49/99(각 ±1e-9), 합 1. 가짜 카탈로그(전설 1종 추가) → 0.01/0.05/0.15/0.30/0.49 그대로. 가짜 카탈로그(영웅·전설 비움) → 희귀 15/94, 고급 30/94, 일반 49/94. 계란초밥·판매 스킨(drawGrade 없음)은 어느 등급에도 없다. `grades`는 보유를 받지 않아 결과가 사람마다 같다.
- [ ] AC5 (표시 = 판정): `displayPercents`(실제 카탈로그) = 전설 "준비 중", 영웅 "5.0%", 희귀 "15.2%", 고급 "30.3%", 일반 "49.5%" — 숫자 합 정확히 100.0. 전설 1종 가짜 카탈로그 → "1.0%"·"5.0%"·"15.0%"·"30.0%"·"49.0%". `perSkinPercent` 실제 카탈로그 → 연어(특) "5.05%", 성게(특) "5.05%", 장어(특) "10.10%", 새우(특) "24.75%". 표시값은 `grades()`의 chance에서만 계산한다(별도 상수 없음 — 소스 검사 또는 같은 입력 비교).
- [ ] AC6 (뽑기 판정, 가짜 rng): 실제 카탈로그에서 `NextNumber` = 0.0505 → 영웅(연어), 0.0506 → 희귀, 0.2020 → 희귀, 0.2021 → 고급, 0.5050 → 고급, 0.5051 → 일반, 0.9999 → 일반(경계는 누적값 기준 `<`, 테스트는 정확한 누적값 ± 1e-6으로). 등급 안에서 `NextInteger(1, n)`의 값대로 skinIds의 그 스킨. 안 가진 스킨 → `Skin`, 가진 스킨 → `Duplicate` + 그 등급 코인(일반 20 / 고급 40 / 희귀 80 / 영웅 150, 가짜 전설 300). 꽝(`Consolation`) 결과는 없다.
- [ ] AC7 (분포, 고정 시드): 결정적 rng로 100,000번 `roll`(빈 보유) → 등급 비율이 AC4 실제 값 ± 0.005, 등급 안 스킨 비율이 1/n ± 0.01(그 등급 안에서). 보유 4종으로 다시 돌려도 등급 비율은 같고, 가진 스킨이 나온 횟수는 전부 `Duplicate`.
- [ ] AC8 (적용): `apply`는 티켓을 정확히 1 줄이고, Skin이면 `ownedSkins`에 넣고 `equippedSkin`·코인 그대로, Duplicate면 코인만 +N이고 `ownedSkins` 그대로. `canDraw`는 티켓 0 `NoTickets`, 잠금 `Locked`, 저장 불가 `CannotSave`이고 이때 `apply`는 불리지 않는다(지갑 변화 0).
- [ ] AC9 (대표 스킨): `featured(빈 보유)` = `concept-salmon`. 연어(특) 보유 → 희귀 중 order가 가장 앞인 것. 9종 모두 보유 → `concept-salmon`. 전설 1종 가짜 카탈로그 빈 보유 → 그 전설.
- [ ] AC10 (지급): `RewardLogic.onResult(…, "Won")` 묶음에 `tickets = 1`(이벤트 기간 `now`여도 1). `Passed`·`Eliminated`·결승 출발·하루 첫 판에는 티켓 없음. `addTickets(98, 1)` → 99, `addTickets(99, 1)` → 99와 added 0. 기존 시뮬레이션의 코인 결과 불변.
- [ ] AC11 (Studio 전부 입기): `ShopLogic.unlockAllActive(isStudio, flag, persist)`는 `(true, true, false)`만 true. 켜진 상태의 `canEquip`은 모르는 id만 거절(`UnknownSkin`)하고 잠금이면 여전히 `Locked`. 켜져 있어도 `DrawLogic.roll`의 중복 판정·`featured`·`canBuyWithCoins`는 저장된 `ownedSkins`로만. `Config.DEBUG.unlockAllSkinsInStudio` **커밋 값 `true`**(테스트로 고정).
- [ ] AC12 (관리자 명령): `AdminLogic.commandTier("tickets") = "StudioOnly"`. 인자 정수 −99 ~ 99(아니면 `BadArgs`), 결과 0 ~ 99로 자름. `persistDataInStudio = true`·실서버 거절. `AdminService` 소스에 `DrawLogic`·`DataService`가 없다.
- [ ] AC13 (리모트·타입·설정): `Remotes` RemoteFunction 16개(+`DrawTicket`), RemoteEvent 11개 — 개수 테스트 갱신. `Types.DrawGrade`, `Types.ProfileView`에 `drawTickets: number`·`studioUnlockAll: boolean`, `Types.RewardGrant`에 `tickets: number?`·`ticketsFull: boolean?`, `Types.DrawResult = { kind: "Skin" | "Duplicate", skinId: string, grade: DrawGrade, coins: number, ticketsLeft: number }`. `Config.Draw.GradeWeights` 합 = 1, `DuplicateCoins` 5등급 모두 양의 정수, `SkinChance`·`ConsolationCoins` 키 없음(테스트로 고정).
- [ ] AC14 (탈의실 로직): `ShopLogic.tabs`에 "🎫 특" 탭(전체 다음) = 뽑기 전용 스킨(`isDrawOnly`) order 순, 가진 것·안 가진 것 모두. 특 스킨은 "기본" 탭에서 빠지고(기본 = 계란초밥만) "전체"에는 있다. 안 가진 특 스킨 `cardState` = `"Draw"`, `cardButtonText` = "🎫 뽑기로 얻기", 로벅스·코인 버튼 없음. 카드 배지 텍스트는 뽑기 등급 이름. `studioUnlockAll = true` view에서는 "입기 (Studio)".
- [ ] AC15 (기존 테스트): m5-27·28·29·30 테스트에서 "무료·새 프로필에서 입기·`AlreadyOwned`·이름 '(테스트)'"를 고정한 기대값을 새 규칙으로 **바꾼다**. 모양·관절·파츠 상한·렌더 검사는 약화 없이 통과. 바꾼 테스트 목록을 개발 메모에.
- [ ] AC16: 검증 5단계 통과(rojo build, stylua, selene, `lune run tests` "N passed, 0 failed", luau-lsp 끝 코드 0). 돌리지 못한 단계는 보고에 그대로.

### Studio 확인
- [ ] AC17 (현지화 — 조건부): main에 m5-26(`src/shared/Localization/Strings.csv`)이 있으면 특 9종 이름 키(위 표 en), 등급 이름 5개, 뽑기 화면·토스트·거절 문구 키를 넣고 m5-26 테스트 통과. 없으면 "해당 없음"으로 개발 메모에, 문구는 코드 상수로.
- [ ] AC18 (티켓 받기): `minPlayersToStart = 1`로 혼자 한 판 끝까지 → 우승 토스트와 함께 "+1 🎫 우승 뽑기권", 순위표 "이번 판"에 🎫 +1, 🍣 스킨 버튼에 빨간 배지 "1". 관리자 `tickets 98` 뒤 우승 → 99, 한 번 더 → "🎫 뽑기권이 가득 찼어요 (99장)" 토스트, 99 그대로.
- [ ] AC19 (뽑기 화면 — 샘플과 나란히 봄): `unlockAllSkinsInStudio = false`로 바꾸고 `tickets 30` → 탈의실 "🎫 뽑기" → 샘플과 같은 구성: 왼쪽 위 나무 간판 "스킨 뽑기", "보유 중인 뽑기권 🎫 ×30" + "1등만…" 안내, 가운데 단상 위 연어초밥 (특) 인형이 돌고 "연어초밥 (특) 스킨 획득 가능!", 노란 "🎫 뽑기 시작하기 ›", 오른쪽 확률표 "전설 준비 중 / 영웅 5.0% / 희귀 15.2% / 고급 30.3% / 일반 49.5%"(등급색 왕관) + 안내 문구, 오른쪽 위 X. ⓘ를 누르면 스킨별 "각 x.xx%"와 중복 코인. 확률표 값이 서버 `DrawLogic.grades()`와 같다.
- [ ] AC20 (뽑기 결과): "뽑기 시작하기" → 약 1.5초 접시 연출(등급색 빛) → "스킨 획득!" 화면
  - 새 스킨: 인형 + 이름판 + 등급 배지 + "입기"·"확인". "입기"를 누르면 바로 입힘. 보유 목록 n/9가 하나 늘고 단상 대표 스킨이 바뀐다(가장 높은 등급 미보유).
  - 중복(관리자 `tickets`로 여러 번 뽑아 일반이 겹칠 때까지): "이미 가진 스킨이에요 → 🍚 +20"(일반), 코인 배지가 그만큼 늘고 "입기" 없음.
  - 연출 중 버튼이 눌리지 않고, 연타해도 티켓이 두 장 빠지지 않는다. 뽑기권 0장이면 버튼 꺼짐 + "우승하면 🎫 뽑기권을 받아요".
  - 꽝 결과는 한 번도 나오지 않는다. 서버 Output에 `[Draw]` 로그 한 줄씩.
- [ ] AC21 (보유 목록·상세): "보유 스킨 목록 n/9" — 가진 카드는 인형 썸네일·이름·등급 배지, 안 가진 카드는 어둡게 🔒. 카드를 누르면 상세(등급 배지·이름·설명·큰 미리보기·표정 썸네일 4칸 — 누르면 표정이 바뀜·"입기"/"입는 중"/"🎫 뽑기로 얻기").
- [ ] AC22 (잠금): 라운드 소개·달리는 중·탈락/우승 연출 중에는 뽑기 화면이 탈의실과 같이 숨고, 리모트를 직접 불러도 `Locked`(티켓 그대로).
- [ ] AC23 (Studio 전부 입기): 기본 커밋 값(`true`)으로 새 Studio 세션 → 탈의실 모든 카드가 "입기 (Studio)", 입으면 내 캐릭터가 바뀌고 다른 테스트 플레이어(Clients and Servers)에게도 보인다. `ownedSkins`가 늘지 않았다(뽑기 화면 보유 목록 0/9). `persistDataInStudio = true`면 꺼지고 서버 경고 한 줄.
- [ ] AC24 (휴대폰): Device 에뮬레이터(짧은 변 500px 이하)에서 뽑기 화면(간판 접힘·확률표 5줄·버튼)·결과 화면·보유 목록·상세가 잘리지 않고 버튼 44px 이상.

## 공용 파일 변경 (담당: 이 스펙 developer)
- `shared/Config.luau`: `Config.Draw = { TicketsPerWin = 1, MaxTickets = 99, GradeWeights = { Legendary = 0.01, Epic = 0.05, Rare = 0.15, Uncommon = 0.30, Common = 0.49 }, DuplicateCoins = { Common = 20, Uncommon = 40, Rare = 80, Epic = 150, Legendary = 300 }, RequestCooldown = 1 }`. `Config.DEBUG.unlockAllSkinsInStudio = true` (주석: Studio 전용, `persistDataInStudio`와 같이 켜면 꺼짐, 저장에 안 남음 — **커밋 값 true**).
- `shared/Remotes.luau`: RemoteFunction `DrawTicket()` → `(ok, err?, result: DrawResult?)`, 머리 주석 갱신. RemoteEvent 변화 없음.
- `shared/Types.luau`: `DrawGrade`, `DrawResult`, `ProfileView.drawTickets`·`studioUnlockAll`, `RewardGrant.tickets?`·`ticketsFull?` (AC13).
- 공용 아님(이 스펙이 고침): `Skins`, `ShopLogic`, `ProfileSchema`(VERSION 3, `drawTickets`, `ViewExtra.unlockAll`), `ProfileLogic`, `RewardLogic`, `RewardService`, `ShopService`, `DataService`(view extra), `AdminLogic`, `AdminCommands`, 새 `DrawLogic`, 클라이언트 `ShopController`·탈의실 UI·새 뽑기 화면(`ui/Draw*`)·`CoinController`(토스트), `SfxCues`(`DrawReveal`·`DrawWin`, 무음).
- 없음: `Attributes`, `maps/*`, `default.project.json`, init 스크립트, `rokit.toml`.

## 문서 반영 (docs-writer 몫, 이 스펙이 `qa-passed`된 뒤)
- `CLAUDE.md` "스킨 · 상점 규칙": "능력치 판매·뽑기 없음" → "**유료 뽑기 없음.** 무료 등급별 뽑기(🎫 우승자 뽑기권, m5-31)만 — 뽑기권은 우승으로만 얻고 Robux·코인·이벤트 재화·코드·상품으로 팔거나 주지 않는다(뽑기 자체를 돈으로 할 수 없음), 꽝 없음, 확률은 뽑기 화면에 공개, 스킨은 겉모습만". 카탈로그 "31종" + 특 9종(뽑기 전용, `drawGrade`) 줄. 판단 `DrawLogic`, 지급 `ShopService`의 `DrawTicket`이 `DataService.update` 한 번.
- `CLAUDE.md` 디버그 기본값에 `unlockAllSkinsInStudio = true`, 관리자 StudioOnly에 `tickets`, Remotes 개수(RemoteFunction 16 + RemoteEvent 11 = 27), 프로필 v3, 현재 상태(m5-31).
- `docs/DEV-SETUP.md`: 디버그 표에 `unlockAllSkinsInStudio`(구매·뽑기 흐름 확인 때만 false), 3-10에 뽑기 확인 절(AC17~AC24).
- `docs/CHANGELOG.md`: M5 m5-31 줄.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 우승 보상으로 뽑기를 넣을지 · **우승자 뽑기 티켓**: 1등 우승(`Won`)하면 🎫 1장. ~~스킨 10% / 꽝 90%(🍚 +20)~~ → 2차 결정으로 바뀜(아래) · 사용자
- 2026-10-14 · 뽑기 풀 · **콘셉트 몸 스킨 9종 전부**. 지금은 실험 스킨이라 모두가 무료로 갖지만 이제 **뽑기로만** 얻는다(무료 아님, 판매 아님) · 사용자
- 2026-10-14 · 이름 · "콘셉트 ○○ (테스트)" → "○○ (특)" (위 이름 표) · 사용자
- 2026-10-14 · 테스트 환경 · **Studio에서는 모든 스킨을 장착 가능**(보유 안 해도), 저장(`ownedSkins`)에는 안 남김. `Config.DEBUG.unlockAllSkinsInStudio`(Studio만, `persistDataInStudio = true`면 꺼짐), 커밋 기본값 true · 사용자
- 2026-10-14 · GDD 9.1 "유료 랜덤 뽑기 없음"과의 관계 · 유료 뽑기 금지는 그대로, **무료 뽑기만**: 뽑기권은 플레이(우승)로만, Robux·코인으로 팔지 않음, 확률 공개, 스킨은 겉모습만. Robux·게임 재화 지불이 없는 행동 보상은 유료 랜덤 아이템이 아님 — 근거: Roblox Paid random items·Content maturity [원문], REFERENCE §1 · 사용자 결정 + 기획 확인
- 2026-10-14 · 도박으로 읽히지 않게 · 뽑기권은 뽑기 말고 쓸 곳 없음, 코인으로 사거나 바꿀 수 없음, 거래 없음, 뽑기는 늘 무언가를 줌(2차부터는 꽝도 없음) · 기획 — 근거: Content maturity 도박 정의 [원문], REFERENCE §1
- ~~2026-10-14 · 이미 가진 스킨 · 후보에서 빼고 남은 것 중 균등, 9종 다 가지면 🍚 +100~~ → **폐기**(2차: 가진 스킨도 후보에 남고 등급별 코인)
- 2026-10-14 · 티켓 상한 · 99장, 가득이면 안 늘고 토스트 · 기획 기본값 — 근거: REFERENCE §3
- 2026-10-14 · 프로필 · v3, `drawTickets`. 옛 서버가 v3를 읽으면 "미래 버전 — 저장 안 함" 보호가 이미 있음. 특 스킨을 입었지만 보유가 없는 프로필은 계란초밥으로(공개 전이라 실제 손실 없음) · 기획
- 2026-10-14 · 내부 등급 · 특 9종 `tier = "Basic"` 유지, 화면 배지는 뽑기 등급(2차에서 "🎫 특" 단일 배지 → 등급별 배지로 바뀜) · 기획
- 2026-10-14 · 당첨 스킨 자동 장착 · 하지 않음 — 결과 화면 "입기" 버튼 · 기획 기본값
- 2026-10-14 · 서비스 위치 · 새 서비스 없이 `ShopService`에 `DrawTicket` · 기획
- 2026-10-14 · 관리자 명령 · `tickets <n>`, **StudioOnly** · 기획
- 2026-10-14 · 저장 시점 · 뽑기 뒤 `saveNow` 안 함(무료 보상). 저장 전에 서버가 죽으면 티켓·보상이 같이 되돌아감 · 기획
- **2026-10-14 (2차, 사용자 결정 — 메인 세션 전달)**
  - 화면 · 사용자가 뽑기 화면 샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png`를 보냄. **뽑기 화면은 이 샘플을 참고해 만든다**(위 "UI"). 이미지 에셋 대신 기본 UI 요소로 흉내 냄 · 사용자 (기본 UI 요소 방식은 기획 — 에셋 업로드는 사용자 작업이 늘고 모더레이션 대기가 생김)
  - 확률 구조 · **샘플대로 꽝 없이 등급별**: 전설 1% / 영웅 5% / 희귀 15% / 고급 30% / 일반 49%(샘플은 일반 48%라 합 99 → 100이 되게 49로, 메인 세션). 등급을 먼저 뽑고 등급 안에서 균등. 이미 가진 스킨이 나오면 등급별 코인 일반 20 / 고급 40 / 희귀 80 / 영웅 150 / 전설 300(`Config.Draw`). 1차 "스킨 10% / 꽝 90% +20", "9종 다 가지면 +100" 폐기 · 사용자 — 근거: 등급별 확률 상자는 MM2·TDS·Rivals 공통 구조 (REFERENCE §2·§4)
  - 뽑기 등급 · `drawGrade`(상점 tier와 별개): 연어 영웅 / 성게·문어·연어알 희귀 / 유부·장어·참치 고급 / 새우·계란 일반. 샘플에 없는 참치·연어알은 메인 세션이 정함. **전설 = 고등어 초밥 [신선]**(`fresh-mackerel`, m5-32) · 사용자 + 메인 세션
  - 고등어 · **뽑기 전설로도 나오고 로벅스 199 판매도 한다**. 뽑기로 얻든 사든 같은 보유. 이미 가진 사람은 구매를 막음(기존 `AlreadyOwned`). 넣는 것은 m5-32 · 사용자
  - 빈 등급 · m5-31에는 전설 스킨이 없으므로 `DrawLogic`이 빈 등급 확률을 나머지 등급에 비율대로 나누고, **화면 확률표도 나눠진 실제 값**을 보여 준다(화면 = 서버, 테스트). m5-32가 고등어를 넣으면 코드 수정 없이 1% · 사용자
  - 확률 표시 형식 · 등급 줄은 소수 1자리 + 최대 나머지 방식(합 정확히 100.0%), 빈 등급 줄은 "준비 중", ⓘ 상세는 스킨별 소수 2자리 + 반올림 안내 문구 · 기획 — 근거: Roblox Paid random items 문서의 표시 규칙(퍼센트, 합 100%, 반올림 안내 문구, "각 X%" 묶음 허용) [원문 2026-10-14 재확인], REFERENCE §1. 무료 뽑기라 의무는 아니지만 같은 수준으로 공개 (developer가 다른 형식을 쓰면 결정 기록에)
  - 고등어 판매와 정책 · 고등어를 로벅스로도 팔지만 **뽑기 자체는 어떤 돈·재화로도 할 수 없다**(뽑기권 = 우승만). 로벅스로 사는 것은 "정해진 스킨 하나"이지 랜덤 결과가 아니므로 뽑기는 계속 무료 행동 보상이다. 확률을 올리는 상품·보장권도 만들지 않는다 · 기획 — 근거: REFERENCE §1·§4
  - 대표 스킨(단상) · 아직 없는 가장 높은 등급 스킨, 다 가졌으면 가장 높은 등급 · 기획 기본값 (샘플은 전설 고등어를 세움)
  - 탈의실 "🎫 특" 탭 · 뽑기 전용 9종만(m5-32 고등어는 전설 탭에 판매 카드로, 뽑기 화면 보유 목록에는 들어감) · 기획
- 2026-10-14 · **3차 결정 (사용자)** — 열린 질문 1·2 답: **천장 없이 간다**, **적은 인원 방 몰아주기도 일단 막지 않는다**(플레이테스트 뒤 다시 봄) · 사용자
- **열린 질문 (사용자)**
  1. **천장(보장)**을 둘지: 꽝이 없어져 첫 뽑기는 늘 새 스킨이지만, 영웅(연어)·전설(고등어)은 낮다 — 고등어 1%는 평균 100장(8명 방 기준 약 800판, 추정), 50장 뽑아도 못 얻을 확률 약 60%. 추천: 우선 없이 내고(고등어는 R$ 199로 살 수도 있음), 플레이테스트 반응을 보고 "N장마다 영웅 이상 보장" 같은 천장을 후속으로. (천장 사례는 비교 게임에서 확인 못 함)
  2. 판 인원이 적은 방(4명 비공개 방)에서 친구끼리 우승을 몰아주는 티켓 파밍: 지금은 막지 않음. 추천: 그대로 두고 플레이테스트 뒤 필요하면 "5명 이상 판에서만 뽑기권".
  3. Roblox 성숙도·준수 설문에서 "유료 랜덤 아이템"을 "없음"으로 답하면 되는지 — 문서상 그렇다(고등어가 판매돼도 뽑기권은 무료). 퍼블리시 때 사용자가 확인(USER-TODO C4).

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 사용자 변경 2026-10-14 (메인 세션 전달, 구현에 반영)
- 꽝 없음, 등급별 확률 전설 1 / 영웅 5 / 희귀 15 / 고급 30 / 일반 49(`Config.Draw.GradeWeights`), 중복은 등급별 🍚 20/40/80/150/300(`Config.Draw.DuplicateCoins`). 1차의 10%/꽝 +20/9종 다 가지면 +100은 코드에서 지웠다(`SkinChance`·`ConsolationCoins` 없음 — 테스트로 고정).
- `drawGrade`(상점 tier와 별개): 연어 영웅 / 성게·문어·연어알 희귀 / 유부·장어·참치 고급 / 새우·계란 일반. 전설은 m5-32 고등어 몫이라 지금은 빈 등급 → 나머지에 비율대로(5/99·15/99·30/99·49/99), 화면도 같은 값(최대 나머지 방식 5.0/15.2/30.3/49.5, 전설 "준비 중").
- 뽑기 화면은 샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png` 구성을 기본 UI 요소로 옮김(아래 "Studio 확인").

### 바뀐 파일
- 공용: `src/shared/Config.luau`(`Config.Draw`, `DEBUG.unlockAllSkinsInStudio = true`), `src/shared/Remotes.luau`(`DrawTicket`, RemoteFunction 16 + RemoteEvent 11), `src/shared/Types.luau`(`DrawGrade`, `DrawResult`, `ProfileView.drawTickets`·`studioUnlockAll`, `RewardGrant.tickets`·`ticketsFull`).
- shared: `Skins`(이름 "(특)", `drawGrade`, `DRAW_IDS`, `DRAW_GRADES`·`DRAW_GRADE_INFO`, `DRAW_INFO`, `TIER_ROBUX`, `isFree` = 계란초밥만, `isDraw`·`isDrawOnly`·`drawGradeOf`, validate), 새 `DrawLogic`, `ShopLogic`(`unlockAllActive`, `canEquip(…, unlockAll)`, "🎫 특" 탭, 카드 `Draw`·"입기 (Studio)"), `ProfileSchema`(v3 `drawTickets`, `ViewExtra.unlockAll`), `ProfileLogic`(migrate), `RewardLogic`(Won `tickets`, `simulate` 세 번째 값, 토스트·정산 글씨), `AdminLogic`(`tickets` StudioOnly, info에 🎫), `SfxCues`·`SfxLibrary`(`DrawReveal`·`DrawWin`, 무음).
- server: `ShopService`(`DrawTicket`, Studio 전부 입기, `[Draw]` 로그), `RewardService`(같은 update 안에서 뽑기권), `DataService`(`setStudioUnlockAll` — 화면용), `AdminCommands`(`tickets`).
- client: 새 `ui/DrawScreen.luau`(뽑기 화면), `ShopScreen`(🎫 뽑기 버튼·배지·특 스킨 등급 배지), `ShopController`(DrawTicket 흐름, 숨김 연동), `CoinController`(뽑기권 토스트·정산), `AdminPanel`(🎫 +1/+10/+98/0으로).
- tests: 새 `tests/m5-31-draw-logic.spec.luau`(25). 바꾼 기존 테스트(AC15): `m5-27-concept-skin`(이름·drawGrade, validate 문구, 보유 = NotOwned/NotForCoins/NotRobux, 카드 "🎫 뽑기로 얻기", 보유 없는 장착 → 계란초밥), `m5-28-concept-skins`·`m5-29-concept-skins-2`(이름 "(특)", 같은 보유 규칙), `m5-28-qa`·`m5-29-qa`(🎫 특 탭에도 보임, 보유해야 장착값 유지), `skins.spec`(이름 표), `m4-foundation`·`m5-03-foundation`·`m5-03-qa`·`m4-07-data-qa`(VERSION 3, 리모트 27, 미래 버전 4, DataService view extra 문자열, DEBUG 기본값), `m5-07-qa`·`shop-logic`(탭 수 +1), `reward-logic`(Won 묶음에 tickets), `admin-logic`(info 줄 🎫, tickets 등급), `camera-priority`(SfxCues 2개), `m4-14-qa`·`m5-08-qa`(가짜 모듈 표에 DrawLogic). 모양·관절·파츠 상한(70)·렌더 검사는 그대로.

### 결정 기록 (개발)
- 스펙 2차 이름 그대로: `Config.Draw.GradeWeights`, `DrawLogic.grades/roll/displayPercents/perSkinPercent/featured`, `Skins.isDrawOnly`·`DRAW_IDS`. `DrawResult`에 `skinsLeft`는 두지 않음(스펙 타입대로). `Skins.DRAW_GRADES`는 순서 목록, 이름·색은 `Skins.DRAW_GRADE_INFO`로 나눔. `drawGrade` + `robux`는 `Skins.TIER_ROBUX`(29/59/99/199)와 같아야 통과.
- 관리자 인자 거절 이유는 기존 `BadCommandArgs`(스펙의 `BadArgs`)를 그대로 씀.
- 탈의실에 원래 "기본" 탭이 없음(전체·일반·레어·에픽·전설) — 특 스킨은 등급 탭에 안 나오고 전체·🎫 특에만.
- `DataService`는 `ShopLogic`을 require하지 않고 `ShopService.init`이 `DataService.setStudioUnlockAll`로 알려 줌(가짜 DataService 테스트를 안 깨려고).
- 단상은 ViewportFrame 안 3D 원기둥 대신 2D 둥근 Frame(그라데이션) + 인형 ViewportFrame — Studio에서 보고 바꿀 것. 결과 연출 시간은 `DrawScreen.SUSPENSE_TIME` 1.2초 + 열림 0.35~0.5초.
- `saveNow` 안 부름(무료 보상). 현지화(AC17): main에 m5-26 `Localization/Strings.csv` 없음 → **해당 없음**, 문구는 코드 상수.

### Studio 확인 방법 (AC18~AC24)
1. 커밋 값 그대로 Play → 탈의실 모든 카드 "입기 (Studio)", 입으면 바뀜, 서버 Output `[ShopService] Studio: all skins can be worn…`. 🎫 뽑기 화면 보유 목록 0/9(저장 안 됨).
2. `Config.DEBUG.unlockAllSkinsInStudio = false` → 🛠 패널 "명령" 탭 "🎫 티켓 +10"(+98) → 🍣 스킨 버튼 빨간 배지 → 탈의실 머리줄 "🎫 뽑기 N" → 샘플과 나란히 비교(간판·뽑기권 ×N·단상 연어초밥 (특)·"연어초밥 (특) 획득 가능!"·노란 "🎫 뽑기 시작하기 >"·확률표 전설 준비 중/5.0/15.2/30.3/49.5·ⓘ 스킨별 각 x.xx%).
3. "뽑기 시작하기" → 🛎️ 들썩 → 등급색 빛 + "👑 스킨 획득!" / 중복이면 "이미 가진 스킨이에요 → 🍚 +N". 서버 Output `[Draw] …` 한 줄. 연타해도 한 장씩.
4. 혼자 한 판(`minPlayersToStart = 1`) 우승 → "+1 🎫 우승 뽑기권", 정산 "🎫 +1". +98 뒤 우승 2번 → "🎫 뽑기권이 가득 찼어요 (99장)".
5. 라운드 중에는 뽑기 화면이 탈의실과 같이 닫힘. Device 에뮬레이터(짧은 변 ≤ 500)에서 탭 "🎫 뽑기 / 📊 확률 / 📦 목록"으로 나뉘어 겹치지 않는지.
6. `persistDataInStudio = true`면 전부 입기 꺼짐 + 경고 한 줄.

### 검증 (2026-10-14, Windows 로컬)
rojo build OK · stylua --check OK · selene 0 errors/0 warnings · `lune run tests` **1888 passed, 0 failed** · luau-lsp 끝 코드 0.

### 남은 이슈
- 뽑기 화면 모양은 Studio 확인 필요(렌더러 없음). 소리 id 미정(무음).

### QA 반려 (2026-10-14, `docs/qa/m5-31-winner-ticket-draw.md`)
- **in-dev 이유: [P2] B1** 휴대폰(짧은 변 ≤ 500)에서 뽑기 화면 버튼(상세 "입기" 약 17px, 표정 썸네일 29px, ⓘ·ⓘ 창 ✕ 26px, 결과 "확인"·"입기" 37px, "뽑기 시작하기" 38px — 844×390 계산)이 44px보다 작아 AC24를 못 지킴. `DrawScreen.setLayout`이 이 버튼들을 `UiLayout.touchSize`로 맞추지 않음. 이번 QA는 "P0~P2면 반려" 기준.
- P3: B2 두근두근 중 배경 보유 목록이 먼저 바뀜, B3 휴대폰 배치(탭 3개·상세 아래 반쪽)가 스펙 UI 11과 다르고 결정 기록에 없음.
- AC1~AC16 lune 통과(1906 passed, 0 failed), 서버 판정·보안 문제 없음.
