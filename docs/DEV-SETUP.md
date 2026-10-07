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
rojo, stylua, selene, lune 버전은 `rokit.toml`에 고정돼 있어요. Rokit이 그 버전 그대로 설치해 줘요.
```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```
설치가 끝나면 **터미널을 새로 열고** (PATH에 `~/.rokit/bin`이 추가돼요) 저장소 폴더에서:
```bash
rokit install        # 처음이면 각 도구를 신뢰할지 물어봐요 → 모두 y
rojo --version       # Rojo 7.7.1 이 나오면 성공
```

### 1-4. Rojo Studio 플러그인
```bash
rojo plugin install
```
`rojo` 명령어와 같은 버전(7.7.1)의 플러그인이 Studio 플러그인 폴더에 들어가요. Studio가 켜져 있었다면 껐다 켜요.

### 1-5. 에디터 (VS Code 추천, 선택)
확장 프로그램:
- **Luau Language Server** (JohnnyMorganz) — 자동 완성, 타입 검사
- **StyLua** — 저장할 때 자동 정렬
- **Selene** — 린트

## 2. 코드 검증 (Studio 없이, 커밋 전에 매번)
저장소 루트에서:
```bash
rojo build -o build.rbxl     # Rojo 프로젝트 구조가 맞는지 (build.rbxl은 커밋 안 함, .gitignore에 있음)
stylua --check src tests     # 포맷 검사. 고칠 때는: stylua src tests
selene src                   # 린트
lune run tests               # 순수 로직 테스트 (라운드 규칙·판정·순위, 방 로직, 관전, 맵 인터페이스·맵별 계산)
```
4개 모두 에러 없이 끝나야 해요. `lune run tests`는 `tests/*.spec.luau` 파일별 결과 뒤 마지막 줄에 `N passed, 0 failed`가 나와요 (M2 기준 18개 파일, 209개). `Config.DEBUG.forceMapPlan`을 바꾼 채로 두면 실패해요 (3-7).

## 3. Studio에서 게임 테스트

### 3-1. 코드 동기화 연결
1. 터미널에서 저장소 루트로 가서 `rojo serve` 를 켜 둬요. (`Rojo server listening: localhost:34872` 같은 줄이 나와요)
2. Studio에서 **새 Baseplate** 플레이스를 열어요.
3. 상단 **Plugins** 탭 → **Rojo** → 열린 창에서 **Connect**.
4. 연결되면 파일을 저장할 때마다 Studio에 바로 반영돼요. 테스트용 플레이스 파일은 저장하지 않아도 돼요 (코드는 전부 저장소에 있어요).

### 3-2. 기본 구조 확인 (M0, 연결할 때마다)
Explorer 창에서:
- [ ] `ServerScriptService` → `Server` (Script)와 그 안의 `RoomService`, `MatchService`, `RoundService`, `EliminationService`, `CharacterUtil`
- [ ] `ReplicatedStorage` → `Shared` 안의 `Config`, `Rules`, `RoundLogic`, `RoomLogic`, `SpectateLogic`, `Remotes`, `Types`, `Cleanup`, `maps`(안에 `MapTypes`, `RotatingBelt`, `RotatingBeltChopstick`, `SoySwamp`, `SoySwampLayout`, `SoySwampHazards`, `HotPlate`, `HotPlateLogic`, `SkewerShowdown`, `SkewerShowdownLogic`)
- [ ] `StarterPlayer` → `StarterPlayerScripts` → `Client` (안에 `ui` 폴더: `Lobby*`, `Room*`, `Hud*`, `Spectate*`)
- [ ] `Workspace`에 나무 바닥판 `Baseplate`와 `LobbySpawn`

**Play**(F5)를 눌러서:
- [ ] `ReplicatedStorage`에 `Remotes` 폴더가 생기고 안에 리모트 11개(RemoteFunction 6, RemoteEvent 5)가 있어요
- [ ] **Output** 창(View → Output)에 빨간 에러가 없어요
- [ ] 캐릭터가 나무 바닥 위 스폰에 서 있고, 화면에 로비 UI가 떠요 (3-4)

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
> - **관전**: 탈락하면 3초 뒤 자동 관전 + [로비로](관전만 끔, 방은 유지) → [👀 관전하기]로 다시 관전할 수 있어요. Race 통과자는 대기석에서 바로 관전하고 [내 캐릭터 보기]로 꺼요. ←/→ 또는 Q/E로 대상을 바꿔요. 우승 때는 모두의 카메라가 우승자를 비추고 순위표(1등~꼴등)가 떠요.
> - **HUD 진행 숫자**: Race는 "통과 n/목표 · 남은 인원 n", Survival·결승은 "남은 인원 n".
> - 시간(초)은 `Config`에 있어요: 매치 시작 3 · 라운드 소개 3 · 결과 5 · 우승 6 · 탈락 연출 3, 라운드 제한 Race 90 / Survival 60 / Final 90.

**혼자 (Play, F5)** — 라운드는 안 돌아요
- [ ] 방을 만들고 **시작!** → "매치 시작!" 배너가 3초 뜬 뒤, **라운드 없이 바로** "🏆 우승!" 배너에 내 이름이 떠요 (살아 있는 사람이 1명이라 바로 부전승이에요)
- [ ] 6초 뒤 방 대기실로 돌아오고, 같은 방에서 **시작!**을 다시 누를 수 있어요
- 혼자서 라운드를 끝까지 돌려 보려면 3-7의 `forceMapPlan`을 써요. 맵 하나만 빨리 보려면 3-6의 Command bar 방법을 써요.

**두 명 (Test → Clients and Servers, 2명)** — 결승만 가장 빨리 보는 방법
- [ ] 방장이 **시작!** → "매치 시작!" 뒤 **"라운드 1 / 3" 없이 바로 "라운드 3 / 3 · 회전 꼬치 쇼다운"** 소개가 떠요 (시작부터 2명이라 결승으로 건너뛰어요, 정상). 소개 동안 이미 무대 위에 서 있고 움직일 수 없어요
- [ ] 왼쪽 위 "남은 인원 2", 오른쪽 위 남은 시간(90초부터)
- [ ] 먼저 떨어진 사람은 "🥢 탈락했어요… (2등)", 남은 사람은 그 순간 "🏆 우승했어요!"를 받아요
- [ ] "🏆 우승!" 배너와 순위표(1·2등)가 두 화면 모두 같고, 두 카메라가 우승자를 비춰요. 우승자는 로비 스폰에 살아 있어요. 6초 뒤 방 대기실로 돌아와요

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
   - [ ] `Conveyors`, `Hazards`(`ChopstickStation` 2개), `FinishLine`, `EndWall` 파츠가 있어요
   - [ ] 출발 구간(넓음) → 벨트(어두운 금속 바닥) → 병목(간장 종지로 좁아짐) → 벨트(젓가락 2개) → 결승(네온 노란 줄) 순서로 바닥이 이어져요
   - [ ] 벽(반투명 유리색)이 양옆을 막고 있어서 코스 밖으로 안 떨어져요
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

실제 라운드에서는 `RoundService`가 이 맵을 지어서 돌려요 — 3-5에서 매치 흐름 안의 동작(목표 인원 통과 시 라운드 종료, 탈락 시 로비 스폰 복귀와 자동 관전)을 확인할 수 있어요. 다른 맵(`soy-swamp`, `hot-plate`, `skewer-showdown`)도 `Maps.get("<id>")`만 바꾸면 같은 방법으로 지어 볼 수 있어요. 다만 `hot-plate`와 `skewer-showdown`은 결승선이 없어서 `pass`가 불리지 않아요.

### 3-7. M2 확인 (한 판 MVP)
출처: `docs/qa/m2-07-full-match-integration.md`의 "한 번에 따라 하는 Studio 체크리스트". 결과(특히 실패·이상한 점)는 QA 리포트에 반영할 수 있게 메모해 두세요.

**강제 플랜 디버그 (`Config.DEBUG.forceMapPlan`)**
혼자이거나 특정 맵 순서를 보고 싶을 때 라운드 구성을 고정해요. **Studio에서만** 적용돼요.
1. `src/shared/Config.luau`의 `Config.DEBUG`에서 **로컬로만** 바꿔요 (저장하면 Rojo가 바로 반영해요):
   ```lua
   forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" } :: { string }?,
   ```
2. 맵 id 3개면 3라운드, 4개면 4라운드로 그 순서 그대로 돌아요. 종류 순서는 검사하지 않아서 Survival을 1라운드에 두는 것도 돼요. 맵 id: `rotating-belt`, `soy-swamp`, `hot-plate`, `skewer-showdown`.
3. 강제 플랜일 때는 **결승 건너뛰기가 없고, 혼자(생존자 1명)여도 모든 라운드를 끝까지 돌아요.** 혼자 F5로 방을 만들고 **시작!**하면 돼요.
4. 목록 길이가 3·4가 아니거나 없는 id가 있으면 무시돼요. 서버 Output에 `ignoring Config.DEBUG.forceMapPlan` 경고가 뜨고 평소 랜덤 구성으로 돌아요.
5. **끝나면 반드시 `forceMapPlan = nil :: { string }?,`으로 되돌려요.** 안 되돌리면 `lune run tests`가 실패하고, 커밋하면 안 돼요.

준비: `rojo serve` → Studio 연결. **매 단계마다 서버·클라이언트 Output에 빨간 에러가 없는지 봐요.** 여러 명은 Test 탭 → 플레이어 수 → Start (Clients and Servers). 스톱워치를 하나 준비해요.

**1. 혼자 기본 확인 (1분)**
- [ ] F5 → 방 만들기 → 시작 → 라운드 없이 "🏆 우승!"(내 이름), 6초 뒤 대기실

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

> 알려진 한계 (P3): 관전 중 ←/→는 카메라도 같이 돌려요(Q/E 권장). Studio에서는 관전 순서가 역순일 수 있어요(m2-06 S2, Studio 전용). 결승에서 낙하와 리셋이 같은 순간이면 리셋한 사람이 우승할 수 있어요(m2-07 I1, 기획 결정 대기).

## 4. 문제가 생기면
| 증상 | 해결 |
|---|---|
| `rojo: command not found` | 터미널을 새로 열어요. 그래도 안 되면 `~/.zshrc`에 `export PATH="$HOME/.rokit/bin:$PATH"` 추가 |
| `rokit install`이 신뢰 확인에서 멈춤 | 각 도구에 `y`. 또는 `rokit trust rojo-rbx/rojo` 처럼 하나씩 |
| `rojo plugin install`: Roblox를 못 찾음 | Studio를 한 번 실행해서 로그인한 다음 다시 |
| 플러그인이 버전이 안 맞는다고 함 | `rojo plugin install`을 다시 실행해서 플러그인을 CLI 버전에 맞춰요 |
| Connect가 안 됨 | `rojo serve`가 켜져 있는지, 포트가 플러그인 창의 포트와 같은지 확인 |
| 포트가 이미 쓰임 | 다른 `rojo serve`를 끄거나 `rojo serve --port 34873` 후 플러그인에서 포트 변경 |
| `stylua --check`가 모든 파일이 다르다고 함 | 줄바꿈 문제예요. `.gitattributes`가 LF로 고정하니까 `git add --renormalize .` 후 다시 체크아웃 |

## 5. 에이전트 협업·병렬 작업할 때
작업 흐름(스펙 → 개발 → QA → 문서), 에이전트별 파일 소유권, worktree 나누는 법은 [`docs/WORKFLOW.md`](WORKFLOW.md)에 있어요. 여기는 Studio 쪽에서 필요한 것만 적어요.

- **확인할 브랜치/worktree 하나만 연결해요.** worktree마다 Rojo 포트를 다르게 띄우고(`rojo serve --port 34872`, `34873`, `34874`, ...), Studio 플러그인 창의 포트를 그 번호로 맞춰서 Connect 해요. 한 Studio 창에는 한 worktree만 연결해요.
- **QA가 "사용자 확인 필요"로 남긴 항목**은 `docs/qa/<스펙 id>.md`에 있어요. 문서화 담당이 스펙을 `done`으로 넘길 때 그 체크리스트를 이 문서의 마일스톤 절(3-x)로 옮겨요.
- 머지는 QA 통과 뒤 메인 세션에서 해요. 머지 후에는 `main`에서 `rojo serve`를 다시 켜고 3-2부터 확인해요.

## Windows 메모
- Rokit은 [릴리스 페이지](https://github.com/rojo-rbx/rokit/releases)에서 `windows-x86_64.zip`을 받아 `rokit.exe self-install` 하면 사용자 PATH에 `%USERPROFILE%\.rokit\bin`이 추가돼요. 터미널을 새로 열어야 적용돼요.
- 나머지 명령어는 macOS와 같아요.
