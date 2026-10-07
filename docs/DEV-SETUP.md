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
lune run tests               # 순수 로직 테스트 (라운드 수, 통과 인원, 라운드 구성, 맵 인터페이스)
```
4개 모두 에러 없이 끝나야 해요. `lune run tests`는 마지막 줄에 `N passed, 0 failed`가 나와요.

## 3. Studio에서 게임 테스트

### 3-1. 코드 동기화 연결
1. 터미널에서 저장소 루트로 가서 `rojo serve` 를 켜 둬요. (`Rojo server listening: localhost:34872` 같은 줄이 나와요)
2. Studio에서 **새 Baseplate** 플레이스를 열어요.
3. 상단 **Plugins** 탭 → **Rojo** → 열린 창에서 **Connect**.
4. 연결되면 파일을 저장할 때마다 Studio에 바로 반영돼요. 테스트용 플레이스 파일은 저장하지 않아도 돼요 (코드는 전부 저장소에 있어요).

### 3-2. 지금 단계(M0)에서 확인할 것
Explorer 창에서:
- [ ] `ServerScriptService` → `Server` (Script)와 그 안의 `RoomService`, `MatchService`, `RoundService`, `EliminationService`
- [ ] `ReplicatedStorage` → `Shared` 안의 `Config`, `Rules`, `Remotes`, `Types`, `Cleanup`, `maps`
- [ ] `StarterPlayer` → `StarterPlayerScripts` → `Client`
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
방이 출발하면 `MatchService`가 `RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting` 순서로 진행하고, 화면은 로비/방 대기실 대신 매치 HUD(위: 라운드 번호·맵 이름·규칙, 오른쪽 위: 남은 시간, 왼쪽 위: 통과 인원/목표/남은 인원, 가운데: 라운드 소개·결과·우승 배너, 아래: 내 통과/탈락/우승 안내)로 바뀌어요. 1라운드는 항상 `race-belt` 트랙이 만든 회전 벨트 맵(`rotating-belt`)이 떠요.

**혼자 (Play, F5)**
- [ ] 방을 만들고 **시작!** → "매치 시작!" 배너 뒤 "라운드 1 / N · 회전 벨트" 소개 배너가 뜨고, 잠깐 뒤 맵이 보이고 캐릭터가 Spawns 위치로 이동해요
- [ ] 라운드 중 왼쪽 위 "통과 n/목표" 숫자와 오른쪽 위 남은 시간이 줄어들어요
- [ ] 벨트 구간에 서 있으면 뒤로 밀리고, 젓가락 구간에서 경고 뒤 붙잡히면 화면이 잠깐 멈춰요 (3-6의 동작 상세 참고)
- [ ] 결승선을 통과하거나 탈락하면 화면 아래에 "✅ n번째로 통과했어요!" 또는 "🥢 탈락했어요… (n등)"이 떠요
- [ ] 탈락하면 캐릭터가 그 자리에 멈췄다가 몇 초 뒤 로비 스폰으로 돌아가요
- [ ] Studio는 혼자라 통과 목표(`targetCount`)가 1명이라, 결승선을 넘으면 바로 그 라운드가 끝나요. 시작 인원 4~8명이면 3라운드, 9명 이상이면 4라운드가 돌고, 남은 인원이 2명 이하가 되면 중간 라운드를 건너뛰고 바로 결승(Final 맵)으로 가요
- [ ] 결승에서 1명만 남으면 "🏆 우승!" 배너가 뜨고 몇 초 뒤 방 대기실로 돌아와요 (같은 멤버로 바로 "시작!"을 다시 누를 수 있어요)
- [ ] 서버 Output에 빨간 에러가 없어요

**여러 명 (Test → Clients and Servers, 4명)**
- [ ] 4명이 들어간 방에서 방장이 **시작!** → 4명 모두 화면이 매치 HUD로 바뀌고 같은 라운드 소개·결과·우승 배너를 동시에 봐요
- [ ] 라운드 중 한 명씩 결승선을 넘으면 각자 "n번째로 통과" 안내를 받고, 목표 인원이 다 통과하면 라운드가 끝나요 (나머지는 그 라운드 기준으론 탈락이 아니라 다음 라운드로 안 넘어가는 것 — Survival 맵이면 다름, GDD 참고)
- [ ] 우승 배너에 적힌 이름이 네 화면 모두 똑같아요 (서버가 정한 우승자 한 명을 모두에게 방송)
- [ ] 매치 중 한 명이 **Stop**으로 접속을 끊어도 서버 Output에 에러가 없어요 (`RoomService.onMemberLeft` → `MatchService`가 생존자 명단에서 빼요)
- [ ] 매치가 끝나면 전원 방 대기실로 돌아오고, 인원수가 줄어든 멤버 목록이 보여요

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
   - [ ] `Conveyors`, `Hazards`(`ChopstickStation` 2개), `FinishLine` 파츠가 있어요
   - [ ] 출발 구간(넓음) → 벨트(어두운 금속 바닥) → 병목(간장 종지로 좁아짐) → 벨트(젓가락 2개) → 결승(네온 노란 줄) 순서로 바닥이 이어져요
   - [ ] 벽(반투명 유리색)이 양옆을 막고 있어서 코스 밖으로 안 떨어져요
3. 다 봤으면 `model:Destroy()`로 치워요.

**동작 확인 (Play, F5 — `RoundContext`를 손으로 흉내 내서 start() 호출)**
`RoundService`가 아직 없어서 진짜 라운드 없이 아래 스크립트로 흉내 낼 수 있어요. Command bar에:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Players = game:GetService("Players")
local Cleanup = require(Shared.Cleanup)
local Maps = require(Shared.maps)
local map = Maps.get("rotating-belt")

local origin = CFrame.new(0, 10, 0)
local model = map.build(origin)
model.Parent = workspace

local cleanup = Cleanup.new()
local ctx = {
	model = model,
	origin = origin,
	rng = Random.new(),
	targetCount = 1,
	cleanup = cleanup,
	isActive = function() return true end,
	getRacers = function() return Players:GetPlayers() end,
	pass = function(player) print("[race-belt] PASS", player.Name) end,
	eliminate = function(player) print("[race-belt] ELIMINATE", player.Name) end,
}
map.start(ctx)
_G.beltCtx = ctx -- 정리할 때 쓰려고 전역에 보관
```
캐릭터를 `Spawns.Spawn01` 근처로 순간이동(또는 그냥 걸어서)시켜 확인해요.
- [ ] 벨트(어두운 금속 바닥) 구간에 서 있으면 진행 반대 방향(결승 반대쪽)으로 서서히 밀려나요
- [ ] 걸어서 버티면(WalkSpeed로 밀리는 속도를 이길 수 있게) 전진할 수 있어요 — 완전히 못 움직이면 안 돼요
- [ ] 병목 구간에서는 간장 종지 때문에 옆으로 못 빠져나가요
- [ ] 젓가락 구간에 가까워지면 빨간 경고 바닥이 1초간 떴다가, 젓가락(갈색 막대 2개)이 내려와요
- [ ] 경고가 뜬 자리에 서 있으면 젓가락이 내려오는 순간 3초간 WalkSpeed/JumpPower가 0이 돼요(Output에는 안 뜨지만 캐릭터가 안 움직여야 해요), 3초 뒤 풀려요
- [ ] 반대쪽 레인(젓가락이 없는 쪽)으로 피하면 안 붙잡혀요
- [ ] 결승선(노란 네온 줄)을 밟으면 Output에 `[race-belt] PASS (내 이름)`이 떠요 (한 번만)
- [ ] 코스 옆 벽을 넘어가거나 일부러 바닥 아래로 떨어지면(예: `origin`보다 40 studs 아래) Output에 `[race-belt] ELIMINATE (내 이름)`이 떠요
- [ ] 확인이 끝나면 `_G.beltCtx.cleanup:run()`으로 벨트/젓가락 루프를 멈추고 `_G.beltCtx.model:Destroy()`로 치워요 (안 하면 Heartbeat 연결이 계속 돌아요)

`RoundService`는 이미 이 맵을 실제 라운드에 연결해서 쓰고 있어요 — 3-5에서 실제 매치 흐름 안의 동작(목표 인원 통과 시 라운드 종료, 탈락 시 관전 전환)을 확인할 수 있어요.

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

## 5. 병렬 작업할 때 (M1~)
`CLAUDE.md`의 병렬 작업 계획대로 worktree마다 Rojo 포트를 다르게 써요:
`rojo serve --port 34872` (room-system), `34873` (match-flow), `34874` (race-belt).
Studio 플러그인 창에서 포트를 맞춰서 Connect 해요. 한 Studio 창에는 한 worktree만 연결해요.

## Windows 메모
- Rokit은 [릴리스 페이지](https://github.com/rojo-rbx/rokit/releases)에서 `windows-x86_64.zip`을 받아 `rokit.exe self-install` 하면 사용자 PATH에 `%USERPROFILE%\.rokit\bin`이 추가돼요. 터미널을 새로 열어야 적용돼요.
- 나머지 명령어는 macOS와 같아요.
