# 개발 환경 세팅과 테스트 방법 (macOS 기준)

새 컴퓨터에서 이 저장소로 개발을 이어갈 때 순서대로 따라 하면 돼요. Windows 메모는 맨 아래에 있어요.

## 1. 한 번만 하는 설치

### 1-1. Roblox Studio
1. https://create.roblox.com 에서 Roblox Studio를 받아 설치해요.
2. **한 번 실행해서 로그인**해요. 이때 플러그인 폴더가 만들어져요 (안 하면 1-4의 플러그인 설치가 실패해요).

### 1-2. 저장소 받기
```bash
git clone https://github.com/JangRuBin2/sushi-survival-race.git
cd sushi-survival-race
```
이미 받아 둔 저장소면 `git pull`만 해요.

### 1-3. Rokit (도구 버전 관리)
rojo, stylua, selene, lune, luau-lsp(타입 검사, M4부터) 버전은 `rokit.toml`에 고정돼 있어요. Rokit이 그 버전 그대로 설치해 줘요.
```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```
설치가 끝나면 **터미널을 새로 열고** (PATH에 `~/.rokit/bin`이 추가돼요) 저장소 폴더에서:
```bash
rokit install        # 처음이면 각 도구를 신뢰할지 물어봐요 → 모두 y
rojo --version       # Rojo 7.7.1 이 나오면 성공
luau-lsp --version   # 1.70.1 이 나오면 성공
```
M4 전에 받아 둔 저장소라면 `git pull` 뒤 `rokit install`을 한 번 더 해요(luau-lsp가 새로 들어갔어요).

### 1-4. Rojo Studio 플러그인
```bash
rojo plugin install
```
`rojo` 명령어와 같은 버전(7.7.1)의 플러그인이 Studio 플러그인 폴더에 들어가요. Studio가 켜져 있었다면 껐다 켜요.

### 1-5. 에디터 (VS Code 추천, 선택)
확장 프로그램:
- **Luau Language Server** (JohnnyMorganz) — 자동 완성, 타입 검사. 검증과 같은 결과를 보려면 설정 `luau-lsp.fflags.enableNewSolver = true`
- **StyLua** — 저장할 때 자동 정렬
- **Selene** — 린트

## 2. 코드 검증 (Studio 없이, 커밋 전에 매번)
저장소 루트에서 5단계 (PowerShell·bash 공통):
```bash
rojo build -o build.rbxl     # 1. Rojo 프로젝트 구조가 맞는지 (build.rbxl은 커밋 안 함, .gitignore에 있음)
stylua --check src tests tools   # 2. 포맷 검사. 고칠 때는: stylua src tests tools
selene src                   # 3. 린트
lune run tests               # 4. 순수 로직 테스트 (라운드 규칙·판정·순위, 방·맵·연출·입력·저장·보상·결제 로직)
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src   # 5. 타입 검사
```
- 모두 에러 없이 끝나야 해요. `lune run tests`는 `tests/*.spec.luau` 파일별 결과 뒤 마지막 줄에 `N passed, 0 failed`가 나와요 (2026-10-14 main `4229e9a` 기준 134개 파일, 1992개). 실패가 하나라도 있으면 끝 코드 1이에요(예전에 "실패가 있어도 0"이라고 적었던 건 틀린 설명). 그래도 마지막 줄의 `0 failed`를 꼭 읽어요.
- 5단계(타입 검사)는 에러가 없으면 끝 코드 0이고 `[INFO] Loading definitions…`·`[WARN] … didChangeWatchedFiles` 같은 줄만 나와요. 에러가 있으면 `파일(줄,칸): TypeError …`와 끝 코드 1. `sourcemap.json`은 커밋 안 함(.gitignore). 정의 파일·검사기 선택 이유는 `types/README.md`.
- 도구를 받을 수 없는 환경(클라우드 세션 등)에서는 돌리지 못한 단계를 "타입 검사 못 함"처럼 보고에 적어요.
- `Config.DEBUG`의 디버그 값(`forceMapPlan`, `forceMapPlans`, `persistDataInStudio`, `simulateMatchServer`, `logArenaStats`, `fakeRobuxInStudio`, `overtimeAt`, `eventNow`, `fakeVipInStudio`, `unlockAllSkinsInStudio`)을 바꾼 채로 두면 테스트가 실패해요 (3-9 "디버그 설정", 3-10). `unlockAllSkinsInStudio`만 커밋 값이 **`true`**예요. 관리자 설정 `src/server/AdminConfig.luau`의 `StudioAllAdmins`도 확인 뒤 `true`로 되돌려요. 코드 보상 확인용 `src/server/CodeList.luau`는 `.gitignore`라 커밋되지 않아요(실제 코드를 문서 예시와 다르게).

### 2-1. 맵 미리보기 렌더러 (m5-23, Studio 없이 맵 모습 보기)
맵 모듈의 `build(origin)`을 Lune에서 진짜로 돌려(`@lune/roblox` 인스턴스) 순수 Luau 소프트웨어 렌더러로 PNG를 그려요. 에이전트·개발자가 Studio 없이 구도·실루엣·빈 공중·색 비율·밀도·조명 분위기를 확인하는 도구예요.
```bash
lune run tools/render-map <mapId|all> [--view intro|overview|eye|top|mobile|all] [--size 960x540]
                         [--quality fast|high] [--out build/renders] [--studio-art] [--lobby-light]
# 예) lune run tools/render-map hot-plate
#     lune run tools/render-map all --quality fast
```
- 결과: `build/renders/<mapId>/<뷰>.png` + `stats.txt` (`build/`는 커밋 안 함). 맵 스펙이 요구하는 최종 PNG만 `docs/renders/<mapId>/`에 복사해 커밋해요.
  - `intro-01…` 맵 `IntroCamera` 경유점 그대로(라운드 소개 카메라) · `overview` 위 35°·옆 40° 전체 · `eye` 1번 스폰 캐릭터 뒤 12·위 4(Roblox 기본 카메라 근사, 스폰 1~3에 계란초밥 크기 인형) · `top` 위에서 직교(플레이 영역보다 높은 지붕은 빼요) · `mobile` eye를 480×270으로.
- 콘솔 한 줄: `decor=<n>/<예산> lights=<n>/<예산> (shadowed n/m) particles anim tris void=<뷰별 %> time`. 예산은 그 맵 `<Map>Art.BUDGET`("Extended"면 1500·24·16) 기준. `void%`는 화면 중 **수평선 아래인데 아무것도 없는 허공** 비율 — intro·eye 뷰에서 높으면 "빈 공중이 보인다"는 뜻이에요(overview·top은 떠 있는 아레나라 원래 높아요).
- 조명: 맵의 `lighting`(`MapLighting.PRESETS` 등)으로 해 방향·Ambient·안개·블룸·색 보정을 맞춰요. `--lobby-light`면 로비 조명으로 비교.
- 속도: 맵 하나 전체 뷰가 `high`(2×2 슈퍼샘플·그림자 2048)로 보통 5~35초. 같은 입력이면 같은 PNG 바이트예요.
- `--studio-art`: `assets/map-art/<id>.rbxm`이 있으면 읽어서 붙여요.
- **실제 Roblox 렌더와 다른 점(근사)**: 재질은 텍스처 대신 밝기·하이라이트·약한 무늬만, 그림자는 해 하나(점광 그림자 없음), 하늘 가림은 위에서 본 깊이 지도로 흉내, 파티클은 한 순간의 점 구름, 반투명은 삼각형 단위 정렬, 빛 번짐·안개·톤매핑·색 보정 수치는 "비슷해 보이게" 맞춘 값, 스카이박스·SurfaceGui·Decal·Texture·MeshPart 모양·Beam 곡선은 안 그려요(MeshPart·Union은 상자). Ball은 가장 짧은 변 지름, Cylinder 축은 로컬 X(Roblox와 같음). **CornerWedge 꼭대기 방향(로컬 +X·위·-Z 모서리)은 Studio에서 한 번 확인 필요**. 최종 판단은 Studio.
- 맵이 shim에 없는 Roblox API를 쓰면 그 API 이름(예: `X is not a valid member of Model`)이 찍히고 그 맵만 실패해요 → `tools/render/Shims.luau`에 가짜를 보태요.

### 2-2. 캐릭터 미리보기 렌더러 (m5-25, Studio 없이 스킨 모습 보기)
게임과 같은 `SushiBody.build(id)`(서버 캐릭터·연출 인형·탈의실이 모두 쓰는 함수)로 캐릭터를 만들어 2-1과 같은 렌더러로 그려요.
```bash
lune run tools/render-character [skinId|all] [--view lineup|turntable|face|gameplay|all]
                                [--light studio|lobby|both] [--quality fast|high] [--out build/renders/characters]
# 예) lune run tools/render-character all --quality fast     (전체 스킨 × 조명 2개)
#     lune run tools/render-character cat-sushi --view turntable --light studio
#     lune run tools/render-character --sample concept-tuna      (콘셉트 몸 스킨 묶음, m5-28)
#     lune run tools/render-character fresh-mackerel --pose all  (고등어 자세·팔딱 프레임·시트 비교, m5-32)
```
- 결과 `build/renders/characters/<studio|lobby>/`: `lineup.png`(전체 격자, 앞 3/4, 칸 아래 id) + `lineup.txt`(칸 → id·등급), `turntable/<id>.png`(앞·3/4·옆·뒤·위), `face.png`(계란초밥 얼굴), `gameplay-back/front.png`(Roblox 기본 카메라: 머리 뒤 12.5 studs·시야 70°, 이름표는 픽셀 글자 흉내), `mobile-back/front.png`(480×270), 그리고 `build/renders/characters/stats.txt`(스킨별 파츠·모양·효과·재질·색 수·외곽·삼각형, `zfight=` 같은 쪽 면이 같은 평면에서 겹치는 파츠 쌍, `floating=` 아무 데도 안 닿는 파츠).
- 조명: `studio` = 중립 회색 스튜디오, `lobby` = 로비 조명. 해가 캐릭터 앞 왼쪽 30°에서 오도록 캐릭터를 돌려 세워요.
- 기준 그림은 `docs/renders/characters/`: `before-*.png` = m5-25 전, `after-*.png` = m5-25 새 기준 몸, `concept-*.png` = 콘셉트 몸 스킨(m5-27~m5-30), `fresh-mackerel-*.png` = 고등어(m5-32, `sheet-compare`·`flop-strip`·`poses`·`closeup`). 한계는 2-1과 같아요(`Sparkles`·이름표 글꼴은 안 그려요, 뽑기 화면 같은 2D UI는 렌더러가 없어요).
- 콘셉트 몸·고등어 옵션: `--sample <concept-…>`(콘셉트 몸 묶음 — turntable·turntable-run·expressions·gameplay·mobile·compare), 콘셉트 몸 게임 스킨 id(예 `fresh-mackerel`)는 expressions(표정 6종)·poses·flop-strip·sheet-compare까지, `--pose <이름|all>`(Rest·TailLeft·TailRight·JumpArch·LandPeak·Knocked·Hurt·Splash), `--sheet <png>`(비교할 시트). 사용법은 `tools/render-character.luau` 머리 주석.

## 3. Studio에서 게임 테스트

### 3-1. 코드 동기화 연결
1. 터미널에서 저장소 루트로 가서 `rojo serve` 를 켜 둬요. (`Rojo server listening: localhost:34872` 같은 줄이 나와요)
2. Studio에서 **새 Baseplate** 플레이스를 열어요.
3. 상단 **Plugins** 탭 → **Rojo** → 열린 창에서 **Connect**.
4. 연결되면 파일을 저장할 때마다 Studio에 바로 반영돼요. 테스트용 플레이스 파일은 저장하지 않아도 돼요 (코드는 전부 저장소에 있어요).

### 3-2. 기본 구조 확인 (M0, 연결할 때마다)
Explorer 창에서:
- [ ] `ServerScriptService` → `Server` (Script)와 그 안의 `DataService`, `PlaceService`, `PlaceBackend`, `RoomService`, `RoomDirectory`, `MatchService`, `MatchEvents`, `RoundService`, `EliminationService`, `CharacterUtil`, `AppearanceService`, `GrabService`, `LobbyService`, `RewardService`, `MovementGuardService`, `ShopService`(🎫 `DrawTicket` 포함), `RobuxShopService`, `PurchaseLog`, `AdminConfig`, `AdminService`, `AdminCommands`, `OfferService`, `CodeService`, `CodeConfig`, `CodeList.example`(로컬에 `CodeList.luau`를 만들었으면 그것도)
- [ ] `ServerStorage` → `MapArt` 폴더 (비어 있어도 정상, `assets/map-art`)
- [ ] `ReplicatedStorage` → `Shared` 안의 `Config`, `Rules`, `RoundLogic`, `RoomLogic`, `SpectateLogic`, `Remotes`, `Types`, `Cleanup`, `Attributes`, `CameraPriority`, `SushiBody`, `SushiConceptSample`, `ConceptMackerel`, `SushiPose`, `PartMath`, `CharacterAnimLogic`, `Skins`, `ShopLogic`, `DrawLogic`, `DrawScreenLayout`, `TouchLayoutLogic`, `ReceiptLogic`, `ProfileSchema`, `ProfileLogic`, `RewardLogic`, `PlaceRole`, `PlacePayload`, `RoomDirectoryLogic`, `MoveExempt`, `MovementGuardLogic`, `LobbyLayout`, `UiLayout`, `IntroLayout`, `EliminationCutsceneLogic`, `IntroCameraLogic`, `VictoryCutsceneLogic`, `DiveLogic`, `GrabLogic`, `GrabInputLogic`, `SfxCues`, `SfxLibrary`, `AdminLogic`, `Seasons`, `Offers`, `OfferLogic`, `FxCatalog`, `CodeLogic`, `IceLogic`, `maps`(안에 `MapTypes`, `MapKit`, `MapKitLogic`, `MapKitShapes`, `MapFxPresets`, `MapDecorAnimLogic`, `MapDecorTags`, `MapLighting`, `MapLightingLogic`, `MapSfx`, `MapSfxLogic`, 그리고 맵 15개 — 맵마다 `Art`·`Logic`/`Layout` 모듈이 붙어요)
- [ ] `StarterPlayer` → `StarterPlayerScripts` → `Client` (안에 `CameraDirector`, `Sfx`, `ProfileStore`, `PriceCache`, `ui` 폴더: `Lobby*`, `Room*`, `Hud*`, `Spectate*`, `Coin*`, `Shop*`, `DrawScreen`, `Offer*`, `Code*`, `Admin*`, `ChatTagController`, `UiScaleController`, `SettingsButton`, `TouchLayoutEditor`, `fx` 폴더: `CharacterFxController`, `FishRig`, `DollAnimator`, `EliminationCutscene*`, `CutsceneProps`, `Intro*`, `VictoryCutscene*`, `VictoryProps`, `LobbyFxController`, `MapLightingController`, `MapDecorFxController`, `input` 폴더: `Dive*`, `Grab*`, `IceController`, `TouchLayoutController`)
- [ ] `Workspace`에 바닥판 `Baseplate`와 `LobbySpawn`. Play하면 `Workspace.Lobby`(회전초밥집 로비, m4-06)가 생겨요

**Play**(F5)를 눌러서:
- [ ] `ReplicatedStorage`에 `Remotes` 폴더가 생기고 안에 리모트 27개(RemoteFunction 16, RemoteEvent 11 — m5-31 `DrawTicket`까지)가 있어요
- [ ] **Output** 창(View → Output)에 빨간 에러가 없어요. 한 플레이스 모드라 `[PlaceService]`·`[RoomDirectory]` 줄도 없어요
- [ ] 캐릭터가 회전초밥집 로비의 스폰에 계란초밥(또는 입은 스킨) 모습으로 서 있고, 화면에 로비 UI, 왼쪽 위 "🍚 0 (저장 안 됨)" 배지와 "🍣 스킨"·"🎁 상점"·"🎟 코드" 버튼, 왼쪽 가장자리 "🛠"(Studio에서는 관리자)가 떠요 (3-4, 3-9, 3-10)
- [ ] Output에 `[CodeConfig] no src/server/CodeList.luau …` 경고 한 줄은 정상이에요(코드 목록을 로컬에 안 만들었을 때)

동기화 확인:
- [ ] `src/shared/Config.luau`에서 아무 숫자를 바꾸고 저장 → Studio의 `Shared.Config`를 열어 보면 바뀌어 있어요 (확인 후 되돌려요)

### 3-3. 여러 명 테스트 하는 법
- **혼자(Play, F5)**: Studio에서는 `Config.DEBUG.minPlayersToStart`(1명)가 적용돼서 혼자서도 방장 시작 버튼을 누를 수 있어요. 실제 서버는 4명부터예요. 다만 혼자면 라운드 없이 바로 우승으로 끝나요. 혼자 라운드를 돌리려면 `Config.DEBUG.forceMapPlan`을 써요 (3-7).
- **여러 명**: 상단 **Test** 탭 → Clients and Servers 옆 플레이어 수를 고르고(예: 4) **Start**. 서버 창 1개 + 플레이어 창(Player1~4)이 떠요. 창을 오가며 각자 버튼을 눌러요.
- 끝낼 때는 서버 창에서 **Cleanup**(Stop).
- 서버 쪽 경고/에러는 **서버 창의 Output**에 나와요. 클라이언트 에러는 각 플레이어 창의 Output에 나와요.

### 3-4. 방 시스템 확인 (M1 room-system)
이제 매치(MatchService)가 연결돼 있어서, **방을 시작하면 실제로 매치가 진행돼요** (3-5 참고). 아래 체크리스트는 그 전 단계인 로비·방 대기실 화면만 확인해요.

**로비 화면 (혼자, F5)**
- [ ] 로비에 **빠른 참가**, **방 만들기**, 방 코드 입력칸 + **코드로 참가**, **공개 방** 목록이 보여요
- [ ] 방이 없을 때 목록에 "열린 방이 없어요. 방을 만들거나 빠른 참가를 눌러 보세요!"가 나와요
- [ ] 코드 입력칸을 비우거나 숫자 4자리가 아닌 걸 넣고 **코드로 참가** → 빨간 안내 메시지
- [ ] 없는 코드(예: `0000`)로 참가 → "그 코드의 방이 없어요"

**방 만들기 (혼자)**
- [ ] **방 만들기** → 창에서 최대 인원(4/8/12/16/24명), 공개/비공개(코드), 방 이름을 고를 수 있고, 기본 이름이 "(내 이름)의 초밥집"이에요
- [ ] **만들기** → 방 대기실로 바뀌고, 방 이름 · "공개 방 · 1/12명", 멤버 목록에 "👑 (내 이름) (나)"가 보여요
- [ ] 비공개로 만들면 "방 코드: 1234"처럼 숫자 4자리가 보여요
- [ ] 방장 안내 문구가 "준비되면 시작을 눌러 주세요"예요 (Studio라 1명부터)
- [ ] **시작!** → 화면이 매치 HUD로 바뀌고 "매치 시작!" 배너가 떠요 (매치가 끝나면 대기실로 돌아와요, 자세한 건 3-5)
- [ ] **나가기** → 로비로 돌아오고, 공개 방 목록에서 내 방이 사라져요 (마지막 사람이 나가면 방이 닫혀요)
- [ ] **빠른 참가** (열린 방이 없을 때) → "(내 이름)의 초밥집", 12명 공개 방이 자동으로 만들어져요
- [ ] 방 이름에 아주 긴 이름을 넣으면 24글자로 잘려요. Studio에서 텍스트 필터가 실패하면 기본 이름이 쓰이고 서버 Output에 `room name filter failed` 경고가 떠요 (Studio에서는 정상일 수 있어요)

**여러 명 (Test → 플레이어 4명)**
- [ ] Player1이 공개 방(최대 8명)을 만들면 Player2~4의 로비 목록에 바로 "1/8명 · 참가"로 떠요
- [ ] Player2가 목록에서 **참가** → 두 사람 화면의 멤버 목록과 인원 수가 같이 갱신돼요. Player2 화면은 "방장이 시작하기를 기다리는 중…"
- [ ] Player2 화면에는 **시작!**을 눌러도 "방장만 시작할 수 있어요"가 떠요
- [ ] Player3이 **빠른 참가** → 새 방을 만들지 않고 Player1의 방으로 들어가요
- [ ] **방장 승계**: Player1(방장)이 **나가기** → 가장 먼저 들어온 Player2에게 👑가 넘어가고 시작 버튼을 쓸 수 있어요
- [ ] **비공개 방**: Player4가 비공개 방을 만들면 다른 사람 로비 목록에는 안 보여요. 화면의 코드를 다른 창에서 입력해 **코드로 참가**하면 들어가져요
- [ ] **자동 시작**: 최대 4명 방을 만들고 4명이 모두 들어가면 "정원이 다 찼어요! 10초 뒤 자동 시작" 카운트다운이 돌고, 10초 뒤 시작돼요 (매치가 끝나면 대기실로 복귀)
- [ ] 카운트다운 중에 한 명이 **나가기** → 카운트다운이 취소돼요
- [ ] 매치가 도는 동안 그 방은 로비 목록에 "게임 중"으로 보이고 참가가 안 돼요
- [ ] 버튼을 아주 빠르게 연타하면 "너무 빨라요. 잠시 뒤 다시 눌러 주세요"가 뜰 수 있어요 (요청 간격 0.3초 제한, 정상)

### 3-5. 매치 플로우 확인 (M1 → M2 동작 기준)
방이 출발하면 `MatchService`가 `RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting` 순서로 진행하고, 화면은 로비/방 대기실 대신 매치 HUD(위: 라운드 번호·맵 이름·규칙, 오른쪽 위: 남은 시간, 왼쪽 위: 진행 숫자, 가운데: 라운드 소개·결과·우승 배너와 순위표, 아래: 내 통과/탈락/우승 안내)로 바뀌어요.

> **동작 요약 (M2 기준)**
> - **맵 풀 4개**: Race `rotating-belt`(회전 벨트)·`soy-swamp`(간장 늪 & 와사비 산), Survival `hot-plate`(뜨거운 철판), Final `skewer-showdown`(회전 꼬치 쇼다운). 3라운드는 Race → (Race 또는 Survival) → 회전 꼬치 쇼다운, 4라운드는 Race → (남은 Race와 Survival을 한 번씩, 순서는 랜덤) → 회전 꼬치 쇼다운이에요. 한 판에 같은 맵은 안 나와요.
> - **소개 = 출발 대기**: 라운드 소개(3초)가 뜨는 순간 이미 새 맵 스폰에 서 있고 걷기·점프가 0이에요. 소개가 끝나 `RoundActive`가 되는 순간 모두 같이 풀려요. 이때부터 **리셋하거나 죽으면 탈락**이에요(결과 화면 동안의 리셋은 괜찮아요).
> - **라운드 종료**
>   - Race: 목표 인원이 결승선을 넘는 순간 끝나고, 못 넘은 사람은 탈락해요. 시간 종료(90초)면 더 멀리 간 순서로 빈 자리를 채워요.
>   - Survival: 남은 인원이 목표 이하가 되거나 60초가 지나면 끝나고, **버틴 사람은 목표보다 많아도 전원 통과**예요.
>   - 결승(마지막 라운드, 회전 꼬치 쇼다운): **1명이 남는 순간 우승**이에요. 같은 순간에 남은 사람이 다 떨어지거나 90초가 지나면 더 높이 있던 사람이 우승해요.
> - **결승 진출 2명 보장**: 결승 전 라운드에서 떨어져서 살아남을 사람이 2명 아래로 줄면, 그 순간 떨어진 사람 중 더 멀리(Race)·더 높이(Survival) 있던 사람부터 탈락 대신 "✅ 통과"예요. 리셋·퇴장은 구제하지 않아요.
> - **혼자 남으면 부전승**: 결승 전 라운드에서 다른 사람이 모두 리셋·퇴장해 1명만 남으면, 결과 화면 없이 바로 "🏆 우승했어요!"와 우승 배너가 떠요.
> - **결승 건너뛰기**: 결승 전 라운드를 시작할 때 남은 사람이 2명 이하면(소개 중 이탈 포함) 바로 결승으로 가요.
> - **위치**: Race 통과자는 바로 로비 스폰(대기석)으로 옮겨져요. 라운드가 끝나면 남은 통과자·우승자도 로비 스폰으로 가고, 다음 소개 때 새 맵으로 옮겨져요. 탈락자는 3초 멈췄다가 로비 스폰으로 가요. 이때 걷기·점프 값도 돌아와요.
> - **관전**: 탈락하면 3초 뒤 자동 관전 + [로비로](관전만 끔, 방은 유지) → [👀 관전하기]로 다시 관전할 수 있어요. Race 통과자는 대기석에서 바로 관전하고 [내 캐릭터 보기]로 꺼요. Q/E(또는 화면 ◀ ▶)로 대상을 바꿔요(←/→는 M4에서 뺐어요). 우승 때는 모두의 카메라가 우승자를 비추고 순위표(1등~꼴등)가 떠요.
> - **HUD 진행 숫자**: Race는 "통과 n/목표 · 남은 인원 n", Survival·결승은 "남은 인원 n".
> - 시간(초)은 `Config`에 있어요: 매치 시작 3 · 라운드 소개 3 · 결과 5 · 우승 10(M3: 우승 연출 6 + 순위표 4) · 탈락 연출 3, 라운드 제한 Race 90 / Survival 60 / Final 90.
> - **M4에서 바뀐 것**: 맵 풀이 6개(Race에 `ramen-rapids` 라멘 국물 급류, Survival에 `chef-board` 셰프의 도마 추가)이고 결승은 그대로 회전 꼬치 쇼다운. 관전 대상은 **Q/E와 화면 ◀ ▶로만** 바꿔요(←/→ 삭제). 결승에서 같은 순간 낙하와 리셋이 섞이면 리셋한 사람이 더 나쁜 등수예요. 라운드 통과·결승 출발·우승 때 코인 알림이 뜨고, 우승 순위표 아래에 이번 판 코인 합계가 나와요. M4 확인은 3-9.
> - **M3에서 바뀐 것**: 우승 때 우승 연출(6초)이 먼저 나오고 그 뒤에 "🏆 우승!" 배너·순위표가 떠요. 낙하·리셋·시간 종료 탈락은 "🥢 탈락했어요…" 글씨 대신 탈락 연출의 "먹혔다!" 도장과 등수가 떠요. 결승에서 마지막 한 명이 떨어지면 3초 뒤에 우승이 발표돼요. 아래 체크리스트의 글씨·시간은 M3 기준으로 고쳐 두었어요. M3 기능 확인은 3-8.

**혼자 (Play, F5)** — 라운드는 안 돌아요
- [ ] 방을 만들고 **시작!** → "매치 시작!" 배너가 3초 뜬 뒤, **라운드 없이 바로** 우승 연출(6초)이 나오고 "🏆 우승!" 배너에 내 이름이 떠요 (살아 있는 사람이 1명이라 바로 부전승이에요)
- [ ] 우승 단계 10초 뒤 방 대기실로 돌아오고, 같은 방에서 **시작!**을 다시 누를 수 있어요
- 혼자서 라운드를 끝까지 돌려 보려면 3-7의 `forceMapPlan`을 써요. 맵 하나만 빨리 보려면 3-6의 Command bar 방법을 써요.

**두 명 (Test → Clients and Servers, 2명)** — 결승만 가장 빨리 보는 방법
- [ ] 방장이 **시작!** → "매치 시작!" 뒤 **"라운드 1 / 3" 없이 바로 "라운드 3 / 3 · 회전 꼬치 쇼다운"** 소개가 떠요 (시작부터 2명이라 결승으로 건너뛰어요, 정상). 소개 동안 이미 무대 위에 서 있고 움직일 수 없어요
- [ ] 왼쪽 위 "남은 인원 2", 오른쪽 위 남은 시간(90초부터)
- [ ] 먼저 떨어진 사람은 셰프 손 연출과 "먹혔다!" 도장 + "2등", 남은 사람은 3초 뒤 "🏆 우승했어요!"를 받아요
- [ ] 우승 연출 뒤 "🏆 우승!" 배너와 순위표(1·2등)가 두 화면 모두 같고, 두 카메라가 우승자를 비춰요. 우승자는 로비 스폰에 살아 있어요. 우승 단계 10초 뒤 방 대기실로 돌아와요

**네 명 (Test → Clients and Servers, 4명)** — M1부터 이어진 기본 흐름
- [ ] 정원 4명 방에 4명이 다 들어가면 10초 뒤 자동 시작돼요 (또는 방장이 **시작!**). 4명 모두 같은 소개·결과·우승 배너를 동시에 봐요
- [ ] "라운드 1 / 3"(회전 벨트 또는 간장 늪) 뒤 왼쪽 위가 "통과 0/2 · 남은 인원 4"예요 (4명 × 60% = 2.4 → 2명 통과)
- [ ] 결승선을 넘으면 "✅ n번째로 통과했어요!"와 함께 로비 스폰(대기석)으로 옮겨지고 관전 화면이 떠요. **2명이 통과하는 순간 라운드가 끝나고** 나머지 2명은 탈락해요. 결승선에 더 가까이 갔던 사람이 3등, 덜 간 사람이 4등이에요
- [ ] 남은 인원이 2명이라 2라운드를 건너뛰고 "라운드 3 / 3 · 회전 꼬치 쇼다운"으로 가요
- [ ] **시간 종료**: 아무도 결승선을 넘지 않고 90초가 지나면 가장 멀리 간 2명이 통과해요
- [ ] **젓가락 잡힘 복구**: 젓가락에 잡힌 채 라운드가 끝나 탈락한 사람도 로비로 돌아간 뒤 걷기·점프가 정상이에요
- [ ] 매치 중 한 명이 **Stop**으로 접속을 끊어도 서버 Output에 에러가 없고 남은 인원 표시가 줄어요. 방장이 끊어도 매치는 이어지고, 끝난 뒤 대기실에서 다음 사람이 👑예요
- [ ] 매치가 끝나면 전원 방 대기실로 돌아오고([로비로]를 누른 사람 포함), 인원수가 줄어든 멤버 목록이 보여요

**다섯 명 (Test → Clients and Servers, 5명)** — 소개 중 이탈
- [ ] 5명으로 시작하면 1라운드 목표가 3명이에요 ("통과 0/3"). 3명이 통과하면 "라운드 2 / 3" 소개가 떠요
- [ ] "라운드 2 / 3" 소개(3초) 사이에 한 명이 **Stop**으로 접속을 끊으면, 2라운드를 하지 않고 "라운드 3 / 3"(결승) 소개가 이어서 떠요

> 정원이 찬 방은 매치가 끝나고 대기실로 돌아오면 자동 시작 카운트다운이 다시 걸려요. GDD v0.3에서 "매치 뒤 자동 시작 유지"로 확정된 동작이에요.

### 3-6. 회전 벨트 맵 단독 확인 (M1 race-belt)
위 3-5로 실제 매치 흐름 안에서 확인할 수 있지만, 맵 자체의 구조나 장애물 동작만 따로 빨리 보고 싶을 때는 **Command bar**(View → Command Bar)에서 맵 모듈을 직접 불러 Workspace에 지어 보고 확인해요.

**구조 확인 (혼자, F5 없이도 가능 — Edit 모드에서)**
1. Command bar에 아래를 입력해서 맵을 지어요.
   ```lua
   local Shared = game:GetService("ReplicatedStorage").Shared
   local Maps = require(Shared.maps)
   local map = Maps.get("rotating-belt")
   local origin = CFrame.new(0, 10, 0)
   local model = map.build(origin)
   model.Parent = workspace
   ```
2. Explorer에서 생긴 `rotating-belt` Model을 확인해요.
   - [ ] `Spawns` 폴더 안에 `Spawn01`~`Spawn24` 24개가 있어요
   - [ ] `Conveyors`, `Hazards`(`ChopstickStation` 2개, 정리용 — 동작은 `Conveyor`·`Chopstick` 태그로 찾아요), `FinishLine`, `EndWall` 파츠와 장식 `Decor`, 소개 카메라 `IntroCamera` 폴더가 있어요
   - [ ] 출발 구간(나무 바닥) → 벨트(어두운 바닥 + 가로 줄무늬) → 병목(흰 간장 종지로 좁아짐) → 벨트(젓가락 2개) → 결승(체크무늬 + 노렌 문) 순서로 바닥이 이어져요 (M4 아트, 치수는 M1 그대로)
   - [ ] 벽(반투명 유리색 + 위에 은색 레일)이 양옆을 막고 있어서 코스 밖으로 안 떨어져요
3. 다 봤으면 `model:Destroy()`로 치워요.

**동작 확인 (Play, F5 — `RoundContext`를 손으로 흉내 내서 start() 호출)**
혼자서는 매치 라운드가 돌지 않으니(3-5), 방·매치 없이 맵만 띄워서 아래 스크립트로 라운드를 흉내 내요. Command bar에:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Players = game:GetService("Players")
local Cleanup = require(Shared.Cleanup)
local Maps = require(Shared.maps)
local map = Maps.get("rotating-belt")

-- 로비 바닥(높이 0)보다 충분히 높이 띄워야 코스 밖으로 떨어졌을 때 낙하 판정(origin보다 40 아래)이 돼요
local origin = CFrame.new(0, 100, 0)
local model = map.build(origin)
model.Parent = workspace

-- 실제 RoundService처럼 통과/탈락한 사람은 레이서 목록에서 빼요.
-- (빼지 않으면 결승선을 넘은 뒤 매 프레임 PASS가 찍혀요. 맵은 getRacers에 남은 사람만 판정해요)
local done = {}
local cleanup = Cleanup.new()
local ctx = {
	model = model,
	origin = origin,
	rng = Random.new(),
	targetCount = 1,
	cleanup = cleanup,
	isActive = function() return true end,
	getRacers = function()
		local list = {}
		for _, p in Players:GetPlayers() do
			if not done[p] then table.insert(list, p) end
		end
		return list
	end,
	pass = function(player) done[player] = true print("[race-belt] PASS", player.Name) end,
	eliminate = function(player) done[player] = true print("[race-belt] ELIMINATE", player.Name) end,
}
map.start(ctx)
_G.beltCtx = ctx -- 정리할 때 쓰려고 전역에 보관
_G.beltDone = done -- 다시 확인하려면 table.clear(_G.beltDone)

-- 출발선으로 순간이동
local character = Players:GetPlayers()[1].Character
character:PivotTo(model.Spawns.Spawn01.CFrame + Vector3.new(0, 3, 0))
```
맵이 공중(높이 100)에 있어서 위 스크립트 마지막 줄이 캐릭터를 `Spawn01`로 옮겨 줘요. 다시 옮기려면 마지막 두 줄만 다시 실행해요.
- [ ] 벨트(어두운 금속 바닥) 구간에 서 있으면 진행 반대 방향(결승 반대쪽)으로 서서히 밀려나요
- [ ] 걸어서 버티면(WalkSpeed로 밀리는 속도를 이길 수 있게) 전진할 수 있어요 — 완전히 못 움직이면 안 돼요
- [ ] 병목 구간에서는 간장 종지 때문에 옆으로 못 빠져나가요
- [ ] 젓가락 구간에 가까워지면 빨간 경고 바닥이 1초간 떴다가, 젓가락(갈색 막대 2개)이 내려와요
- [ ] 경고가 뜬 자리에 서 있으면 젓가락이 내려오는 순간 3초간 WalkSpeed/JumpPower가 0이 돼요(Output에는 안 뜨지만 캐릭터가 안 움직여야 해요), 3초 뒤 풀려요
- [ ] 반대쪽 레인(젓가락이 없는 쪽)으로 피하면 안 붙잡혀요
- [ ] 결승선(코스 끝 벽 4스터드 앞의 노란 네온 줄)을 지나가면 Output에 `[race-belt] PASS (내 이름)`이 한 번 떠요. 점프해서 넘어도 떠요
- [ ] 코스 끝은 벽(`EndWall`)으로 막혀 있어서 결승선을 넘은 뒤 밖으로 떨어지지 않아요
- [ ] (`table.clear(_G.beltDone)` 후 다시 Spawn01로 옮겨서) 코스 옆 벽을 넘어 바닥 아래로 떨어지면 Output에 `[race-belt] ELIMINATE (내 이름)`이 떠요
- [ ] 확인이 끝나면 `_G.beltCtx.cleanup:run()`으로 벨트/젓가락 루프를 멈추고 `_G.beltCtx.model:Destroy()`로 치워요 (안 하면 Heartbeat 연결이 계속 돌아요)

실제 라운드에서는 `RoundService`가 이 맵을 지어서 돌려요 — 3-5에서 매치 흐름 안의 동작(목표 인원 통과 시 라운드 종료, 탈락 시 로비 스폰 복귀와 자동 관전)을 확인할 수 있어요. 다른 맵(`soy-swamp`, `ramen-rapids`, `hot-plate`, `chef-board`, `skewer-showdown`)도 `Maps.get("<id>")`만 바꾸면 같은 방법으로 지어 볼 수 있어요. 다만 `hot-plate`, `chef-board`, `skewer-showdown`은 결승선이 없어서 `pass`가 불리지 않아요. 이 방법은 라운드 밖이라 이동 감시(m4-10)가 보지 않고, Command bar(Edit 모드)에서는 Studio 아트(`ServerStorage.MapArt`)가 붙지 않아요.

### 3-7. M2 확인 (한 판 MVP)
출처: `docs/qa/m2-07-full-match-integration.md`의 "한 번에 따라 하는 Studio 체크리스트". 결과(특히 실패·이상한 점)는 QA 리포트에 반영할 수 있게 메모해 두세요.

**강제 플랜 디버그 (`Config.DEBUG.forceMapPlan`)**
혼자이거나 특정 맵 순서를 보고 싶을 때 라운드 구성을 고정해요. **Studio에서만** 적용돼요.
1. `src/shared/Config.luau`의 `Config.DEBUG`에서 **로컬로만** 바꿔요 (저장하면 Rojo가 바로 반영해요):
   ```lua
   forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" } :: { string }?,
   ```
2. 맵 id 3개면 3라운드, 4개면 4라운드로 그 순서 그대로 돌아요. 종류 순서는 검사하지 않아서 Survival을 1라운드에 두는 것도 돼요. 맵 id: `rotating-belt`, `soy-swamp`, `ramen-rapids`(Race), `hot-plate`, `chef-board`(Survival), `skewer-showdown`(Final). 매치마다 다른 플랜을 쓰려면 `forceMapPlans`(3-9).
3. 강제 플랜일 때는 **결승 건너뛰기가 없고, 혼자(생존자 1명)여도 모든 라운드를 끝까지 돌아요.** 혼자 F5로 방을 만들고 **시작!**하면 돼요.
4. 목록 길이가 3·4가 아니거나 없는 id가 있으면 무시돼요. 서버 Output에 `ignoring Config.DEBUG.forceMapPlan` 경고가 뜨고 평소 랜덤 구성으로 돌아요.
5. **끝나면 반드시 `forceMapPlan = nil :: { string }?,`으로 되돌려요.** 안 되돌리면 `lune run tests`가 실패하고, 커밋하면 안 돼요.

준비: `rojo serve` → Studio 연결. **매 단계마다 서버·클라이언트 Output에 빨간 에러가 없는지 봐요.** 여러 명은 Test 탭 → 플레이어 수 → Start (Clients and Servers). 스톱워치를 하나 준비해요.

**1. 혼자 기본 확인 (1분)**
- [ ] F5 → 방 만들기 → 시작 → 라운드 없이 우승 연출 뒤 "🏆 우승!"(내 이름), 10초 뒤 대기실

**2. 5명 3라운드 (5명, 약 5분 × 2~3판)**
- [ ] 공개 방, 5명 참가, 방장 시작. 스톱워치 시작
- [ ] R1 소개 "라운드 1 / 3" + Race 맵(회전 벨트 또는 간장 늪). 소개 동안 이미 맵에 서 있고 움직일 수 없어요. 배너가 사라지면 모두 동시에 출발
- [ ] R1 왼쪽 위 "통과 0/3". 결승선을 넘은 사람은 1초 안에 로비 스폰(대기석)으로 옮겨지고 관전 화면이 떠요
- [ ] 3명이 통과하는 순간 나머지 2명 탈락 → 탈락자는 3초 뒤 자동 관전 + [로비로]. 한 명은 [로비로]를 눌러 로비를 돌아다녀요
- [ ] R2: Race면 "통과 0/2", 뜨거운 철판이면 "남은 인원 n"이 떨어질 때마다 줄어요. 철판에서 60초를 버티면 버틴 사람 전원 통과
- [ ] R3 "회전 꼬치 쇼다운": 시작 직후 꼬치가 약 2초 뒤에 다가오고, 결승선 없이 마지막 1명이 남는 순간 "🏆 우승!". 무대 조각 경계에 틈·깜빡임이 보이면 기록 (m2-04 B3)
- [ ] 순위표 1~5등이 각자 받은 "n등" 안내와 같아요. 모든 화면이 우승자를 비춰요
- [ ] 대기실로 전원 돌아와요 ([로비로]를 누른 사람 포함). 스톱워치 정지 → 한 판 길이 기록 (기준 약 3~5분)
- [ ] 같은 방으로 2~3번 반복해서 R2에 Race와 Survival이 둘 다 나오는지 봐요

**3. 4명 (약 3분)**
- [ ] R1(목표 2) 뒤 R2 소개 없이 바로 "라운드 3 / 3 · 회전 꼬치 쇼다운". 먼저 떨어진 사람 2등, 남은 1명 우승. 한 판 길이 기록

**4. 새 동작 (4명, 강제 플랜 없이)**
- [ ] **결승 진출 2명 보장**: R1 Race에서 아무도 결승선을 넘지 않고 한 명씩 코스 밖으로 떨어지면 → 처음 둘은 탈락, 마지막 둘은 "✅ 통과"를 받고 결승으로 가요
- [ ] **혼자 남음 부전승**: 새 판 R1에서 3명이 차례로 Esc → Reset → 3번째 리셋 순간 결과 화면 없이 남은 1명에게 "🏆 우승했어요!"와 우승 배너가 떠요. 순위표에서 리셋한 3명은 2~4등
- [ ] **결과 화면 중 리셋**: 라운드 결과 화면 동안 리셋한 사람이 다음 라운드 시작 때 탈락하지 않고 정상 배치돼요
- [ ] **결승 소개 중 이탈**: 결승 소개 중 상대가 Stop으로 나가면 남은 사람이 로비 스폰에서 우승 화면을 봐요. 허공에서 떨어지지 않아요
- [ ] 간장 늪이 나왔다면: 와사비 패드 맨 앞에서 키를 떼고 튀어도 산 위에 오르는지 (m2-02 W2)

**5. 4라운드 (4명)**
- [ ] 위 강제 플랜 예시(맵 4개)를 넣고 → "라운드 1 / 4"~"4 / 4"가 끝까지 돌아요 → 끝나면 `nil`로 되돌려요

**6. 연달아 3판**
- [ ] 2~3번에서 같은 방으로 3판을 돌린 뒤 Explorer의 Workspace에 `Round*` Model, 날치알 공(`Tobiko`), 꼬치, 셰프 손, 철판 타일이 남아 있지 않아요
- [ ] 전원 정상 속도로 걷고 점프할 수 있어요

**7. 두 방 동시 (4명)**
- [ ] 2명씩 두 방을 만들어 거의 동시에 시작 (Studio라 1명부터 시작 가능). 두 아레나가 x 2000 간격으로 따로 지어지고, HUD 숫자·관전 대상·순위표가 각자 방 사람만이에요

> 알려진 한계 (P3): Studio에서는 관전 순서가 역순일 수 있어요(m2-06 S2, Studio 전용). (관전 ←/→ 카메라 회전과 결승 같은 순간 낙하 + 리셋(m2-07 I1)은 M4에서 해소 — ←/→ 삭제, 리셋한 사람이 더 나쁜 등수)

### 3-8. M3 확인 (맛 내기: 캐릭터 · 연출 · 다이브/잡기 · 소리)
출처: `docs/qa/m3-09-integration-polish.md`의 "사용자 Studio 확인 체크리스트 (M3 전체)". 수치는 모두 기본값이라, 바꾸고 싶은 것도 같이 메모해 두세요 (N).

준비
- `rojo serve` → Studio 연결. **모든 단계에서 서버·클라이언트 Output에 빨간 에러가 없는지** 같이 봐요. 여러 명은 Test 탭 → 플레이어 수 → Start (Clients and Servers).
- 맵 순서를 고르고 싶을 때만 `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan`을 **로컬에서** 바꿔요 (사용법은 3-7 "강제 플랜 디버그"). 예: 4맵 한 번씩 `{ "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`, 결승만 빨리 `{ "rotating-belt", "hot-plate", "skewer-showdown" }`. 강제 플랜이면 혼자서도 모든 라운드가 돌아요.
- **확인이 끝나면 `forceMapPlan = nil :: { string }?,`으로 되돌려요.** 안 되돌리면 `lune run tests`가 실패하고, 커밋하면 안 돼요.
- 서버 Explorer와 클라이언트 Explorer를 오가야 하는 항목이 있어요. Test 탭의 **Current: Client / Server** 버튼으로 바꿔요.

**A. 계란초밥 외형 (m3-02)**
- [ ] 혼자 F5. 로비 캐릭터가 계란초밥(흰 밥·노란 계란·김 띠·눈·입·발)이고 아바타 옷·모자·얼굴이 안 보여요. 끝까지 줌인해서 1인칭이 돼도 초밥이 화면을 가리지 않아요.
- [ ] Esc → Reset 3번. 서버 Explorer `Workspace/<내 이름>` 아래 `SushiBody`가 하나, 그 안 `Body`에 `SushiJoint`가 있어요. 라운드를 옮겨 다닌 뒤에도 하나예요.
- [ ] 2명: 상대 초밥 머리 위에 **흰 이름이 하나만** 보여요(두 개 겹치면 안 돼요). 100 studs 넘게 떨어지면 사라져요.
- [ ] 걸으면 통통 튀며 기우뚱하고, 멈추면 서요. 날치알·꼬치에 맞으면 누워 떨며 "@_@"와 넘어지는 소리가 나요.
- [ ] 낙하로 탈락하는 순간에는 내 화면·남 화면 모두 "@_@"·넘어지는 소리가 **나지 않아요**.

**B. 탈락 연출 (m3-03)**
- [ ] 3명, 회전 벨트에서 A가 떨어져요 → A 화면: 젓가락 → 간장 → "냠!" + "먹혔다!" 도장 + "n등", 약 3초 뒤 관전. B·C 화면: 같은 연출이 그 자리에서 보이고, 그동안 A 캐릭터·이름표는 안 보여요.
- [ ] 라운드 중 Esc → Reset → 리셋한 자리에서 젓가락 연출.
- [ ] 철판에서 떨어지면 아래에서 벌린 입 연출.
- [ ] **시간 종료(Timeout)**: 회전 벨트에서 통과 인원이 차거나 90초가 지나 남은 사람이 탈락 → 그 사람에게도 젓가락 연출 + "먹혔다!" (예전 "🥢 탈락했어요" 글씨 대신).
- [ ] 방 나가기로 빠진 사람은 연출이 없어요.
- [ ] 클라이언트 Explorer `Workspace/EliminationCutscenes`가 연출 뒤 비어 있어요.

**C. 라운드 소개 (m3-04)**
- [ ] 혼자 4라운드(강제 플랜 4개): 소개 3초 동안 카메라가 새 맵을 훑고 내 초밥 뒤로 돌아온 뒤 "출발!" + 소리, 바로 움직일 수 있어요.
- [ ] 3명: 1라운드에서 탈락한 C는 2라운드 소개 때 관전 화면 그대로, 플라이스루·"출발!"이 없어요.
- [ ] 소개 3초 안에 Esc → Reset: 탈락 연출로 넘어가고 "출발!"·출발 소리가 **안 뜨며**, 플라이스루 카메라가 다시 잡히지 않아요.
- [ ] 방 2개(2명씩) 동시 시작: 각자 자기 방 아레나만 훑어요.

**D. 우승 연출 (m3-05)**
- [ ] 결승 우승 → 문이 열리고 초밥 인형이 부두를 달려 물에 뛰어듦 → "탈출 성공! 🏆"(다른 사람 화면은 "{이름} 탈출 성공!") + 물고기 박수(인형·물고기가 보임) → 약 6초 뒤 로비의 우승자 비추기 → "🏆 우승!" 배너·순위표 → 대기실.
- [ ] 끝난 뒤 `Workspace.CurrentCamera.FieldOfView`가 70이고, `Workspace`에 `VictoryCutscene`이 없어요.
- [ ] 연출 도중 우승자 창을 닫아도 나머지 화면에서 끝까지 재생돼요.

**E. 다이브 (m3-06)**
- [ ] Shift / E / 게임패드 X로 앞으로 엎드려 날고, 착지 뒤 0.5초 경직, 1.5초 쿨다운.
- [ ] **점프 직후 Shift를 1.5초마다 반복**해도 그냥 달리기보다 빠르지 않아요. 점프 꼭대기에서 다이브하면 그냥 점프보다 멀리 가요.
- [ ] 다이브 도중 맵 밖으로 떨어져 탈락 → 엎드린 자세가 아니라 탈락 연출 인형이 보이고, 연출 뒤 로비 캐릭터가 똑바로 서서 방향을 돌고 점프할 수 있어요.
- [ ] 젓가락에 들린 동안·넘어진 동안·소개 중·관전 중에는 다이브가 안 돼요.
- [ ] (메모) 발판 끝·벨트 틈에서 공중 다이브로 코스를 건너뛸 수 있는지, 와사비 패드 + 다이브가 너무 멀리 가는지 (m3-06 B2·B3).

**F. 잡기 (m3-07)**
- [ ] 2명, 라운드 중: A가 B 뒤에서 마우스 왼쪽 버튼을 누르고 있으면 선 + "잡혔다!", B가 약 절반 속도, 2초 뒤 풀려요.
- [ ] 잡힌 B가 젓가락에 들리거나 날치알에 맞으면 풀리고, 내려온 뒤 B 속도가 정상이에요(서버 `Humanoid.WalkSpeed` 16).
- [ ] 잡힌 B가 다이브해서 멀어지면 풀려요.
- [ ] 3명: A가 B를 잡고 있는 동안 C가 A를 잡으려 해도 안 잡혀요. A가 놓으면 C가 A를 잡을 수 있어요.
- [ ] A가 잡은 채 Shift(다이브) → 바로 풀려요. 버튼을 계속 누르고 있어도 다시 누르기 전에는 안 잡아요.
- [ ] 로비·대기석에서는 잡히지 않아요.

**G. 사운드 (m3-08)**
- [ ] 로비 버튼을 누르면 "딸깍". 음소거 버튼은 **Roblox 위쪽 바 줄의 오른쪽 끝**(Roblox 메뉴·채팅 버튼이 있는 줄)에 있어요: 🔊 소리 켬 → 🎵 음악 끔 → 🔇 모두 끔(딸깍·장애물 소리도 안 남) → 다시 🔊.
- [ ] 결승선 통과 "뿅". 한 판 뒤 클라이언트 Explorer `SoundService`에 다 울린 Sound가 쌓여 있지 않아요(`Sfx`·`Music` SoundGroup과 지금 곡만).
- [ ] 휴대폰 에뮬레이터에서 점프·다이브·잡기 버튼은 "딸깍"이 **안 나요**(메뉴 버튼은 나요).

**H. 장애물 소리 (m3-09)**
- [ ] 간장 늪: 간장 웅덩이에 들어갈 때 "출렁"(낮은 수영 소리), 와사비 패드에 튕길 때 "뾰잉"(높은 점프 소리).
- [ ] 철판: 타일이 사라질 때 낮은 발소리.
- [ ] 꼬치 쇼다운: 10·20·30·40·50·60초마다 "휙".
- [ ] 회전 벨트 젓가락 경고·철판 달아오름·셰프 손 경고는 지금 **무음이 정상**이에요(`SfxLibrary`에 id 없음, 아래 "소리 id 넣는 법").
- [ ] 120 studs 밖 장애물 소리는 안 들리고, 다른 방 아레나 소리도 안 들려요. 🔇 모두 끔이면 장애물 소리도 안 나요.

**I. 맵 판정 회귀** — 4맵을 한 번씩(강제 플랜 4개)
- [ ] 회전 벨트 결승선 통과·젓가락 포획, 간장 늪 감속·와사비, 철판 타일(뜨거운 타일 탈락, 60초를 버티면 버틴 사람 전원 통과), 꼬치 쇼다운 낙하 탈락·우승이 M2와 같아요(3-7).

**J. 교차 시나리오 (3명)**
- [ ] 관전 중에 다음 라운드 소개가 와도 관전 화면이 그대로예요.
- [ ] 달리는 사람 기준 카메라 순서: 플라이스루 → "출발!" → 떨어짐 → 탈락 연출 카메라 → 자동 관전 → (결승 뒤) 우승 연출 → 로비 우승자 비추기 → 대기실 내 캐릭터. 카메라가 엉뚱한 곳에 멈추지 않아요.
- [ ] 관전 중 보던 사람이 떨어지면 약 2.7초 그 자리를 비춘 뒤 다음 사람으로 넘어가요(로비로 순간이동하는 모습이 안 보여요).
- [ ] 2명 결승에서 한 명이 떨어짐 → 셰프 손 연출이 3초 끝까지 보이고(진 사람 화면에 "먹혔다! 2등"), 그동안 맵이 남아 있어요. 우승자 화면에는 그 3초 뒤부터 우승 연출 직전까지 "🏆 우승했어요!"가 떠 있어요. 그 뒤 "라운드 종료" 약 5초 → 모두 우승 연출을 봐요. 두 사람이 거의 동시에 떨어져도 같아요.
- [ ] 탈락 연출·우승 연출·플라이스루 도중 "방 나가기" → 카메라가 로비의 내 캐릭터로 돌아오고, `Workspace`에 연출 소품(`EliminationCutscenes` 안, `VictoryCutscene`)이 남지 않아요.

**K. 휴대폰** — Test 탭 Device 에뮬레이터(iPhone SE 가로 등)
- [ ] 음소거 버튼이 아이콘(🔊)만(폭 900px 미만) **Roblox 위쪽 바 줄 오른쪽 끝**에 있고, Roblox 메뉴·채팅 버튼과 안 겹치며 엄지로 눌려요. 로비·방·매치 HUD·관전 화면 어디서도 우리 UI와 안 겹쳐요(게임 화면은 위쪽 바 아래에만 그려져요).
- [ ] **"출발!" 자리** (휴대폰 가로 844×390, 667×375): 라운드 시작 때 "출발!"이 위쪽 맵 이름·규칙 배너 **아래**에 뜨고, 커지는 동안에도 배너를 덮지 않아요. 화면이 낮으면 글씨가 조금 작아져요(`shared/IntroLayout.luau`).
- [ ] 점프·다이브·잡기 버튼, 관전 바, HUD가 서로 안 겹쳐요. "먹혔다!"·"탈출 성공!" 글씨가 잘리지 않아요.
- [ ] PC 창(폭 900px 이상)에서는 음소거 버튼이 글자("🔊 소리 켬")로 위쪽 바 오른쪽 끝에 있고, 창 폭을 900~980px로 줄여도 로비 패널 제목 줄과 안 겹쳐요(m3-09 B5 해소). "출발!"은 예전처럼 화면 40% 높이·큰 글씨(120)예요.

**L. 성능** — Clients and Servers 8명
- [ ] 1라운드에서 여러 명이 거의 동시에 떨어져도 클라이언트 프레임(Ctrl+F7 또는 Shift+F5 통계)이 30fps 아래로 오래 떨어지지 않아요. 7명째부터는 연출 없이 캐릭터만 사라졌다 나타나요(동시 연출 한도 6).

**M. 두 판 연속**
- [ ] 한 판을 우승까지 → 같은 방에서 바로 다시 시작해 우승까지. 두 번째 판도 같게 동작하고(소개·연출·관전·소리), Output에 빨간 에러가 없어요.

**N. 친구 테스트 (M3 완료 기준)**
- [ ] 4명 이상(친구 또는 Clients and Servers 여러 창)으로 **3판 이상**. `forceMapPlan`은 nil 그대로(실제 맵 뽑기). 판마다 시작 버튼 → 대기실 복귀까지 시간을 재요(기획: 한 판 4~5분).
- [ ] 탈락·우승 연출에 "웃기다" 반응이 나오는지 봐요.
- [ ] 판마다 아래 양식으로 한 줄씩 적어 **`docs/playtest/m3.md`의 표에 붙여요**. 그 결과로 바꾸고 싶은 수치(`Config.Dive`, `Config.Grab`, `Config.Match`, `Config.Fx`)와 연출·대사를 메인 세션에 알려 주세요. 기획 담당이 GDD v0.4·스펙에, 개발 담당이 `src/shared/Config.luau`에 반영해요.

플레이테스트 의견 양식 (판마다 한 줄)

| 날짜 | 인원 | 맵 순서 | 한 판 길이 | 재미 (1~5) | 웃긴 순간 (탈락·우승 연출, 대사) | 헷갈린 점 (규칙·화면·카메라) | 조작감 (다이브·잡기) | 바꿀 수치 | 그 밖 |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | |

적을 때 같이 보면 좋은 것 (지금 기본값)
- **다이브** (`Config.Dive`): 쿨다운 1.5초, 착지 경직 0.5초, 수평 속도 40·위로 16. 짧다/적당/길다, 그냥 달리기보다 쓸모 있는지, 공중 다이브로 코스를 건너뛰는지 (E, m3-06 B2·B3).
- **잡기** (`Config.Grab`): 거리 5, 최대 2초, 잡힌 사람 ×0.5·잡는 사람 ×0.7, 쿨다운 1.5초. 약/적당/강, 철판·결승에서도 잡기가 있는 게 좋은지 (지금은 출발한 모든 라운드에서 돼요).
- **탈락 연출** 3초 (`Config.Match.EliminationCutscene`): 웃긴지 1~5, 길거나 지루한지. 결승 마지막 탈락 뒤 우승 발표까지 3초 기다리는 게 답답한지.
- **우승 단계** 10초 (연출 6초 + 순위표 4초, `Config.Match.VictoryDuration`·`VictoryCutscene`): 짧다/적당/길다.
- **라운드 소개** 3초 (`Config.Match.IntroDuration`): 플라이스루가 어지러운지(없음/약간/심함), "출발!"이 잘 보이는지.
- **헷갈림**: 내가 통과했는지·탈락했는지, 지금 누구를 관전 중인지, 철판(Survival)과 결승 규칙 차이를 알아봤는지.

**소리 id 넣는 법**
1. Studio **Toolbox → Creator Store → Audio**(또는 create.roblox.com의 Creator Store)에서 소리를 골라 에셋 id(숫자)를 복사해요. 다른 사람이 올린 오디오는 권한 때문에 재생되지 않을 수 있으니, Studio에서 실제로 소리가 나는지 들어 보고 써요.
2. `src/shared/SfxLibrary.luau`의 `SfxLibrary.Entries`에서 그 cue의 `nil`을 `"rbxassetid://<id>"`로 바꿔요. 예: `VictoryFanfare = sfx("rbxassetid://1234567890", 0.9),`, `Lobby = music("rbxassetid://1234567890", 0.6),`
3. 저장하면 Rojo가 바로 반영해요. 지금 비어 있는 것: 배경음 `Lobby`·`Round`·`Final`·`Victory`, 효과음 `VictoryFanfare`·`SpeechPop`·`ChefHand`·`FishClap`·`GrabStart`·`ChopstickWarn`·`HotTileSizzle`·`ChefHandWarn`.
4. 이미 채워진 기본 소리(`rbxasset://sounds/...`)가 어색하면 같은 자리에서 바꿔요. 음 높이는 `sfx(id, 볼륨, pitch, 흔들림)`의 세 번째 값이에요.
5. 배경음은 로비 → 라운드 → 결승 → 우승으로 바뀔 때 0.5초 동안 서서히 넘어가요. 전체 볼륨은 `Config.Fx.SfxVolume`(0.7)·`MusicVolume`(0.3).
6. 바꾼 뒤 `lune run tests`로 확인하고 커밋해요(`tests/sfx-library.spec.luau`가 cue 목록과 맞는지 봐요).

> 알려진 한계 (P3): `docs/CHANGELOG.md` M3 "알려진 한계 · 보류" 참고.

### 3-9. M4 확인 (출시 준비: 맵 6개 · 로비 · 저장 · 코인 · 휴대폰 · 이동 감시 · 서버 분리 · 스킨 · 결제)
출처: `docs/qa/m4-01-foundation.md` ~ `docs/qa/m4-14-robux-shop.md`의 "사용자 Studio 확인 체크리스트"를 기능별로 모았어요. QA 뒤 고쳐진 버그는 빼고 "고쳐졌는지" 확인으로 바꿨고, 가격은 확정된 A안(일반 R$29·🍚300, 레어 R$59·🍚900, 에픽 R$99, 전설 R$199) 기준이에요. 결과(특히 실패·이상한 점·숫자)는 메인 세션에 알려 주거나 해당 스펙 개발 메모에 적어 주세요.

각 절 제목 옆 표시: **[바로]** = 지금 Studio에서 바로 · **[C1 먼저]** = 게임 퍼블리시 + Studio API 접근 허용 뒤 · **[C2 먼저]** = Match 플레이스 + PlaceId 입력 뒤(실서버) · **[C3 먼저]** = 개발자 상품 15개 + 상품 id 입력 뒤. C1~C3은 `docs/USER-TODO.md` C절.

**준비**
- `rojo serve` → Studio 연결. **모든 단계에서 서버·클라이언트 Output에 빨간 에러가 없는지** 같이 봐요. 여러 명은 Test 탭 → 플레이어 수 → Start (Clients and Servers), 휴대폰은 Test 탭 → Device 에뮬레이터.
- 서버 쪽 Command Bar가 필요한 항목은 Test 탭 **Current: Server**로 바꾼 뒤 써요.

**디버그 설정** (`src/shared/Config.luau`의 `Config.DEBUG`, 전부 **Studio에서만** 적용, 로컬에서만 바꾸고 **커밋 금지**)

| 설정 | 기본값(커밋 값) | 켜면 | 쓰는 절 |
|---|---|---|---|
| `minPlayersToStart` | `1` | Studio에서 혼자도 시작 (바꿀 일 없음) | 전부 |
| `forceMapPlan` | `nil :: { string }?` | 맵 id 3~4개 순서 그대로 라운드 구성, 혼자여도 끝까지 (3-7) | 맵 확인 |
| `forceMapPlans` | `nil :: { { string } }?` | 플랜 목록을 넣으면 매치마다 다음 플랜 (`forceMapPlan`이 우선) | L 연속 5판 |
| `persistDataInStudio` | `false` | Studio에서도 진짜 DataStore에 저장 (C1 필요) | G·H·M·N |
| `simulateMatchServer` | `false` | Studio를 매치 서버처럼: 대기실 없이 바로 매치, 끝나면 텔레포트 대신 로그 + 로비 스폰 | K |
| `logArenaStats` | `false` | 매치가 끝날 때마다 `[ArenaStats]` 한 줄 (Workspace 자식 수·남은 아레나·라운드 훅·메모리) | L |
| `fakeRobuxInStudio` | `false` | 상품 id 없이도 로벅스 버튼이 켜지고 결제 창 없이 가짜 영수증으로 결제 흐름을 탐. `persistDataInStudio`와 같이 켜면 가짜 결제는 꺼지고 경고만 나와요 | N |

**되돌리기**: 확인이 끝나면 위 표의 기본값으로 되돌려요(`nil`은 `nil :: { string }?`처럼 타입 표기를 그대로 둬요). 안 되돌리면 `lune run tests`가 실패해요(커밋 값을 고정하는 테스트가 있음). Studio 설정 → Network → **Incoming Replication Lag**을 바꿨다면(J) 0으로 되돌려요. Studio에서 `ServerStorage.MapArt`에 시험용 Model을 넣었다면(B) 지워요.

**A. 기반·회귀 (m4-01)** [바로]
1. `forceMapPlan = { "ramen-rapids", "chef-board", "soy-swamp", "skewer-showdown" }`로 혼자 한 판 → 4라운드까지 돌고 우승 화면 → 로비. (라멘·도마는 이제 완성 맵이에요, D·E)
2. 클라이언트 Command Bar `local v = require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get() print(v and v.coins, v and v.persistent)` → `0 false`. `nil nil`이면 그대로 알려 주세요(Command Bar가 모듈 캐시를 따로 쓰는 경우).
3. 서버 Explorer에 `ServerStorage.MapArt` 폴더(비어 있음).
4. `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, Clients and Servers 2명: 결승에서 Player1이 무대 밖으로 떨어지면 Player2 화면의 탈락 연출이 **무대 가장자리 높이**에서 나와요(예전엔 무대 20 studs 아래). 리셋 탈락은 리셋한 자리에서.
5. Device 에뮬레이터 휴대폰 → 기기를 세로로 돌려도 화면이 가로로 유지.
6. (선택) 2명 결승에서 둘이 거의 동시에 떨어지게 → 우승 화면의 우승자가 "🏆 우승했어요!"를 받은 사람과 같아요. 한 명은 떨어지고 한 명은 리셋하면 떨어진 사람이 우승.

**B. Race 맵 아트: 회전 벨트 · 간장 늪 (m4-02)** [바로] — `forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`
1. 회전 벨트: 나무 바닥 출발·결승, 어두운 벨트 + 가로 줄무늬, 벽 위 은색 레일·나무 손잡이, 벽 밖 카운터·의자·초밥 접시·간장병·찻잔, 거대 손님 얼굴 3개, 흰 종지 + 남색 테두리 + 빨강·파랑·금색 접시 더미, 빨강/검정 젓가락 + 나무색 끝, 체크무늬 결승 + 노렌 문. 간장 늪: 나무 바닥, 반짝이는 간장, 웅덩이 흰 테두리, 연두 패드 위 작은 공, 연두 언덕, 날치알 그릇, 거대 간장병, 강판, 분홍 생강. 맵마다 스크린샷 1장 이상.
2. 줄무늬·체크무늬·웅덩이 테두리·와사비 공 위를 걸어도 걸리거나 튀지 않아요. 카메라를 한 바퀴 돌려 코스가 가려지는 곳이 없어요. 회전 벨트 결승 노렌이 머리 위로 충분히 높아요(m4-12에서 올림).
3. 회전 벨트: 벨트에서 뒤로 밀림, 빨간 경고 약 1초 → 약 3초 못 움직임 → 풀림, 젓가락 끝 나무색 조각이 젓가락과 같이 움직여요(떨어져 남지 않음). 간장 늪: 간장에서 느려지고 점프 안 됨, 와사비 튕김, 날치알에 맞으면 넘어졌다 일어남. 완주 시간이 M3와 비슷해요.
4. 라운드 소개: 회전 벨트는 출발 위 → 병목·젓가락 → 결승 노렌 → 출발선 뒤, 간장 늪은 출발 위 → 와사비·절벽 → 날치알 내리막·결승 → 출발선 뒤. 벽 속에 묻히지 않고, 간장 늪 마지막 구간에서 빨간 종이 등이 화면을 덮지 않아요(m4-12에서 비킴). 간장 늪 끝점은 출발 유리벽 뒤라 유리 너머로 보이는 게 정상.
5. **스폰 수정 확인**: Clients and Servers 4명, 2명씩 방 2개를 만들어 둘 다 회전 벨트로 시작 → 시작 직후 아무도 떨어지지 않고 끼지 않아요. 각 방의 젓가락이 자기 맵에서만 움직여요. (선택) 회전 벨트 `Spawns`의 Spawn13~24가 모두 나무 바닥 위.
6. `ServerStorage.MapArt`에 Model `rotating-belt`(파트 1개, 피벗 = 맵 origin)를 넣고 회전 벨트 시작 → 맵 `Decor/StudioArt`에 나타나고 그 파트를 지나갈 수 있어요. 확인 뒤 지우기.
7. Shift+F1/F2로 두 맵이 도는 동안 프레임 50 이상.

**C. Survival·결승 맵 아트: 철판 · 꼬치 쇼다운 (m4-03)** [바로] — B와 같은 `forceMapPlan`
1. 철판: 진회색 다이아몬드 철판 + 스테인리스 테두리·모서리 기둥 + 위 후드 + 멀리 흰 타일 벽 + 주걱 2개 + 테두리에서 김. 결승: 흰 도자기 접시(남색 테두리·금 선) + 빨간 기둥 + 앞쪽 가게 문(노렌·등롱·출구 판). 스크린샷.
2. 철판 타일을 밟고 서 있기 → 회색 → 주황 → 빨강(0.9초부터 빛남) → 1.5초에 사라짐. 주황 단계가 그림자 때문에 어둡지 않아요.
3. 철판 맨 아래층에서 떨어지면 아래 입 벌린 손님 얼굴 3개 쪽으로 떨어지는 게 보이고 이어서 탈락 연출.
4. **카메라 가림(m4-03 B2)**: 철판 맨 위층 앞쪽 가장자리에서 가운데를 보며 줌아웃 → 주방 벽(62 studs 밖으로 옮김)에 화면이 막히는지, 카메라를 높이 들면 후드 천장에 가려지는지. 결승 무대 가게 문 쪽 가장자리에서도. 가리면 거리를 메모.
5. **툇마루(m4-03 B1 수정 확인)**: 결승 무대 가게 문 쪽 가장자리에서 문 쪽으로 점프 → 꼭대기에서 다이브 → 가게 툇마루에 닿지 않아요(8 낮추고 18 studs 밖으로 옮김).
6. 2명 이상 결승: 닭·대파 조각에 몸이 닿아 보일 때만 맞아요("안 닿았는데 맞음" 없음).
7. 라운드 소개: 결승은 가게 문 → 무대 한 바퀴 → 무대 바깥 위, 철판은 손님 얼굴 → 층 옆 → 앞쪽 바깥에서 끝. 장식 속을 지나가지 않아요.
8. 우승 연출에서 초밥이 박차고 나가는 문 방향이 결승 맵의 가게 문 쪽(무대 앞 -Z)과 같아요.
9. Shift+F1/F2로 프레임을 M3와 비교. 높은 꼬치가 10초에 나타날 때 음식 장식도 같이 나타나고, 셰프 손이 조각을 집을 때 금 선·테두리도 같이 빨갛게 깜빡이고 사라져요. 철판·꼬치 무대 테두리가 턱처럼 보이지 않아요(m4-12에서 윗면을 맞춤). 철판 테두리가 "밟을 수 있는 바닥"처럼 보여 헷갈리면 알려 주세요(충돌 없음, 밟으면 떨어짐).

**D. 새 Race "라멘 국물 급류" (m4-04)** [바로] — `forceMapPlan = { "ramen-rapids", "hot-plate", "soy-swamp", "skewer-showdown" }`
1. 소개 카메라가 그릇 위를 지나 출발선 뒤로 와요. 스폰 노란 발판 24개가 전부 출발 바닥 위.
2. 급류에서 가만히 서 있으면 앞으로 흘러가고, **달려도 밀리는 느낌**이 있어요(밀기 20 studs/s). 소용돌이(진한 원) 위에서 벽 쪽으로 쏠려요. 벽(높이 3)을 넘으면 떨어져 탈락.
3. 급류 끝 넓은 착지판에 내려선 뒤, 차슈 위에 서면 같이 천천히 내려가고 수면 아래로 잠기면 빠져서 탈락. 잠기기 전에 옆 차슈·나루토로 건널 수 있어요. 미끄러지거나 차슈가 올라올 때 덜컹거리지 않아요.
4. 회전 젓가락 막대에 맞으면 바깥으로 튕겨 약 1초 넘어지고(@_@), 점프로 넘을 수 있어요.
5. 급류 옆·토핑 사이·원판 밖에서 떨어지면 1초 안에 탈락 연출. 결승선(노란 네온)을 넘으면 통과 → 대기석.
6. 급류를 **가장자리로** 내려와 끝에서 걸어 나가기·점프 → 착지판에 내려서요. 처음 하는 사람 기준 60~90초 안에 목표 인원이 차는 난이도인지(바꿀 값은 `RamenRapidsLayout`).
7. Clients and Servers 4명, 방 2개를 동시에 이 맵으로 → 각 방의 차슈·막대·나루토 장식이 자기 맵에서만 움직이고, 한 방이 끝나도 다른 방은 계속 돌아요.

**E. 새 Survival "셰프의 도마" (m4-05)** [바로] — `forceMapPlan = { "rotating-belt", "chef-board", "soy-swamp", "skewer-showdown" }`
1. 약 3초에 빨간 줄이 깜박이고 1.2초 뒤 칼이 그 줄로 내려쳐요. 줄 위면 바깥으로 튕겨 1초 넘어지고(@_@), 바로 옆 줄이면 무사. 40초 이후엔 경고가 0.8초.
2. 칼이 지나간 줄 양 끝 칸이 0.5초 흔들리다 떨어지고 칸 떨어지는 소리. 60초 동안 도마가 작아지되 가운데 3×3(24×24 studs)은 끝까지 남아요.
3. 10·20·30·40·50초에 도마가 약 8도 기울고 낮은 쪽으로 밀리다 3초 뒤 평평해져요. 경고 줄과 칼도 기울기를 따라 내려치고, 친 뒤 도마 가운데 위로 올라가요(m4-12에서 고침).
4. 도마 밖으로 떨어지면 손님 얼굴 쪽으로 떨어지며 탈락 연출. 4명 이상에서 남은 인원이 목표 이하가 되면 바로 끝나고, 60초를 버티면 남은 사람 전원 통과.
5. 4명 이상에서 60초 안에 적당히 떨어지는지 (바꿀 값은 `ChefBoardLogic` 맨 위 상수).
6. 클라이언트 8명 정도로 방 2개를 동시에 → 칼·경고 줄·칸·기울기가 자기 방 맵에서만.

**F. 로비 · 조명 · 우승자 단상 (m4-06)** [바로]
1. F5: 스폰 앞(-Z) 약 40에 타원 카운터와 도는 접시 16개, 카운터 안 셰프·도마, 뒤 벽 메뉴판 4장·남색 노렌, 반대쪽 벽 빨간 노렌과 수조, 오른쪽(+X 30) 3단 단상 위 "다음 우승자는 누구?". 조명이 따뜻해요. 스크린샷.
2. 스폰에서 W로 카운터까지, D로 단상까지 막힘 없이. 카운터 위로 뛰어 안쪽에 들어갔다 나올 수 있고, 벽 모서리·기둥 사이에 끼이지 않아요. 로비 UI가 건물에 가려지지 않아요.
3. `forceMapPlan`에 맵 3개를 넣고 혼자 한 판 이기기 → 단상 가운데에 1.5배 초밥 인형(입은 스킨, 스폰 쪽을 봄)과 "🏆 내 이름 / 탈출 초밥 / 1승"이 **세 줄 다 보여요**(m4-06 L1 수정 확인). 한 번 더 이기면 "2승". 인형은 클라이언트 Explorer `Workspace.Lobby.Podium.WinnerDoll`에만 있어요(서버에는 없는 게 정상).
4. Clients and Servers 2명: 두 창에서 금색 첫 접시 자리가 거의 같고(1초 이내), 서버 뷰 `Workspace.Lobby.Plates.Plate01` Position은 안 바뀌어요.
5. 2명 이상으로 매치 → 아레나도 따뜻한 조명, 관전 화면에서 먼 쪽이 안개로 뿌옇지 않아요.
6. 로비 프레임(Shift+F5 또는 Ctrl+F6)을 M3 로비와 비교, 휴대폰 에뮬레이터에서도.
7. (선택) 방 2개를 거의 같은 시각에 끝내면 단상에 나중에 끝난 방의 우승자만 남아요.

**G. 저장 (m4-07)** — 1은 [바로], 2~6은 [C1 먼저]
1. 기본(`persistDataInStudio = false`) Play → Output에 `[DataService]` 경고·에러 없음. 클라이언트 `print(require(game.Players.LocalPlayer.PlayerScripts.Client.ProfileStore).get().persistent)` → `false`.
2. `persistDataInStudio = true` → Play → 서버 Command Bar `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.coins = 123 end)` → 2초 → Stop → 다시 Play → `ProfileStore.get().coins` = 123, `.persistent` = true, 배지에 "(저장 안 됨)" 없음.
3. 음소거 버튼을 🔇까지 누르고 2초 → Stop → Play → 🔇로 시작하고 효과음이 안 나요.
4. coins = 456으로 바꾸고 **바로** Stop → Play → 456. Output에 `session lock lost`·`failed` 없음.
5. API 접근을 끈 채 `persistDataInStudio = true` → `DataStore unavailable in Studio, using memory only` 경고 **한 줄만**, 게임 정상, `persistent = false`.
6. 접속 직후(1초 안) Stop → 저장 오류·멈춤 없이 종료되고, 다음 Play에서 로드가 10초 기다리지 않아요(m4-07 D5 수정).
7. [C2 먼저, 실서버 2개] 같은 계정으로 서버 A에서 코인을 바꾸고 나가 바로 서버 B → 코인이 줄지 않아요. B Output에 `taking the lock` 경고가 보이면 알려 주세요(m4-07 D6).
- 끝나면 `persistDataInStudio = false`.

**H. 밥알 코인 · 칭호 (m4-08)** — 1~6 [바로], 7 [C1 먼저]
1. `forceMapPlan`에 맵 4개(예: `{ "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }`), 혼자 Play: 왼쪽 위 "🍚 0 (저장 안 됨)". 1·2·3라운드 통과마다 "+10 🍚 라운드 통과", 결승 출발 때 "+30 🍚 결승 진출", 우승 "+100 🍚 우승!", 이어서 "+50 🍚 오늘 첫 판". 우승 연출 6초 뒤 순위표 아래 "이번 판 +210 🍚 (총 210)"이 4초 동안, 순위표와 안 겹쳐요.
2. 같은 세션에서 한 판 더 → "오늘 첫 판" 없이 "+160 🍚 (총 370)".
3. 로비·매치 중·관전에서 배지가 보이고 음소거 버튼·HUD·로비 패널과 안 겹쳐요. 창 폭 800 / 1280 / 1920, 휴대폰 에뮬레이터. **작은 창(세로 720 이하)에서 우승할 때 "+100 🍚 우승!" 알림이 우승 큰 글씨와 겹치는지**(m4-08 B4).
4. Clients and Servers 2명, `forceMapPlan = nil`로 한 명이 우승 → 다른 창에서 우승자 머리 위 이름 위에 작은 금색 "탈출 초밥". 이름 줄 높이가 칭호 없는 사람과 같고, 우승자 본인 화면엔 자기 이름표가 안 보여요.
5. 한 명이 탈락할 때 탈락 연출 동안 그 사람의 이름표·칭호가 같이 사라져요.
6. 2명 판에서 1라운드를 통과(+10)한 뒤 "방 나가기" → 코인 그대로, 에러 없음. 남은 사람이 판을 끝내도 나간 사람에게 "+50 오늘 첫 판"이 **안 떠요**(m4-08 B1 수정 확인).
7. 저장 켠 상태에서 이긴 뒤 나갔다 다시 접속 → 코인·승수·칭호 유지.

**I. 휴대폰 · 작은 화면 (m4-09)** — 1~7 [바로], 8 [C1 먼저 + 실제 휴대폰]
1. **iPhone SE (667×375)**: 로비 패널이 위쪽에 붙고 위쪽 바와 안 겹침. 위쪽 바 줄 왼쪽에 코인 배지, 오른쪽에 음소거. 방 목록이 드래그로 스크롤, 버튼 높이 44px 이상(스크린샷으로 재 보기). 방 만들기: 이름 칸이 맨 위, 인원 버튼 두 줄(4+1), 맨 아래까지 스크롤해 "만들기"와 안내 줄이 안 잘림. 방 대기실 목록 스크롤. 매치 HUD 위쪽 한 줄 [인원] [라운드·맵] [시간], 내 결과는 위쪽 오른쪽, "출발!"이 위쪽 줄과 안 겹침, 코인 알림이 HUD와 심하게 안 겹침. 오른쪽 아래 점프, 왼쪽 "🤸 다이브", 위 "✊ 잡기"가 안 겹치고 각각 동작, 조이스틱과 안 겹침, 다이브 쿨다운 동안 어두워짐. 탈락 도장 글씨가 화면 안. 관전 ◀ 왼쪽 아래·▶ 오른쪽(잡기 버튼 바로 위)·"로비로"는 아래 가운데, ◀를 누를 때 조이스틱이 같이 반응하지 않음. 우승 순위표가 화면 안이고 정산 줄과 안 겹침.
2. **iPhone 14 Pro Max (932×430)**: 1의 로비·HUD·터치 버튼·관전 반복. 노치 쪽에 글씨·버튼이 가리지 않아요.
3. **iPad (1024×768)**: PC와 같은 배치(배율 약 1.07), 잘림 없음. 터치 버튼은 큰 점프 버튼 기준 85%.
4. **1366×768 PC 창**: 로비 → 한 판, 잘림·겹침 없음.
5. **1920×1080 PC**: M3와 같은 배치이고 25% 커진 정도. 코인 배지는 위쪽 바 왼쪽, 음소거는 오른쪽.
6. **관전 키**: 관전 중 ←/→로는 대상이 안 바뀌고(카메라만 기본대로), Q/E로 바뀜. 관전 중 E를 눌러도 대기석 캐릭터가 다이브하지 않아요.
7. 플레이 중 Device를 iPhone SE ↔ 1920×1080으로 바꾸면 배치가 바로 바뀌어요.
8. 실제 휴대폰(Android·iOS)으로 한 판, 불편한 점을 `docs/playtest/m4.md`에(USER-TODO D).

**J. 서버 이동 감시 (m4-10)** [바로] — 서버 Output은 서버 창에서 봐요
1. **오탐 없음**: `forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`로 한 판, `{ "ramen-rapids", "chef-board", "soy-swamp", "skewer-showdown" }`로 한 판. 다이브 연타(땅·점프 직후 공중), 벨트 위 뒤로 걷기·다이브, 젓가락에 잡히기, 간장 들락날락, 와사비 연속, 날치알 맞기, 급류·소용돌이 타며 다이브, 막대·꼬치·칼에 맞기, 철판 타일 떨어질 때까지 서 있기, 셰프 손이 조각을 집을 때 근처 서 있기, 도마가 기울 때 가장자리에서 다이브. 기대: 서버 Output에 `[MovementGuard]` 없음, 갑자기 뒤로 끌려가는 일 없음.
2. **순간이동**: 회전 벨트 라운드에서 (a) 출발 구역 (b) 벨트 위 (c) **소개 중**에 각각 클라이언트 Command Bar `local f; for _, d in workspace:GetDescendants() do if d.Name == "FinishLine" and d:IsA("BasePart") then f = d end end; game.Players.LocalPlayer.Character:PivotTo(f.CFrame + Vector3.new(0, 3, 0))` → 세 경우 모두 통과 없이 원래 자리(소개 중이면 스폰)로 돌아와요.
3. **속도**: `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 120` 후 출발 구역과 벨트·급류 위에서 달리기 → 계속 뒤로 당겨지고 서버 Output에 `[MovementGuard] userId … strikes 3 in this round` 한 줄, 킥 없음. 다음 라운드에서 다시 하면 또 한 줄. 벨트 위에서 가끔 안 끌려오면 기록(m4-10 R2).
4. Clients and Servers 2~3명: 서로 잡기, 다이브로 부딪히기, 넉백으로 다른 사람 쪽으로 날아가기 → 경고·되돌림이 있으면 몇 번인지 기록(B4).
5. **복제 지연**: Studio 설정 → Network → Incoming Replication Lag 0.3초로 벨트·급류에서 다이브 연타 → 되돌림 없음. 0.6초로 한 번 더 해 보고 되돌림이 얼마나 자주 나는지 기록(m4-10 R1, USER-TODO A1 결정에 씀). **끝나면 0으로.**
6. 다이브 중 서버 Command Bar로 `HumanoidRootPart.AssemblyLinearVelocity.Magnitude`를 찍어 40을 넘는지 기록.

**K. 로비/매치 서버 분리 (m4-11)** — 1~2 [바로], 3 [C2 먼저]
1. **한 플레이스 회귀** (설정 그대로, Clients and Servers 2~4명): `Config.Places`가 비어 있고 `simulateMatchServer = false`. 방 만들기(공개/비공개), 목록 참가, 코드 참가, 빠른 참가(방 있을 때/없을 때), 나가기, 방장 시작 → 한 판 끝까지 → 같은 방 대기실로 → 단상에 우승자. 서버 Output에 `[PlaceService]`·`[RoomDirectory]` 줄이 **하나도 없고**, 방 목록에 🌐가 없어요.
2. **매치 서버 흉내** (`simulateMatchServer = true`, Clients and Servers 2~4명): 로비 건물·방 목록·대기실 없이 "매치 서버 연결 중…" → 마지막 사람이 들어오고 약 5초 뒤 바로 Starting → 라운드들 → 우승 화면 → 서버 Output `[PlaceService] (Studio) would teleport N players back to the lobby (match finished), room studio-simulated`, 캐릭터가 로비 스폰으로, 화면 "로비로 돌아가는 중…". 관전 "로비로"는 관전만 꺼요. (선택) 1명만 켜도 시작돼요. **끝나면 false.**
3. **실서버** (USER-TODO C2: Match 플레이스 + 두 플레이스 퍼블리시 + `Config.Places`, 친구 3명 이상)
   - 4명이 한 방에서 시작 → 로딩 뒤 같은 매치 서버 → 한 판 → 함께 로비로 → **같은 이름·설정·방장**의 방(비공개면 새 코드) → 단상에 우승자. F9 Server 로그 `[PlaceService] room … → match server`, `… arrived, starting match`, `… players → lobby (match finished)`.
   - 다른 로비 서버의 공개 방이 내 목록에 🌐로(최대 5초 지연) → 누르면 "방이 있는 서버로 이동하고 있어요…" → 그 방에 들어감. 비공개 코드도.
   - 매치 중 한 명이 게임 종료 → 매치 계속 → 나머지가 같은 방으로.
   - 매치 전 코인·승수 기억 → 매치에서 받고 로비로 돌아와도 그대로, 한 번 더 갔다 와도 그대로. `[DataService] … taking the lock` 경고가 보이면 기록.
   - 시작 직후 한 명이 게임을 닫음 → 나머지는 약 20초 뒤 시작. 남은 사람이 1명이면 매치 없이 같은 방으로.
   - 매치 서버 링크로 직접 들어가려 하면 로비로 돌려보내져요.
   - 4/4 정원 방이 돌아오면 10초 뒤 자동 출발해요(m4-11 R6). 이게 싫으면 알려 주세요.

**L. 출시 점검 (m4-12)** [바로]
1. **연속 5판**: `logArenaStats = true`, `forceMapPlan = nil` 그대로, `forceMapPlans`에 아래 목록. Play 한 번(서버 하나)에서 방 만들기 → 시작 → 끝까지를 5번(매치마다 다음 플랜, 6개 맵이 다 나와요).
   ```lua
   forceMapPlans = {
   	{ "rotating-belt", "hot-plate", "skewer-showdown" },
   	{ "soy-swamp", "chef-board", "skewer-showdown" },
   	{ "ramen-rapids", "hot-plate", "rotating-belt", "skewer-showdown" },
   	{ "soy-swamp", "ramen-rapids", "chef-board", "skewer-showdown" },
   	{ "rotating-belt", "soy-swamp", "skewer-showdown" },
   } :: { { string } }?,
   ```
   매치가 끝날 때마다 `[ArenaStats] room … ended: workspace children N, arena models 0, open matches 0, round hooks 0, instances …, memory M MB`. 기준: 5줄 모두 `arena models 0`·`round hooks 0`·`children` 같음, 5번째 memory − 1번째 ≤ 50, 빨간 에러 없음. 첫 판 전 Workspace 자식 수와 5줄의 숫자를 알려 주세요. **끝나면 `logArenaStats = false`, `forceMapPlans = nil`.**
2. **잡기 입력**: Clients and Servers 2명, 상대 바로 뒤에서 좌클릭을 아주 빨리 두 번 하고 두 번째를 누른 채 → 약 0.1초 뒤 잡힘. Device 휴대폰에서 잡기 버튼을 누른 채 마우스 왼쪽을 눌렀다 떼도 잡기 유지, 버튼을 떼면 놓음. 반대 순서도.
3. **다이브 지름길**: 6개 맵의 벽 끝·절벽·국물 구간에서 점프 → 다이브로 코스를 건너뛸 수 있는지(간장 늪은 와사비 위 다이브도). 찾으면 맵·대략 위치를 알려 주세요(m4-12 결정 기록에 적고 고칠지 정함).
4. **8명 부하**: Clients and Servers 8명, 24명 방 → 시작(4라운드는 `forceMapPlan` 4개) → F9 → Server Stats → Heartbeat 55 이상. 꼬치 쇼다운 결승에서 특히(m4-03 B5).

**M. 스킨 · 탈의실 (m4-13)** — 1~5 [바로], 2의 저장 확인은 [C1 먼저]
1. 왼쪽 위 코인 배지 아래 "🍣 스킨" → 16종 카드(등급 색 테두리), 탭(전체/일반/레어/에픽/전설) 전환, 카드를 누르면 미리보기가 천천히 돌고 말풍선 대사. Device 휴대폰에서 카드 2열·미리보기 위쪽·잘림 없음. 스킨 모양 스크린샷(색·토핑 수정에 씀).
2. 서버 Command Bar `local D=require(game.ServerScriptService.Server.DataService) for _,p in game.Players:GetPlayers() do D.update(p,function(x) x.coins+=400 end) end` → "연어" 카드 "🍚 300으로 해금" → 코인 100, 바로 연어초밥. "참치"는 "🍚 200개 더 필요해요"(비활성). 레어 "성게"는 "🍚 900으로 해금" 버튼(코인이 모자라면 "🍚 n개 더 필요해요")과 "R$ 59 — 곧 열려요" 버튼 두 개. [C1 먼저] `persistDataInStudio = true`로 Stop → Play 해도 연어 유지.
3. 연어를 입고 `forceMapPlan`으로 한 판 → 매치 캐릭터, 탈락 연출 인형(다른 사람 탈락 포함), 우승 연출 인형, 로비 단상 인형이 모두 연어. 탈락 말풍선에 "연어는 언제나 옳아!"/"기름기가 살살 녹네~"가 나올 수 있음(무작위).
4. 달리는 중 "🍣 스킨" 버튼이 숨어요. 클라이언트 `print(game.ReplicatedStorage.Remotes.EquipSkin:InvokeServer("tamago"))` → `false 매치가 끝나면 바꿀 수 있어요`. **탈락 연출 3초 동안은 버튼이 안 보이고**(m4-13 N1 수정), 그 뒤 관전·대기석에서 버튼이 보이고 장착이 거절 없이 바뀌어요.
5. Clients and Servers 2명: 한 명 연어, 한 명 계란초밥 → 서로 같은 모습, 이름표 높이·키·꼬치 맞는 높이가 같아요. 반짝이(황금 참치·다이아 성게)·불꽃(불꽃 연어)이 시야를 크게 가리지 않아요 — 서버 Command Bar `D.update(p,function(x) x.ownedSkins["golden-otoro"]=true end)`로 지급 후 입기.
6. 상품 id가 없을 때 에픽·전설 카드 버튼은 "R$ 99 — 곧 열려요"/"R$ 199 — 곧 열려요"(회색), 눌러도 아무 일 없어요.

**N. 로벅스 상점 (m4-14)** — 1~3·5 [바로], 4 [C1 + C3 먼저], 6 [C3 먼저 + 실서버]
1. `fakeRobuxInStudio = true`(`persistDataInStudio = false` 그대로) → "🍣 스킨" → 레어 "성게" → "R$ 59로 사기" → 결제 창 없이 성게를 입고 카드 "입는 중", 결과 줄 "🎉 성게 획득!". 서버 Output `[Shop] receipt studio-… skin uni -> PurchaseGranted (GrantAndRecord: granted)` 한 줄. 에픽 "무지개 롤"은 "R$ 99" 버튼 하나로 같은 결과. false로 돌리면 다시 "곧 열려요"(회색).
2. (fake = true, Play 중) 서버 Command Bar `print(game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("<내 이름>", "eel", "studio-test-1"))`를 두 번 → 둘 다 `PurchaseGranted`, Output 두 번째 줄이 `AlreadyRecorded`, 장어 카드 하나. fake = false로 Play하면 `game.ServerStorage:FindFirstChild("ShopDebug")`가 `nil`.
3. 가진 스킨은 로벅스 버튼 없이 "입기"/"입는 중". fake = false + `persistDataInStudio = false`에서 클라이언트 `print(game.ReplicatedStorage.Remotes.RequestRobuxPurchase:InvokeServer("eel"))` → `false 준비 중이에요`(상품 id 없을 때). 상품 id를 넣은 뒤 같은 상태로 로벅스 버튼 → "저장이 안 되는 상태라 지금은 살 수 없어요". `fakeRobuxInStudio`와 `persistDataInStudio`를 같이 켜면 시작 때 경고가 나오고 가짜 결제가 꺼져요.
4. [C1 + C3] 상품 15개 id를 `src/shared/Skins.luau`에 넣고 `lune run tests` → 퍼블리시 → `persistDataInStudio = true`, `fakeRobuxInStudio = false` → 로벅스 버튼 → Roblox 결제 창(Studio 테스트 구매, 청구 없음)의 가격이 버튼 가격과 같음 → 확인 → 스킨이 들어오고 입혀짐, Output `[Shop] receipt <PurchaseId> … PurchaseGranted`. Stop 후 다시 Play해도 남음. 결제 창을 취소하면 아무것도 안 바뀌고, 그 뒤 같은 스킨을 코인으로 해금해도 "🎉 획득!"이 아니라 코인 해금 문구. 결제 창이 열린 동안 같은 스킨 코인 해금은 "로벅스 결제가 끝날 때까지 기다려 주세요". **이 확인 때 fake는 끄기.**
5. 휴대폰 에뮬레이터(iPhone SE)에서 일반·레어 스킨 정보 칸에 "🍚 해금" + "R$ n로 사기" + 결과 줄이 잘리지 않고 겹치지 않으며 손가락으로 따로 눌려요. 에픽·전설은 버튼 하나.
6. [C3 + 실서버] 실제 계정으로 가장 싼 일반 스킨 하나 구매 → 들어오고, 매치 서버로 옮겨 가도 남아요. Creator Dashboard → Data Stores → `Purchases_v1`에 PurchaseId 키 한 줄.

**O. 비공개 테스트 → 공개 (출시 체크리스트, m4-12)** — 사용자 할 일은 `docs/USER-TODO.md` 칸으로 연결해요

| # | 할 일 | USER-TODO | 언제 |
|---|---|---|---|
| 1 | 출시 방식 결정: 한 플레이스 모드(서버 최대 40, C2 불필요) / 로비·매치 분리(C2 필요). 소리가 없을 때 무음으로 시작할지 | A1 | 비공개 테스트 전 |
| 2 | 게임 이름·설명(한국어 + 영어 한 줄), 장르, 아이콘 512×512, 썸네일 1920×1080 3장 이상 ("먹히는 초밥"을 전면에) | A3 | 비공개 테스트 전 |
| 3 | 소리 고르기(배경음 4·효과음 9, 지금 무음 — M5 `Overtime` 포함) | A2 | 비공개 테스트 전(또는 무음으로 시작 결정) |
| 4 | M3·M4 Studio 확인 (3-8, 3-9) | B2, B3 | 비공개 테스트 전 |
| 5 | 퍼블리시 + Studio API 접근 허용 | C1 | 비공개 테스트 전 |
| 6 | (분리로 낼 때) Match 플레이스 만들기, 같은 빌드를 두 플레이스에 퍼블리시, PlaceId 2개 → `Config.Places` | C2 | 비공개 테스트 전 |
| 7 | 경험 설문, 지원 기기(PC·휴대폰·태블릿 켬, 콘솔 끔), 서버 최대 인원 Lobby 40 / Match 24 | C4 | 비공개 테스트 전 |
| 8 | 접근을 친구·지정 사용자로 제한(비공개 유지 + Collaborators/허용 목록, 메뉴 이름은 대시보드 버전마다 다름)하고 4명 이상 × 5판 이상, 결과는 `docs/playtest/m4.md` | D | 위 1~7 뒤 |
| 9 | 개인정보 삭제 요청 절차 메모 (`PlayerData_v1`의 `u_<UserId>`, `Purchases_v1`의 그 사용자 기록) | C4 | 공개 전 |
| 10 | 개발자 상품 15개(가격 A안) + 상품 id 입력 → N4 확인 | C3 | 공개 전 |
| 11 | 공개 전환 | C4 | m4-14 확인 + 비공개 테스트 큰 문제 없음 |

> 알려진 한계 (P3): `docs/CHANGELOG.md` M4 "알려진 한계 · 보류" 참고.

### 3-10. M5 확인 (연장전 · 관리자 · 시즌 · 상점 · 연출 · 코드 · 스킨 · 새 맵 9개)
출처: `docs/qa/m5-01-…`~`docs/qa/m5-22-…`의 "사용자 Studio 확인 체크리스트"(맵은 재QA 절 포함). m5-24 이후(아트 패스 v2·캐릭터·콘셉트 스킨·뽑기·고등어·버튼 편집)는 3-12.
- **m5-31 뒤 바뀐 점**: Studio는 기본으로 모든 스킨을 입을 수 있어요(`unlockAllSkinsInStudio = true`). 아래 D(시즌 스킨 사기·교환)·E(묶음·VIP 금박)·I(코인 해금)처럼 **보유·구매를 보는 항목은 먼저 `unlockAllSkinsInStudio = false`**로 바꾸고 확인한 뒤 `true`로 되돌려요. QA 뒤 고쳐진 것은 고친 뒤 동작으로 적었어요("QA 뒤 고침"). 맵 비주얼 키트(조명)는 3-11. 결과(특히 실패·이상한 점)는 메인 세션에 알려 주거나 해당 스펙 개발 메모에 적어 주세요. 표시 [바로] / [C1 먼저] / [C2 먼저]는 3-9와 같아요.

**디버그 설정 (M5에서 추가)** — 로컬에서만 바꾸고 **커밋 금지**. 3-9 표의 설정도 그대로 써요.

| 설정 | 위치 | 기본값(커밋 값) | 바꾸면 | 쓰는 절 |
|---|---|---|---|---|
| `overtimeAt` | `src/shared/Config.luau` `Config.DEBUG` | `nil :: number?` | 결승 연장전 시작을 그 초로 당겨요(예: `15`). Studio에서만 적용 | A, J, R, S |
| `eventNow` | `src/shared/Config.luau` `Config.DEBUG` | `nil :: number?` | 서버가 쓰는 "지금 시각"(UTC unix 초). 할로윈 `1792108800`~`1793923199`, 끝 `1793923200`, 크리스마스 `1796947200`. Studio에서만(실서버는 무시) | C, D, G, H |
| `fakeVipInStudio` | `src/shared/Config.luau` `Config.DEBUG` | `false` | 게임 패스 없이 VIP로 봐요. `persistDataInStudio`와 같이 켜면 꺼지고 경고만 | E |
| `unlockAllSkinsInStudio` | `src/shared/Config.luau` `Config.DEBUG` | **`true`** (m5-31) | `true`면 Studio에서 보유와 상관없이 모든 스킨이 "입기 (Studio)"(저장된 보유에는 안 남음, 서버 Output `[ShopService] Studio: all skins can be worn …` 한 줄). **구매·코인 해금·🎫 뽑기 흐름을 볼 때만 `false`**로 — 켜 두면 탈의실이 "입기 (Studio)"만 보여요. `persistDataInStudio`와 같이 켜면 꺼지고 경고 한 줄. 실서버는 무시 | I, 3-12 |
| `fakeRobuxInStudio` | (3-9 표) | `false` | 시즌·특별 상품도 가짜 결제로 | D, E |
| `persistDataInStudio` | (3-9 표) | `false` | 켜면 가짜 결제·가짜 VIP·Studio 전부 입기가 꺼지고, 관리자 코인·재화·🎫 티켓·프로필 초기화 명령이 거절돼요 | C3, G4, H7, 3-12 |
| `src/server/CodeList.luau` | 로컬 파일(`.gitignore`) | 없음 | `CodeList.example.luau`를 복사해 코드 목록을 적어요. 커밋되지 않아요. 실제 코드는 문서 예시와 다르게 | G |
| `StudioAllAdmins` | `src/server/AdminConfig.luau` | `true` | `false`면 Studio에서도 UserId 목록(과 퍼블리시된 플레이스의 개인 소유자)만 관리자 — 비관리자 화면 확인용 | B5 |
| `LiveEnabled` | `src/server/AdminConfig.luau` | `true` (확정, 2026-10-08) | `false`면 **실서버**에서 아무도 관리자가 아님. Studio에는 영향 없음. 공개 출시 전에 유지/끄기 재확인(USER-TODO A1) | B7 |

**되돌리기**: 확인이 끝나면 `forceMapPlan = nil`, `overtimeAt = nil`, `eventNow = nil`(타입 표기 `nil :: number?` 그대로), `fakeRobuxInStudio = false`, `fakeVipInStudio = false`, `persistDataInStudio = false`, **`unlockAllSkinsInStudio = true`**, `StudioAllAdmins = true`. 맵 Art에 잠깐 넣은 시험용 장식(3-11 4번)도 지워요. 안 되돌리면 `lune run tests`가 실패하거나(Config 커밋 값 고정 테스트) 관리자 확인이 헷갈려요. `git status`로 `src/`에 바뀐 파일이 없는지 확인하고 커밋하지 마세요.

**A. 결승 연장전 (m5-01)** [바로] — 준비: `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, 빠르게 보려면 `overtimeAt = 15`
1. (AC11) Test → Clients and Servers 2명, 방 만들고 시작 → 결승(꼬치 쇼다운)까지 둘 다 살아남아 버티기. 15초(디버그) 또는 90초가 되면:
   - [ ] 두 화면 모두 가운데 "⚡ 연장전!" / "접시가 무너져요! 끝까지 버텨요" 배너가 약 2초 뜨고 사라져요.
   - [ ] 오른쪽 위 타이머가 빨간 "⚡ 20초"로 바뀌어 1초씩 줄고, 0이 되면 "⚡ 버텨요!".
   - [ ] 배경음이 조금 빨라져요(곡 id가 있을 때). `Overtime` 경적은 id가 없으면 무음이 정상.
2. (AC12)
   - [ ] 남은 모든 조각의 가장 바깥 남색 줄이 1초 빨갛게 깜빡인 뒤 사라지고, 약 2.7초(19/7초)마다 한 줄씩 안쪽으로 이어져요. 디버그 15초(조각이 여러 개 남은 상태)여도 **남은 조각 전부**가 같이 무너져요.
   - [ ] 연장전 뒤 셰프 손이 새 조각을 집으러 오지 않아요(이미 빨갛게 깜빡이던 조각은 마저 가져감).
   - [ ] 꼬치가 눈에 띄게 빨라져요.
3. (AC13)
   - [ ] 연장전 시작 약 20초 뒤 가장 안쪽 줄까지 사라져 두 사람 다 떨어져요. **더 늦게 떨어진 쪽**에 "🏆 우승했어요!" → 약 3초 뒤 Victory 연출.
   - [ ] 기둥 옆에 붙기, 기둥 위로 점프, 꼬치·손·장식 위에 올라타기 — 전부 실패하고 떨어져요.
4. (AC14) Play(혼자) 같은 설정으로 결승까지 →
   - [ ] 연장전 → 붕괴로 떨어지면 우승 처리되고 Victory → 로비로 끝나요(멈추지 않음). 기본값이면 약 110초, `overtimeAt = 15`면 약 36초.
5. (AC15) 2명, 연장전 중(빨간 타이머가 보일 때)
   - [ ] 한 명이 리셋(Esc → Reset)하면 남은 사람에게 즉시 "🏆 우승했어요!".
   - [ ] 다시 해서 한 명이 게임을 나가면(창 닫기) 남은 사람이 즉시 우승.
   - [ ] 연장전 전에 떨어진 사람(관전 중) 화면에도 배너·빨간 타이머가 똑같이 보여요.
6. (AC16) `forceMapPlan = { "skewer-showdown", "hot-plate", "rotating-belt" }`, 2명
   - [ ] 1라운드(꼬치 쇼다운)는 90초가 되어도 연장전 배너가 없고, 버틴 사람이 전원 통과해요.
   - [ ] 매치 시작 때 서버 Output에 `forceMapPlan ends with rotating-belt (Race), not a Final map …` 경고 한 줄. 3라운드(회전 벨트가 결승 역할)는 연장전·배너 없이 끝나요 — 아무도 결승선에 안 들어가면 90초에 가장 멀리 간 1명이 우승(m5-01 B2 수정).
7. (AC17) Test → Device(휴대폰 가로) 에뮬레이터로 1번 반복
   - [ ] "⚡ 20초", "⚡ 버텨요!"가 타이머 칸 안에 들어가고(잘리거나 넘치지 않음) 읽혀요.
   - [ ] "⚡ 연장전!" 배너가 왼쪽 위 인원·내 결과·조작 버튼과 겹치지 않아요.
8. 끝나면 `forceMapPlan`, `overtimeAt`를 `nil`로.

**B. 테스트용 관리자: 스킨 미리보기 (m5-02)** — 1~5 [바로], 6 [C1 먼저], 7 실서버(C1 뒤), 8 실서버(C2 뒤)
1. (AC6) Play(혼자)
   - [ ] 화면 왼쪽 가장자리 세로 가운데에 "🛠" 버튼. 위쪽 바(코인·음소거)·오른쪽 아래 터치 버튼·탈의실 창과 겹치지 않아요.
   - [ ] 누르면 패널 제목 "🛠 테스트 착용 (저장 안 됨)", 16종 버튼(등급 색).
   - [ ] `황금 오토로`(golden-otoro, 안 산 전설)를 누르면 내 초밥이 바로 바뀌고, 서버 Output에 `[Admin] <이름>(<id>) preview golden-otoro`.
   - [ ] "🍣 스킨" 탈의실에서 황금 오토로는 여전히 구매 버튼(상품 id 전이면 "R$ 199 — 곧 열려요"), 코인 숫자 그대로.
2. (AC7)
   - [ ] 미리보기 중 탈의실에서 계란초밥 "입기" → 계란초밥으로 바뀌고 패널의 초록 강조가 꺼져요.
   - [ ] 다시 아무 스킨 미리보기 → 패널 "끄기 (내 스킨으로)" → 프로필 장착 스킨으로 돌아와요.
   - [ ] 미리보기 중인 안 산 스킨은 탈의실에서 "입기"가 아니라 구매 버튼이에요(미리보기는 보유가 아님).
3. (AC8) Test → Clients and Servers 2명
   - [ ] Player1이 `용 롤`(dragon-roll) 미리보기 → Player2 화면에서도 Player1이 용 롤, 이름표·칭호 높이 정상.
   - [ ] 그대로 매치(필요하면 `forceMapPlan`) → 라운드·탈락 연출 인형·우승 연출·로비 단상(우승했을 때)에서 같은 스킨.
4. (AC9)
   - [ ] 라운드 소개·달리는 중·탈락 연출 중에 패널 버튼 → "라운드 중에는 바꿀 수 없어요", 외형 그대로.
5. (AC10, **가장 중요 — 비관리자 차단 확인**)
   1. `src/server/AdminConfig.luau`의 `StudioAllAdmins = true` → **`false`**로 바꾸고 저장.
   2. Test → Clients and Servers **2명**으로 Start (Studio 테스트 계정은 음수 UserId라 목록에 없어요).
   - [ ] 두 클라이언트 모두 화면에 "🛠" 버튼이 없고, Explorer의 `Players.<이름>.PlayerGui`에 `AdminPanel` ScreenGui가 **아예 없어요**.
   - [ ] 클라이언트 창 하나의 Command Bar(Current: Client)에서 `print(game.ReplicatedStorage.Remotes.AdminPreviewSkin:InvokeServer("uni"))` → `false 권한이 없어요`, 외형이 바뀌지 않아요.
   - [ ] 같은 줄을 여러 번 실행해도 서버 Output의 `[Admin] … tried AdminPreviewSkin without permission` 경고는 **플레이어당 한 줄**.
   - [ ] 클라이언트 Command Bar `game.Players.LocalPlayer:SetAttribute("IsAdmin", true)` 뒤 다시 Invoke해도 `false 권한이 없어요`(클라이언트 속성은 권한이 아님).
   3. **확인 뒤 `StudioAllAdmins = true`로 되돌리기.** (참고: 퍼블리시된 플레이스를 본인 계정으로 Play(혼자)하면 `false`여도 목록·소유자라 관리자예요 — 이 확인은 Clients and Servers로 해요, m5-02 B2)
6. (AC11) [C1 먼저] `persistDataInStudio = true`
   - [ ] 미리보기를 켜고 나갔다 다시 들어오면 탈의실 보유·장착·코인이 미리보기 전과 같아요. Creator Dashboard → Data Stores의 `PlayerData_v1` / 키 `u_<UserId>`도 그대로, `Purchases_v1`에 새 기록 없음.
   - 확인 뒤 `persistDataInStudio = false`.
7. (AC12) [실서버, C1 뒤]
   - [ ] 퍼블리시된 게임에 본인 계정(11402290839)으로 들어가면 "🛠"가 있고, 목록에 없는 친구 계정 화면에는 없어요.
8. (AC13) [실서버, C2 뒤 — 플레이스 분리로 낼 때만]
   - [ ] 로비에서 미리보기를 켠 채 매치에 들어가면 매치 서버에서도 같은 스킨이고, 매치가 끝나 로비로 돌아와도 유지돼요.
   - [ ] 끄기(또는 1시간 뒤) 다음 접속은 내 장착 스킨.

**C. M5 기반 (m5-03)** [바로] — 3번만 [C1 먼저]
1. (AC11) Play(혼자)
   - [ ] 로비·탈의실이 전과 같이 열리고 Output에 빨간 에러가 없어요. `[CodeConfig] no src/server/CodeList.luau …` 경고 한 줄은 정상. 이벤트 기간 밖(`eventNow = nil`이고 실제 날짜가 기간 밖)이면 안 가진 시즌 스킨 4종은 탈의실에 안 보이는 게 정상이에요(D에서 확인). 금박 계란초밥(VIP 전용)은 전설 탭에 있어요(E).
2. (AC12) `forceMapPlan = { "dessert-fridge", "tempura-pot", "ikura-bombs" }` → 세 맵을 한 판에 끝까지 돌 수 있어요(맵별 확인은 J·K·L).
3. (AC13, 선택) [C1 먼저] `persistDataInStudio = true`로 M4 때 저장한 계정으로 Play → 코인·스킨이 그대로, 나갔다 다시 들어와도 그대로(이제 v2로 저장). 끝나면 `false`.

**D. 시즌 이벤트 (m5-07)** [바로] — 준비: `eventNow = 1792108800`(할로윈 첫날). 끝나면 `eventNow = nil`, `fakeRobuxInStudio = false`, `forceMapPlan = nil`.
1. (AC8)
   - [ ] 코인 배지 옆에 "🍬 0".
   - [ ] "🍣 스킨" → "🎃 할로윈" 탭이 맨 앞에서 먼저 선택돼 있고, 머리줄 "할로윈 초밥 축제 · 11월 5일까지 · 🍬 0"과 안내 "이벤트가 끝나면 받을 수 없어요. 다음 해에 다시 올 수도 있어요." — 초 단위 카운트다운이 없어요. 카드는 호박 초밥(R$ 99), 유령 계란초밥("🍬 0 / 80", 비활성) 2개.
2. (AC12) 로비 카운터 둘레에 호박 6개와 보라 조명 2개. 그 위를 걸어 지나갈 수 있고(충돌 없음), 카운터 양 끝 호박이 의자와 겹치지 않아요(QA 뒤 고침).
3. (AC9) `forceMapPlan`으로 한 판 → 라운드 통과 토스트 "+10 🍚 +1 🍬 라운드 통과"(`TokenGet` 무음), 배지가 바로 늘어요. 매치 끝 "+50 🍚 +4 🍬 오늘 첫 판"(그날 첫 판) / 두 번째 판부터 "+1 🍬 판 참가". 우승하면 우승 화면 아래 "이번 판 +N 🍚 +M 🍬 (총 …)".
4. (AC10) 관리자 "🛠 명령" 탭에서 재화 +80(또는 명령줄 `require(game.ServerScriptService.Server.DataService).update(game.Players:GetPlayers()[1], function(p) p.eventTokens["halloween-2026"] = 80 end)`) → 탈의실을 닫았다 열기 → 유령 계란초밥 "🍬 80으로 받기" → "🎉 유령 계란초밥 받았어요!", 바로 입혀지고 배지 "🍬 0". 라운드 중(소개 포함)에는 받기가 거절돼요.
5. (AC11) `fakeRobuxInStudio = true` → 호박 초밥 "R$ 99" → 가짜 결제로 지급·장착.
6. (AC11·AC12) `eventNow = 1793923200`(끝) → 이벤트 탭·🍬 배지·호박 장식이 없어요. 가진 호박 초밥은 에픽 탭, 유령 계란초밥은 레어 탭에 "한정"으로 남고, 안 가진 한정 스킨은 "전체" 탭에도 없어요.
7. (AC12) `eventNow = 1796947200`(크리스마스) → "🎄 크리스마스" 탭, "⭐ 0", 머리줄 "1월 7일까지", 로비에 트리 2·선물 4·눈 내림.
8. (AC13) 시즌 스킨 4종과 금박 계란초밥(관리자 "🛠" 미리보기)을 입어 보고 크기·겹침·빛(유령 빛·트리 별·금박 반짝이)이 과하지 않은지. (AC14) 휴대폰 에뮬레이터에서 이벤트 탭·머리줄·🍬 배지가 다른 UI와 안 겹쳐요.

**E. 🎁 특별 상품 · VIP 패스 (m5-08)** [바로] — 준비: `fakeRobuxInStudio = true`(VIP 항목은 `fakeVipInStudio = true`도), **`persistDataInStudio`는 false 그대로**. 끝나면 모두 false. 9번만 [C1 + C3-1 먼저 + 실서버]
1. (AC8) "🍣 스킨" 아래 "🎁 상점" → 카드 6개(스타터 팩·에픽 세트·전설 세트·고양이 손님·불꽃놀이·VIP — `fakeVipInStudio`가 꺼져 있으면 VIP는 "곧 열려요"), 스타터 팩 "따로 사면 R$ 146", 에픽 297·전설 597.
2. (AC9) 스타터 팩 "R$ 79로 사기" → 결과 줄 "🎉 스타터 팩 획득! 탈의실에서 새 스킨을 입어 보세요"(초록), 로비 안내도 **오류색(빨강)이 아니에요**(QA 뒤 고침). Output `[Shop] receipt studio-… offer starter-pack -> PurchaseGranted (GrantAndRecord: granted)`. 탈의실에 연어·참치·새우·장어 보유, 입던 스킨 그대로. 스타터 팩은 아래 회색 "산 상품".
3. (AC9 중복) 명령줄(Server) `game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("<내 이름>", "starter-pack", "studio-test-1")` 두 번 → 두 번째 `AlreadyRecorded`, 스킨 개수 그대로.
4. (AC10) Stop → 다시 Play(새 메모리 프로필) → 연어를 먼저 얻기 → 상점에 스타터 팩 카드가 **아예 없어요**.
5. (AC11) 고양이 손님 사기 → "✨ 내 연출"에 "입는 중 · 벗기". Explorer → Players → 내 플레이어 Attributes `EliminationFx = cat-customer`. 벗기 → 속성 사라짐, 입기 → 다시 생김.
6. (AC12) `fakeVipInStudio = true` + Clients and Servers 2명 → 상대 화면에서 내 이름표 "👑 이름", 채팅 금색 "[VIP]"(`TextChatService.ChatVersion`이 `TextChatService`일 때), 내 탈의실에 금박 계란초밥 보유(장착은 안 됨), VIP 카드는 "산 상품". (자기 이름표는 원래 안 보여요.) `persistDataInStudio`와 같이 켜면 가짜 VIP는 꺼지고 경고만 나와야 해요.
7. (AC13) 매치 시작 → "🎁 상점" 버튼이 사라지고(소개·달리기·대기석·관전), 열려 있던 창도 닫혀요. 로비로 오면 다시 보여요.
8. (AC14) Device(휴대폰) → 카드 1열 스크롤, 버튼 44px 이상, "🍣 스킨"·"🎁 상점"·"🎟 코드" 버튼이 다른 로비 UI와 안 겹쳐요.
9. (AC15, 실서버) USER-TODO C3-1 상품 5개·패스 1개 id를 `src/shared/Offers.luau`에 넣고 퍼블리시 → 실제 결제 → 지급, 개발자 콘솔(F9 → Server) `PurchaseGranted`. VIP를 산 뒤 다시 접속해도 👑. 비공개 서버·테스트 계정으로.

**F. 연출 팩: 고양이 손님 · 불꽃놀이 (m5-09)** [바로] — 준비: `forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`, E처럼 가짜 결제로 사서 입거나 관리자 "🛠 명령" 탭 연출 미리보기
1. (AC6) 회전 벨트에서 떨어지기 → 주황 고양이 발이 젓가락으로 집어 간장에 찍고, 고양이 얼굴(세모 귀·수염)이 "냠!" 하고 오물오물. 말풍선 "냥~ 신선하다냥!"/"생선은 역시 최고냥"/"한 접시 더 달라냥!" 중 하나.
2. (AC6) Survival에서 떨어지기 → 아래에서 고양이 입이 받아먹음. 결승에서 떨어지기 → 줄무늬 고양이 앞발이 움켜쥐고 올라감.
3. (AC7, 2명) 연출을 입은 Player1이 떨어지면 Player2 화면에도 고양이, Player2(안 입음)는 두 화면 모두 기본 연출.
4. (AC8, 2명) 불꽃놀이를 입은 사람이 우승 → 풍덩 뒤 바다 위 불꽃이 좌우 번갈아(마지막 가운데 큰 금색), 두 화면이 같아요. 첫 불꽃은 다이빙 카메라 때라 안 보여도 알려진 P3.
5. (AC9) 탈락 3초·우승 10초 그대로. 끝난 뒤 `Workspace.EliminationCutscenes`가 비고 `VictoryCutscene`(안의 `Fireworks`)이 남지 않아요. 2~3판 연달아도 남는 것 없음.
6. (AC10, 4명 이상 모두 고양이) 한꺼번에 떨어질 때 프레임 체감(가능하면 휴대폰 에뮬레이터도).
7. 속성에 모르는 값(`"아무거나"`, 탈락 칸에 `"fireworks"`) → 기본 연출, 에러 없음.
8. 소리 `CatMeow`·`Fireworks`는 무음(USER-TODO A2).

**G. 🎟 코드 보상 (m5-10)** [바로] — 4번만 [C1 먼저]. 준비: `src/server/CodeList.example.luau`를 같은 폴더 `CodeList.luau`로 복사하고 테스트 코드 두 개를 넣어요(커밋 안 됨). **이 예시는 공개돼 있으니 퍼블리시 전에 지우고, 실제 출시 코드는 다른 문자열로.**
```lua
{ code = "EXAMPLE2026", coins = 200, expiresAt = 1798761600 },
{ code = "EXAMPLESPOOKY", coins = 100, tokens = 10, eventId = "halloween-2026", startsAt = 1792108800, expiresAt = 1793923200 },
```
1. (AC8) 로비 "🎟 코드" → "코드 넣기" 창. `  example2026 ` → "받기" → 초록 "🍚 200 받았어요!", 토스트 "+200 🍚 코드 보상", 배지 +200. 서버 Output `[Code] 이름(UserId) redeemed EXAMPLE2026 +200`.
2. (AC9) 같은 코드 다시 → "이미 받은 코드예요". `NOPE123` → "없는 코드예요". 2초 안에 다시 → "잠시 뒤에 다시 해 주세요". 간격을 두고 틀린 코드 8번 → Output `[Code] … locked after 8 failures` 한 줄(틀린 문자열은 Output에 없음), 그 뒤 진짜 코드도 10분 동안 "잠시 뒤에 다시 해 주세요".
3. (AC10) `eventNow = 1792108800` → 새 세션에서 `examplespooky` → "🍚 100 + 🍬 10 받았어요!". `eventNow = 1793923200` → "기간이 끝난 코드예요". 확인 뒤 `eventNow = nil`.
4. (AC11) [C1 먼저] `persistDataInStudio = true`로 1번 → Stop → 다시 Play → 같은 코드 "이미 받은 코드예요". 확인 뒤 `false`.
5. (AC12) 매치 중 "🎟 코드" 버튼이 사라지고 열린 창도 닫혀요. 휴대폰 에뮬레이터에서 창이 위쪽에 붙고 키보드와 안 겹쳐요. 21자 넘게 붙여 넣으면 20자로 잘리고, Enter로도 보내져요.
6. (AC13) Explorer: `ServerScriptService.Server`에 `CodeConfig`·`CodeList`, `ReplicatedStorage.Shared`에는 `CodeLogic`만(목록 없음).
7. `CodeList.luau`를 지우고 Play → `[CodeConfig] no src/server/CodeList.luau …` 경고 한 줄, 어떤 코드든 "없는 코드예요".

**H. 관리자 명령 (m5-11)** [바로] — 9번만 실서버
1. (AC7) "🛠" → 탭 "👕 미리보기"/"🛠 명령". `ℹ info` → "Single · 서버 … · 방 0 · 플레이어 1 · 내 방 없음 · 코인 0".
2. (AC8) 방 만들기 → "▶ 바로 시작" → 카운트다운 → 매치. 방이 없으면 "방에 들어가 있지 않아요".
3. (AC9) 맵 버튼 `dessert-fridge` → `tempura-pot` → `ikura-bombs` → "다음 판에 쓰기"(결승 자리가 Final이 아니면 "주의: …") → 바로 시작 → 그 순서. 다음 판은 랜덤으로 돌아오고, "비우기"가 목록을 비워요.
4. (AC10) 코인 +1000 → 배지가 바로 올라요. −1000을 여러 번 해도 0 아래로 안 내려가요. 이벤트 밖 재화 +80 → "진행 중인 이벤트가 없어요". `eventNow = 1792108800 + 3600` → 재화 +80 → info에 재화가 보여요.
5. (AC11) 연출 "고양이 손님" → "연출 미리보기: 고양이 손님 (저장 안 됨)". 달리는 중에는 "라운드 중에는 바꿀 수 없어요".
6. (AC12) "프로필 초기화" 3초 안에 두 번 → 코인 0·계란초밥.
7. **저장을 켠 Studio**: `persistDataInStudio = true` → 코인·재화·프로필 초기화가 모두 "저장을 켠 Studio에서는 쓸 수 없어요"(사용자 결정 2026-10-13). info·미리보기·바로 시작·맵 순서는 돼요. 확인 뒤 `false`.
8. (AC13) `StudioAllAdmins = false` + Clients and Servers 2명 → 비관리자 창에 "🛠" 없음, 그 창 Command Bar(Client) `print(game.ReplicatedStorage.Remotes.AdminCommand:InvokeServer("coins", 1000))` → `false 권한이 없어요`, 서버 warn 1번, 코인 그대로. **확인 뒤 `true`로.** 서버 Output에 모든 명령이 `[Admin] 이름(UserId) <명령> <값> -> ok|<이유>`.
9. (AC14, 퍼블리시 뒤) 실서버 관리자 계정: info·연출 미리보기만 되고 나머지는 "Studio에서만 쓸 수 있는 명령이에요", 프로필 초기화 버튼은 없어요.

**I. 스킨 기반 v2 · 새 스킨 10종 (m5-21, m5-22)** [바로] — 코인이 부족하면 관리자 "🛠" 미리보기로
1. 탈의실에 새 10종이 타코야키 → 유니콘 롤 순서로, 가격 일반 29 R$ / 300코인, 레어 59 R$ / 900코인, 에픽 99·전설 199 R$(코인 버튼 없음), 로벅스 버튼은 "곧 열려요".
2. 10종을 입어 실루엣이 서로 다른지(타코야키 울퉁불퉁 공, 에그토스트 비대칭 노른자, 버거 층, 돈가스 사선 줄, 고양이 귀·수염, 로보 바이저·안테나, 갤럭시 별, 소프트아이스크림 소용돌이·체리, 크라운 참치 왕관·망토, 유니콘 뿔·갈기).
3. (m5-21 AC9) 쐐기: 고양이 귀·왕관 뾰족이·유니콘 갈기가 **위로 뾰족한 쐐기**인지(뒤집혔으면 어느 쪽을 보는지 적어 주세요).
4. (AC10) 갤럭시 롤·크라운 참치·유니콘 롤은 반짝이 + 은은한 빛 **둘 다** 보이고 산만하지 않아요. 탈락 연출 때 진짜 캐릭터의 효과가 같이 사라졌다가 끝나면 다시 켜져요.
5. (AC11) Clients and Servers 4명 이상이 2효과 스킨을 입고 한 판 → 프레임이 눈에 띄게 안 떨어져요(View → Stats).
6. 고양이 초밥·소프트아이스크림 롤·유니콘 롤을 계란초밥 옆에 세워 너무 커 보이지 않고 이름표가 머리 장식에 안 묻혀요. 비초밥 7종의 탈락 말풍선(예: "야옹~ 잡아봐!", "삐빅, 시스템 가동 완료!")이 어색하지 않아요.
7. (AC12) 서버 시작 Output에 `Skins.validate`·catalog 경고가 없어요.

**새 맵 확인 공통** — `forceMapPlan`으로 그 맵이 들어간 판을 돌리고(확인 뒤 `nil`), 결승 맵은 `overtimeAt = 15`로 연장전을 당겨 봐요(확인 뒤 `nil`). 모든 맵에서: 장식(벽 밖 소품·기둥·간판)에 올라설 수 없고 통과해 떨어져요, 넉백·튕김 뒤 서버 Output에 `[MovementGuard]` 되돌림 로그가 없어요, 소개가 시작되면 1~2초 안에 그 맵 조명으로 바뀌어요(3-11), 두 방 동시(Clients and Servers 4명, 방 2개)면 각자 자기 맵만 움직여요, 휴대폰 에뮬레이터에서 경고·구멍·가장자리가 보여요. 결과(특히 체감·숫자)는 `docs/playtest/`나 메인 세션에.

**J. 결승 "연어알 폭탄 접시" (m5-04)** — `forceMapPlan = { "rotating-belt", "hot-plate", "ikura-bombs" }`
1. 결승 소개: 바다 넓은 샷 → 숟가락 → 위에서 내려다보기 → 출발 자리, 해 질 녘 조명.
2. (AC10) 출발 3초 뒤 빨간 원(흰 테두리)이 뜨고 숟가락이 그 위로, 1.5초 뒤 주황 연어알이 떨어져 터져요. 원 안이면 날아가 넘어졌다(@_@) 1초 뒤 일어나고, 원 밖이면 아무 일 없어요. 잡은 상태에서 맞으면 잡기가 풀려요.
3. (AC11) 같은 바깥 칸에 두 번 맞으면 어두워졌다(금 줄) 빨갛게 깜빡이며 떨어져요. 가운데 원판은 금이 안 가요. 40초부터 바깥, 60초부터 가운데 고리 칸이 하나씩 떨어져요.
4. (AC12, 2명) 연장전: 바깥 고리 깜빡임(1초) 뒤 사라짐 → 약 10초 뒤 가운데 고리 → 약 20초에 원판까지 → 설 곳이 없고 늦게 떨어진 사람이 우승. 숟가락·셰프 팔·종지·군함 탑·등 기둥에 설 수 없어요. (AC13) 혼자 결승도 붕괴로 끝나고 탈락 연출은 셰프 손.
5. (AC18) 숟가락 그림자가 접시에 떨어지는지, 빨간 경고 원이 군함 탑·떨어지는 연어알 주황과 헷갈리지 않는지(B3), 연장전 동시 폭발 3개의 알갱이가 각자 자리에서 터지는지(B4), 와사비·생강 종지가 디딤판처럼 보이지 않는지(B2).

**K. Survival "튀김 냄비 탈출" (m5-05)** — `forceMapPlan = { "rotating-belt", "tempura-pot", "skewer-showdown" }`
1. (AC10) 출발 뒤 약 6초까지 기름 그대로, 그 뒤 눈에 보이게 올라와요. 바구니에 가만히 있으면 약 13~14초에 탈락(손님 입 연출).
2. (AC11) 바구니 → 7층 → 나선을 따라 옆 발판으로 건너며 꼭대기(31층)까지 점프로 올라가요. 미끄러지지 않고, 머리가 위층에 부딪혀 막히는 곳이 없어요.
3. (AC12) 10초부터 내 발밑에 주황 원 → 약 1.2초 뒤 기름이 튀며 밀려 넘어져요(1초). 원 밖으로 5 넘게 피하면 안 맞아요. 2명으로 아래층 사람 발밑에 원이 떴을 때 **바로 위층(11층) 가장자리 사람은 안 날아가요**(QA 뒤 고침, 높이 범위 3.5).
4. (AC13) 60초 끝에 살아 있는 사람 전원 통과, 4명 이상이면 목표 인원만 남는 순간 끝.
5. (AC17) 밤 주방 조명(어두운 청색 + 주황 기름빛), 기름이 오를 때 빛·김도 같이. 너무 어두우면 `TempuraPotArt.LIGHTING`의 Brightness·ExposureCompensation만 올려요. (선택) 냄비 바깥면이 무쇠로 보이는지, 새우 꼬리 색이 경고처럼 보이지 않는지.
6. (AC15, 플레이테스트) 4~8명이 60초 안에 목표 인원 근처까지 줄어드는지, 처음 하는 사람도 "위로 가야 한다"를 바로 아는지.

**L. Race "디저트 냉장고" (m5-06)** — `forceMapPlan = { "dessert-fridge", "hot-plate", "skewer-showdown" }`
1. (AC9) 얼음(파란 바닥)에서 달리다 손을 떼면 약 16 studs 미끄러져 멈추고, 꺾으면 둥글게 돌아요. 출발·결승의 흰 바닥에서는 바로 멈춰요. 얼음 위 다이브는 평소보다 멀리. 얼음 큐브에 부딪혀도 떨리거나 끼지 않아요.
2. (AC10) 구멍(왼쪽·오른쪽 하나씩)에 빠지거나 얼음 끝으로 미끄러져 떨어지면 1초 안에 탈락 연출.
3. (AC11) 젤리 3개(빨강·초록·빨강)가 위 칸(케이크 단)까지 튕겨 줘요 — 너무 높이·오래 뜨지 않는지(실제 정점 약 24, B1). 오른쪽 쿠키 계단으로 걸어서도 올라가요. C 구간 폭 30(사용자 확정).
4. (AC12) D 선반에서 송풍구(민트색 상자) 앞에 서리 → 2초 바람에 옆으로 밀리고, 반대로 누르면 버틸 수 있어요. 바람이 쉴 때 상자 쪽으로 미끄러지면 상자를 통과해 떨어지는데 헷갈리는지(B2).
5. (AC13, 2명) 상대가 얼음에서 미끄러지는 모습이 자연스럽고, 얼음 위에서 잡기로 상대가 느려져요.
6. (AC14) 혼자 60~90초 안에 완주. (AC15) 다음 맵·로비·리셋 뒤에는 바로 멈춰요(얼음 느낌이 남지 않음).
7. (AC17) 차가운 흰-파랑 조명, 출발에서 문밖 주황 빛이 보여요. 양옆 유리 선반이 밟을 곳처럼 보이지 않는지(옆으로 다이브하면 유리를 뚫고 떨어져요, B3). 젤리 컵·체리·마카롱·병이 움직여요.

**M. 맵 확장 기반 (m5-13)** [바로]
1. `forceMapPlan = { "bouncy-castle-maze", "giant-jenga", "lantern-bridge", "tug-of-war-platform" }` → 4라운드가 그 순서, 소개 이름 "방방 미로 → 와르르 나무 블록 → 등불 다리 건너기 → 줄다리기 발판". Output에 `[MapTypes]`·`unknown map`·`duplicate map id` 에러가 없어요.
2. `forceMapPlan = nil`로 4명 이상 랜덤 판 여러 번 → 첫 라운드 Race 6개·Survival 5개·결승 4개가 섞여 나와요(결승 4개 중 무작위라 한 맵이 약 4판에 1번).

**N. Race "방방 미로" (m5-14)** — `forceMapPlan = { "rotating-belt", "bouncy-castle-maze", "skewer-showdown" }`
1. (AC9) 대기실·미로 바닥에서는 가만히 있어도 계속 튕기고, 출발·출구·결승 바닥에서는 안 튕겨요.
2. (AC10) 튕기면서 W를 눌러도 앞으로 가던 속도가 끊기지 않아요(QA 뒤 고침). 칸막이 틈으로 꺾어 들어갈 수 있고, 점프·다이브로 칸막이·벽 위를 못 넘어요.
3. (AC11) 대기실에서 오른쪽 3칸(2·3·4번 레인 앞)은 빨간 문에 막혀요. 1번 레인으로 곧장 달리면 출구 벽에 막혀 2번 레인으로 꺾어야 해요(4번 레인 끝만 출구).
4. (AC15) 혼자 60~90초 안에 완주(코스가 S자로 약 360 studs — 시간 제한 안인지 꼭 확인).
5. (AC14) 휴대폰 에뮬레이터에서 튕기는 중 점프·다이브 버튼이 돼요. (AC16) 다음 맵·로비에서 이동이 평소와 같고 루트에 `BounceLaunch`가 남지 않아요.

**O. Race "등불 다리 건너기" (m5-15)** — `forceMapPlan = { "lantern-bridge", "hot-plate", "soy-swamp", "skewer-showdown" }`
1. (AC12) 혼자 완주. 다리 위에 가만히 있어도 약하게 흔들려요.
2. 다리가 오른쪽으로 내려가 있을 때 몸이 **오른쪽(내려간 쪽)으로** 미끄러져요(QA 뒤 고침).
3. (AC13, 2~3명) 같은 다리에 모이면 더 크게 흔들리고, 다른 다리는 따로 흔들려요. 다리에서 떨어지는 중인 사람은 흔들림에 안 들어가요.
4. (AC14) 다리 3(가장 좁음)이 아슬아슬하고 다리 4가 상대적으로 여유 있는지, 3명 이상이 다리 3에 몰리면 가만히 있어도 떨어지는지(설계 유지 — 체감 의견).
5. (AC15) 옆으로 떨어지면 1초 안에 탈락, 결승선을 넘으면 통과. (AC17) 소개 카메라가 도리이·등불에 가리지 않아요.

**P. Survival "와르르 나무 블록" (m5-16)** — `forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`
1. (AC10) 6초쯤 바깥 칸 하나가 삐걱이며 흔들린 뒤 **맨 위 블록이 빠지며** 칸이 내려가 보여요(QA 뒤 고침). 시작할 때 칸들이 들썩이지 않아요. 가운데 3×3은 끝까지 그대로.
2. (AC11·AC12) 빠진 칸 주변만 기울고(셰프의 도마와 다른 느낌) 낮은 쪽(구멍 쪽)으로 서서히 밀려요. 혼자 가라앉은 테두리 칸은 바깥으로 거의 안 기울어요. 칸이 완전히 사라지면 떨어져 손님 입 연출.
3. (AC13) 48초 이후 1.5초마다 2칸씩 빨라져요. (AC14) 목표 인원 이하가 되면 바로 끝, 60초를 버티면 살아 있는 전원 통과.

**Q. Survival "고양이 카페 캣타워" (m5-17)** — `forceMapPlan = { "rotating-belt", "cat-cafe-shelves", "skewer-showdown" }`
1. (AC12) 1단 선반에 가만히 서 있으면 공·고양이 발에 안 맞는 동안 안 떨어져요.
2. (AC13) 분홍 공이 선반을 왕복하고 닿으면 타워 바깥쪽으로 밀려요. 꼭대기에서 공과 옆으로 떨어져 서 있으면 안 밀려요(QA 뒤 고침).
3. (AC14) 8초부터 사람이 선 선반이 주황으로 변하고 약 1.1초 뒤 크게 밀려요. 경고 시작 간격이 약 5 → 3.2 → 2초(45~60초)인지. 안쪽 끝·바깥쪽 끝에서 한 번씩 맞아 보고 떨어지는지 적어 주세요(넉백 세기 R1).
4. (AC15) 1단 → 2단 → 꼭대기로 점프해 오를 수 있고, 꼭대기에는 주황 경고가 안 떠요. (AC16) 혼자면 60초 끝에 통과, 4명이면 목표 인원만 남는 순간 끝.
5. (AC18) 재미·밀림 세기(너무 약함/셈) — 숫자로 알려 주면 상수만 고쳐요.

**R. 결승 "줄다리기 발판" (m5-18)** — `forceMapPlan = { "rotating-belt", "hot-plate", "tug-of-war-platform" }`
1. (AC9) 오른쪽(+X, `Spawn13`~`Spawn24` 쪽) 끝으로 가면 그쪽이 1~2초에 걸쳐 서서히 내려가요(내 쪽이 올라가면 `TILT_SIGN`을 뒤집어야 해요). 반대편으로 가면 서서히 평평해져요.
2. (AC10, **가장 중요**) 혼자 끝에 서면 약 10°. Clients and Servers 3명 이상이 한쪽 끝에 몰려 30°가 됐을 때 **가만히 선 사람이 실제로 미끄러지는지** 꼭 적어 주세요(R1 — 안 미끄러지면 평소 결승이 너무 쉬워요). 2명이 반대편에 나뉘면 오래 버티는지.
3. (AC11) `overtimeAt = 15` → 배너 뒤 좌우로 점점 크게 흔들리다 약 20초 뒤 수직이 되고, 그 순간 발판이 통과돼 남은 사람이 모두 떨어지고 바로 끝나요(QA 뒤 고침). 끝 모서리에 매달려도 버틸 수 없어요. (AC13) 혼자 결승도 같아요.
4. (AC12) 미끄러질 때·연장전 스윙 때 `[MovementGuard]` 로그가 없어요. (AC15) 휴대폰에서 저울 접시·동아줄이 시야를 가리지 않고 카메라가 어지럽지 않아요.

**S. 결승 "인형뽑기 기계 속" (m5-19)** — `forceMapPlan = { "rotating-belt", "hot-plate", "claw-machine-prize" }`
1. (AC9) 5초 뒤 노란 깜빡임 구역(2×2) → 2초 뒤 그 칸들이 들려 사라져요. 그 칸 위면 떨어지고 옆 칸이면 괜찮아요. 칸 사이 높이 차에 걸려 못 피하는 곳이 없어요(높이 차 2 이하로 고침).
2. (AC10) 30·60초 뒤 주기가 빨라지고 60초부터 3×3. 사람이 있는 쪽을 자주 노려요. `overtimeAt = nil`로 끝까지: 90초 전에 바닥이 다 사라지지 않고, 남은 칸이 적으면 집게가 작은 구역만 집거나 쉬어요. **2명 결승 길이**를 적어 주세요.
3. (AC11, 2명, `overtimeAt = 15`) 집게가 멈추고 상자가 기울며 **낮아지는 쪽 줄부터** 노랗게 깜빡이고 사라져요(앞뒤·좌우 어느 방향이든). 상자가 위아래로 크게 떠오르거나 가라앉지 않고, 칸 위에 서 있는데 탈락하는 일이 없어요. 연장전 직전 집게가 들고 있던 칸은 떨리지 않고 멈춘 채 같이 기울어요. 유리벽·천장·레일에 못 서요.
4. (AC12) 혼자 결승도 연장전으로 끝나고 탈락 연출은 셰프 손. (AC13) 유리벽·천장이 카메라를 가리지 않아요.

**T. 기존 맵 장식 다듬기 (m5-20, 판정 불변)** [바로] — 맵 5개라 `forceMapPlans = { { "rotating-belt", "soy-swamp", "chef-board", "skewer-showdown" }, { "ramen-rapids", "hot-plate", "skewer-showdown" } }`로 두 판(강제 플랜은 3~4개만 받아요 — QA 리포트의 5개짜리 플랜은 그대로 쓰면 거절돼요). 끝나면 `forceMapPlans = nil`
1. 회전 벨트: 머리 위 종이 등 3개 아래 주황 빛, 간장 종지 반짝임이 천천히 올라옴. 손님 눈 3쌍이 2~4초마다 따로 깜빡여요(깜빡일 때 흰 반짝임 점만 떠 보이면 B1).
2. 간장 늪: 와사비 산 흰 밥알 2곳의 연두빛, 간장 웅덩이 3곳 보글거림. 셰프의 도마: 머리 위 등 3개, 칼이 내려찍을 때 불꽃이 **한 번만**.
3. 라멘 급류: 양옆 다시마·통깨·젓가락 받침이 코스를 가리지 않아요. 간장 늪·라멘·도마 바깥 옅은 안개 판의 분위기가 서로 다르고, 라멘 그릇 밖으로 유리판 모서리가 삐져나와 보이거나(B2) 판 너머 국물·파티클이 사라져 보이는지(B5).
4. 철판 맵 선반 위 간장병 3개가 천천히 흔들려요 — 서버 화면에서는 안 움직여요(로컬 전용).
5. 회전 벨트·간장 늪 소개에 내려다보는 반전 샷, 카메라가 등·벽을 뚫거나 화면이 굴러 보이지 않는지(B3). 소개 길이 약 3초 그대로. Output에 `[MapKit] decor has`/`decor skipped` 경고가 없고, 다섯 맵 판정(낙하·결승선·시간 종료)이 전과 같아요.
6. m5-24 아트 패스가 들어오면 이 맵들은 다시 바뀌어요.

> 알려진 한계 (P3): `docs/CHANGELOG.md` M5 "알려진 한계 · 보류" 참고.

### 3-11. M5 맵 비주얼 키트 확인 (m5-23: Future 조명 · 맵별 조명 분위기 · 움직이는 장식)
출처: `docs/qa/m5-23-map-visual-kit.md` 체크리스트. 사용자 할 일 USER-TODO B1-1(Future 한 번 확인).
1. **Future 조명**: Rojo 연결 뒤 Explorer → `Lighting` → Properties의 `Technology`가 `Future`인지 봐요(`LightingStyle` Realistic, `PrioritizeLightingQuality` 켬). 아니면 직접 Future로 바꾸고 플레이스를 저장해요. 로비가 너무 어둡거나 하얗게 날아가지 않는지, 회전 접시·우승자 단상에 그림자가 생기는지 봐요.
2. **맵별 조명**: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }`(확인 뒤 nil로)으로 혼자 Play → 라운드 소개가 시작되면 1~2초 안에 조명이 부드럽게 바뀌어요(회전 벨트 = 저녁 노을빛, 철판 = 밤·주황 열기, 꼬치 = 축제 해질녘). 라운드가 끝나 대기석(로비)으로 오면 로비 조명으로 돌아와요. 번쩍임·깜빡임이 없어야 해요.
3. **방 2개 동시**: Test → Clients and Servers 2명, 서로 다른 방에서 다른 맵을 돌려요 → 각 화면이 **자기 아레나** 조명이에요. 탈락 뒤 관전으로 다른 사람을 비출 때도 그 아레나 조명이에요.
4. **움직이는 장식(anim)**: m5-24 등에서 `anim`을 단 장식이 생기면 — 제자리에서 돌거나(Spin)·오르내리거나(Bob)·흔들리거나(Sway)·숨 쉬듯 커졌다 작아지는지(Pulse), 서버 Output에 복제 경고가 없는지, 2명이 같은 장식을 같은 순간 같은 모습으로 보는지 봐요.
5. **CornerWedge 방향**: 렌더러는 CornerWedge 꼭대기를 로컬 (+X, 위, -Z) 모서리로 그려요. `MapKitShapes.bevelBox`(깎은 상자)를 처음 쓰는 맵에서 Studio로 귀퉁이 네 개가 매끈하게 맞물리는지 한 번 봐요(어긋나면 developer에게 — `CORNER_YAW` 표만 고치면 돼요).
6. **휴대폰 성능**: 가장 무거운 맵(Extended 예산 맵: 튀김 냄비·디저트 냉장고·연어알 폭탄) 소개·달리기 중 30fps 이상인지(`View → Stats`/MicroProfiler 기록). Future를 지원 안 하는 기기는 자동으로 단순한 조명으로 내려가요.
7. **Surface 조명**: SurfaceLight는 range 16까지만 비춰요(Roblox 상한, 검사·렌더러도 16에서 자름). 간판·창 빛이 렌더 PNG와 Studio에서 비슷한 넓이인지 봐요.
8. 소개 첫 컷부터 맵 조명인지(giant-jenga 포함, QA 뒤 고침 — 소개 카메라 점을 아레나 상자에 넣음). 서버 효과와 겹쳐 `Atmosphere`·`Bloom`이 `Lighting`에 두 개씩 생기지 않는지.

> m5-23은 QA 수정 뒤 재QA 전(`in-qa`)이에요. 결과가 이상하면 메인 세션에 알려 주세요.

### 3-12. M5 확인 2 (아트 패스 v2 · 캐릭터 · 콘셉트 스킨 · 🎫 뽑기 · 고등어 · 버튼 편집)
출처: 아래 QA 리포트의 "사용자 Studio 확인 체크리스트"(재QA 절 포함). 단계별 순서는 **리포트를 그대로 따라 하면 돼요** — 여기에는 준비물, 리포트를 쓴 뒤 바뀐 점, 꼭 볼 것만 모았어요. 결과(특히 실패·이상한 점)는 메인 세션에 알려 주세요. 전부 [바로](Studio만). 디버그 설정은 3-10 표, 끝나면 3-10 "되돌리기".

**리포트를 쓴 뒤 바뀐 점 (먼저 읽기)**
- 콘셉트 몸 스킨 9종은 m5-31부터 이름이 "○○ (특)"(예: 장어초밥 (특))이고 **뽑기 전용**이에요. m5-28·m5-29·m5-30 리포트의 "콘셉트 ○○ (테스트)", "전체 탭 맨 아래, 모두 '입기'", "`resetprofile` 뒤에도 '입기'"는 옛 동작이에요. 지금은 탈의실 **"🎫 특" 탭**(전체 탭에도 있음)에 있고, 커밋 값(`unlockAllSkinsInStudio = true`)에서는 "입기 (Studio)", `false`면 안 가진 카드가 "🎫 뽑기로 얻기"예요. 모양 확인은 `true` 그대로 하면 돼요.
- 콘셉트 몸 표정은 6종(화남·슬픔 추가, m5-32). 뽑기 확률표는 고등어가 들어와서 **전설 1.0 / 영웅 5.0 / 희귀 15.0 / 고급 30.0 / 일반 49.0**, "준비 중" 줄 없음, 보유 목록 n/**10**(m5-31 리포트의 "전설 준비 중·5.0/15.2/30.3/49.5·n/9"는 고등어 전 값). ⓘ의 스킨별 %도 바뀌어요(영웅 5.00%, 희귀 각 5.00%, 고급 각 10.00%, 일반 각 24.50%, 전설 1.00% — `DrawLogic.perSkinPercent`).
- m5-31 재QA P3 R1(상세 창 빈 곳 터치가 아래 카드로 샘)·R2(큰 미리보기가 이름·대사와 겹침)는 m5-32에서 고쳤어요 → m5-32 체크리스트 3번으로 확인.
- 고등어 넘어짐 "@_@"가 몸 속에 가려지던 것(m5-32 재QA B3)은 병합 뒤 고쳤어요 → 체크리스트 13번.
- 젠가 소개 카메라가 블록탑을 뚫던 것(m5-24 B1)은 병합 전에 고쳤어요(탑 모서리를 돌아감) → m5-24 체크리스트 2-a는 "안 뚫는지"로 봐요.

**A. 기존 맵 12개 아트 패스 v2 (m5-24)** — [`docs/qa/m5-24-map-art-pass-v2.md`](qa/m5-24-map-art-pass-v2.md) "사용자 Studio 확인 체크리스트" 1~5
- 준비: `forceMapPlans`에 리포트의 5판 플랜(혼자 = 3라운드라 맵 3개씩), 결승 연장전은 `overtimeAt = 5` + Clients and Servers 2명. 끝나면 `forceMapPlans = nil`, `overtimeAt = nil`.
- 꼭 볼 것: 맵마다 조명 분위기(1-a 목록), 소개 카메라가 벽·블록을 뚫지 않는지(2), 장식에 올라서거나 부딪히는 곳이 없는지(3-f), 회전 벨트 벽 바깥 카운터가 바닥처럼 보이지 않는지(3-a), 방방 미로 출발 시점(4-b, 렌더러로 못 봄), **인형뽑기 연장전에 오락실 전체가 같이 기우는 모습이 괜찮은지**(5-c — 결과로 planner가 B2 방향을 정해요), 휴대폰에서 방방·회전 벨트·등불 다리가 끊기지 않는지(4-c).

**B. 캐릭터 퀄리티 (m5-25)** — [`docs/qa/m5-25-character-quality.md`](qa/m5-25-character-quality.md) 1~9
- 숨쉬기·깜빡임·걸음·착지 찌그러짐·넘어짐 자세, 31종 탈의실 미리보기, 인형이 땅에 서 있는지, 빛 효과가 몸 주변만인지, 바짝 줌 때 몸 속이 비치는지(P3), 휴대폰에서 눈·입이 보이는지.

**C. 콘셉트 몸 스킨 (m5-28, m5-29, m5-30)** — [`m5-28`](qa/m5-28-concept-skins.md) 1~7, [`m5-29`](qa/m5-29-concept-skins-2.md) 1~8, [`m5-30`](qa/m5-30-concept-topping-quality.md) 1~6
- 위 "바뀐 점"대로 "🎫 특" 탭에서 입어요. 팔 흔들기·발 닿음·깜빡임, 탈락 인형(x x + 반창고)·우승/단상 인형(^ ^), 휴대폰 뒤 카메라에서 비슷한 쌍(장어 ↔ 연어, 성게 ↔ 연어알, 문어 ↔ 새우, 참치 ↔ 연어)이 구분되는지.
- 사용자 판단이 필요한 것: **장어 정면에서 주황 살이 너무 커 보이는지**(m5-30 체크리스트 2, B-V1), 새우 꼬리가 넘어질 때 묻히는지, 연어알·장어 Glass가 Future 조명에서 너무 투명·검게 보이는지, 유부 Sand 재질, 문어·성게 멀리서 깜빡임(z-fighting).

**D. 🎫 우승자 뽑기 (m5-31)** — [`docs/qa/m5-31-winner-ticket-draw.md`](qa/m5-31-winner-ticket-draw.md) 1~8 + "재QA Studio 체크리스트" 9~10
- 준비: 1번만 커밋 값(`unlockAllSkinsInStudio = true`), **2번부터 `unlockAllSkinsInStudio = false`**(끝나면 `true`로). 티켓은 🛠 명령 탭 🎫 +1/+10/+98/0으로(혼자 우승으로도 1장). 7번은 `persistDataInStudio = true`라 실제 DataStore를 써요 — 테스트 계정으로만, 끝나면 `false`.
- 꼭 볼 것: 우승 토스트·배지(2), 샘플 그림과 같은 구성인지(3 — 확률 값은 위 "바뀐 점"), 결과 연출·중복 코인·연타해도 한 장씩·꽝 없음(4), 판 시작하면 뽑기 화면이 탈의실과 같이 닫히는지(6), 휴대폰 버튼 44px·탭 3개(8·9), 두근두근 동안 배경 목록이 먼저 안 바뀌는지(10).

**E. 🐟 고등어 초밥 [신선] (m5-32)** — [`docs/qa/m5-32-fresh-mackerel.md`](qa/m5-32-fresh-mackerel.md) 1~9 + "Studio 체크리스트 추가" 10~14
- 준비: 판매 카드 확인(1)은 `fakeRobuxInStudio = true` + `unlockAllSkinsInStudio = false`(끝나면 둘 다 되돌림), 뽑기 확인(2)은 🛠 `tickets 99`. 움직임만 볼 때는 커밋 값 그대로 "입기 (Studio)".
- 꼭 볼 것: **팔딱이 "굉장히 팔딱"으로 느껴지는지, 너무 잦거나 정신없지 않은지**(4 — 바꾸고 싶으면 간격·각도를 숫자로), 월드 인형(단상·우승·탈락)에서 고등어만 움직이고 밥·얼굴은 가만히 있는지(5·12), Future 조명 윤기·꼬리 반짝이(6), 8명 모두 고등어일 때 프레임(7, 마이크로프로파일러 숫자), 이름표·👑·칭호가 4.8에 뜨고 다른 스킨으로 바꾸면 3.6으로 내려오는지(10·11), "@_@"가 보이는지(13), 레이스 뒤 카메라에서 앞 시야를 너무 가리지 않는지(14), 근접 정면에서 분홍 혀가 "빨간 띠"처럼 보이는지(8). 소리는 id가 없어 무음이 정상(9).

**F. 📱 터치 버튼 위치·크기 편집 (m5-41)** — [`docs/qa/m5-41-touch-button-layout.md`](qa/m5-41-touch-button-layout.md) 1~8
- 준비: Test → Device 에뮬레이터에서 휴대폰 가로(작은 화면)로 Play, `minPlayersToStart = 1`(커밋 값). PC 화면에서는 ⚙가 안 보이는 게 정상.
- 꼭 볼 것: **옮긴 점프 버튼이 리셋·라운드 시작·기기 변경 뒤에도 그 자리인지, 원래 자리로 돌아가거나 깜빡이지 않는지**(3, 가장 중요 — 되돌아가면 자체 점프 버튼으로 바꿔요), 금지 구역·겹침·최소 크기(4), 편집 중 입력이 안 나가는지·취소·기본값으로·프리셋(5), 라운드 중 잠금(6 — 카운트다운 중에는 열리는 게 지금 동작, B1), 휴대폰/태블릿 배치가 따로인지(7), 관전 ◀ ▶가 옮긴 버튼과 안 겹치는지(8). 재접속 유지는 퍼블리시 뒤 실제 휴대폰(USER-TODO C1).

> 알려진 한계 (P3): `docs/CHANGELOG.md` M5 "알려진 한계 · 보류" 참고.

## 4. 문제가 생기면
| 증상 | 해결 |
|---|---|
| `rojo: command not found` | 터미널을 새로 열어요. 그래도 안 되면 `~/.zshrc`에 `export PATH="$HOME/.rokit/bin:$PATH"` 추가 |
| `rokit install`이 신뢰 확인에서 멈춤 | 각 도구에 `y`. 또는 `rokit trust rojo-rbx/rojo` 처럼 하나씩 |
| `rojo plugin install`: Roblox를 못 찾음 | Studio를 한 번 실행해서 로그인한 다음 다시 |
| 플러그인이 버전이 안 맞는다고 함 | `rojo plugin install`을 다시 실행해서 플러그인을 CLI 버전에 맞춰요 |
| Connect가 안 됨 | `rojo serve`가 켜져 있는지, 포트가 플러그인 창의 포트와 같은지 확인 |
| 포트가 이미 쓰임 | 다른 `rojo serve`를 끄거나 `rojo serve --port 34873` 후 플러그인에서 포트 변경 |
| `luau-lsp: command not found` | 저장소 폴더에서 `rokit install`을 다시 해요 (M4에서 추가된 도구) |
| 타입 검사가 `sourcemap.json`을 못 찾음 | 같은 폴더에서 `rojo sourcemap default.project.json -o sourcemap.json`을 먼저 돌려요 |
| `stylua --check`가 모든 파일이 다르다고 함 | 줄바꿈 문제예요. `.gitattributes`가 LF로 고정하니까 `git add --renormalize .` 후 다시 체크아웃 |

## 5. 에이전트 협업·병렬 작업할 때
작업 흐름(스펙 → 개발 → QA → 문서), 에이전트별 파일 소유권, worktree 나누는 법은 [`docs/WORKFLOW.md`](WORKFLOW.md)에 있어요. 여기는 Studio 쪽에서 필요한 것만 적어요.

- **확인할 브랜치/worktree 하나만 연결해요.** worktree마다 Rojo 포트를 다르게 띄우고(`rojo serve --port 34872`, `34873`, `34874`, ...), Studio 플러그인 창의 포트를 그 번호로 맞춰서 Connect 해요. 한 Studio 창에는 한 worktree만 연결해요.
- **QA가 "사용자 확인 필요"로 남긴 항목**(M3는 3-8, M4는 3-9, M5는 3-10·3-11·3-12)은 `docs/qa/<스펙 id>.md`에 있어요. 문서화 담당이 스펙을 `done`으로 넘길 때 그 체크리스트를 이 문서의 마일스톤 절(3-x)로 옮겨요.
- 머지는 QA 통과 뒤 메인 세션에서 해요. 머지 후에는 `main`에서 `rojo serve`를 다시 켜고 3-2부터 확인해요.

## Windows 메모
- Rokit은 [릴리스 페이지](https://github.com/rojo-rbx/rokit/releases)에서 `windows-x86_64.zip`을 받아 `rokit.exe self-install` 하면 사용자 PATH에 `%USERPROFILE%\.rokit\bin`이 추가돼요. 터미널을 새로 열어야 적용돼요.
- 나머지 명령어는 macOS와 같아요.
