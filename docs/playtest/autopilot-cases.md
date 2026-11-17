# Autopilot 테스트 케이스 목록 (로블록스판)

사용법·설치: [`docs/AUTOPILOT-PLAYTEST.md`](../AUTOPILOT-PLAYTEST.md) · 결과 기록: [`autopilot.md`](autopilot.md)

- Claude Code에서 **"Use Autopilot to …"** 뒤에 "요청" 칸을 그대로 붙여 넣어요. 화면 글씨(버튼·맵 이름)는 한국어 그대로 따옴표로.
- 모든 요청 끝에 공통으로: `Don't spend Robux. Report what you did, what happened, and anything that looked wrong.`
- 종류: **탐색**(Exploration) · **테스트**(Testing, 이상한 것 찾기) · **확인**(Verification, 정해진 동작) · **목표**(Goal, 수치)
- 🅿 = [PR #6](https://github.com/JangRuBin2/sushi-survival-race/pull/6)(m6-14) 병합 뒤 또는 그 브랜치에서만.
- **추천 순서**: 처음 1회차는 L01 → L02 → R01(회전 벨트) 세 개로 기억을 쌓고, 그다음 표 순서대로.

## L. 로비 · UI

| ID | 종류 | 요청 | 통과 기준 | 근거 |
|---|---|---|---|---|
| L01 | 탐색 | Explore the lobby: walk around the sushi restaurant, then try the "빠른 참가", "방 만들기", "연습" buttons and close each window again. | 모든 창이 열리고 닫힘, 오류·멈춤 없음 | GDD 3.1 |
| L02 | 확인 | Open "연습" and verify the "🏃 혼자 연습하기" window lists Race, Survival and Final sections with 26 map buttons in total, and that it closes. | 26개, 세 묶음 | m6-13 |
| L03 🅿 | 확인 | Verify the lobby "접기" button hides the room list panel, that you can walk around the lobby, and that the "🔍 방 찾기" button at the top brings the panel back. | 숨김 → 이동 가능 → 다시 펼침 | m6-14 A |
| L04 🅿 | 확인 | Open "방 만들기". Pick "16명" and "비공개", check the summary line says "16명 · 비공개", then close with the X button. Open it again and verify it reset to "8명 · 공개". | 요약 문구·초기화·X 닫기 | m6-14 B |
| L05 🅿 | 확인 | Open "방 만들기", choose "4명" and "공개", type room name "테스트", press "방 만들기", and verify you are in a waiting room named "테스트" with max 4 players. | 대기실 진입, 이름·인원 | GDD 3.2 |
| L06 | 탐색 | Open the skin shop "🍣 스킨", browse every tab, equip a different skin you already own (any skin is wearable in Studio), close it, and verify your character looks different. | 탭 이동·장착·외형 변경 | m4-13 |
| L07 | 확인 | Open the code window "🎟 코드", enter "WRONGCODE1" and verify an error message appears and nothing is granted. | 오류 문구, 코인 그대로 | m5-10 |
| L08 | 탐색 | Open the ⚙ settings menu and every item in it, then close everything. | 창이 겹치거나 안 닫히는 곳 없음 | m5-41 |

## M. 한 판 흐름

| ID | 종류 | 요청 | 통과 기준 | 근거 |
|---|---|---|---|---|
| M01 | 확인 | Create a room with "방 만들기", start it alone with "시작", and play through: map intro → countdown → round → results. Verify you end up back in the lobby or waiting room without getting stuck. | 각 단계가 넘어감, 끝나고 로비/대기실 | GDD 4 |
| M02 | 확인 | During a match, verify the top HUD shows the round number, a timer, and a qualified/remaining counter that changes when you finish. | HUD 3개 정보 | m2 HUD |
| M03 | 테스트 | In a match, after you finish a round, watch the waiting area and the spectate view until the round ends. Tell me anything confusing or broken. | 대기석·관전 정상 | m3 관전 |

## R. Race 맵 (연습 모드)

각 맵마다 두 요청을 돌려요. **R-목표**: `Open "연습", pick "<맵>", reach the finish line as fast as possible. Do 3 runs and report each clear time in seconds and where you fell.` **R-테스트**: `Open "연습", pick "<맵>" and tell me everything that looks wrong: stuck spots, invisible walls, holes in the floor, places where falling does not respawn you, obstacles that hit you without visible contact, unreadable signs.`

| ID | 맵 | 목표 시간 (빠른 사람) | 특히 볼 것 |
|---|---|---|---|
| R01 | 회전 벨트 | 45~55초 | 접시 가장자리 끼임 |
| R02 | 간장 늪 & 와사비 산 | 45~55초 | 와사비 튕김 방향 |
| R03 | 라멘 국물 급류 | 45~55초 | 소개 화면 국자 손잡이 가림(L2 B2) |
| R04 | 디저트 냉장고 | 45~55초 | 얼음 미끄러짐, 젤리 튕김 |
| R05 | 방방 미로 | 45~55초 | 풍선 기둥 위로 올라서지는지(L3 B1) |
| R06 | 등불 다리 건너기 | 45~55초 | 흔들다리 |
| R07 | 깨끗하게! 설거지통 | 45~55초 | F 복도 수세미 타이밍(m5-34 P3-1) |
| R08 | 우주 회전초밥 | 45~55초 | 레일 위 이동 |
| R09 | 초밥집 카운터 대횡단 | — (대형) | 넓은 길에서 길 잃음 |
| R10 | 도시락 뚜껑 대탈출 | — (대형) | 뚜껑 타이밍 |
| R11 | 팬트리 선반 대질주 | — (대형) | 선반 사이 점프 |

## S. Survival 맵 (연습 모드)

각 맵: `Open "연습", pick "<맵>" and survive until the timer ends. Report how many seconds you lasted, what knocked you off, and whether the sudden-death phase started near 60 seconds.` + R-테스트와 같은 "이상한 것 찾기".

| ID | 맵 | 볼 것 |
|---|---|---|
| S01 | 뜨거운 철판 | 75초 끝까지 버티면 통과 처리 |
| S02 | 셰프의 도마 | 칼 타이밍 |
| S03 | 튀김 냄비 탈출 | 층 잠김(L4 P3-1) |
| S04 | 와르르 나무 블록 | 블록 붕괴 |
| S05 | 고양이 카페 캣타워 | 고양이 밀치기 |
| S06 | 초대형 밥솥 | 끓어오름 |
| S07 | 수산시장 | 생선 튕김 |
| S08 | 중식당 회전 원판 (대형) | 원판 회전 |
| S09 | 연회상 쟁반 쓸기 (대형) | 낮은 쟁반 벽 점프(m6-07) |

## F. Final 맵 (연습 모드)

각 맵: `Open "연습", pick "<맵>", survive as long as you can and report the time and what eliminated you.` 연습에서는 **연장전·우승 연출이 없어야** 해요(90초에 끝).

| ID | 맵 | 볼 것 |
|---|---|---|
| F01 | 회전 꼬치 쇼다운 | 낮은/높은 꼬치 |
| F02 | 연어알 폭탄 접시 | 폭탄 타일 예고 |
| F03 | 줄다리기 발판 | 발판 기울기 |
| F04 | 인형뽑기 기계 속 | 집게 |
| F05 | 찻잎 정원 | 찻잔 3개 속도(m5-38 D13) |
| F06 | 온천탕 인형뽑기 | 증기 넉백 |

## X. 기능

| ID | 종류 | 요청 | 통과 기준 | 근거 |
|---|---|---|---|---|
| X01 | 확인 | In a Race practice run, jump off the course on purpose. Verify a 3-2-1 countdown appears and you respawn at the start about 3 seconds later. | 카운트다운 + 3초 부활 | m6-01 |
| X02 | 확인 | During a Race practice run, press F. Verify an attack effect appears, then press F again within 8 seconds and verify nothing happens, then again after 8 seconds and verify it works. | 쿨다운 8초 | m6-08 |
| X03 | 확인 | During a Race practice run, use dive several times. Verify you lunge forward, lie down briefly and get up, and that diving again immediately does nothing. | 다이브 → 엎드림 → 쿨다운 | m3-06 |
| X04 | 탐색 | Play 10 Race practice runs on "회전 벨트". If a "🧨" dynamite appears, pick it up, press F to light it, and report what happens after the countdown. | (10% 라운드라 안 나올 수 있음) 폭발 → 출발점 | m6-12 |
| X05 | 확인 | Open the 🛠 admin panel, run the command "tickets" with 3, open the skin shop "🍣 스킨" → "🎫 특" tab → "🎫 뽑기 시작하기", draw once, and verify a skin result is shown and the ticket count drops by 1. | 결과 표시, 뽑기권 −1 | m5-31 (Studio 메모리 저장이라 안전) |
| X06 | 확인 | Open the 🛠 admin panel and use "fx" preview on any elimination effect, then fall off a Survival practice map and verify the effect plays. | 연출 재생 | m5-09 |

## E. 경계 · 이상한 플레이 (회귀 찾기)

| ID | 요청 | 볼 것 |
|---|---|---|
| E01 | In a Race practice run, stand still and do nothing until the time limit. Report what happens at the end. | 시간 종료 처리, 멈춤 없음 |
| E02 | In a Race practice run, try to leave the course sideways at every section and try to climb on decorations. Report any place you can stand outside the intended course. | 코스 밖 서기·지름길 |
| E03 | In a Survival practice run, keep jumping into walls and corners. Report any spot where you get stuck or clip through. | 끼임·뚫림 |
| E04 | Start a Survival practice run, fall off on purpose, then press "로비로" while spectating. Verify you return to the lobby and can immediately start another practice run. | 정리·재시작 |
| E05 | Open and close every lobby window 5 times quickly in a row. Report any window that stays open, overlaps, or stops responding. | UI 겹침 |

## N. 처음 하는 사람 시점
Autopilot 기억을 비운 뒤(설치 문서 3.3) 아무 설명 없이: `This is a game you have never seen. Figure out how to play from the lobby on your own and try to win a practice run on "회전 벨트". Report every moment you were confused and what the game failed to explain.` → 안내 문구·튜토리얼 필요 지점. R01·S01·F01에 한 번씩.
