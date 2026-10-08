# QA — m4-13 스킨 목록 · 탈의실 · 코인 해금

- 스펙: `docs/specs/m4-13-skins-closet.md`
- 검증 커밋: `1704d9b` (구현 71e5f0c, 014e595, b9f5a6f)
- 결과: **통과** (P0/P1 없음, P3 4건) → 스펙 `qa-passed`. Studio AC6~AC11은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests` | 974 passed, 0 failed (구현 952 + QA 22) |
| `rojo sourcemap` + `luau-lsp analyze --platform roblox ... --flag:LuauSolverV2=true src` | 진단 0건, exit 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 카탈로그 16종·가격 | 통과 | `skins.spec` "AC1: 카탈로그 16종이 표와 같아요" 외 2개. 레어 이상 `coins = nil`, `productId` 전부 nil |
| AC2 생김새·외곽 ±15%·효과 ≤1 | 통과 | `skins.spec` AC2 6개 + QA "16종 build — 모든 파츠 Massless·충돌·쿼리·터치 없음", "외곽 비율 기록". 가장 빠듯한 축: 용 롤 높이 ×1.117·두께 ×1.116, 새우 두께 ×1.107, 오이마키 ×0.912 |
| AC3 canBuyWithCoins / canEquip | 통과 | `shop-logic.spec` AC3 4개 + QA 서버 핸들러 테스트(499 → "🍚 1개 더", 레어 → "코인으로는 살 수 없어요") |
| AC4 대사 1~2줄, linesFor | 통과 | `skins.spec` AC4 2개 |
| AC5 검증 5개 | 통과 | 위 표 |
| AC6 탈의실 16종·3D 미리보기·휴대폰 | 사용자 확인 필요 | 체크리스트 1 |
| AC7 연어 해금·저장 | 사용자 확인 필요 (서버 로직은 QA 테스트로 확인) | 체크리스트 2 |
| AC8 매치·탈락 인형·우승·단상 모두 연어 | 사용자 확인 필요 (코드 경로 확인: 탈락 인형·우승 인형은 캐릭터 `AppearanceId`, 단상은 `MatchService.luau:124-131` + 스냅샷) | 체크리스트 3 |
| AC9 라운드 중 거절, 관전·대기석 허용 | 사용자 확인 필요 (서버 잠금은 QA 테스트로 확인) | 체크리스트 4 |
| AC10 2명 같은 모습, 키·이름표 높이 같음 | 사용자 확인 필요 (Body·눈·입·발 값이 16종 동일, 이름표는 Body에 붙음) | 체크리스트 5 |
| AC11 로벅스 버튼 비활성 | 사용자 확인 필요 (`cardState` enabled=false, `ShopController.act`가 로벅스면 요청 안 함 — 로직 확인) | 체크리스트 6 |

자동 확인 가능한 AC 5/5 통과, Studio AC 6개는 사용자 확인 대기.

## 중점 검토
### 공정성 (GDD 6, 9 Pay-to-Win 금지)
- 히트박스·이동: 스킨은 `SushiBody` 파츠만 바꾸고 Humanoid·HRP·HipHeight·WalkSpeed는 손대지 않음. `CanLoadCharacterAppearance = false` 그대로라 체형도 같음.
- 파츠: 가짜 Instance로 16종을 실제 `build`해서 모든 Part가 `Massless`, `CanCollide/CanQuery/CanTouch = false`, Body만 Anchored(입힐 때 풀림)임을 확인. 장애물 Touched·레이캐스트·공간 쿼리에 안 잡힘.
- 효과: 불꽃 연어(ParticleEmitter), 황금 참치·다이아 성게(Sparkles)만 1개씩. 빛(PointLight 등) 없음. `setEffectsEnabled`가 탈락 연출 숨김 때 효과도 끔.
- 시야: 외곽이 계란초밥 ±15% 안이고 용 머리(앞쪽 z -0.8~-1.02)도 3인칭 카메라를 가릴 크기 아님. 반짝이 크기 체감은 Studio(체크리스트 5)에서.

### 보안·경제 (`src/server/ShopService.luau`)
- 인자: `type(skinId) ~= "string"` 거절(76-82, 100-106), 카탈로그·보유·등급·가격·코인은 `ShopLogic`, 요청 간격 0.3초를 두 리모트가 공용(62-70), 잠금(41-47) = 배치된 레이서 + 탈락 연출 3초 + 우승 VictoryDuration+1초. 퇴장(Left)은 잠그지 않음.
- 원자성: `DataService.update`는 동기(yield 없음, `DataService.luau:377-386`)이고 콜백 안에서 `ShopLogic.buyWithCoins`가 재판단 → 차감·보유·장착을 한 번에(121-123). 연타·간격 뒤 재요청 모두 한 번만 차감, 음수 없음(QA 테스트).
- 저장: `canPersist = false`는 실서버 거절, Studio 허용(111). 성공 뒤 `saveNow`를 spawn — 실패해도 `writeOnce`가 dirty를 되돌려 자동 저장·퇴장 저장이 다시 씀. 차감과 보유가 같은 스냅샷이라 한쪽만 저장되는 일 없음.
- 핸들러 에러는 pcall로 "다시 해 주세요"(158-167).

### 외형 단일 지점
- 캐릭터에 입히는 곳은 `AppearanceService.applyAppearance`뿐(`setResolver`/`refresh`가 이것만 부름). QA 테스트로 `src` 전체에서 `SetAttribute(Attributes.AppearanceId`가 AppearanceService 밖에 없음을 확인. `SushiBody.build`의 다른 사용처는 인형(탈락·우승·단상·미리보기)뿐.
- 탈락 인형·우승 인형: 캐릭터 `AppearanceId`. 로비 단상: 우승 판정 직전 스냅샷(`rememberAppearances`) → m4-06 L2의 외형 부분 해결.
- 매치 서버(m4-11 분리): ShopService가 모든 역할에서 돌고, 프로필이 늦게 로드되면 `onLoaded → refresh`로 다시 입힘. 승자 외형은 같은 `fireWinnerShowcase` 정보로 MatchResult에 실림.

### m4-14 준비 인터페이스
- `Skins.forProduct(productId)`: 숫자만, 없으면 nil. `validate`가 productId 중복·비정수를 잡음(QA 테스트).
- `ShopService.grantSkin(player, id, equip)`: 모르는 id·프로필 없음 → false, 이미 보유여도 true(멱등), 잠금 중이면 보유만 하고 장착 안 함, 저장은 안 함. 결제 처리에 쓰기에 적절. 단 N3 참고 — **임시 프로필에도 true**라서 m4-14 `ProcessReceipt`는 `canPersist` 확인 + `saveNow` 결과가 true일 때만 `PurchaseGranted`여야 함.

### 회귀
- `m4-foundation.spec` 리모트 개수 17 → 19: 스펙 "공용 파일 변경"(RemoteFunction 2개 추가)과 일치, 정당한 기대 변경.
- M3/M4 기존 테스트 전부 통과(m3-02 외형 가짜 환경, 탈락·우승 연출, 이동 감시, 플레이스 분리 포함).
- 이름표(`CharacterFxController.luau:146-150`)는 Body가 바뀌면 다시 만들어서 장착 변경 뒤에도 붙음.

## 버그
### [P3] N1 탈락 직후 3초 동안 버튼은 보이는데 장착하면 "매치가 끝나면 바꿀 수 있어요"
- 재현: 매치에서 탈락 → 관전 화면에서 바로 "🍣 스킨" → 다른 스킨 "입기".
- 기대: 버튼이 보이면 바뀌거나, 거절이면 "잠시 뒤에" 같은 맞는 문구.
- 실제: 클라이언트는 탈락 즉시 버튼을 보여 주지만(`ShopController.luau:53-54`) 서버는 탈락 연출 3초 동안 잠금(`ShopService.luau:151-152`)이라 "매치가 끝나면 바꿀 수 있어요"가 뜸. 3초 뒤엔 됨. 탈락 연출이 화면을 덮는 동안이라 실제로 누를 일은 드묾.
- 위치: `src/client/ui/ShopController.luau:53`, `src/server/ShopService.luau:151`
- 제안: 탈락 PlayerResult 뒤 `Config.Match.EliminationCutscene` 동안 버튼 숨김, 또는 잠금 이유별 문구.

### [P3] N2 매치 서버에서 프로필이 늦게 로드되면 라운드 중에 외형이 바뀜 (보이는 것만)
- 재현: 분리 모드, 로비 서버의 세션 잠금 해제가 늦어 매치 서버 프로필 로드가 첫 라운드 배치 뒤로 밀림.
- 기대: 라운드 중엔 외형 고정(또는 매치 시작 전에 프로필 대기).
- 실제: `onLoaded → AppearanceService.refresh`가 잠금을 보지 않아 달리는 중 계란초밥 → 장착 스킨으로 바뀜. 파츠가 판정에 안 끼므로 공정성 영향 없음. 매치 시작 스냅샷(`rememberAppearances`)이 기본 외형일 수 있지만 라운드마다·우승 직전에 다시 찍어서 단상은 맞음.
- 위치: `src/server/ShopService.luau:181-183`

### [P3] N3 `grantSkin`이 임시 프로필(canPersist=false)에도 true
- 재현: QA 테스트 "grantSkin: 임시 프로필(canPersist=false)에도 true를 돌려줘요".
- 기대: m4-14가 결제를 "저장된 것"으로 처리할 수 있게.
- 실제: 메모리에만 넣고 true. 이 스펙 범위에선 문제 없음(호출처 없음). m4-14 `ProcessReceipt`가 `DataService.canPersist` 확인 + `saveNow` 성공일 때만 `PurchaseGranted`를 돌려줘야 로벅스를 받고 스킨이 날아가는 일이 없음. 영수증 PurchaseId 중복 처리도 m4-14 몫.
- 위치: `src/server/ShopService.luau:135-147`

### [P3] N4 (L2 나머지, 개발 메모에 기록됨) 우승자가 연출 전에 나가면 우승 연출 인형은 기본 외형, 단상 칭호·승수 없음
- 위치: `src/client/fx/VictoryCutsceneController.luau:50` (Victory 방송에 외형 없음). 단상 외형은 이번에 해결.

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 (타입, 카탈로그, 보유, 등급·가격, 코인, 요청 간격, 라운드·연출 잠금). 방 소속·방장은 해당 없음
- [x] 소유·코인·장착 판정이 서버(`ShopService` + 순수 `ShopLogic`)에만 있다. 클라이언트 `cardState`는 표시용
- [x] 맵 상태 해당 없음. 매치 외형 스냅샷은 `ctx.appearances`(매치 컨텍스트)에 있음
- [x] 정리: `lastRequestAt`/`lockedUntil` PlayerRemoving에서 지움, 미리보기 RenderStepped는 창 닫으면 끊음, 옛 SushiBody는 다시 입힐 때 Destroy

## 사용자 Studio 확인 체크리스트
1. **AC6 탈의실**: Play → 왼쪽 위 코인 배지 아래 "🍣 스킨" → 16종 카드(등급 색 테두리)가 보이는지, 탭(전체/일반/레어/에픽/전설) 전환, 카드를 누르면 왼쪽 미리보기가 천천히 돌고 말풍선 대사가 나오는지. Test → Device에서 휴대폰 가로를 골라 카드 2열·미리보기 위쪽·잘림 없음 확인. 스킨 모양 스크린샷을 남겨 주면 색·토핑 수정에 씀.
2. **AC7 코인 해금**: 서버 Command Bar `local D=require(game.ServerScriptService.Server.DataService) for _,p in game.Players:GetPlayers() do D.update(p,function(x) x.coins+=600 end) end` → "연어" 카드 "🍚 500으로 해금" → 코인 100, 바로 연어초밥. 다시 "참치"를 누르면 "🍚 400개 더 필요해요"로 비활성. 저장 확인은 `Config.DEBUG.persistDataInStudio = true`(API 접근 허용) 뒤 Stop → Play로 연어 유지(확인 후 설정 되돌리기).
3. **AC8 한 판**: 연어를 입고 `forceMapPlan`으로 한 판(커밋 전 nil로) → 매치 캐릭터, 탈락 연출 인형(다른 사람 탈락 포함), 우승 연출 인형, 로비 단상 인형이 모두 연어. 탈락 말풍선에 "연어는 언제나 옳아!"/"기름기가 살살 녹네~"가 나올 수 있음(무작위라 몇 번).
4. **AC9 잠금**: 라운드 달리는 중 "🍣 스킨" 버튼이 숨는지. 클라이언트 Command Bar `print(game.ReplicatedStorage.Remotes.EquipSkin:InvokeServer("tamago"))` → `false 매치가 끝나면 바꿀 수 있어요`. 탈락 후 3초 지나 관전 중, 통과해 대기석에 있을 때 버튼이 보이고 장착이 바뀌는지. (N1: 탈락 직후 3초 안이면 거절 문구가 나올 수 있음 — 알려진 P3)
5. **AC10 2명**: Test → Clients and Servers 2명. 한 명이 연어, 다른 한 명이 계란초밥 → 서로 화면에서 같은 모습. 스킨을 바꿔도 이름표 높이·키가 같고, 꼬치 쇼다운에서 맞는 높이가 같은지. 반짝이(황금 참치·다이아 성게)·불꽃(불꽃 연어)이 상대 시야를 크게 가리지 않는지 — 이 스킨은 Command Bar `D.update(p,function(x) x.ownedSkins["golden-otoro"]=true end)`로 지급 후 입기.
6. **AC11 로벅스**: 레어 이상 카드의 버튼이 "R$ 99 — 곧 열려요" 회색, 눌러도 결과 글씨·요청 없음.

## 추가한 테스트
- `tests/m4-13-qa.spec.luau` (22개): ShopService를 가짜 Roblox 환경에서 실제로 돌림
  - 리모트 인자 검증(비문자열·모르는 id), 미보유 거절·장착·기본으로 되돌리기, 요청 간격 공용
  - 코인 해금 한 번만 차감·두 번째 "이미 있음", 500으로 두 개 사기 → 음수 없음, 499·레어 거절 문구, update 안 재판단, 소스 검사(차감은 update 콜백 안 ShopLogic만)
  - canPersist=false 실서버 거절 / Studio 허용, 프로필 없음, 핸들러 에러 pcall
  - 잠금: 배치된 레이서, 탈락 연출 3초, 우승 VictoryDuration+1, 퇴장은 잠금 없음
  - grantSkin(모르는 id, 프로필 없음, 잠금 중 보유만, 멱등, 저장 안 함, 임시 프로필 true), resolver(미보유·카탈로그 밖 → 기본)
  - 외형 단일 지점(AppearanceId를 쓰는 곳), 마이그레이션이 기본 스킨 보유 보장
  - 16종 실제 build: 파츠 판정 속성·효과 개수·setEffectsEnabled, 외곽 최대 비율, forProduct/validate productId 중복

## 인계 메모
- 브랜치: `m4-13-qa` (origin/main 1704d9b에서), push 완료.
- 끝난 것: 자동 검증 5개, AC1~AC5 통과, 서버 검증·원자성·잠금·외형 단일 지점·m4-14 인터페이스 검토, QA 테스트 22개 추가, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 체크리스트 1~6 (AC6~AC11), 스킨 모양 스크린샷. P3 N1·N2는 개발이 원하면 수정(머지 차단 아님), N3은 m4-14 스펙에 "ProcessReceipt는 canPersist + saveNow 성공일 때만 PurchaseGranted"로 반영 권장.
- 다음 첫 단계: 메인 세션이 `m4-13-qa`를 main에 병합 → docs-writer가 CHANGELOG·DEV-SETUP 반영.
- 막힌 점: 없음. Studio가 없어 화면·모양·효과 체감은 확인 못 함.
