# REFERENCE — 결승 시간 초과·연장전, 테스트용 관리자 기능

조사일: **2026-10-08** (planner). M5 스펙 `docs/specs/m5-01-final-overtime.md`, `docs/specs/m5-02-admin-skin-preview.md`의 근거예요.
표기: **원문 확인** = WebFetch로 그 페이지에서 직접 읽음 / **검색 요약** = 검색 결과 요약만 보고 원문은 못 엶(403·402 등) / **확인 못 함** = 찾지 못함. 추정은 "추정"이라고 따로 적어요.

---

## 1. 지금 우리 결승 (조사 전 상태)
- 결승(마지막 라운드)은 생존형. 1명 남으면 즉시 우승, 같은 판정 틱에 모두 떨어지면 더 높이 있던 낙하자, 리셋·퇴장은 같은 묶음 낙하보다 나쁜 등수 (`src/shared/RoundLogic.luau` 머리 주석).
- **90초(`Config.TimeLimit.Final`)가 지나면 그 순간 가장 높이 있는 사람이 우승**. 무대가 평평해서 서 있는 두 사람의 "높이"는 거의 같고, 사실상 그 순간 점프 중이던 사람이나 무작위로 정해져요 → 납득하기 어려운 판정.
- 회전 꼬치 쇼다운: 20초부터 8초마다 조각을 가져가 2조각에서 멈췄다가, 60초 서든데스부터 3초마다 → 약 63초에 경고가 시작되는 마지막 손으로 **1조각만 남음**(약 66초). 그 뒤 90초까지는 꼬치 최고 속도(낮은 150°/s, 높은 120°/s)만 계속돼요. 두 명이 계속 잘 뛰면 90초 판정까지 가요.

## 2. 사례 비교 — 결승·라스트맨스탠딩의 시간 초과 처리

| # | 게임 / 모드 | 시간 제한 | 시간이 끝나면 | 끝나지 않게 하는 장치 | 근거 수준 |
|---|---|---|---|---|---|
| A | **Fall Guys** Hex-A-Gone (결승) | 숨은 5:00 | **남은 사람 전원 우승**(각자 화면에 왕관) | 밟은 타일이 사라짐, 층이 내려감 | 원문 확인 (Inverse 2020-09-02) |
| B | **Fall Guys** 결승 전반 (Royal Fumble 제외) | 숨은 5:00 | 남은 사람 전원 승리·왕관 ("7명이 끝까지 살아남은 것도 봤다") | 맵마다 다름 | 원문 확인 (Steam 토론 2020-10-15, 사용자 증언) |
| C | **Fall Guys** Jump Showdown (결승, **우리 꼬치 쇼다운의 원형**) | (B의 5:00) | (B와 같음) | 돌아가는 막대 두 개 + **발판이 떨어져 결국 2개만 남음**, 막대 가속 | 발판·가속은 검색 요약, 제거 사유는 원문 확인 |
| C' | 〃 출시 직후 일시 제거 (2020-08) | — | — | **가장자리 매달리기("infinite hang")로 끝없이 버티는 문제** 때문에 내림 → 안전한 자리가 남으면 판이 안 끝난다는 교훈 | 원문 확인 (Gfinity 2020-08-20) |
| D | **Fall Guys** Royal Fumble (꼬리잡기 결승) | 1:30 (2:00에서 줄임, 2020-08 패치) | 그 순간 꼬리를 가진 사람 1명 우승 | 시간 자체가 판정 | 검색 요약 (PC Gamer·EGM 원문 못 엶) |
| E | **Fall Guys** Thin Ice (결승) | 5:00 | 남은 사람 전원 우승 | 얼음이 깨짐 | 검색 요약 (Fandom 402) |
| F | **Stumble Guys** Laser Tracer Endless (패치 0.75) | **없음** | — "마지막 플레이어가 탈락할 때까지 멈추지 않는다", 생존 시간을 재는 타이머 | 시간이 갈수록 레이저가 늘고 빨라짐 | 원문 확인 (stumbleguys.com 2024-07-10) / 레이저 단계는 검색 요약 |
| G | **Stumble Guys** Stumblewood (팀) | 있음 | 숫자가 많은 팀 승리, **동점이면 연장전** | — | 원문 확인 (stumbleguys.com 2025-03-06) |
| H | **Super Bomberman** 배틀 | 2:00 | **무승부, 트로피 없음**. 같은 순간 전원 폭사도 무승부 | 1:30에 "Hurry Up!" → 벽이 바깥부터 떨어져 경기장이 좁아짐(맞으면 즉사) | 원문 확인 (Wikipedia "Super Bomberman") |
| I | Roblox **Circle Clash** | 라운드 타이머 | "타이머가 끝날 때 원 안에 있어야" 함, 마지막 생존자 승리 | 라운드마다 원이 줄어듦 | 원문 확인 (roblox.com 게임 페이지) |
| J | Roblox **Murder Mystery 2** | 3:00 | 살아남은 무고한 사람 쪽 승리(생존자 전원) | — | 검색 요약 |
| K | Roblox **Natural Disaster Survival** | 재난 1개 길이 | 재난이 끝날 때 살아 있는 사람 전원 생존 | — | 검색 요약 (게임 페이지에는 규칙 없음) |
| L | Roblox **Epic Minigames** (Pyre Pit 등 생존 미니게임) | 60초 | 버틴 사람이 라운드 승리 | — | 검색 요약 (Fandom 402) |

### 읽은 것
1. **시간 초과 처리는 세 갈래**: ① 남은 사람 **공동 우승**(Fall Guys 결승, Roblox 생존 게임 J·K·L) ② **무승부·보상 없음**(Bomberman) ③ 그 순간의 **기준 1명**(Royal Fumble = 꼬리, 우리 지금 = 높이).
2. **시간 제한이 실제로 쓰이는 일은 드물게** 만든다: Fall Guys는 숨은 5분(결승이 보통 1~2분에 끝남), Stumble Guys Endless는 아예 없음. 대신 **맵이 점점 좁아지거나 빨라져서** 결판이 나게 한다(A·C·F·H·I). Bomberman은 "Hurry Up" 경고 → 경기장 축소라는 **연장전 단계를 눈에 보이게** 한다.
3. **안전한 자리가 하나라도 남으면 판이 끝나지 않는다** (Jump Showdown의 infinite hang, C'). 결승 맵은 결국 **설 곳 자체를 없애야** 한다.
4. 로블록스 생존 게임은 "끝까지 버틴 사람 = 이긴 사람"이 일반적이라(J·K·L) 어린 이용층이 납득하기 쉽다. 반대로 무승부·보상 없음(H)은 억울함이 크다 (추정: 로블록스 주 이용층이 어린 연령이라는 점은 `docs/REFERENCE-roblox-monetization.md` 1절).

## 3. 우리 게임에 쓸 규칙 (m5-01 기본값, 사용자 수정 가능)

| 시점 (출발 기준) | 일어나는 일 | 근거 |
|---|---|---|
| 0~90초 | 지금과 같음 (꼬치 가속, 셰프 손, 60초 서든데스 → 1조각) | — |
| **90초 = 연장전 시작** | 화면에 "⚡ 연장전! 접시가 무너져요" + 경적. 꼬치가 더 빨라지고, 남은 접시가 **바깥 줄부터 안쪽으로 무너져요**(줄마다 1초 빨간 경고) | H(Hurry Up → 축소), C·F(가속) |
| **110초 = 바닥 0** | 설 곳이 하나도 없어요 → 늦게 떨어진 사람이 우승. 같은 판정 틱이면 지금 규칙(더 높이, 리셋·퇴장은 더 나쁨) | C'(안전한 자리 금지), 지금 규칙 유지 |
| **150초 = 안전 상한** (정상 플레이에선 오지 않음) | 남은 사람 중 **가장 높이 있는 1명 우승**(지금 90초 규칙을 그대로 옮김), 같으면 무작위 | 우승자 1명 불변식(코인·단상·우승 연출) 유지 |

- 연장전은 **결승(마지막 라운드)에서만**. Race 시간 종료(진행도 순 채우기)·Survival 시간 종료(버틴 사람 전원 통과)는 그대로 — 둘 다 이미 결정적으로 끝나고, Survival은 Fall Guys 서바이벌과 같은 방식(GDD 5.2).
- **공동 우승을 기본값으로 하지 않은 이유**: 우리 시스템은 "우승자 = Won을 받은 1명"(순위표 1등, 코인 +100, 로비 단상 1명, 우승 연출 1명)이 전제예요. 바닥이 사라지는 연장전이 있으면 150초 상한까지 갈 일이 사실상 없어서, 큰 변경 없이 1명 규칙을 지켜요. 사용자가 원하면 대안으로 남겨요(아래).

### 사용자 선택지 (150초 안전 상한의 판정)
| 안 | 내용 | 장점 | 단점 |
|---|---|---|---|
| **1 (기본값)** | 가장 높이 있는 1명 우승 | 지금 코드·불변식 그대로 | 거의 무작위 |
| 2 | 남은 사람 **공동 우승** (Fall Guys A·B) | 로블록스 생존 게임 문화와 같음, 억울함 없음 | Standings·Victory·코인·단상을 여러 명용으로 바꿔야 함 (큰 변경) |
| 3 | 무승부, 우승자 없음 (Bomberman H) | 단순 | 어린 이용층에 억울함 큼 |

## 4. 테스트용 관리자 기능 — 권한 판단 관행

| 항목 | 내용 | 근거 수준 |
|---|---|---|
| 비밀번호를 게임에 넣으면 안 되는 이유 | Roblox 커뮤니티 기준은 "비밀번호 또는 접근 토큰"을 공유하면 안 되는 개인정보로 들고, 남의 계정 접근 시도·피싱을 금지해요. 비밀번호를 코드·리모트·클라이언트에 두면 저장소(GitHub)·클라이언트 스크립트로 새어 계정 탈취로 이어져요 | 원문 확인 (about.roblox.com/community-standards) |
| 클라이언트를 믿지 않기 | "악용자는 자기 로컬 상태와 네트워크를 완전히 통제한다 … 클라이언트 쪽 강제에 기대는 보안은 결국 뚫린다", 서버가 규칙·진행의 최종 판단자 | 원문 확인 (create.roblox.com/docs 보안 전술) |
| 관리자 지정 방식 | Roblox 공식 채팅 관리자 명령 모듈은 **UserId 목록** 또는 **그룹 랭크**로 권한을 줘요. 이름은 바뀔 수 있어서 UserId를 써요 | 원문 확인 (DevForum 2022-01-15) / 이름 변경 이유는 검색 요약 |
| 내 UserId 찾기 | 웹에서 내 프로필을 열면 주소가 `https://www.roblox.com/users/<숫자>/profile` — 그 숫자 | 검색 요약 (여러 안내 글이 같은 방법) |
| Studio 판정 | `RunService:IsStudio()`는 서버에서 판단 — Studio 테스트에서만 참이고 퍼블리시된 서버에선 거짓 (이미 `Config.DEBUG` 적용 방식으로 쓰는 중, CLAUDE.md "규칙") | 프로젝트 관행 |

→ m5-02 기본값: **Studio이거나, 서버에만 있는 UserId 허용 목록에 있거나, 게임 소유자(개인 소유일 때)**만 관리자. 비밀번호·키 입력 없음. 관리자 UI는 관리자에게만 만들고, 서버 리모트가 권한을 다시 확인해요.

## 5. 출처 (확인일 2026-10-08)
- Inverse, "Secret Hex-a-Gone mechanic in Fall Guys breaks the game wide open" (2020-09-02) — https://www.inverse.com/gaming/fall-guys-hex-a-gone-strategy-glitch-tips-tie (원문 확인)
- Steam Community, Fall Guys 토론 (2020-10-15) — https://steamcommunity.com/app/1097150/discussions/0/4477100383801786545 (원문 확인, 사용자 증언)
- Fall Guys Wiki "Final" — https://fallguysultimateknockout.fandom.com/wiki/Final (402, 검색 요약만)
- Gfinity, "Mediatonic Removes Jump Showdown Following Exploit" (2020-08-20) — https://www.gfinityesports.com/article/fall-guys-jump-showdown-removed-mode-ps4-pc-infinite-hang (원문 확인)
- Prima Games, Jump Showdown 재작업 글 — https://primagames.com/gaming/fall-guys-dev-rework-stage (403, 검색 요약: 발판이 2개 남을 때까지 떨어짐, 막대 가속)
- PC Gamer / GameSpot, 2020-08-20 패치 (Royal Fumble 2:00 → 1:30) — https://www.pcgamer.com/fall-guys-patch-notes/ , https://gamespot.com/articles/fall-guys-update-prevents-back-to-back-team-games-/1100-6481195/ (원문 못 엶, 검색 요약)
- Stumble Guys Patch 0.75 "Laser Tracer Endless" (2024-07-10) — https://www.stumbleguys.com/news/update75 (원문 확인)
- Stumble Guys "Stumblewood" (2025-03-06) — https://www.stumbleguys.com/news/stumblewood (원문 확인)
- Wikipedia, "Super Bomberman" 배틀 모드 — https://en.wikipedia.org/wiki/Super_Bomberman (원문 확인)
- Roblox, Circle Clash 게임 페이지 — https://www.roblox.com/games/15105797247 (원문 확인)
- Murder Mystery 2 규칙 — https://murder-mystery-2.fandom.com/wiki/Innocent , https://cyberpost.co/what-are-the-rules-in-mm2-roblox/ (원문 못 엶, 검색 요약)
- Natural Disaster Survival — https://www.roblox.com/games/189707/Natural-Disaster-Survival (설명에 규칙 없음), https://www.sportskeeda.com/roblox-news/how-win-every-round-roblox-natural-disaster-survival (405, 검색 요약)
- Epic Minigames Pyre Pit — https://typical-games.fandom.com/wiki/Pyre_Pit?oldid=4079 (402, 검색 요약)
- Roblox Community Standards — https://about.roblox.com/community-standards (원문 확인)
- Roblox Creator Docs, Security tactics — https://create.roblox.com/docs/scripting/security/security-tactics (원문 확인)
- Roblox DevForum, "Chat Module Admin Commands" (2022-01-15) — https://devforum.roblox.com/t/chat-module-admin-commands/1628091 (원문 확인)
- UserId 찾는 법 — https://www.exitlag.com/blog/roblox-ids/ 등 (검색 요약)

### 확인 못 함
- Fall Guys 결승별 정확한 현재(2026) 시간 제한 값 — 위키 접근 불가. 2020년 자료 기준.
- Super Bomb Survival의 라운드 종료 규칙 — 게임 페이지·검색 모두 규칙 설명 없음.
- 로블록스 인기 "Fall Guys류" 게임 중 결승 연장전을 쓰는 사례 — 찾지 못함.
