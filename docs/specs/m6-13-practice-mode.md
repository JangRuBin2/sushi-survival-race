status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-13 — 🏃 1인 연습 모드 (맵 고르기)

- 마일스톤: M6 · GDD 근거: §3.1(로비에서 할 수 있는 것), §4(매치 흐름 — 연습은 예외), §9.4(보상 — 연습은 없음)
- 사용자 요청 (2026-11-15): "1인 연습 모드도 가능하게 해줘. 맵 선택이 가능하게"
- 담당: 메인 세션(공용 파일 `Remotes`·`Types` 포함, 병렬 작업 없음)

## 결정 (질문 없이 기본값 — 플레이테스트 뒤 바꿀 수 있음)
| 항목 | 기본값 | 이유 |
|---|---|---|
| 보상 | **없음** — 코인·승수·하루 첫 판·🎫 뽑기권·단상 모두 없음 | 혼자 반복해서 보상을 쌓는 파밍 방지 (9.6 뽑기권은 "우승으로만") |
| 고를 수 있는 맵 | 랜덤 판 풀 26개 전부(대형 맵 포함) | 연습 목적 |
| Race 맵 | Race 방식, 떨어지면 3초 뒤 부활(m6-01), 결승선 통과로 끝 | 코스 익히기 |
| Survival·Final 맵 | 버티기: 시간 끝까지 버티면 성공, 떨어지면 끝(구제 없음) | 결승 방식이면 혼자라 바로 "우승"이 돼 버려요 |
| 결승 연장전 | 없음 (Final 맵도 시간 제한에 끝) | 연장전은 결승 방식에서만 |
| 🧨 다이너마이트 라운드 | Race 맵이면 평소처럼 10% | 바꿀 이유 없음 |
| 한 판 뒤 | 결과 단계 → 로비 (방이 닫혀요) | 다시 하려면 연습 버튼 |

## 구현
- 순수 `shared/PracticeLogic.luau`: `resolveMap(raw, Maps.infos())`(문자열·길이·풀 검사), `orderedMaps`(Race → Survival → Final).
- 리모트 `StartPractice(mapId)` → `RoomService` 핸들러: `requireNoRoom`(매치 서버·이미 방·텔레포트 중 거절) → 맵 검사 → **비공개·코드 없음·1인 방**(`room.practiceMapId`)을 만들고 바로 `beginMatch`. 로비 역할이어도 `launchMatch`(텔레포트)를 쓰지 않고 이 서버에서 돌려요. 비공개라 목록·빠른 참가·서버 간 디렉터리에 안 보이고 코드가 없어 참가할 수 없어요.
- `MatchService.runPractice`: RoundIntro → RoundActive → RoundResults 한 번, 방송에 `practice = true`(roundCount 없음 → HUD "연습", 탈락 연출에 결승 변형 없음). **MatchEvents를 하나도 보내지 않아요** → RewardService 추적기가 없어 Passed 보상이 없고, 결승이 아니라 Won이 생기지 않아요. 크래시 경로도 `endFired = true`라 매치 끝 훅 없음.
- `RoundService.prepareRound{ practice = true }`: 마지막 라운드여도 결승 아님 + `round.noRescue`(RoundLogic: 결승 진출 2명 보장 구제 끔).
- `RoomService.endMatch`: 연습 방이면 대기실로 돌리지 않고 멤버를 빼서 방을 닫아요.
- 클라이언트: 로비 "연습" 버튼 → `ui/PracticeDialog`(처음 열 때 맵 모듈을 읽어 종류별 버튼, GamepadNav.window) → `request("StartPractice", mapId)`. 현지화 키 `lobby.practice.*`, `hud.practice`, `room.err.BadPracticeMap`.
- 테스트 `tests/m6-13-practice-mode.spec.luau` (리모트 수 테스트 16 → 17 갱신).

## Studio 확인
`docs/DEV-SETUP.md` 3-19.
