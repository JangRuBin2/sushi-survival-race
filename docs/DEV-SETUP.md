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
- [ ] 캐릭터가 나무 바닥 위 스폰에 서 있어요

동기화 확인:
- [ ] `src/shared/Config.luau`에서 아무 숫자를 바꾸고 저장 → Studio의 `Shared.Config`를 열어 보면 바뀌어 있어요 (확인 후 되돌려요)

M0에서는 서비스가 비어 있어서 화면에는 바닥과 캐릭터만 보여요. 방 만들기와 라운드는 M1부터 동작해요.

### 3-3. 여러 명 테스트 (M1부터)
- 혼자 할 때: Studio에서는 `Config.DEBUG.minPlayersToStart`(1명)가 적용돼서 혼자서도 방을 시작할 수 있어요.
- 여러 명: Studio 상단 **Test** 탭 → **Clients and Servers**에서 플레이어 수(예: 4)를 고르고 **Start**. 서버 창 1개 + 플레이어 창 4개가 떠요.
- 끝낼 때는 서버 창에서 **Cleanup**.

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
