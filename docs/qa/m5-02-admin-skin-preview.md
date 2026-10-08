# QA — m5-02 테스트용 관리자: 스킨 무료 착용(미리보기)

- 스펙: `docs/specs/m5-02-admin-skin-preview.md`
- 검증 커밋: `ec40090` (브랜치 `m5-02-admin`, `origin/main`과 병합할 것 없음 — 이미 최신)
- QA 브랜치: `m5-02-qa`
- 결과: **통과** (P0/P1 없음, P3 3건) → 스펙 `qa-passed`

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings / 0 parse errors |
| `lune run tests` | 1066 passed, 0 failed (개발 1045 + QA 21) |
| `luau-lsp analyze ... src` (타입 검사) | 에러 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `admin-logic.spec` AC1 4개 + `m5-02-qa.spec` "Studio + studioAllAdmins false still honours the list even if liveEnabled false" |
| AC2 | 통과 | `admin-logic.spec` AC2 2개 + QA "group id equal to a user id never makes that user owner-admin", "unpublished place (creatorId 0)", "listed user on a group-owned game is still admin" |
| AC3 | 통과 | `admin-logic.spec` AC3 3개 + QA "booleans, whitespace and case variants are rejected" |
| AC4 | 통과 | `admin-logic.spec` AC4 |
| AC5 | 통과 | 위 5단계 직접 실행 |
| AC6 | 사용자 확인 필요 | 코드상 미리보기는 `previewOf`(서버 메모리)만 바꾸고 프로필 쓰기 0회 (QA "coin unlock of the previewed skin…", 개발 "listed admin … without touching the profile") |
| AC7 | 사용자 확인 필요 | 코드상 `onEquip` 성공 → `clearPreview` (`ShopService.luau` onEquip), 실패한 장착은 미리보기 유지 (QA 테스트) |
| AC8 | 사용자 확인 필요 | 탈락 인형·우승 연출·단상이 모두 캐릭터 `AppearanceId` 속성을 읽음(`EliminationCutsceneController:297`, `VictoryCutsceneController:50`, `MatchService:108·127`) → 미리보기가 그대로 보일 것 |
| AC9 | 사용자 확인 필요 | 코드상 `ShopService.isLocked` 재사용 (개발 테스트 "locked are rejected") |
| AC10 | 사용자 확인 필요 | 코드상 `AdminController.start`가 `IsAdmin ~= true`면 아무것도 만들지 않음, 서버 거절 + warn 1회 (QA "non-admin 200 requests → 1 warn") |
| AC11 | 사용자 확인 필요 | 코드상 `AdminService`·미리보기 경로에 DataService·PurchaseLog·Receipt 호출 없음 (QA/개발 소스 검사) |
| AC12 | 사용자 확인 필요 (실서버) | |
| AC13 | 사용자 확인 필요 (실서버, C2 뒤) | MemoryStore 쓰기·복원·비관리자 미복원은 가짜 환경으로 확인 |

자동 확인 5/5 통과, Studio·실서버 8개는 사용자 확인 필요.

## 보안 점검 (요청 항목)
- [x] **AdminConfig 복제 안 됨**: `default.project.json`에서 `src/server` → `ServerScriptService.Server`. `src/client`·`src/shared` 코드 어디에도 `AdminConfig`·`11402290839` 없음 (QA "src/server maps to ServerScriptService…"). `Shared.AdminLogic`은 순수 함수뿐이라 목록이 없음.
- [x] **권한 입력**: `computeAdmin`(`AdminService.luau:52`)은 `player.UserId`, `RunService:IsStudio()`, `game.CreatorType/CreatorId`, `AdminConfig`만 씀. 서버 코드 어디에서도 `IsAdmin`/`AdminPreview` 속성을 읽지 않음, `DisplayName` 미사용, `Name`은 로그에만 (QA 소스 검사). 클라이언트가 스스로 단 `IsAdmin`은 무시됨 (개발 테스트). 리모트는 매번 `admins[UserId]` 표 확인.
- [x] **소유자 규칙**: `creatorType == "User"`일 때만 `creatorId == userId` 비교. 그룹 게임은 그룹 id와 같은 숫자의 유저도 소유자 관리자 아님. 미퍼블리시(creatorId 0)는 `userId > 0` 검사로 막힘.
- [x] **리모트 스팸**: 비관리자는 첫 줄에서 표 조회 후 바로 거절, warn 플레이어당 1회, MemoryStore 읽기/쓰기 0, 다시 입히기 0, 프로필 쓰기 0 (QA 200회 테스트). 인자는 nil/""/문자열만, 카탈로그 확인, 그 밖 타입 거절. 처리 중 에러는 `pcall`로 감싸 일반 문구.
- [x] **MemoryStore `AdminPreview_v1`**: 쓰기는 `saveEntry`가 `admins[UserId]`일 때만, 키는 자기 `u_<UserId>`만. 읽기는 그 서버에서 관리자로 판단된 사람만, 자기 키만. 비관리자가 키를 심어도 읽지 않음, 다른 사람 키는 영향 없음 (QA 테스트 2개). 실패하면 warn만 (QA "MemoryStore failure only warns").
- [x] **공개 출시 차단**: `LiveEnabled = false` → 실서버에서 목록·소유자 모두 false (개발 테스트 + 순수 테스트). Studio에는 영향 없음.

## 경제 오염 점검
- [x] 미리보기 슬롯은 `ShopService`의 `previewOf`(메모리)와 Player 속성 `AdminPreview`뿐. `assignPreview`/`clearPreview`/`setPreview`/`getPreview`/`setPreviewListener` 본문에 DataService 없음 (QA 소스 검사).
- [x] 코인 해금: 미리보기 중인 스킨을 코인으로 사도 정상 차감·보유 추가, 미리보기 꺼짐 (QA). 미리보기는 보유가 아니라 `EquipSkin`으로 입을 수 없음 (QA).
- [x] 로벅스: `RobuxShopService`의 미보유 판단·`grantSkin`은 프로필 기준이라 영향 없음. 잠금 중 지급(wear false)은 보유만 늘고 미리보기 유지 — 스펙대로("실제 장착됐을 때만 끔") (QA).
- [x] 우승 단상·탈락/우승 인형은 `AppearanceId` 속성(외형 단일 지점 `AppearanceService.applyAppearance`가 씀)을 읽어 미리보기가 그대로 반영. 잠금 중에는 다시 입히지 않음.
- [x] 외형 단일 지점 유지: 미리보기는 리졸버(`equippedOf` → `AdminLogic.pickAppearance`)만 바꾸고 입히는 곳은 여전히 `AppearanceService`.

## 기존 테스트 기대 변경 타당성
- `camera-priority` 속성 11→13: `IsAdmin`(스펙) + `AdminPreview`(개발 재량, 패널 강조용, 서버만 씀·권한 미사용 확인). 타당.
- `m4-foundation` 리모트 20→21: `AdminPreviewSkin` 1개. 타당.
- `m4-14-qa` 가짜 환경: ShopService가 새로 require하는 `Shared.AdminLogic`·`Attributes`를 넣은 것뿐, 기대값 변경 없음. 타당.

## 버그
### [P3] B1 MemoryStore 복원이 읽는 동안 내린 선택을 덮어씀
- 재현: (실서버) 미리보기를 켠 채 다른 서버로 이동 → 접속 직후 `GetAsync`가 끝나기 전에 탈의실 "입기" 또는 패널 "끄기"(미리보기가 아직 없어서 상태 변화·쓰기 없음).
- 기대: 직접 고른 장착 스킨이 남음.
- 실제: 읽기가 끝나면 `restoreEntry`가 이전 미리보기를 `setPreview`로 다시 입힘. 창이 짧고(수십~수백 ms) 다시 "입기"하면 풀림. 경제 영향 없음.
- 위치: `src/server/AdminService.luau:120-136` (읽기 전후 미리보기/장착 변경 여부를 보지 않음). 제안: 읽기 시작 때 세대 번호를 잡고, 그 사이 `assignPreview`가 불렸으면 복원 건너뛰기.

### [P3] B2 `StudioAllAdmins = false`에서도 Studio 소유자는 관리자 (설정 주석과 다름)
- 재현: 퍼블리시한 플레이스를 Studio Play(혼자, 실제 UserId)로 `StudioAllAdmins = false` 실행.
- 기대(AdminConfig 주석): "false면 Studio에서도 위 목록만".
- 실제: `IncludeOwner = true`면 소유자(`game.CreatorId`)도 관리자. 사용자 본인이 목록에도 있어 결과는 같고, AC10은 Clients and Servers(음수 UserId)라 영향 없음. 문서 문구만 어긋남.
- 위치: `src/server/AdminConfig.luau:8`, `src/shared/AdminLogic.luau:65`. 제안: 주석을 "위 목록·소유자만"으로.

### [P3] B3 잠금 중 복원되면 패널 강조와 실제 외형이 잠깐 다름
- 재현: 매치 서버에서 라운드 배치 뒤에 MemoryStore 복원이 끝나는 경우(드묾).
- 실제: `AdminPreview` 속성은 바로 바뀌어 패널은 그 스킨을 강조하지만 몸은 다음 스폰까지 이전 스킨. 개발 메모에 적힌 의도된 동작이고 연출·판정 영향 없음 (QA "restore while locked").
- 위치: `src/server/ShopService.luau` `ShopService.setPreview`.

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자를 서버에서 검증한다 (타입, 카탈로그, 관리자 표, 잠금, 요청 간격)
- [x] 권한 판단이 서버에만 있다 (클라이언트 `IsAdmin`은 UI 생성 여부만)
- [x] 맵 상태 — 해당 없음
- [x] 정리: `PlayerRemoving`에서 `admins`·`warned`·`lastRequestAt`(AdminService), `previewOf`·`lastRequestAt`·`lockedUntil`(ShopService) 지움. 클라이언트 `IsAdmin` 대기 연결은 생성 뒤 끊음.

## 사용자 Studio 확인 체크리스트
1. **AC6** Studio Play(혼자) → 화면 왼쪽 세로 가운데 "🛠" 버튼이 있는지, 위쪽 바(코인·음소거)·오른쪽 아래 터치 버튼·탈의실 창과 겹치지 않는지 확인 → 눌러 패널 제목 "🛠 테스트 착용 (저장 안 됨)" 확인 → `황금 오토로` 클릭 → 내 초밥이 바로 바뀜, 서버 Output에 `[Admin] <이름>(<id>) preview golden-otoro` → "🍣 스킨" 탈의실에서 황금 오토로가 여전히 "R$ 199로 사기", 코인 숫자 그대로.
2. **AC7** 미리보기 중 탈의실에서 계란초밥 "입기" → 계란초밥으로 바뀌고 패널 초록 강조가 꺼짐 → 다시 아무 스킨 미리보기 → 패널 "끄기 (내 스킨으로)" → 프로필 장착 스킨으로 돌아옴. 미리보기 중인 미보유 스킨은 탈의실에서 여전히 "입기"가 아닌 구매 버튼인지도 확인(미리보기는 보유가 아님).
3. **AC8** Test → Clients and Servers 2명 → Player1이 `용 롤` 미리보기 → Player2 화면에서도 용 롤, 이름표·칭호 높이 정상 → 그대로 매치(필요하면 `Config.DEBUG.forceMapPlan`) → 라운드·탈락 인형·우승 연출·로비 단상에서 같은 스킨.
4. **AC9** 라운드 소개·달리는 중 패널 버튼 → "라운드 중에는 바꿀 수 없어요", 외형 그대로. 탈락 연출 중에도 같은 문구인지.
5. **AC10** `src/server/AdminConfig.luau`의 `StudioAllAdmins = false` → Clients and Servers → 각 클라이언트 PlayerGui에 `AdminPanel` 없음, "🛠" 없음 → 클라이언트 명령줄 `game.ReplicatedStorage.Remotes.AdminPreviewSkin:InvokeServer("uni")` → `false 권한이 없어요` → 같은 줄 여러 번 실행해도 서버 Output warn은 플레이어당 한 줄 → 클라이언트 명령줄 `game.Players.LocalPlayer:SetAttribute("IsAdmin", true)` 뒤 다시 Invoke해도 거절. **확인 뒤 true로 되돌리기.**
6. **AC11** (C1 퍼블리시 뒤) `Config.DEBUG.persistDataInStudio = true` → 미리보기 켜고 나갔다 다시 들어오기 → 탈의실 보유·장착·코인이 전과 같음, Creator Dashboard `PlayerData_v1`/`u_<UserId>` 그대로, `Purchases_v1` 새 기록 없음. **확인 뒤 false로.**
7. **AC12** (실서버) 본인 계정으로 접속하면 "🛠" 있음, 목록에 없는 친구 계정 화면에는 없음.
8. **AC13** (실서버, C2 뒤) 로비에서 미리보기 → 매치 서버에서도 같은 스킨 → 로비 복귀 뒤에도 유지 → 끄기(또는 1시간 뒤) 다음 접속은 내 장착 스킨.
9. 공개 출시 전 결정: 관리자 미리보기를 실서버에서 끌지(`LiveEnabled = false`).

## 추가한 테스트
- `tests/m5-02-qa.spec.luau` (21개): isAdmin 경계(그룹 소유 + 목록, 그룹 id = 유저 id, 미퍼블리시, Studio 목록 모드 + LiveEnabled false), checkPreview 이상 인자(불리언·공백·대소문자·긴 문자열), decodeEntry 변조 값, storeKey 충돌 없음, 비관리자 200회 스팸, 심은 키·남의 키, 자기 키만 쓰기, MemoryStore 실패, 코인 해금·장착 실패·잠금 중 로벅스 지급과 미리보기, 퇴장 뒤 정리, 잠금 중 복원, 소스 검사(rojo 트리·AdminConfig 비복제·속성/이름 미사용·미리보기 경로 DataService 미사용·클라이언트 IsAdmin 게이트).

## 인계 메모
- 2026-10-08 (최신)
  - 브랜치: `m5-02-qa` (`origin/m5-02-admin` ec40090 기반, origin/main 병합 필요 없음).
  - 끝난 것: 검증 5단계, 보안·경제 코드 리뷰, QA 테스트 21개, 이 리포트, 스펙 `qa-passed`.
  - 남은 것: 사용자 Studio 확인(AC6~AC11), 실서버 확인(AC12·AC13). P3 B1·B2는 개발 백로그(선택).
  - 다음에 할 첫 단계: `m5-02-qa`를 `m5-02-admin`/main에 병합 → docs-writer 반영. m5-01과 병합할 때 `m4-foundation` 리모트 개수·`camera-priority` 속성 개수 합산 확인.
  - 막힌 점: 없음. Studio가 없어 화면·외형은 확인 못 함.
