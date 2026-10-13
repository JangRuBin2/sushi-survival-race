# QA — m5-26 다국어(현지화) 1단계

- 스펙: `docs/specs/m5-26-localization.md`
- 검증 커밋: `f273c18` (origin/main `3ed86cb` + origin/m5-26-i18n `4516c7e` 병합, m5-25 포함)
- 결과: **반려 (P1 1개)** — 스펙 상태 `in-dev`

## 요약
- 카탈로그·키·폴백·LocText 계약은 튼튼해요. 순수 AC1~AC15는 모두 통과했고, Rojo가 만든 `LocalizationTable` 내용이 우리 CSV 파서 결과와 397행 모두 같아요(Key·Source·Context·Example·en).
- **P1 1개**: 로비 복귀 티켓(TeleportData, 클라이언트가 바꿀 수 있음)에 `nameIsDefault = true`를 넣으면 방 이름 필터를 건너뛰어요. 필터 안 된 글이 로비 방 목록에 모두에게 보여요(B1). 고치기 쉬워요.
- 그 밖에는 P3뿐이에요(영어 문구 몇 줄, 다른 언어 서수, 번역기가 늦게 올 때 화면 언어가 섞이는 문제).

## 자동 검증 (로컬 Windows, 2026-10-13)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공. `ReplicatedStorage.Shared.Localization.Strings`(LocalizationTable) 397 항목 — `.rbxlx`로 따로 빌드해 `Contents` JSON을 CSV 파서 결과와 397행 모두 비교: 차이 0 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **1807 passed, 1 failed** (117개 파일). 실패 1개는 QA가 추가한 B1 재현 테스트(의도한 실패). 개발 테스트(`localization.spec` 20개 포함)는 모두 통과. QA 테스트 추가 전에는 1787 passed 0 failed |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0, 오류 없음 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 CSV 읽기·머리줄 | 통과 | `localization.spec` AC1, QA "파일 머리줄·열 수…"(BOM 없음, 따옴표·쉼표·줄바꿈 칸, 짝 안 맞는 따옴표·짧은 행 보고), Rojo `Contents` 대조 |
| AC2 키 형식·중복·빈 칸 | 통과 | `localization.spec` AC2·AC3, QA "앞뒤 공백·줄바꿈 없음, Context 있음, 대소문자만 다른 키 없음", QA "en 열에 한글이 없어요" |
| AC3 자리표시자·괄호·Example | 통과 | `localization.spec` AC2·AC3 (자리표시자 있는 63행 모두 Example 있음) |
| AC4 코드 키 ↔ CSV | 통과 | `localization.spec` AC4 + QA 보강 "소스의 모든 문자열 리터럴 중 키 모양은 CSV에 있어요"(테이블·if 식 안 키까지, 키 모양 리터럴 150개 이상 확인). 백틱 키는 `LocalizeLogic`의 동적 키 도우미뿐 |
| AC5 데이터 동기화 | 통과 | `localization.spec` AC5 4개 |
| AC6 이유 enum → LocText | 통과 | `localization.spec` AC6 |
| AC7 format | 통과 | `localization.spec` AC7, QA "인자 값 안의 {이름}은 다시 바꾸지 않아요"(`%1` 같은 gsub 문자도 그대로, 문자열 인자는 키로 풀지 않음) |
| AC8 choose 폴백 | 통과 | `localization.spec` AC8, QA "choose 경계"(빈 결과·짝 안 맞는 괄호·오류 플래그·en 번역기가 한국어를 돌려줌·ja 자동 번역·알 수 없는 언어) |
| AC9 languageOf·formatNumber·ordinal | 통과 | `localization.spec` AC9, QA 추가 경계(de-de·zh-cn·en_US, NaN·inf·-0.4, 23rd·24th·112th) |
| AC10 isLocText | 통과 | `localization.spec` AC10, QA 경계(깊이 3 거절, NaN·inf, 메타테이블, 101자 키, 인자 이름, 중첩 모양) |
| AC11 한국어 리터럴 금지 | 통과 | `localization.spec` AC11 (허용 목록 5줄 모두 이유 있음·관리자 `forceStart`·Studio 매치 이름). 서버 전체를 따로 grep: 남은 한국어는 관리자 명령, `LobbyService`/`LobbyLayout` 단상(2단계), `SoySwampHazards` "매워!!"(2단계)뿐 |
| AC12 버튼·탭 길이 | 통과 | `localization.spec` AC12 |
| AC13 조사 규칙 | 통과 | `localization.spec` AC13 + QA 보강(랑·야·라·아·나·이나·이고·든) 0행 |
| AC14 서비스 오류 키 비교 | 통과 | 기존 테스트 변경 검토(아래 "회귀") + QA가 **`RoomService` 소스를 가짜 환경으로 직접 돌려** 확인: 이미 방 안·방장 아님·최소 인원(`args.count = 4`)·꽉 찬 방·잘못된 코드(`args.count = 4`)·없는 코드·없는 방(문자열·숫자 id)·방 밖 나가기·잘못된 설정·최대 인원·너무 빠름 → 모두 CSV 키의 LocText. 핸들러 오류는 `room.err.ServerError`. Notice는 서버 전체에서 `(LocText, kind)` 두 인자 |
| AC15 기본 방 이름 | 통과 | `localization.spec` AC15 + QA 서비스 실행: 이름 없이 만든 방 → 스냅샷·목록 `nameIsDefault = true`, `name = "Mina"`, 필터 호출 0번 / 이름 쓴 방 → 필터된 이름, `nameIsDefault` nil / 복귀 때 필터 실패 → 그 사람 DisplayName 기본 이름 |
| AC16 검증 5단계 | 통과(개발 코드 기준) | 위 표. 지금 `lune` 실패 1개는 B1 재현 테스트 — B1을 고치면 통과해야 해요 |
| AC17 한국어 그대로 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC18 영어 전체 흐름 | 사용자 확인 필요 | 체크리스트 2 |
| AC19 영어 서버 메시지 | 사용자 확인 필요 | 체크리스트 3 (서버 쪽 키는 AC14로 확인) |
| AC20 다른 언어 폴백 | 사용자 확인 필요 | 체크리스트 4 (폴백 사슬은 AC8로 확인) |
| AC21 번역기 실패 | 사용자 확인 필요 | 체크리스트 5 |
| AC22 휴대폰 넘침 | 사용자 확인 필요 | 체크리스트 6 |
| AC23 이름 번역 안 함 | 사용자 확인 필요 | 체크리스트 7. 코드: Kit label·button·textBox와 직접 만든 TextLabel/TextButton 12곳 모두 `AutoLocalize = false`(QA 테스트) |
| AC24 실서버 자동 번역 | 사용자 확인 필요 | 퍼블리시·CSV 업로드 뒤 |
| AC25 (2단계) | 일부 | 이름표 칭호 `Loc.titleFromName`·이름표 AutoLocalize false는 됨. 로비 단상(빈 상태 문구·"{wins}승"·우승자 이름 라벨 AutoLocalize)은 남음 |
| AC26 (2단계) | 미구현 | 간장 늪 "매워!!" — 2단계 |

정리: 1단계 자동 AC1~AC16 **16개 통과**(AC16은 B1 재현 테스트 제외 기준), 실패 0. Studio·실서버 AC17~AC24 **8개 사용자 확인 필요**. 2단계 AC25 일부·AC26 남음.

## 버그

### [P1] B1 확인 안 된 로비 복귀 티켓의 `nameIsDefault`를 믿고 방 이름 필터를 건너뜀
- 재현: 분리 모드(Lobby/Match). 매치 서버 → 로비 복귀 텔레포트의 TeleportData(`kind = "return"`)를 바꿔서 `settings = { name = "<필터에 걸릴 글>", nameIsDefault = true, … }`로 보냄(TeleportData는 클라이언트를 거쳐 와서 바꿀 수 있어요 — CLAUDE.md "TeleportData는 힌트로만"). 그 방의 `MatchResult`가 없으면(키를 바꾸거나 결과 저장 실패) 확인 안 된 티켓으로 처리돼요.
- 기대: 확인 안 된 티켓에서 온 이름은 예전처럼 `filterRoomName(name, player)`를 거치거나, 기본 이름이면 서버가 아는 DisplayName으로 다시 만들어요.
- 실제: `PlacePayload.validateSettings`는 모양만 보고 `nameIsDefault = true`를 받아 주고, `RoomService.restoreRoom`이 `if filterWith and not nameIsDefault then`이라 필터를 건너뛰어요. 필터 안 된 글(최대 24자)이 `"{name}의 초밥집"` / `"{name}'s Sushi Bar"` 모양으로 로비 공개 방 목록에 모두에게 보여요. m5-26 전에는 `filterWith`가 있으면 항상 필터했어요(회귀). Roblox 텍스트 필터 규칙 위반이 될 수 있어 P1로 둬요.
- 위치: `src/server/RoomService.luau:695-702`, 입력 경로 `src/server/PlaceService.luau:364-374, 423-427`, `src/shared/PlacePayload.luau:114-131`
- 고치는 방향(개발이 정함): `filterWith`가 있으면 `nameIsDefault`와 상관없이 필터(DisplayName은 필터를 통과하니 기본 이름 표시는 그대로) — 또는 `nameIsDefault`면 이름을 `filterWith`/방장 DisplayName으로 다시 만들기. 정상 기본 이름 방은 복귀 뒤에도 `nameIsDefault = true`가 유지돼야 해요(QA 테스트 "정상 기본 이름 방은 복귀해도…").
- 테스트: `tests/m5-26-qa.spec.luau` "QA B1 (P1)…" (지금 실패, 고치면 통과)

### [P3] B2 영어 문구 몇 줄이 어색하거나 뜻이 흐림
- `hud.result.passed` "✅ You qualified in {place}!" → 화면에 "You qualified in 3rd!" (어색). `shop.btn.needCoins` "Need {count} 🍚" → "more"가 빠져 "총 필요 개수"로 읽혀요(스펙 6절 예시도 "Need {count} more 🍚"). 나머지는 아래 "영어 다듬기 목록".
- 위치: `src/shared/Localization/Strings.csv` (키는 그대로, `en`만)

### [P3] B3 영어·한국어 밖 언어에 영어 서수가 들어감
- 재현: Locale 독일어·일본어(클라우드 업로드 뒤 자동 번역). 탈락·통과 줄, 순위표, "먹혔다" 아래 등수.
- 기대: 그 언어 숫자 또는 숫자만.
- 실제: `Loc.place`가 ko가 아니면 모두 `ordinal(n, "en")` → "5th"가 독일어 문장 안에 들어가요(업로드 전에는 영어 폴백이라 문제 없음).
- 위치: `src/client/Loc.luau:161-163`. 제안: `language == "en"`일 때만 서수, 그 밖은 숫자.

### [P3] B4 번역기가 3초 뒤에 오면 화면 언어가 섞일 수 있음
- 재현: 클라우드 업로드 뒤, 독일어 계정에서 `GetTranslatorForPlayerAsync`가 3초 넘게 걸리는 경우.
- 실제: 처음 3초 안에 만든 화면(로비 버튼 등)은 영어 폴백으로 남고, 번역기가 온 뒤 만든 글씨는 독일어 — 한 화면에 두 언어. ko·en은 영향 없음(ko는 원문, en은 카탈로그 en = 클라우드 en).
- 위치: `src/client/Loc.luau:79-96`. 지금 범위에서는 둬도 돼요(스펙이 "언어를 게임 중에 바꾸는 경우는 다루지 않는다"). 고치려면 번역기가 늦게 오면 `Loc.changed` 신호로 화면 다시 그리기.

### [P3] B5 (알려진 2단계 범위) 서버가 만드는 글씨 3곳이 아직 한국어·자동 번역 대상
- 로비 우승자 단상: "다음 우승자는 누구?"(`src/shared/LobbyLayout.luau:314`), "{wins}승"(`src/server/LobbyService.luau:218`), 우승자 이름 라벨이 `AutoLocalize` 기본값(`src/server/LobbyService.luau:140`) → 영어 화면에 한글, 다른 언어에서 이름이 자동 번역될 수 있음(AC23의 단상 쪽).
- 간장 늪 "매워!!"(`src/shared/maps/SoySwampHazards.luau:103-109`).
- 스펙 2단계(AC25·AC26)로 이미 남겨 둔 것이라 1단계 반려 이유는 아니에요. 2단계에서 처리.

## 영어 다듬기 목록 (CSV `en`만, 키는 그대로)
| 키 | 지금 | 제안 | 이유 |
|---|---|---|---|
| `hud.result.passed` | ✅ You qualified in {place}! | ✅ Qualified! ({place} place) | "qualified in 3rd" 어색, `hud.result.out`과 모양 맞춤 |
| `shop.btn.needCoins` | Need {count} 🍚 | Need {count} more 🍚 | 뜻(모자란 개수). 4자리 기준 16자로 `.btn` 제한 안 |
| `common.err.connection` | The connection to the server is shaky | Connection problem. Please try again | "shaky"는 어색, 다음 행동 안내 |
| `offer.fxOff.btn` | On · Remove | In Use · Remove | "On"만으로는 무엇이 켜졌는지 모름 (15자) |
| `room.err.BadCode` | Room codes have {count} numbers | Room codes are {count} digits | 자연스러운 표현 |
| `offer.err.OwnsSome` | You already have one of these skins, so buy the others one by one | You already own a skin in this set. Buy the others one at a time | 짧고 분명하게 |
| `reward.summary` | This match +{total} 🍚 (Total {coins}) | This match: +{total} 🍚 (Total: {coins}) | 구두점 |
| `reward.summaryTokens` | This match +{total} 🍚 +{tokens} {icon} (Total {coins}) | This match: +{total} 🍚 +{tokens} {icon} (Total: {coins}) | 위와 같게 |
| `room.status.needPlayers` | You can start when {count} or more players are here | Need {count}+ players to start | 휴대폰 상태 줄 길이 |
| `code.err.NotSaved` | Saving isn't working right now, so you can't use codes yet | Saving is down right now. Try codes again later | 짧게 (선택) |

그 밖의 `en` 397행은 끝까지 읽었어요: 용어집(Wardrobe·Skins·Wear/Wearing·Unlock·Limited·Quick Join·Create Room·Join with Code·GO!·EATEN!·ESCAPED!·Sushi Bar·맵 15개·스킨 31개·상품·칭호·등급·시즌)은 스펙 7절과 모두 같아요(QA 테스트로 고정). 오타·한글 섞임·"kill/die/dead" 없음. 스킨·손님 대사는 아이 눈높이로 자연스러워요. 참고: 연출 입기 버튼은 "Wear" 대신 "Use"(`offer.fxWear.btn`)인데, 연출에는 "Use"가 더 자연스러워 그대로 둬도 돼요. 코인은 오류 줄에서 "coins"(소문자)라 "Rice Coins"는 화면에 안 나와요 — 원문도 "코인"이라 괜찮아요.

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자 검증은 그대로(이 스펙은 반환값만 바꿈). 서버는 클라이언트가 보낸 LocText를 받지 않아요(서버에 `isLocText` 사용 없음 — QA 테스트).
- [x] LocText 키는 서버·순수 로직의 고정 문자열이나 `LocalizeLogic` 동적 키 도우미(맵·스킨 id 등 서버 데이터)에서만 나와요. 인자 문자열은 키로 풀지 않아요(테이블 인자만 LocText로 풀고, 그것도 `isLocText` 검사·깊이 2·인자 20개·200자).
- [x] 클라이언트 `Loc.text`는 `isLocText`인 값만 키로 풀고, 문자열은 그대로(옛 서버), 그 밖은 빈 문자열 + 경고 한 번. 다른 클라이언트가 만든 값을 키로 푸는 곳 없음(칭호·외형 속성은 서버가 달아요).
- [x] 방 이름·플레이어 이름은 번역기를 거치지 않아요(기본 방 이름은 이름을 인자로만 넣음). 이름이 보이는 Kit·직접 만든 라벨 모두 `AutoLocalize = false`.
- [ ] **방 이름 필터: B1**(복귀 티켓 `nameIsDefault` 신뢰).
- [x] Notice는 `kind`를 항상 보내요(PlaceService 기본 "error", OfferService는 grantNotice의 kind).
- [x] Kick 2곳은 `ServerLoc.render(player.LocaleId)` — 번역기 기다림 없음.
- 판정·맵 상태·Cleanup: 이 스펙은 판정 코드를 바꾸지 않았어요(해당 없음).

## Loc 초기화·폴백 (코드 읽기)
- `Loc.init`은 `init.client.luau`에서 컨트롤러보다 먼저. 카탈로그는 `Shared.Localization.Strings:GetEntries()`(없으면 경고 한 번, 그 뒤 모든 키가 키 문자열 — 빌드에 항상 들어가므로 실제로는 안 남).
- 번역기: `pcall(GetTranslatorForPlayerAsync)`, 첫 시도가 바로 실패하면 기다리지 않고 진행, 걸리면 최대 3초. 그 뒤 1·2·4초 간격 3번 더, 끝까지 없으면 `[Loc] no translator…` 경고 한 번.
- `FormatByKey`는 `pcall` — 키가 클라우드 표에 없거나(업로드 전·Studio) 오류면 카탈로그로. ko는 번역기를 부르지 않아요.
- 언어: 번역기의 `LocaleId`, 없으면 `LocalPlayer.LocaleId`. ko → 원문, 그 밖 → 번역기 결과가 원문과 다르고 `{…}`가 안 남았을 때만, 아니면 카탈로그 en.
- 없는 키: 키 문자열 + 키마다 경고 한 번(테스트가 막아서 실제로는 안 나와야 함).

## 회귀 (바뀐 기존 테스트 검토)
- 기존 테스트 19개 파일(+ `tests/lib/FakeSfxEnv.luau`)의 문구 비교는 `LocTest.ko(값)`으로 풀어 같은 한국어와 비교해요 — 비교하는 동작은 같아요. `LocTest.ko`는 문자열이면 그대로 돌려줘서, 서비스가 다시 한국어 문자열을 돌려주는 회귀는 이 테스트들만으로는 못 잡지만 AC11(한국어 리터럴 금지)과 QA AC14 서비스 테스트(`isLocText` 확인)가 잡아요. 없는 키는 `render`가 키 문자열을 돌려줘서 비교가 실패해요(약해지지 않음).
- 기대값이 바뀐 곳은 스펙이 정한 차이뿐: 조사 규칙("🍬 80 · 받기", "R$ 29 · 사기", "R$ 79 · 사기"), 천 단위 쉼표("(총 1,234)"), `RoomLogic.defaultName("Rubin") == "Rubin"`(+ 키로 "Rubin의 초밥집"), `OfferLogic.message(nil) == nil`(예전 ""), `type(err) == "string"` → LocText 모양 확인. `DiveButton` 소스 검사·Notice 클라이언트 검사도 새 코드 모양으로 같은 의도를 확인해요.
- m4-14·m5-08 하네스는 `LocalizeLogic`·`Types`만 공유 캐시로 추가 — 다른 가짜 모듈은 그대로.

## m5-25 병합 안전
- `CharacterFxController`: m5-25의 얼굴·애니메이션 변경 위에 `Loc` require, 이름표·칭호·Dizzy 라벨 `AutoLocalize = false`, 칭호 `Loc.titleFromName`만 더했어요(diff 7줄). 칭호 속성은 여전히 서버 한국어 이름 → 클라이언트가 키로 바꿔요(`Config.Titles`에 없는 이름은 그대로).
- 병합 뒤 m5-25 테스트(`m5-25-qa` 등) 포함 전체 통과, 타입 검사 0.

## 사용자 Studio 확인 체크리스트
준비: Studio **Test** 탭 → **Player Emulator** 켜기 → Locale 고르기 → Play. `Config.DEBUG.minPlayersToStart = 1`(커밋 값)이면 혼자 한 판 가능.

1. **한국어(AC17)** — Locale 기본(한국어)으로 Play. 로비·방 만들기 창·방 대기실·카운트다운·라운드 소개·HUD·탈락("먹혔다!" + "N등")·관전 바·우승 배너·코인 토스트/정산·탈의실·상점·코드 창이 예전과 같은지. 의도한 차이만 있어야 해요: "🍚 300 · 해금", "R$ 29 · 사기", "🍬 80 · 받기", 코인 천 단위 쉼표(1,234).
2. **영어(AC18)** — Locale **English (United States)**. 로비 제목 "🍣 Sushi Survival Race", 버튼 "Quick Join"·"Create Room"·"Join with Code"·"🍣 Skins"·"🎁 Shop"·"🎟 Codes", 빈 방 목록 안내, 방 만들기 창("Max Players", "Who Can Join", "Public"/"Private (Code)"), 대기실("Press Start when you're ready"), 한 판 끝까지: 맵 이름·규칙(영어), "GO!", "Round 1 / 3", 타이머 "⏱ 45s", "Players left: N", "EATEN!" + "5th", 관전 "👀 Watching: …", 결승 "⚡ Overtime!", "ESCAPED! 🏆", 순위표 "1st", 코인 토스트 "+10 🍚 Round cleared", 정산 줄. **플레이어 이름 말고 한글이 하나도 없어야** 해요. Output 창 `[Loc]` 경고는 번역기 없음 한 줄 정도만.
3. **영어 서버 메시지(AC19)** — English에서: 코드로 참가에 "12a4"(→ "Room codes have 4 numbers"류), 없는 코드 "9999"(→ "No room has that code"), Test → Clients and Servers 2명으로 방장 아닌 사람이 시작(→ "Only the host can start"), 코인 모자란 스킨 해금, 🎟 코드 창에 없는 코드·이미 받은 코드. 모든 오류 줄이 영어인지.
4. **다른 언어(AC20)** — Locale **Deutsch**, 그다음 **日本語**. 클라우드 업로드 전이라 키 문구가 영어로 보이고, 한글·키 이름(`shop.err.…`, `room.err.…`)이 안 보여야 해요.
5. **번역기 실패(AC21)** — 퍼블리시 안 한 플레이스(또는 오프라인)에서 English → 영어, 기본 → 한국어. Output에 `[Loc] no translator…`가 한 번만.
6. **휴대폰 넘침(AC22)** — English + Test → **Device Emulator** 가로 667×375(iPhone SE급)와 844×390. 로비 버튼("Join with Code"), 방 만들기 창("Private (Code)"), 대기실 상태 줄("You can start when 4 or more players are here" — 가장 긴 줄), HUD 결과 줄("🥢 You're out! (12th place)"), 탈의실 카드 버튼("Need 300 🍚", "R$ 199 · Soon", "🍚 900 · Unlock")·탭("🎃 Spooky", "Legendary"), 상점 카드("R$ 297 if bought separately", "In Use"/"On · Remove"), 코드 창 안내 줄, 관전 바("Back to Lobby"), Dive·Grab 버튼, 음소거 버튼("🔊 Sound On")이 잘리거나 겹치지 않는지(줄바꿈·글씨 줄임은 괜찮음).
7. **이름 번역 안 함(AC23)** — English 또는 Deutsch에서 방 이름 칸에 "Shop"이라고 쓰고 만들기 → 방 목록·대기실에 "Shop" 그대로. 이름 없이 만든 방은 "<내 이름>'s Sushi Bar"(독일어 업로드 전에도 영어). 이름표·관전 대상·우승 배너의 플레이어 이름도 그대로.
8. **(참고, 2단계)** English에서 로비 우승자 단상이 아직 "다음 우승자는 누구?"·"N승"으로 보이고 간장 늪 와사비에서 "매워!!"가 보이는 건 알려진 2단계 범위(B5)예요.
9. **실서버(AC24, 퍼블리시 뒤)** — `src/shared/Localization/Strings.csv`를 Creator Dashboard → 현지화 → Upload CSV(처음엔 Download CSV로 백업)로 올린 다음 날 독일어 계정으로 접속 → 독일어 자동 번역이 보이고 `{name}` 같은 자리표시자가 그대로 노출되지 않는지.

## 추가한 테스트
- `tests/m5-26-qa.spec.luau` (21개, 20 통과 · 1 실패 = B1)
  - 카탈로그 위생: en에 한글 없음, 앞뒤 공백·줄바꿈 없음, Context 있음, 대소문자만 다른 키 없음, BOM 없음, 따옴표·쉼표·줄바꿈 칸 파싱과 오류 보고
  - AC4 보강: 소스의 모든 키 모양 문자열 리터럴이 CSV에 있음
  - AC13 보강: 추가 조사 목록
  - 용어집: 스펙 7절 영어(맵 15×2, 스킨 31, 상품·칭호·등급·시즌·UI 용어) 고정, 금지 단어 없음
  - LocalizeLogic 경계: choose·format(끼워 넣기)·render·isLocText·languageOf·formatNumber·ordinal
  - 계약·보안 정적 검사: Notice 두 인자, 서버가 클라이언트 LocText를 믿지 않음, `Loc.text` 모양, 직접 만든 Text 객체 AutoLocalize false
  - **`RoomService` 가짜 환경 실행**: 리모트 오류 LocText(AC14), 기본 방 이름(AC15), 복귀 필터 실패, **B1 재현**, 정상 기본 이름 복귀 유지, 핸들러 오류 → ServerError

## 인계 메모 (최신)
- **브랜치**: worktree `worktree-agent-af28d14b6bfa74cd9` → `origin/m5-26-i18n`에 push (main `3ed86cb` + m5-26 병합 위).
- **끝난 것**: m5-26 1단계 QA 전부 — 5단계 자동 검증, AC1~AC16 확인, 코드 리뷰(카탈로그·계약·보안·폴백·조사·영어·회귀·m5-25 병합), QA 테스트 21개, 이 리포트. 스펙 `in-dev`로 반려.
- **남은 것**: developer가 B1(P1) 수정 → `tests/m5-26-qa.spec.luau` "QA B1"이 통과하는지 → QA 재확인(B1만 + 전체 5단계). P3(B2 영어 문구, B3 서수, B4 늦은 번역기)는 선택. 2단계(B5: 단상·"매워!!", AC25·AC26). 사용자 Studio 체크리스트 1~9.
- **다음에 할 첫 단계**: 재QA 요청이 오면 `git merge origin/m5-26-i18n` 후 `lune run tests`에서 `m5-26-qa.spec.luau` 21/21인지, `RoomService.restoreRoom` 변경을 읽기.
- **막힌 점**: 없음. Studio·실서버 항목은 사용자 확인 필요.
