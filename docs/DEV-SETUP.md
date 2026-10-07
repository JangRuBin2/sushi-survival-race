# 개발 환경 세팅과 테스트 방법 (macOS 기준)

새 컴퓨터에서 이 저장소로 개발을 이어갈 때 순서대로 따라 하면 돼요. Windows 메모는 맨 아래에 있어요.

## 1. 한 번만 하는 설치

### 1-1. Roblox Studio
1. https://create.roblox.com 에서 Roblox Studio를 받아 설치해요.
2. **한 번 실행해서 로그인**해요. 이때 플러그인 폴더가 만들어져요 (안 하면 3-1의 플러그인 설치가 실패해요).

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
lune run tests               # 순수 로직 테스트 (라운드 수·통과 인원·라운드 구성, 방 로직, 맵 인터페이스)
```
4개 모두 에러 없이 끝나야 해요. `lune run tests`는 파일별 결과(`rules`, `room`, `maps`) 뒤 마지막 줄에 `N passed, 0 failed`가 나와요 (M1 기준 38개).

## 3. Studio에서 게임 테스트

### 3-1. 코드 동기화 연결
1. 터미널에서 저장소 루트로 가서 `rojo serve` 를 켜 둬요. (`Rojo server listening: localhost:34872` 같은 줄이 나와요)
2. Studio에서 **새 Baseplate** 플레이스를 열어요.
3. 상단 **Plugins** 탭 → **Rojo** → 열린 창에서 **Connect**.
4. 연결되면 파일을 저장할 때마다 Studio에 바로 반영돼요. 테스트용 플레이스 파일은 저장하지 않아도 돼요 (코드는 전부 저장소에 있어요).

### 3-2. 기본 구조 확인 (M0, 연결할 때마다)
Explorer 창에서:
- [ ] `ServerScriptService` → `Server` (Script)와 그 안의 `RoomService`, `MatchService`, `RoundService`, `EliminationService`
- [ ] `ReplicatedStorage` → `Shared` 안의 `Config`, `Rules`, `RoomLogic`, `Remotes`, `Types`, `Cleanup`, `maps`(안에 `MapTypes`, `RotatingBelt`, `RotatingBeltChopstick`)
- [ ] `StarterPlayer` → `StarterPlayerScripts` → `Client` (안에 `ui` 폴더)
- [ ] `Workspace`에 나무 바닥판 `Baseplate`와 `LobbySpawn`

**Play**(F5)를 눌러서:
- [ ] `ReplicatedStorage`에 `Remotes` 폴더가 생기고 안에 리모트 11개(RemoteFunction 6, RemoteEvent 5)가 있어요
- [ ] **Output** 창(View → Output)에 빨간 에러가 없어요
- [ ] 캐릭터가 나무 바닥 위 스폰에 서 있고, 화면에 로비 UI가 떠요 (3-4)

동기화 확인:
- [ ] `src/shared/Config.luau`에서 아무 숫자를 바꾸고 저장 → Studio의 `Shared.Config`를 열어 보면 바뀌어 있어요 (확인 후 되돌려요)

### 3-3. 여러 명 테스트 하는 법
- **혼자(Play, F5)**: Studio에서는 `Config.DEBUG.minPlayersToStart`(1명)가 적용돼서 혼자서도 방장 시작 버튼을 누를 수 있어요. 실제 서버는 4명부터예요.
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

### 3-5. 매치 플로우 확인 (M1 match-flow + race-belt)
방이 출발하면 `MatchService`가 `RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting` 순서로 진행하고, 화면은 로비/방 대기실 대신 매치 HUD(위: 라운드 번호·맵 이름·규칙, 오른쪽 위: 남은 시간, 왼쪽 위: 통과 인원/목표/남은 인원, 가운데: 라운드 소개·결과·우승 배너, 아래: 내 통과/탈락/우승 안내)로 바뀌어요.

> **지금 맵 풀에는 회전 벨트(`rotating-belt`, Race) 하나뿐이에요.** 그래서 2라운드·결승을 포함한 모든 라운드가 회전 벨트로 돌아요. 결승인지는 맵 종류가 아니라 "마지막 라운드인지"로 정해서, 회전 벨트로 도는 결승에서도 1등은 "🏆 우승했어요!"를 받아요.
>
> 라운드 사이 위치: 라운드가 끝나면 맵이 바로 치워져요. 그 전에 **통과자는 로비 스폰으로 옮겨져** 결과·우승 배너 동안 로비에서 기다리다가, 다음 라운드가 시작되면 새 맵 스폰으로 옮겨져요. **탈락자**는 그 자리에 3초 멈췄다가 로비 스폰으로 돌아가요. 이때 걷기·점프 값도 원래대로 돌아와요.
>
> 결승선 판정: 노란 결승선(코스 끝 벽 4스터드 앞)을 몸이 지나가면 통과예요. 점프해서 넘어도 통과고, 코스 끝은 벽으로 막혀 있어요.
>
> 결승 건너뛰기: 결승 전에 남은 사람이 **2명 이하**면 남은 라운드를 건너뛰고 바로 결승으로 가요 (GDD 4.1). 라운드 소개 3초 사이에 누가 나가서 2명 이하가 돼도 그 라운드 대신 결승 소개가 이어서 떠요.
>
> 시간(초)은 `Config`에 있어요: 매치 시작 3 · 라운드 소개 3 · 결과 5 · 우승 6 · 탈락 연출 3, 라운드 제한 Race 90 / Survival 60 / Final 90.

**혼자 (Play, F5)** — 라운드는 안 돌아요
- [ ] 방을 만들고 **시작!** → "매치 시작!" 배너가 3초 뜬 뒤, **라운드 없이 바로** "🏆 우승!" 배너에 내 이름이 떠요 (살아 있는 사람이 이미 1명이라 매치가 바로 끝나요)
- [ ] 6초 뒤 방 대기실로 돌아오고, 같은 방에서 **시작!**을 다시 누를 수 있어요
- [ ] 서버 Output에 빨간 에러가 없어요
- 라운드 안의 동작(맵, 벨트, 젓가락, 결승선)을 혼자 보고 싶으면 3-6의 Command bar 방법을 써요.

**두 명 (Test → Clients and Servers, 2명)** — 결승 한 판만 가장 빨리 보는 방법
- [ ] 방장이 **시작!** → "매치 시작!" 뒤 **"라운드 1 / 3" 없이 바로 "라운드 3 / 3"(결승)** 소개가 떠요. 시작부터 2명이라 결승으로 건너뛰어요 (정상). 가운데 배너에 "회전 벨트"와 규칙 한 줄이 뜨고, 3초 뒤 캐릭터가 맵의 Spawns 위치로 이동해요
- [ ] 왼쪽 위 "통과 0/1 · 남은 인원 2", 오른쪽 위 남은 시간(90초부터)이 바뀌어요
- [ ] 벨트 구간에 서 있으면 뒤로 밀리고, 젓가락 구간에서 경고 뒤 붙잡히면 3초간 못 움직여요 (3-6의 동작 상세 참고)
- [ ] 먼저 결승선을 넘은 사람 화면 아래에 "🏆 우승했어요!"가 뜨고 로비 스폰으로 옮겨져요. 다른 사람은 그 순간 "🥢 탈락했어요… (2등)"이 뜨며 멈췄다가 3초 뒤 로비 스폰으로 돌아가요
- [ ] 결승선 바로 앞에서 **점프해서 넘어도** 통과로 판정되고, 코스 끝 벽에 막혀 밖으로 떨어지지 않아요
- [ ] "🏆 우승!" 배너에 이긴 사람 이름이 두 화면 모두 똑같이 뜨고, 그동안 우승자는 로비에 **살아 있어요**. 6초 뒤 방 대기실로 돌아와요
- 1라운드(목표 인원이 있는 라운드)를 보려면 3명 이상이 필요해요.

**여러 명 (Test → Clients and Servers, 4명)** — M1 완료 기준 (방에서 4명 시작 → 1라운드 → 통과자 집계)
- [ ] 정원 4명 방에 4명이 다 들어가면 10초 뒤 자동 시작돼요 (또는 방장이 **시작!**). 4명 모두 화면이 매치 HUD로 바뀌고, 같은 라운드 소개·결과·우승 배너를 동시에 봐요
- [ ] "라운드 1 / 3" 소개 뒤 왼쪽 위가 "통과 0/2 · 남은 인원 4"예요 (4명 × 60% = 2.4 → 2명 통과)
- [ ] 한 명씩 결승선을 넘으면 각자 "✅ n번째로 통과했어요!"를 받아요. **목표 인원(2명)이 통과하는 순간 라운드가 끝나고**, 못 넘은 나머지 2명은 그 자리에서 탈락해요 (GDD 5.2 "결승선에 목표 인원이 들어오면 종료" + 4.1 "매 라운드 최소 1명은 꼭 탈락"). Survival 맵은 반대로 "버틴 사람이 통과"라 다르게 동작해요
- [ ] 탈락 등수: 결승선에 **더 가까이 갔던 사람이 3등**, 덜 간 사람이 4등이에요
- [ ] 라운드가 끝나면 통과자 2명은 **죽지 않고** 로비 스폰으로 옮겨져 결과 배너("라운드 종료!")를 봐요. 남은 인원이 2명이라 2라운드를 건너뛰고 "라운드 3 / 3"(결승)으로 가고, 결승 시작 때 새 맵 스폰으로 옮겨져요
- [ ] 우승 배너에 적힌 이름이 네 화면 모두 똑같아요 (서버가 정한 우승자 한 명을 모두에게 방송)
- [ ] **시간 종료**: 아무도 결승선을 넘지 않고 90초가 지나면 가장 멀리 간 2명이 통과하고, 나머지는 덜 간 사람이 더 큰 숫자 등수를 받아요
- [ ] **젓가락 잡힘 복구**: 젓가락에 잡혀 있는 동안 라운드가 끝나 탈락한 사람도, 로비로 돌아간 뒤 걷기·점프가 정상이에요
- [ ] 매치 중 한 명이 **Stop**으로 접속을 끊어도 서버 Output에 에러가 없고, 남은 인원 표시가 줄어요 (`RoomService.onMemberLeft` → `MatchService`가 생존자 명단에서 빼요). 방장이 끊어도 매치는 이어지고, 끝난 뒤 대기실에서 다음 사람이 👑예요
- [ ] 매치가 끝나면 전원 방 대기실로 돌아오고, 인원수가 줄어든 멤버 목록이 보여요

**다섯 명 (Test → Clients and Servers, 5명)** — 소개 중 이탈
- [ ] 5명으로 시작하면 1라운드 목표가 3명이에요 ("통과 0/3"). 3명이 통과하면 "라운드 2 / 3" 소개가 떠요
- [ ] "라운드 2 / 3" 소개(3초) 사이에 한 명이 **Stop**으로 접속을 끊으면, 2라운드를 하지 않고 "라운드 3 / 3"(결승) 소개가 이어서 떠요

> 알려진 한계 (M1 QA P3, `docs/qa/m1-retro.md`):
> - 통과자가 로비에서 기다리는 동안 리셋해서 다음 라운드 시작 순간에 리스폰 중이면, 시작하자마자 탈락할 수 있어요 (N1).
> - 정원이 찬 방은 매치가 끝나고 대기실로 돌아오면 자동 시작 카운트다운이 다시 걸려요. 의도한 동작인지는 기획이 정할 예정이에요.

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

실제 라운드에서는 `RoundService`가 이 맵을 지어서 돌려요 — 3-5에서 매치 흐름 안의 동작(목표 인원 통과 시 라운드 종료, 탈락 시 로비 스폰 복귀)을 확인할 수 있어요. 관전 모드는 아직 없어요(M2).

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
