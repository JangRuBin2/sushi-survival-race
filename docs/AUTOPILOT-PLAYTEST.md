# AI 자동 플레이테스트 — Aura Autopilot (로블록스판)

- 작성: 2026-11-17 · 대상: 사용자 PC(Windows) + Roblox Studio + Claude Code
- 도구: [ramenvr/autopilot](https://github.com/ramenvr/autopilot) (Apache-2.0) — AI가 Studio에서 게임을 직접 플레이하며 탐색·테스트·확인하고 결과(판마다 녹화)를 남기는 플레이테스트 도구. 판을 거듭할수록 프로젝트 "기억"을 쌓아 더 잘해요.
- 출처: GitHub README, [`docs/roblox-studio-setup.md`](https://github.com/ramenvr/autopilot/blob/main/docs/roblox-studio-setup.md), [`docs/roblox-mcp.md`](https://github.com/ramenvr/autopilot/blob/main/docs/roblox-mcp.md) (2026-11-17 확인). 공식 사이트(tryaura.dev) 문서는 클라우드 세션에서 열리지 않아 **못 읽었어요** — 가격·보고서 저장 위치처럼 "확인 필요"로 적은 칸은 설치 화면이나 공식 문서에서 확인해 주세요.
- **클라우드 세션(Claude)에서는 못 돌려요.** Studio를 띄워야 하는 도구라 **사용자 PC의 Claude Code**에서 써요.

---

## 1. 이걸로 무엇을 하면 좋은가

| 쓸모 | 예 | 관련 할 일 |
|---|---|---|
| **Race 완주 시간 재기** | 맵마다 결승선까지 몇 초 | USER-TODO B3 "완주·한 판 시간 재기"(m5-40 AC9·AC12) — 지금까지 사람이 직접 재야 했던 것 |
| **맵 회귀 테스트** | 26개 맵을 돌며 "이상한 것 전부 찾기" (끼임·뚫림·안 보이는 벽·떨어져도 탈락 안 됨) | 맵을 고친 뒤마다 |
| **기능 확인** | Race 부활 3초, 공격 쿨다운, 로비 접기·방 만들기 창, 연습 모드 | DEV-SETUP 3-16~3-22의 일부 |
| **처음 하는 사람 시점** | 기억을 비운 상태로 "규칙을 모르는 사람"처럼 플레이 → 어디서 헤매는지 | 난이도·안내 문구 |

**못 하는 것 (지금 확인된 범위)**: 여러 명이 같이 하는 테스트(잡기·공격 상대, 방 참가 — 문서에 멀티 클라이언트 언급 없음), 정밀한 반사신경 플레이(입력마다 왕복 지연), 휴대폰 터치 UI, 클라우드·CI에서 자동 실행(Studio가 떠 있어야 함).

---

## 2. 설치 (한 번)

### 2.1 Autopilot
1. tryaura.dev/autopilot에서 **`Autopilot-<버전>-Roblox.zip`** 받아 압축 풀기.
2. 그 폴더에서 PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File agent_service\install.ps1
   ```
   uv·Python·Bun을 알아서 깔고 `autopilot` 명령을 만들어요. **설치 뒤 새로 연 터미널에서만** `autopilot`이 돼요.
3. `Autopilot.rbxmx`를 `%LOCALAPPDATA%\Roblox\Plugins`에 복사.

### 2.2 Studio MCP 서버 켜기
Studio 위쪽 맨 오른쪽 **Assistant** → **…** → **Settings**(또는 Manage MCP Servers) → **MCP Servers** 탭 → **Enable Studio as MCP server** 켜기 → "MCP Ready"가 되면 끝. (Full access는 필요 없어요.)

### 2.3 우리 게임 열기 (Rojo)
- 평소처럼 `rojo serve` + Studio Rojo 플러그인 Connect, **또는** `rojo build -o build.rbxl` 해서 그 파일을 열어요. Autopilot은 **지금 Studio에 열린 플레이스**를 플레이해요.
- 플러그인은 플레이스를 열 때 읽혀요 — 이미 열려 있었으면 다시 열기. 오른쪽에 **Autopilot** 창이 생겨요(Plugins → Autopilot으로 보이기/숨기기).
- Studio가 플러그인의 HTTP 요청·`127.0.0.1` 연결을 물으면 **허용**.

### 2.4 연결·로그인
1. **새 터미널**에서 `autopilot serve` — Autopilot을 쓰는 동안 **계속 켜 둬요**.
2. Studio → Plugins → Autopilot → **Create Account / Sign in** → "Agent service ready" → Continue.
3. **"Share runs"(플레이 기록 공유)는 끄는 걸 권장**(우리 게임 코드·화면이 외부로 나가지 않게). 나중에 바꾸는 메뉴 위치는 확인 필요.
4. 첫 10분 탐색 실행은 건너뛰어도 돼요(아래 3절에서 우리 게임에 맞게 따로 해요).
5. Claude Code 연결 (한 번): `autopilot connect claude` → 이후 Claude Code에서 **"Use Autopilot to …"**로 시켜요.

### 2.5 비용·계정
- Aura 계정 권장. **Claude 사용량은 사용자의 Claude 구독**에서, Aura는 "판단 모델" 사용량만 따로 센대요. 가격표는 확인 필요.
- 자기 키(BYOK)로 쓰려면 TypeSafe API 키 필요.

### 2.6 막히면
| 증상 | 해결 |
|---|---|
| 창이 "Waiting for the agent service…"에서 멈춤 | `autopilot serve`가 켜져 있는지 |
| 8765 포트가 이미 쓰임 | `autopilot serve --port 8770` + 창 Advanced → Agent service URL `ws://127.0.0.1:8770/v1/bridge` |
| 사진이 안 찍힘 | Studio를 완전히 껐다가 플레이스 다시 열기 |
| 채팅 창이 UI를 가림 | 게임 화면을 키우기 |
| 디스크가 참 | 사진 한 장당 약 0.8 MB가 `%LOCALAPPDATA%\Roblox\tmp-capture-storage`에 쌓임 — Studio 재시작으로 지워져요 |

---

## 3. 우리 게임에서 쓰는 법

### 3.1 테스트 전 준비 (Studio 설정)
- `Config.DEBUG.minPlayersToStart = 1`(커밋 값 그대로) — 혼자서도 방을 시작할 수 있어요.
- **특정 맵만 볼 때는 연습 모드가 가장 쉬워요**: 로비 **"연습"** 버튼 → "🏃 혼자 연습하기" 창 → 맵 버튼 → 바로 그 맵 한 판(보상 없음, Race는 떨어지면 3초 뒤 다시 출발). Autopilot에게 버튼 이름을 그대로 알려 주면 돼요.
- 한 판 전체 흐름(라운드 → 결승)을 볼 때는 "방 만들기" → "시작". 맵 순서를 고정하려면 관리자 🛠 패널 명령 `plan`(Studio 전용) 또는 `Config.DEBUG.forceMapPlan`(테스트 뒤 `nil`로 되돌리기).
- 실행 중에는 **Studio 게임 화면을 클릭하거나 키를 누르지 마세요** — Autopilot이 플레이를 직접 시작·종료해요. Studio가 맨 앞 창일 필요는 없어요.

### 3.2 요청 종류와 우리 게임 예시
Claude Code에서 아래처럼 시켜요. 맵·버튼 이름은 게임 화면 글씨 그대로(한국어) 따옴표로.

**① 탐색 (Exploration)** — 처음 몇 번은 기억 쌓기용
- `Use Autopilot to explore the lobby: try the "빠른 참가", "방 만들기", "연습" buttons, and the skin shop "🍣 스킨". Don't spend Robux.` (m6-14가 들어간 뒤에는 `the "접기" / "🔍 방 찾기" toggle`도 추가)
- `Use Autopilot to explore the practice mode: open "연습", pick "회전 벨트", and learn how to reach the finish line.`

**② 테스트 (Testing)** — 이상한 것 찾기
- `Use Autopilot to open "연습" → "간장 늪 & 와사비 산" and tell me everything that looks wrong (stuck spots, invisible walls, holes, places where falling doesn't respawn you, unreadable signs).`
- 맵 26개를 한 번씩 (아래 3.4 표 순서대로).

**③ 확인 (Verification)** — 정해진 동작이 맞는지
- `Use Autopilot to verify that in a Race practice run, falling off the course shows a 3-2-1 countdown and respawns you at the start after 3 seconds.` (m6-01)
- `Use Autopilot to verify that pressing F during a race shows the attack effect and that pressing F again within 8 seconds does nothing.` (m6-08)
- `Use Autopilot to verify that the lobby "접기" button hides the room list and the "🔍 방 찾기" button at the top brings it back.` (m6-14 — [PR #6](https://github.com/JangRuBin2/sushi-survival-race/pull/6) 병합 후)
- `Use Autopilot to verify that the "방 만들기" dialog closes with the X button and creates a room with the chosen player count and "비공개" setting.` (m6-14 — PR #6 병합 후)
- `Use Autopilot to verify that in a Survival practice run on "뜨거운 철판", staying alive until the timer ends counts as passing.` (m5-40, 75초)

**④ 목표 (Goal)** — 수치 재기
- `Use Autopilot with goal: in practice mode on "회전 벨트", reach the finish line as fast as possible. Run 3 times and report each clear time in seconds.` → Race 8개(+대형 3개)에 반복 → **완주 시간 재기(USER-TODO B3)를 대신**해요. 목표 빠른 사람 45~55초.
- `Use Autopilot with goal: survive until time runs out on "튀김 냄비 탈출" in practice mode. Report how many seconds you lasted and what knocked you off.`

### 3.3 "처음 하는 사람" 시점
기억이 쌓이면 점점 잘해요(= 길 아는 사람). **처음 하는 사람 시간**(목표 60~75초)은 기억을 비우고(Settings → Uninstall 때 메모리 삭제 선택 — 따로 비우는 메뉴는 확인 필요) 첫 판 기록을 쓰세요.

### 3.4 맵 목록 (연습 창 버튼 이름)
| 종류 | 버튼 이름 |
|---|---|
| Race | 회전 벨트 · 간장 늪 & 와사비 산 · 라멘 국물 급류 · 디저트 냉장고 · 방방 미로 · 등불 다리 건너기 · 깨끗하게! 설거지통 · 우주 회전초밥 |
| 대형 Race | 초밥집 카운터 대횡단 · 도시락 뚜껑 대탈출 · 팬트리 선반 대질주 |
| Survival | 뜨거운 철판 · 셰프의 도마 · 튀김 냄비 탈출 · 와르르 나무 블록 · 고양이 카페 캣타워 · 초대형 밥솥 · 수산시장 |
| 대형 Survival | 중식당 회전 원판 · 연회상 쟁반 쓸기 |
| Final | 회전 꼬치 쇼다운 · 연어알 폭탄 접시 · 줄다리기 발판 · 인형뽑기 기계 속 · 찻잎 정원 · 온천탕 인형뽑기 |

---

## 4. 결과 남기기
- Autopilot은 실행이 끝나면 결과(판마다 녹화)를 남겨요 — 저장 위치·형식은 확인 필요.
- 우리 쪽 기록은 **`docs/playtest/autopilot.md`**에 아래 양식으로 한 줄씩. Claude에게 "autopilot 결과 정리해줘" + 보고서 내용을 주면 정리하고, 버그는 QA 리포트(`docs/qa/`)·스펙으로 넘겨요.

```markdown
| 날짜 | 맵/기능 | 요청 종류 | 결과 (시간·성공/실패) | 발견한 문제 | 녹화/보고서 |
|---|---|---|---|---|---|
| 2026-11-xx | 회전 벨트 | 목표(3회) | 52s / 48s / 50s | 2번째 접시 가장자리에 끼임 1회 | (경로) |
```

## 5. 주의
- **플레이 기록 공유는 끄기**(2.4). 실험적인 Studio-MCP 전용 방식으로 돌릴 때는 `AUTOPILOT_SHARE=0`.
- Autopilot이 프로젝트 소스를 읽어요 — 실제 코드 목록 `src/server/CodeList.luau`(.gitignore)·관리자 설정은 Studio 플레이스에 들어가지만 외부 공유를 끄면 우리 PC 밖으로 나가지 않아요(공유 설정 확인 필요).
- 로벅스 결제 창이 뜨는 버튼(상점 구매)은 Studio에서는 가짜 결제지만 요청에 "Don't spend Robux"를 넣어 두세요.
- AI 판정은 틀릴 수 있어요 — "문제 발견"은 사람이 녹화로 한 번 보고 버그로 올려요.
- 스팀판(Unity 6)도 지원 대상(Unity 6000.0 이상)이라 `sushi-run-steam` 1단계가 에디터에서 열리면 같은 방식으로 회전 벨트 완주 시간 등을 재요.
