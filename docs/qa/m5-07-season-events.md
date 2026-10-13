# QA — m5-07 시즌 이벤트: 한정 스킨·이벤트 재화(🍬/⭐)·탈의실 이벤트 탭

- 스펙: `docs/specs/m5-07-season-events.md`
- 검증 커밋: `aa84001` (브랜치 `m5-07-season`, `origin/main` `1ddf47e`와 병합한 상태 `540d888`에서 검증)
- 결과: **통과** (P0/P1 없음, P3 1개) → 스펙 `qa-passed`

## 자동 검증
Windows 로컬, 2026-10-13, `rokit.toml` 고정 버전.

| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 포함) |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **1464 passed, 1 failed** — 실패 1개는 QA가 B1을 재현하려고 추가한 `m5-07-qa.spec` "QA AC12: 시즌 장식이 로비의 충돌 있는 건물(카운터·레일·벽·단상)과 겹치지 않아요". QA 테스트를 넣기 전 병합 상태는 1444 passed, 0 failed |
| `luau-lsp analyze` (새 검사기) | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 재화 지급 (통과 1·결승 2·우승 5, 기간 밖 nil) | 통과 | `reward-logic.spec`(개발), QA "재화는 [시작, 끝) 안에서만 — 경계 1초 단위"(시작−1/시작/끝−1/끝, 두 이벤트 사이, 크리스마스), "RewardService 결승 출발·우승 재화가 eventTokens에 쌓이고" |
| AC2 매치 끝 (DailyFirstMatch 50+4 / MatchPlayed 0+1 / 없음) | 통과 | 개발 테스트 + QA "하루 첫 판인데 이벤트 밖이면 예전과 같은 50, 재화 nil", "매치 끝 — 사람마다 RewardGranted 1번, update 1번", 한 판 시뮬레이션(우승자 13개·1라운드 탈락자 1개·중간 퇴장자 0) |
| AC3 `canBuyWithTokens`·`buyWithTokens` | 통과 | QA "거절 순서 — 카탈로그 → 기간 → 보유 → 잠금 → 저장 → 재화"(조건 여러 개가 같이 빠질 때 앞 순서 이유), 이상한 재화 값(NaN·음수·inf·문자열)은 0, 실패하면 지갑 그대로, 두 번째 요청 AlreadyOwned(이중 차감 없음), 다른 이벤트 재화로는 못 받음 |
| AC4 카드 상태 7가지·`visibleSkins` | 통과 | QA "cardState 7가지 + 버튼 글씨", "탭·보이는 카드". 유료 한정 카드 글씨는 DEV5대로 `R$ 99`(수용). 미보유 한정 스킨은 등급 탭에 안 보임(DEV2, 수용) |
| AC5 머리줄 "11월 5일까지" | 통과 | QA "머리줄 — 날짜만, 크리스마스는 해를 넘겨 1월 7일" |
| AC6 새 스킨 5종 생김새·±15%·효과 1개 이하 | 통과 | `sushi-body.spec`(개발) — 자리 표시 아님, 외곽 상자 ±15%, 효과 ≤ 1. 파츠는 모두 Massless·충돌·쿼리·터치 없음(`SushiBody.luau:1008-1011`), 크기·히트박스·속도는 그대로 |
| AC7 검증 5단계 | 통과 (개발 코드) | 위 표. 실패 1개는 QA 재현 테스트(B1, 장식 위치) |
| AC8~AC14 Studio 확인 | 사용자 확인 필요 | 아래 체크리스트 |

### 이전 QA 버그 닫힘 확인 (m5-03)
- **B2 `BuyWithTokens` 핸들러 없음 → 닫힘.** `ShopService.init`이 `bind("BuyWithTokens", onBuyWithTokens)` (`src/server/ShopService.luau:291`). QA "B2 닫힘: 핸들러가 붙어 있고 잘못된 인자는 바로 거절"(nil·숫자·불리언·표·10만 자·`"__index"` → `false, 이유`, update·저장 없음).
- **B3 기간 밖 시즌 로벅스 카드가 켜져 보임 → 닫힘.** `ShopLogic.cardState(skin, view, robux, now)`가 판매 기간을 보고 `OffSale`(비활성), 클라이언트가 `now`를 넘김(`ShopScreen.luau` render). 미보유 시즌 스킨은 기간 전·후 모든 탭에서 숨김. QA "B3 닫힘: 판매 기간 전(오늘) 가짜 결제여도 호박 초밥 카드는 비활성·숨김".

## 버그

### [P3] B1 로비 시즌 장식이 카운터 양 끝 의자와 겹쳐 보임
- 재현: `Config.DEBUG.eventNow = 1792108800`(할로윈) → Play Solo → 로비 카운터 왼쪽·오른쪽 끝(x = ±35, z = −40)을 본다. 크리스마스(`1796947200`)도 같은 자리.
- 기대: 장식이 로비의 다른 파츠(의자·셰프·수조)와 겹치지 않는다(스펙 "로비 카운터 주변에 장식").
- 실제: 호박 `Pumpkin1`·`Pumpkin2`(지름 3, x = ±35)가 의자 `StoolSeat8`·`StoolSeat1`(x = ±33, 반지름 1.2)을 파고들고, 크리스마스 트리 `TreeLow1`·`TreeLow2`(폭 5)가 의자 다리·자리를 감싼다. 둘 다 충돌이 없어 플레이에는 영향이 없고 보기만 어색하다.
- 처리 제안: `AROUND_COUNTER`의 첫 두 자리를 x = ±38 정도로(의자 끝 34.2, 트리 반폭 2.5) 옮기고 벽·`LIMITS`와 안 겹치는지 확인. QA 테스트가 STRUCTURE·DECOR 전체와 겹침을 검사함.
- 위치: `src/server/LobbyService.luau` `AROUND_COUNTER`(`vec(-35, 0, -40)`, `vec(35, 0, -40)`), `christmasDecor`의 `for i, x in { -35, 35 }`. 의자는 `src/shared/LobbyLayout.luau:471-491`.

### 메모 (버그 아님)
- `LobbyService.start`의 첫 `applySeasonDecor()`는 `pcall` 밖이에요(10분 루프는 `pcall`). 서버 부트스트랩(`init.server.luau:32`)도 `start`를 감싸지 않아 여기서 에러가 나면 뒤 서비스 시작이 멈춰요. 지금 코드는 고정 데이터라 QA 테스트로 장식 함수가 에러 없이 도는 것을 확인했지만, 나중에 장식을 고칠 때를 위해 첫 호출도 `pcall`로 감싸는 걸 권해요.
- `Config.Shop.RequestCooldown` 주석이 아직 "EquipSkin·BuyWithCoins 두 요청"이에요(실제로는 BuyWithTokens까지 세 요청이 같이 씀 — QA 테스트로 확인). 공용 파일이라 다음에 Config를 고치는 스펙에서 한 줄.
- DEV2(받기 전 한정 스킨은 이벤트 탭·전체 탭에만)·DEV3(Glow)·DEV5(`R$ 99` 글씨)·DEV6(장식 데이터 위치)는 메인 세션 판단대로 수용. 다르게 원하면 각각 한 줄 수정.
- 클라이언트 표시 시각은 `GetServerTimeNow()`라 경계에서 배지는 최대 1분, 탈의실은 다시 그릴 때까지 늦게 바뀔 수 있어요. 교환·지급 판단은 서버라 결과는 맞아요(개발 메모와 같음).

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자 검증: `BuyWithTokens`는 요청 간격(EquipSkin·BuyWithCoins와 공유, 간격 검사가 인자 검사보다 먼저) → 문자열 → 프로필 → `canBuyWithTokens`(카탈로그 → 기간 → 보유 → 잠금 → 저장 → 재화) 순서. 통과하면 한 번의 `DataService.update` 안에서 다시 판단하고 차감·보유·장착, 실서버면 `saveNow` 한 번. 실패는 update·저장 없음 (QA 테스트 4개).
- [x] 재화 지급은 서버만: `RewardService`에 클라이언트 리모트 핸들러 없음, `ShopService`는 `eventTokens`를 직접 만지지 않고 `ShopLogic.buyWithTokens`로만 뺌 (QA 소스 테스트).
- [x] `Config.DEBUG.eventNow`는 Studio에서만: 실서버(`IsStudio = false`)에 `eventNow`가 들어 있어도 `os.time()`으로 판단 — ShopService 교환 거절·RewardService 재화 없음을 가짜 환경으로 확인. 커밋 값 nil(개발 테스트).
- [x] 이중 지급 없음: 매치 끝은 사람마다 RewardGranted 1번·update 1번, 결승 통과(Passed)는 지급 없음, 같은 스킨 두 번 교환은 AlreadyOwned로 차감 없음.
- [x] 압박 판매 없음(D4): 머리줄은 날짜만, "마지막 기회"·카운트다운 없음, "다시 올 수도 있어요" 안내.
- [x] 스킨은 겉모습만: 새 5종 모두 충돌·쿼리·터치 없는 Massless 파츠, 외곽 ±15%, 효과 ≤ 1.
- [x] 로비 장식: MapKit 장식 규칙(충돌 없음), 할로윈 20·크리스마스 23 파츠(≤ 40), 조명 ≤ 2, 바닥 위·로비 한계 안·비울 영역(스폰·통로) 밖, 건물(STRUCTURE)과 안 겹침. 종류가 바뀔 때만 이전 폴더를 지우고 새로 만듦(누수 없음). Match 서버는 로비를 안 지어 장식도 없음. 의자와 겹침은 B1.
- [x] 맵·라운드 코드 변경 없음 (`ctx`·Cleanup 해당 없음).

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.eventNow = 1792108800`(할로윈 첫날). **확인이 끝나면 `eventNow = nil`, `fakeRobuxInStudio = false`, `forceMapPlan = nil`로 되돌리기.**

1. (AC8) Play Solo → 왼쪽 위 코인 배지 옆에 "🍬 0"이 보인다.
2. (AC8) "🍣 스킨" → "🎃 할로윈" 탭이 맨 앞에 있고 먼저 선택돼 있다. 머리줄 "할로윈 초밥 축제 · 11월 5일까지 · 🍬 0"과 작은 안내 "이벤트가 끝나면 받을 수 없어요. 다음 해에 다시 올 수도 있어요." — 초 단위 카운트다운이 없다. 카드는 호박 초밥(R$ 99), 유령 계란초밥("🍬 0 / 80", 비활성) 2개뿐.
3. (AC12) 로비 카운터 둘레에 호박 6개와 보라 조명 2개. 그 위를 걸어 지나갈 수 있다(충돌 없음). 카운터 양 끝 호박이 의자에 박혀 보이는지 봐 주세요(B1 — 고쳐지기 전이면 박혀 보이는 게 맞아요).
4. (AC9) `forceMapPlan`으로 한 판 → 라운드 통과 때 토스트 "+10 🍚 +1 🍬 라운드 통과"(`TokenGet`은 소리 id 전이라 무음), 배지 숫자가 바로 늘어난다. 매치 끝 "+50 🍚 +4 🍬 오늘 첫 판"(그날 첫 판일 때), 두 번째 판부터 "+1 🍬 판 참가". 우승하면 우승 화면 아래 "이번 판 +N 🍚 +M 🍬 (총 …)".
5. (AC10) 명령줄(서버)에서 `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.eventTokens["halloween-2026"] = 80 end)` → 탈의실(닫았다 열기) 유령 계란초밥 "🍬 80으로 받기" → 누르면 "🎉 유령 계란초밥 받았어요!", 캐릭터가 바로 유령으로, 배지 "🍬 0".
6. (AC10) 재화를 다시 80으로 채우고(다른 테스트 계정이거나 스킨을 빼는 대신 다음 단계용) 라운드 중(소개 포함)에 탈의실 버튼이 숨거나 받기가 "매치가 끝나면 바꿀 수 있어요"로 거절되는지.
7. (AC11) `fakeRobuxInStudio = true` → 호박 초밥 "R$ 99" → 가짜 결제로 지급·장착.
8. (AC11·AC12) `eventNow = 1793923200`(끝)으로 바꿔 다시 Play → 이벤트 탭·🍬 배지·호박 장식이 없다. 가진 호박 초밥은 에픽 탭에, 유령 계란초밥은 레어 탭에 "한정" 표시로 남는다. 안 가진 한정 스킨은 "전체" 탭에도 없다.
9. (AC12) `eventNow = 1796947200`(크리스마스) → "🎄 크리스마스" 탭, "⭐ 0" 배지, 머리줄 "1월 7일까지", 로비에 트리 2·선물 4·눈 내림.
10. (AC13) 탈의실 미리보기와 게임 속에서 호박 초밥·유령 계란초밥·산타 새우·트리 마키를 입어 보고, 관리자 "🛠" 미리보기로 금박 계란초밥(VIP)도 본다 — 크거나 이상하게 겹치지 않는지, 유령 빛·트리 별 반짝이·금박 반짝이가 과하지 않은지.
11. (AC14) 휴대폰 에뮬레이터(작은 가로 화면)에서 탈의실 이벤트 탭 6개·머리줄 두 줄·코인 배지 옆 🍬가 다른 UI·위쪽 바와 안 겹치는지.

## 추가한 테스트
`tests/m5-07-qa.spec.luau` (21개, 20 통과 + B1 재현 1 실패)
- 재화 경계 [시작, 끝) 1초 단위·이벤트 사이·크리스마스 값, 이벤트 밖 하루 첫 판, 한 판 시뮬레이션(이중 지급 없음)
- `canBuyWithTokens` 거절 순서(조건 여러 개 동시), 이상한 재화 값·다른 이벤트 재화·실패 시 지갑 그대로·두 번 교환
- `cardState` 7가지와 글씨(⭐ 포함), m5-03 B3 닫힘, 탭·`visibleSkins`(기간 끝·보유·VIP 전설 탭), 머리줄(크리스마스 해 넘김), 토스트·정산 글씨
- ShopService(가짜 환경): m5-03 B2 닫힘·잘못된 인자, 성공 update 1·저장 1·두 번째 AlreadyOwned, 요청 간격 공유·간격 우선, 저장 불가/Studio 메모리 모드, **실서버는 `eventNow` 무시**
- RewardService(가짜 환경): 매치 끝 사람마다 1번, 결승 출발·우승 누적 tokenTotal, **실서버는 `eventNow` 무시**, 클라이언트 지급 리모트 없음
- 로비 장식(소스에서 장식 함수를 꺼내 실행): DecorSpec 검사·예산·바닥·한계·비울 영역, 건물·장식과 겹침(B1), 바뀔 때만 다시 만들기·루프 pcall

## 인계 메모
- 브랜치: QA worktree에서 검증, 결과는 `m5-07-season`에 push (`git push origin HEAD:m5-07-season`).
- 끝난 것: 자동 검증 5단계, AC1~AC7 확인, m5-03 B2·B3 닫힘 확인, QA 테스트 21개, 이 리포트, 스펙 `qa-passed`.
- 남은 것: 메인 세션이 `m5-07-season`을 main에 병합. developer가 B1(장식 자리 두 군데 숫자) 고치면 QA 재현 테스트가 통과로 바뀜 — 그 전까지 `lune run tests`에 실패 1개가 남아요. 사용자 Studio 확인 AC8~AC14(위 체크리스트), 상품 id 2개·`TokenGet` 소리(USER-TODO).
- 다음에 할 첫 단계: B1 수정 뒤 `lune run tests`가 0 failed인지 확인.
- 막힌 점: 없음.
