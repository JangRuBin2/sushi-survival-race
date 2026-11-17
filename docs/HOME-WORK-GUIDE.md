# 집에서 이어서 작업하기 (2026-11-17 기준)

> **결론: Roblox Studio만 깔아서는 안 돼요.** 우리 게임은 코드(Rojo)로 Studio에 넣는 구조라 **Git + Rojo**가 필요하고, AI 자동 플레이테스트(Autopilot)는 **PC에 설치한 Claude Code + Autopilot**이 필요해요. 예전에 이 PC에서 Studio 확인을 해 봤다면 1-1~1-3은 이미 돼 있을 수 있어요 — `rojo --version`이 나오면 1-3까지 건너뛰세요.

## 0. 오늘 할 일 (순서)
1. 게임 코드 받아서 Studio에 띄우기 (1절·2절)
2. **m6-14 확인** — 로비 접기·방 만들기 창·터치 버튼 ([`DEV-SETUP.md`](DEV-SETUP.md) 3-21·3-22) → 괜찮으면 GitHub에서 [PR #6](https://github.com/JangRuBin2/sushi-survival-race/pull/6) 병합
3. **Autopilot 설치·첫 실행** (3절) → 테스트 케이스 L01 → L02(연습 창) → R01(회전 벨트 완주 시간)
4. 결과를 Claude에게 전달 (4절)
5. (선택) 스팀판 Unity 시제품 열어 보기 (5절)

## 1. 한 번만 설치 (Windows)
| # | 무엇 | 어떻게 | 확인 |
|---|---|---|---|
| 1-1 | **Roblox Studio** | create.roblox.com → 설치 → **한 번 실행해서 로그인** (플러그인 폴더가 생겨요) | Studio 열림 |
| 1-2 | **Git for Windows** | git-scm.com → 기본값으로 설치 (Git Bash 포함) | `git --version` |
| 1-3 | **Rokit + Rojo** | [`DEV-SETUP.md`](DEV-SETUP.md) 1-3·1-4: Git Bash에서 Rokit 설치 → 터미널 새로 열기 → 저장소 폴더에서 `rokit install` (모두 y) → `rojo plugin install` | `rojo --version` → 7.7.1 |
| 1-4 | **Claude Code** (Autopilot용) | Claude 데스크톱 앱(Code 탭) 또는 PowerShell에서 `irm https://claude.ai/install.ps1 \| iex` → `claude` 실행 → 로그인(Claude 구독 계정) | `claude --version` |
| 1-5 | **Autopilot** | [`AUTOPILOT-PLAYTEST.md`](AUTOPILOT-PLAYTEST.md) 2절 — zip 받기 → `install.ps1` → 플러그인 복사 → Studio MCP 켜기 → `autopilot serve` → 로그인(공유 끄기) → `autopilot connect claude` | Studio 오른쪽 Autopilot 창 "ready" |
| (선택) | VS Code + Luau 확장 | DEV-SETUP 1-5 | |

## 2. 게임 코드 받아서 Studio에 띄우기
```bash
git clone https://github.com/JangRuBin2/sushi-survival-race.git
```
```bash
cd sushi-survival-race
```
**어떤 브랜치?** 이번에 만든 것들이 아직 `develop`에 다 안 들어갔어요.

| 브랜치 | 들어 있는 것 | 언제 |
|---|---|---|
| `claude/lobby-mobile-ux` | develop 최신 + **m6-14**(로비 접기·방 만들기 창·터치 버튼) | 오늘 게임 확인은 이걸로 |
| `claude/autopilot-guide` | develop 최신 + **이 문서·Autopilot 안내·테스트 케이스** | 문서 볼 때 (GitHub 웹에서 봐도 돼요) |
| `develop` | PR #6 병합 전 상태 | PR #6 병합 뒤에는 이걸로 |

```bash
git fetch origin
```
```bash
git checkout claude/lobby-mobile-ux
```
```bash
rokit install
```
```bash
rojo serve
```
Studio → 새 Baseplate(또는 아무 플레이스) 열기 → **Plugins → Rojo → Connect** → 연결되면 ▶ **Play**. (자세히: DEV-SETUP 3-1)
- 연결 대신 파일로: `rojo build -o build.rbxl` → Studio에서 `build.rbxl` 열기.

## 3. Autopilot 첫 실행
1. 터미널 하나에 `rojo serve`, 다른 터미널에 `autopilot serve` — **둘 다 켜 둔 채로**.
2. Studio에 게임이 열려 있고 오른쪽 Autopilot 창이 준비됨을 확인.
3. 저장소 폴더에서 `claude` 실행 → 아래를 그대로 붙여 넣기:
   ```
   Use Autopilot to explore the lobby: walk around the sushi restaurant, then try the "빠른 참가", "방 만들기", "연습" buttons and close each window again. Don't spend Robux. Report what you did, what happened, and anything that looked wrong.
   ```
4. 실행 중에는 **Studio 게임 화면을 만지지 마세요.**
5. 다음 케이스: [`docs/playtest/autopilot-cases.md`](playtest/autopilot-cases.md)의 L02 → R01(회전 벨트 3번 완주 시간) → 나머지 맵.

## 4. 결과를 Claude에게 넘기기
- **이 대화(claude.ai/code 클라우드 세션)에서 이어서** 말하면 돼요 — 저장소·문서가 다 연결돼 있어요. 예: "autopilot R01 결과: 52초/48초/50초, 두 번째 접시에서 끼임" + 보고서 내용 붙여 넣기 → 제가 `docs/playtest/autopilot.md`에 기록하고 버그는 QA 리포트·수정으로.
- m6-14 확인 결과("접기 잘 됨", "방 만들기 창 글씨 잘림" 등)도 같은 방식으로. 콘솔 빨간 오류는 그대로 복사.
- PC의 Claude Code(Autopilot 돌리는 쪽)에서 직접 고쳐도 되지만, 그때는 **브랜치를 따서 push**하고 이 대화에 알려 주세요(같은 파일을 동시에 고치지 않게).

## 5. (선택) 스팀판 Unity 시제품
- 저장소 [`JangRuBin2/sushi-run-steam`](https://github.com/JangRuBin2/sushi-run-steam) → `docs/SETUP.md` (Unity Hub + **Unity 6.3 LTS**, 템플릿에서 설정 폴더 3개 복사 → **SushiRun → Create Feel Prototype Scene** → Play).
- 해 보고 [`docs/specs/s1-01-feel-prototype.md`](https://github.com/JangRuBin2/sushi-run-steam/blob/main/docs/specs/s1-01-feel-prototype.md) "에디터에서 볼 것" 1~6 느낌을 알려 주세요.

## 6. 막히면
| 증상 | 해결 |
|---|---|
| `rojo: command not found` | 터미널 새로 열기 → 그래도 안 되면 DEV-SETUP 4절 |
| Rojo Connect 안 됨 | `rojo serve` 켜져 있는지, 포트(34872) 같은지 |
| Autopilot 창이 "Waiting for the agent service…" | `autopilot serve` 켜져 있는지 |
| `autopilot`/`claude` 명령이 없음 | 설치 뒤 **새로 연** 터미널에서 |
| Claude Code에서 Autopilot이 안 보임 | `autopilot connect claude` 다시 → `claude` 다시 실행 |
| 그 밖 | 화면 캡처나 오류 문구를 이 대화에 붙여 넣기 |
