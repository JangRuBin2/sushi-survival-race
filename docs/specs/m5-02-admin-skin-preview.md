status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-02 — 테스트용 관리자 기능: 스킨 무료 착용(미리보기)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1(스킨은 겉모습만, 능력치 판매 금지), §9.5·§13(결제·저장 오염 방지), §11.2(로비/매치 플레이스 분리), §11.4(판정은 서버). GDD에는 아직 관리자 기능 절이 없어요(바뀔 절은 `docs/planner/m5-plan.md`).
- 레퍼런스: [`docs/REFERENCE-final-overtime.md`](../REFERENCE-final-overtime.md) 4절 (비밀번호 금지 이유, UserId 권한 관행, 클라이언트 불신)
- 담당 개발 worktree: `m5-admin` (Rojo 포트 34873). m5-01과 **병렬 가능**
- 공용 파일 수정 담당: **이 스펙** — `shared/Remotes.luau`, `shared/Attributes.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`. (`Config.luau`·`Types.luau`·`MapTypes.luau`는 m5-01 담당이라 건드리지 않아요)
- **이 스펙이 고치는 파일**: 새 파일 `src/server/AdminConfig.luau`, `src/shared/AdminLogic.luau`, `src/server/AdminService.luau`, `src/client/ui/AdminPanel.luau`, `src/client/ui/AdminController.luau`, `tests/admin-logic.spec.luau`; 고침 `src/server/ShopService.luau`(미리보기 슬롯), 공용 4개(위)
- 배경: 사용자 원안은 "관리자 비밀번호(자기 Roblox 비밀번호)를 입력하면 무료"였지만, 비밀번호가 저장소·클라이언트로 새어 **계정 탈취** 위험이 있고 Roblox 커뮤니티 기준도 비밀번호 공유를 금지해서 메인 세션이 거절했어요. 이 스펙은 **비밀번호·키 입력 없이** 서버가 계정(UserId)으로 판단하는 대체 설계예요.

## 목표
개발자(사용자)가 Studio 테스트나 실서버 비공개 테스트에서 16종 스킨을 **사지 않고 바로 입어 보며** 모양·연출을 확인한다. 이 기능은 관리자에게만 보이고, 입어 본 기록은 코인·보유 목록·결제 기록 어디에도 남지 않는다. 다른 플레이어에게는 그냥 그 스킨을 입은 초밥으로 보인다.

## 범위
- 포함:
  1. **관리자 판단** (서버만, 순수 함수 `AdminLogic.isAdmin`):
     ```lua
     export type AdminInput = {
         isStudio: boolean,
         userId: number,
         allowList: { number },
         includeOwner: boolean,
         creatorType: "User" | "Group",
         creatorId: number,
         studioAllAdmins: boolean,
     }
     AdminLogic.isAdmin(input: AdminInput): boolean
     ```
     - Studio(`RunService:IsStudio()`)이고 `studioAllAdmins`면 **누구나**(Clients and Servers의 음수 UserId 포함).
     - 실서버: `userId > 0`이고 (`allowList`에 있음 **또는** (`includeOwner`이고 `creatorType == "User"`이고 `userId == creatorId`)).
     - 그 밖은 전부 false. 이름(Name·DisplayName)으로는 절대 판단하지 않아요(바뀔 수 있음).
     - 서버는 접속할 때 한 번 계산해 메모리(`admins[userId]`)에 두고, 리모트마다 이 표로 다시 확인해요(클라이언트가 보낸 값·속성은 믿지 않음).
  2. **관리자 목록** — 서버 전용 모듈 `src/server/AdminConfig.luau` (ServerScriptService 아래라 클라이언트에 복제되지 않아요):
     ```lua
     -- 테스트용 관리자 (m5-02). 비밀번호·키는 절대 넣지 않아요. UserId는 프로필 주소 숫자(roblox.com/users/<숫자>/profile).
     return {
         UserIds = { 11402290839 } :: { number }, -- 사용자 본인 (2026-10-08 알려 줌)
         IncludeOwner = true, -- 게임을 개인 계정으로 퍼블리시했으면 소유자도 관리자
         StudioAllAdmins = true, -- Studio에서는 모두 관리자. false면 Studio에서도 위 목록만 (비관리자 화면 확인용)
         LiveEnabled = true, -- false면 실서버에서는 아무도 관리자가 아님 (공개 출시 때 끄고 싶으면)
     }
     ```
     `LiveEnabled = false`면 실서버에서 `isAdmin`이 항상 false(순수 함수 입력에 반영: allowList를 빈 목록·includeOwner false로 넘기거나 인자 추가 — 개발 재량, 테스트로 고정).
  3. **관리자 표시** (`Attributes.IsAdmin = "IsAdmin"`): 서버가 관리자인 `Player`에 `IsAdmin = true` 속성을 달아요(관리자가 아니면 달지 않음). 클라이언트는 이 속성으로 **UI를 만들지 말지만** 정해요. 권한 판단에는 쓰지 않아요.
  4. **리모트** (`Remotes.luau` RemoteFunction 추가):
     `AdminPreviewSkin(skinId: string?)` → `(ok: boolean, err: string?)`
     - 서버 검사 순서: 관리자 표(아니면 `false, "권한이 없어요"` + 플레이어당 한 번 warn 로그) → 요청 간격(`Config.Shop.RequestCooldown` 재사용) → `skinId`가 nil·빈 문자열이면 **미리보기 끄기**, 문자열이면 `Skins.get`으로 카탈로그 확인(없으면 `"없는 스킨이에요"`), 그 밖 타입은 거절 → `ShopService.isLocked(player)`면 `"라운드 중에는 바꿀 수 없어요"`(장착과 같은 잠금: 소개·달리는 중·탈락/우승 연출 중).
     - 성공하면 `ShopService.setPreview(player, skinId 또는 nil)` → 바로 다시 입혀요. 서버 Output에 `[Admin] <이름>(<UserId>) preview <skinId|off>` 한 줄.
     - 순수 함수로 판단: `AdminLogic.checkPreview(isAdmin, skinId: unknown, isKnownSkin: (string) -> boolean, locked: boolean): (ok, reason, normalizedSkinId?)`.
  5. **미리보기 슬롯** (`ShopService` 수정, 프로필은 건드리지 않음):
     - `ShopService.setPreview(player, skinId: string?)`, `ShopService.getPreview(player): string?` — 서버 메모리 `previewOf[userId]`에만 저장.
     - 외형 결정(지금 `equippedOf` 리졸버) = **미리보기 > 프로필 장착 스킨 > 계란초밥**. 미리보기는 보유 여부를 보지 않아요(카탈로그에 있으면 됨). 순서는 순수 함수 `AdminLogic.pickAppearance(preview: string?, equipped: string?, owned: { [string]: boolean }, isKnownSkin): string?`로.
     - **미리보기를 끄는 때**: 관리자가 끄기를 누름, 탈의실 `EquipSkin` 성공, `BuyWithCoins` 성공, `grantSkin(…, equip = true)`로 실제 장착됨(로벅스 구매) — 직접 고른 스킨이 바로 보이게. `PlayerRemoving`에서 지움.
     - `DataService.update`·`saveNow`, `ShopLogic`, `ReceiptLogic`, `PurchaseLog`, `RewardService`는 **부르지도 바꾸지도 않아요**.
  6. **서버 간 유지** (로비 ↔ 매치 서버, m4-11):
     - 실서버에서 미리보기를 켜거나 끌 때 `AdminService`가 MemoryStore HashMap `AdminPreview_v1`, 키 `u_<UserId>`에 `{ skinId = "...", at = os.time() }`(끄면 `skinId = false`)를 TTL **3600초**로 써요. `pcall`, 실패하면 warn만(게임 계속).
     - 아무 서버(로비·매치)에서든 관리자가 접속하면, **그 서버에서 관리자를 다시 판단한 뒤** 그 키를 읽어 카탈로그에 있는 스킨이면 `setPreview`. 관리자가 아니면 읽지도 않아요.
     - Studio(한 플레이스 모드)는 MemoryStore를 쓰지 않고 서버 메모리만(같은 서버라 그대로 유지).
     - TeleportData·매니페스트(`PlacePayload`)는 바꾸지 않아요.
  7. **관리자 UI** (클라이언트, **관리자에게만 생성**):
     - `AdminController.start(gui)`: `LocalPlayer:GetAttribute("IsAdmin")`이 true일 때만(늦게 달릴 수 있으니 `GetAttributeChangedSignal`로 기다림) `AdminPanel`을 만들어요. 아니면 **ScreenGui를 아예 만들지 않아요**.
     - 열기 버튼 **"🛠"**(작은 정사각형): 화면 왼쪽 가장자리 세로 가운데. 위쪽 바 줄(코인 배지·토스트·음소거)·오른쪽 아래 터치 버튼·관전 버튼·탈의실 창과 겹치지 않는 곳(개발이 m4-09 배치 확인). 매치 중 달리는 동안에도 버튼은 보이되 누른 요청은 서버가 잠금으로 거절.
     - 패널: 제목 **"🛠 테스트 착용 (저장 안 됨)"**, 스킨 16종 버튼 격자(이름 + 등급 색, 순서는 `Skins.LIST` order), 지금 미리보기 중인 스킨 강조, **"끄기 (내 스킨으로)"** 버튼, 결과 한 줄(서버 err 문자열). `UiScaleController`로 크기 맞춤, 휴대폰 compact에서 스크롤.
     - 자기 ScreenGui(`AdminPanel`)만 써요. `ShopScreen`/`ShopController`·`HudScreen`은 고치지 않아요(탈의실의 "입는 중" 표시는 프로필 장착 스킨 그대로 — 미리보기는 관리자 패널에만 표시).
- 제외:
  - 그룹 랭크 권한(`GetRankInGroup`) — 게임을 그룹으로 옮기면 그때 추가(REFERENCE 4절).
  - 코인·승수 조작, 강제 시작, 맵 고르기 같은 다른 관리자 명령 — M5 백로그.
  - 관리자 목록을 게임 안에서 바꾸기(코드에서만).
  - 비밀번호·PIN·키 입력 — **하지 않음**.

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/admin-logic.spec.luau`)
- [ ] AC1: `isAdmin` — Studio + studioAllAdmins → userId -1도 true. Studio + studioAllAdmins false → 목록에 있는 id만 true. 실서버: 목록의 11402290839 → true, 목록에 없는 123 → false, userId 0·음수 → false.
- [ ] AC2: `isAdmin` — 실서버, includeOwner true, creatorType "User", creatorId = userId → true. creatorType "Group"(creatorId가 같은 숫자여도) → false. includeOwner false → false. LiveEnabled false면 목록에 있어도 false.
- [ ] AC3: `checkPreview` — 관리자 아님 → 실패(권한). 숫자·테이블 인자 → 실패. 모르는 스킨 → 실패. nil·"" → 성공 + 끄기(normalized nil). `"dragon-roll"`(보유 안 함) → 성공. locked true → 실패(잠금), 끄기 요청도 잠금이면 실패.
- [ ] AC4: `pickAppearance` — preview "uni" + equipped "salmon"(보유) → "uni". preview nil → "salmon". preview nil + equipped "salmon" 미보유 → nil(계란초밥). preview가 카탈로그에 없는 값 → equipped로.
- [ ] AC5: 검증 5단계 통과 (rojo build, stylua, selene, lune run tests, luau-lsp 타입 검사). 못 돌린 단계는 보고에 적는다.

### Studio 확인 (사용자 확인 필요)
- [ ] AC6: Play(혼자): 왼쪽에 "🛠" 버튼이 있고, 패널에서 `golden-otoro`(안 산 전설)를 누르면 내 초밥이 바로 바뀐다. 탈의실("🍣 스킨")을 열면 그 스킨은 여전히 "R$ 199로 사기"이고, 코인 숫자는 그대로다.
- [ ] AC7: 미리보기 중 탈의실에서 보유한 스킨(계란초밥)을 "입기"하면 그 스킨으로 바뀌고 패널 강조가 꺼진다. 패널 "끄기"를 누르면 프로필 장착 스킨으로 돌아온다.
- [ ] AC8: Test → Clients and Servers 2명: Player1이 미리보기로 `dragon-roll`을 입으면 Player2 화면에서도 Player1이 용 롤로 보이고, 이름표·칭호 위치가 정상이다. 그대로 매치를 돌리면 라운드·탈락 연출·우승 연출·로비 단상(우승했을 때)에서 같은 스킨으로 보인다.
- [ ] AC9: 라운드 소개·달리는 중에 패널 버튼을 누르면 "라운드 중에는 바꿀 수 없어요"가 뜨고 외형은 그대로다.
- [ ] AC10: `AdminConfig.StudioAllAdmins = false`로 바꾸고 Clients and Servers로 열면(Studio 테스트 계정은 음수 UserId라 목록에 없음) **"🛠" 버튼과 `AdminPanel` ScreenGui가 PlayerGui에 없다**. 그 클라이언트의 명령줄에서 `game.ReplicatedStorage.Remotes.AdminPreviewSkin:InvokeServer("uni")`를 실행하면 `false, "권한이 없어요"`가 돌아오고 외형이 바뀌지 않으며 서버 Output에 warn 한 줄. **확인 뒤 true로 되돌리기.**
- [ ] AC11: `Config.DEBUG.persistDataInStudio = true`(C1 퍼블리시 후)로 미리보기를 켰다 나가고 다시 들어오면, 프로필의 `ownedSkins`·`equippedSkin`·`coins`가 미리보기 전과 같다(Creator Dashboard Data Stores의 `PlayerData_v1` / 키 `u_<UserId>` 또는 다시 접속한 탈의실 화면으로 확인). `Purchases_v1`에 새 기록이 없다. **확인 뒤 false로**.

### 실서버 확인 (사용자 작업 C1·C2 뒤)
- [ ] AC12: 퍼블리시된 게임에 본인 계정(11402290839)으로 들어가면 "🛠"가 있고, 친구(목록에 없는 계정) 화면에는 없다.
- [ ] AC13: (플레이스 분리 C2를 했으면) 로비에서 미리보기를 켠 채 매치에 들어가면 매치 서버에서도 같은 스킨이고, 매치가 끝나 로비로 돌아와도 유지된다. 1시간 뒤(또는 끄기 뒤) 새로 들어오면 내 장착 스킨이다.

## 공용 파일 변경
- `shared/Remotes.luau`: RemoteFunction `AdminPreviewSkin` 추가(머리 주석에 설명 한 줄).
- `shared/Attributes.luau`: `IsAdmin = "IsAdmin"` (Player, boolean, 서버만 닮).
- `src/server/init.server.luau`: `require(script.AdminService)`를 `ShopService` **다음**(RobuxShopService 뒤도 괜찮음)에 추가.
- `src/client/init.client.luau`: `require(script.ui.AdminController)`를 `ShopController` 다음에 추가.
- `shared/Config.luau`·`Types.luau`·`maps/*`: 바꾸지 않음 (관리자 목록은 서버 전용 `AdminConfig`, 결정 기록 D2).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 비밀번호 방식 · **거절**(메인 세션). 비밀번호를 코드·리모트에 두면 GitHub·클라이언트로 새어 계정 탈취, Roblox 커뮤니티 기준도 "비밀번호 또는 접근 토큰" 공유·남의 계정 접근 시도를 금지. 대신 서버가 UserId·Studio로 판단. 근거: REFERENCE 4절(Roblox Community Standards, Creator Docs 보안 전술, DevForum 관리자 모듈 = UserId/그룹 랭크) · 메인 세션 + planner
- 2026-10-08 · D2 관리자 목록 위치 · 메인 세션 원안은 `Config.Admin.UserIds`. **서버 전용 `src/server/AdminConfig.luau`의 `UserIds`로 바꿈** — 이유 ① `Shared.Config`는 ReplicatedStorage라 누가 관리자인지 모든 클라이언트가 읽을 수 있음(클라이언트에 줄 필요 없는 정보는 서버에만, REFERENCE 4절 "클라이언트 불신") ② `Config.luau`는 병렬 개발 중 m5-01이 고쳐서 공용 파일 충돌을 피함. 값은 같아요. **기본값으로 진행, 사용자 수정 가능**(원하면 `Config.Admin`으로 옮겨도 동작은 같음) · planner
- 2026-10-08 · D3 사용자 UserId · **11402290839** (사용자가 알려 줌, 프로필 https://www.roblox.com/ko/users/11402290839/profile). 기본 목록 `{ 11402290839 }`. USER-TODO "UserId 알려 주기"는 완료. · 사용자
- 2026-10-08 · D4 게임 소유자 자동 포함 · `IncludeOwner = true`: 개인 계정으로 퍼블리시하면 목록 없이도 소유자가 관리자(`game.CreatorType`·`game.CreatorId`는 서버 값이라 위조 불가). 그룹 소유면 해당 없음 → 목록만. **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D5 실서버에서도 켤까 · 켬(`LiveEnabled = true`), 단 목록·소유자만. 실서버 비공개 테스트에서 스킨을 확인해야 해서. 공개 출시 뒤 끄고 싶으면 false. 관리자가 남이 안 산 스킨을 입고 있는 게 보이는 건 테스트 기능이라 허용(능력치 영향 없음, GDD 9.1). **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D6 잠금 · 장착과 같은 잠금(라운드 레이서·연출 중 금지). 달리는 중 외형이 바뀌면 이동 감시·연출·이름표 높이 확인이 헷갈려서. · planner
- 2026-10-08 · D7 서버 간 유지 방법 · MemoryStore 키(1시간). 프로필에 쓰면 "저장 오염 금지"를 어기고, TeleportData는 방 전원에게 같은 값이 가고 클라이언트가 바꿀 수 있음. MemoryStore는 서버만 쓰고 읽으며, 읽는 서버가 관리자를 다시 판단해서 남이 이용할 수 없음. · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 2026-10-08 · 브랜치 `m5-02-admin` (개발 담당). 스펙 기본값 그대로 구현, 막힌 질문 없음.
- **바뀐 파일**
  - 새로: `src/server/AdminConfig.luau`(서버 전용 목록 `{ 11402290839 }`, IncludeOwner/StudioAllAdmins/LiveEnabled = true), `src/shared/AdminLogic.luau`(isAdmin·checkPreview·pickAppearance·storeKey/encodeEntry/decodeEntry·message), `src/server/AdminService.luau`, `src/client/ui/AdminPanel.luau`, `src/client/ui/AdminController.luau`, `tests/admin-logic.spec.luau`(24개).
  - 고침: `src/server/ShopService.luau`(미리보기 슬롯 `setPreview/getPreview/setPreviewListener`, 리졸버 = `AdminLogic.pickAppearance`, EquipSkin·BuyWithCoins 성공·grantSkin 실제 장착 때 미리보기 끔, PlayerRemoving에서 슬롯만 지움), 공용 4개(Remotes `AdminPreviewSkin`, Attributes `IsAdmin`·`AdminPreview`, init 스크립트 2개).
  - 기존 테스트 숫자만 맞춤: `camera-priority`(속성 11→13), `m4-foundation`(리모트 20→21), `m4-14-qa`(가짜 환경에 Shared AdminLogic·Attributes 추가).
- **개발 재량**
  - `AdminInput`에 `liveEnabled: boolean?` 칸 추가(nil = 켜짐). 실서버에서 false면 목록·소유자 모두 false, Studio는 영향 없음.
  - Player 속성 `AdminPreview`(string, 미리보기 중인 스킨, 끄면 없음)를 서버가 달아요 — 패널 강조용. 탈의실에서 입기로 꺼지거나 매치 서버에서 MemoryStore로 복원돼도 패널이 따라가요. 권한 판단에는 쓰지 않아요.
  - 패널 ScreenGui DisplayOrder 15: 탈의실 창(20)이 열리면 그 아래로 가려져요.
  - 잘못된 타입(숫자·테이블) 거절 문구는 "없는 스킨이에요", 너무 빠른 요청은 "잠시 뒤에 다시 해 주세요".
  - MemoryStore 복원은 다시 쓰지 않아요(quiet). 잠금 중(라운드 레이서·연출)에 복원되면 슬롯만 바꾸고 다음에 입힐 때(리스폰·refresh) 반영.
- **Studio 확인 방법** (AC6~AC11)
  1. Play(혼자): 화면 왼쪽 가운데 "🛠" → 패널 → 황금 오토로(golden-otoro) → 내 초밥이 바로 바뀜. 탈의실("🍣 스킨")에서 그 스킨은 여전히 "R$ 199로 사기", 코인 그대로. 서버 Output `[Admin] <이름>(<id>) preview golden-otoro`.
  2. 미리보기 중 탈의실에서 계란초밥 "입기" → 계란초밥으로 바뀌고 패널 초록 강조가 꺼짐. 다시 미리보기 → 패널 "끄기 (내 스킨으로)" → 장착 스킨으로.
  3. Test → Clients and Servers 2명: Player1이 `dragon-roll` → Player2 화면에서도 용 롤, 이름표·칭호 위치 정상. 그대로 매치 → 라운드·탈락·우승 연출·로비 단상에서 같은 스킨.
  4. 라운드 소개·달리는 중 패널 버튼 → "라운드 중에는 바꿀 수 없어요", 외형 그대로.
  5. `src/server/AdminConfig.luau`의 `StudioAllAdmins = false` → Clients and Servers: PlayerGui에 `AdminPanel` 없음. 클라이언트 명령줄 `game.ReplicatedStorage.Remotes.AdminPreviewSkin:InvokeServer("uni")` → `false 권한이 없어요`, 서버 Output warn 한 줄. **확인 뒤 true로 되돌리기**.
  6. (C1 뒤) `Config.DEBUG.persistDataInStudio = true`로 미리보기를 켰다 나가고 다시 들어와 프로필(`ownedSkins`·`equippedSkin`·`coins`)이 그대로인지, `Purchases_v1`에 새 기록이 없는지. **확인 뒤 false로**.
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 1045 passed / 0 failed, luau-lsp analyze 에러 0.
- **남은 이슈**: 실서버(AC12·AC13)는 퍼블리시 뒤 확인. m5-01과 병합할 때 `tests/m4-foundation.spec.luau` 리모트 개수(21)·`camera-priority` 속성 개수(13)가 m5-01 추가분과 겹치면 합산해야 해요.
