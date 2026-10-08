# QA — m3-07 잡기

- 스펙: `docs/specs/m3-07-grab.md`
- 검증 커밋: `82fbe8f` (개발) + `origin/main` `d399995`(m3-03 QA 통과) 병합 = `eda8f38`, 충돌 없음
- 결과: **통과 (P0/P1/P2 없음, P3 4건)** → 스펙 상태 `qa-passed`. Studio 확인(AC7~AC15)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 303 passed, 0 failed (main 262 + 개발 `grab.spec` 13 + QA `m3-07-qa.spec` 28) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `grab.spec` AC1 4개 + QA `GrabLogic: 내적이 0.5보다 조금 작으면 안 잡혀요`(61도/59도), `바라보는 방향이 수직뿐이면 아무도 안 잡아요`, 서버 하네스 `옆·뒤는 못 잡아요` |
| AC2 | 통과 | `grab.spec` AC2 2개 + QA `면역 중인 대상은 begin도 거부해요` |
| AC3 | 통과 | `grab.spec` AC3 (11.49/11.5, 10.99/11) + 서버 하네스 `풀린 직후 잡던 사람은 1.5초 쿨다운`, `풀린 대상은 1초 동안 누구에게도 안 잡혀요` |
| AC4 | 통과 | `grab.spec` AC4 + QA 경계 `2초 정확히 끝, 거리 9 정확히 유지`, 서버 하네스 `거리 9 초과면 풀리고 9 이하는 유지` |
| AC5 | 통과 | `grab.spec` AC5 2개 + 서버 하네스 `서로 보고 같은 틱에 누르면 한 잡기만`, `두 사람이 같은 대상을 노리면 먼저 성립한 잡기만` |
| AC6 | 통과 | 위 자동 검증 |
| AC7 | 사용자 확인 필요 | 체크리스트 2. 서버 성립·2초 해제는 하네스로 확인 (`2초가 지나면 저절로 풀리고…`) |
| AC8 | 사용자 확인 필요 | 체크리스트 3. 쿨다운·면역 서버 동작은 하네스로 확인 |
| AC9 | 사용자 확인 필요 | 체크리스트 4. 하네스 `누른 채 다가가면 거리 안에 들어오는 순간 잡혀요`, `옆·뒤는 못 잡아요` |
| AC10 | 사용자 확인 필요 | 체크리스트 5. 하네스 `대상이 레이서가 아니게 되면 다음 틱에 풀려요`, `넘어짐·젓가락·Anchored·사망이면 풀려요`, `거리 9 초과` |
| AC11 | 사용자 확인 필요 | 체크리스트 6. 하네스 `레이서가 아니면 잡지도, 잡히지도 않아요`. UI 클릭은 `gameProcessed`로 막음 (`GrabController.luau:206`) |
| AC12 | 통과(서버 로직) + 사용자 확인 필요 | 하네스 `다른 방 레이서는 바로 앞에 있어도 못 잡아요` (방 id 비교, `GrabService.luau:129`). Studio 체크리스트 7은 선택 |
| AC13 | 통과(서버 로직) + 사용자 확인 필요 | 하네스 `서버는 Humanoid 값을 하나도 쓰지 않아요`(가짜 Humanoid 쓰기 감시), 정적 검사 `WalkSpeed/JumpPower/PlatformStand 대입 없음`. 실제 속도 복귀는 체크리스트 8 |
| AC14 | 사용자 확인 필요 | 체크리스트 9 |
| AC15 | 통과(서버 로직) + 사용자 확인 필요 | 하네스 `잡힌 사람이 나가면…`, `잡던 사람이 나가면…`, `나간 사람의 면역·누름 기록이 남지 않아요`. Studio 체크리스트 10 |

요약: 순수 로직 AC1~AC6 통과(6/6). Studio AC7~AC15(9개)는 사용자 확인 필요 — 그중 AC12·AC13·AC15의 서버 쪽 동작은 가짜 환경에서 실제 `GrabService.luau`를 돌려 확인했다. 실패한 기준 없음.

## 코드 리뷰

### 변경 범위
- `git diff origin/main..HEAD` 결과 스펙 지정 파일만 바뀜: `GrabLogic.luau`(새), `GrabService.luau`, `GrabController.luau`, `GrabButton.luau`(새), `tests/grab.spec.luau`(새), 문서 2개. 공용 파일·`DiveController.luau`·`RoundService.luau` 수정 없음.

### 서버 판정 · 보안
| 항목 | 결과 | 위치 |
|---|---|---|
| 인자 타입 | boolean 아니면 무시 (`nil`, 숫자, 문자열, 표 하네스로 확인) | `GrabService.luau:184-186` |
| 빈도 제한 | `true`만 `InputMinInterval`(0.1초) 제한, 받아들인 때만 `lastPress` 갱신. `false`는 항상 처리하고 잡기를 즉시 끝냄(틱 기다리지 않음) | `:188-206` |
| 대상 선택 | 클라이언트는 boolean만 보냄 — 대상·위치를 보낼 수 없음. 서버가 `Players:GetPlayers()`에서 같은 `activeRoomOf` 값인 레이서만 후보로 모음 | `:128-145` |
| 잡는 사람 조건 | `canStart`(잡는 중·잡힘·쿨다운) → `activeRoomOf ~= nil` → 몸 있음·`isDown` 아님 | `:114-124` |
| 누른 채 연속 잡기 | `armed`가 새 누름에만 켜지고 성립·해제 때 꺼짐. 중복 `true`는 재무장 안 함 (하네스 확인) | `:76, 161, 195-198` |
| 끝내기 | 매 틱 `shouldEnd`: 놓음·2초·거리>9·레이서 아님(방 id가 잡을 때와 다름)·캐릭터 바뀜·사망·넘어짐·WalkSpeed 0·Anchored | `:88-111` |
| 서버 WalkSpeed | 읽기만 함 (`isDown`). 쓰기 없음 — 간장 늪·젓가락과 충돌 없음 | `:60` |
| 속성 정리 | 끝날 때 잡을 때 저장한 **옛 캐릭터**에서, 값이 그대로일 때만 지움 → 리스폰 후 새 캐릭터에 남지 않음 | `:67-82` |
| 나간 플레이어 | 잡던 것·잡히던 것 끝내고 `removePlayer`로 쿨다운·면역 삭제, `holding/armed/lastPress` 삭제. 같은 userId로 재접속해도 기록이 남지 않음 (하네스 확인) | `:209-223` |
| 메모리 | 플레이어별 표 4개 모두 `PlayerRemoving`에서 지움. `active`는 끝날 때 지움. 장기 누적 없음 | |
| 반복 중 수정 | `tick`·`onPlayerRemoving`에서 `active`를 돌며 nil 대입 — Luau에서 허용(기존 키에 nil) | `:174-176, 214-218` |

### 클라이언트
- 입력: MouseButton1·ButtonR2·GrabButton, `gameProcessed` 무시, 관전 중(CameraSubject ≠ 내 Humanoid) 무시, `WindowFocusReleased`·`CharacterAdded`·`CharacterRemoving`에서 false. 스펙 1과 일치.
- 감속: `BindToRenderStep(Input+1)`에서 `Humanoid:Move(MoveDirection × 배수)`. m3-06 다이브 경직은 `Input+2`에서 `Move(zero)`라 경직이 이김(m3-06 스펙과 일치). 다이브 중 수평 속도는 DiveController가 직접 유지해서 잡힌 B가 다이브로 빠져나갈 수 있음 → 거리 9 초과로 서버가 해제.
- 표시: 매 Heartbeat에 모든 플레이어 속성과 동기화, 속성이 지워지면 다음 프레임에 Beam·Billboard 삭제. 소리 `GrabStart`/`Grabbed`는 `SfxCues`에 있음.
- 모바일 버튼: TouchEnabled + `TouchGui.TouchControlFrame.JumpButton`이 있을 때만, `GrabGui`(ResetOnSpawn=false), 점프 버튼 위 간격 = 높이×0.15, 같은 크기. 잡는 동안 색 변경. 스펙 8과 일치.

## 버그
P0/P1/P2 없음.

### [P3] G1 누름-뗌-누름을 0.1초 안에 하면 두 번째 누름이 서버에서 무시되고, 클라이언트는 누른 상태로 남음
- 재현: 좌클릭을 매우 빠르게 두 번(첫 누름에서 0.1초 안에 다시 누름) 하고 두 번째를 계속 누르고 있는다.
- 기대: 누르고 있는 동안 잡기를 찾는다.
- 실제: 서버는 두 번째 `true`를 빈도 제한으로 버리고(스펙 2대로), 클라이언트 `holding`은 true라 뗄 때까지 다시 보내지 않는다 → 그 누름 동안 잡기 없음. 손을 뗐다 다시 누르면 정상. 스펙대로의 동작이라 버그라기보다 체감 문제. 신경 쓰이면 클라이언트도 0.1초 안의 재누름을 조금 늦춰 보내는 방식으로 m3-09에서.
- 위치: `src/server/GrabService.luau:188-194`, `src/client/input/GrabController.luau:50-56`

### [P3] G2 (기획 질문) 잡고 있는 사람은 다른 사람에게 잡힐 수 있음 — 그때 ×0.5×0.7 = ×0.35
- 재현: B가 C를 잡고 있는 동안 A가 B 뒤에서 잡는다.
- 실제: 후보 조건은 "잡혀 있지 않음"뿐이라 B가 잡힌다(B는 두 속성을 다 가짐). B의 C 잡기는 계속된다. 스펙 위반은 아니고 "잡혀 있는 사람은 잡기 시작 불가"(AC5)도 지켜진다. 사슬 잡기를 막을지, B가 잡히면 B의 잡기를 끝낼지는 기획 결정.
- 위치: `src/shared/GrabLogic.luau:83-91`

### [P3] G3 (기획 질문) 잡는 사람이 다이브해도 잡기가 이어짐
- 실제: 다이브는 `PlatformStand`를 쓰지 않으므로(m3-06 결정) 잡는 사람이 다이브해도 거리가 9 이하면 잡기가 계속된다. 스펙 5 해제 조건에 "잡는 사람의 다이브"는 없어서 스펙대로다. 앞으로 다이브하며 대상을 지나치면 거리로 풀린다.

### [P3] G4 마우스·게임패드·모바일 버튼이 `holding` 하나를 같이 씀
- 실제: 두 입력을 동시에 누르다 하나를 떼면 놓기가 간다. 실사용에서 거의 없음.
- 위치: `src/client/input/GrabController.luau:36, 50-64`

### Studio 위험 (버그 아님, 확인 필요)
- 감속이 `Humanoid.MoveDirection`이 같은 프레임에 ControlModule의 `Move` 결과로 바로 갱신된다는 가정에 기대고 있다. 만약 `MoveDirection`이 이전 프레임 값(이미 줄인 값)이면 배수가 겹쳐 B가 거의 멈출 수 있다. 개발 메모에도 같은 위험이 적혀 있다. 체크리스트 2에서 "약 절반"인지(멈추지 않는지) 꼭 본다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 타입(boolean), 빈도(0.1초), 방 소속(`activeRoomOf` 같은 값), 대상은 서버가 고름. 방장 여부는 해당 없음.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 잡기 성립·해제도 서버만. 클라이언트는 속성을 보고 자기 입력만 줄임(스펙 결정 기록대로 감속 무시 악용은 M4).
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음(맵 변경 없음). 잡기 상태는 서버 전역이지만 방 id로 분리.
- [x] 연결·인스턴스·스레드가 정리된다 — 서버 연결 3개는 서버 수명 동안 하나. 클라이언트 Beam·Billboard는 속성이 지워지면 바로 삭제. GrabButton 점프 버튼 연결은 점프 버튼이 사라지면 끊음.

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "soy-swamp", "skewer-showdown" }`(Race 먼저; 커밋 금지), `rojo serve`, Studio Test 탭 → Clients and Servers, 플레이어 2명(AC12만 4명). 끝나면 `forceMapPlan = nil`로 되돌린다.

1. 방 만들기 → 시작. 라운드 소개가 끝나고 출발할 때까지 기다린다.
2. **AC7** — Player1(A)이 Player2(B) 바로 뒤(2~4칸)에서 B 쪽을 보고 좌클릭을 누르고 있는다. 확인: 두 창 모두에서 흰 굵은 선이 A 앞에서 B까지 이어짐, B 머리 위 "잡혔다!". B 창에서 W를 누르고 있으면 **약 절반 속도로 계속 움직임(멈추지 않음)**, A도 약간 느림. 계속 누르고 있어도 2초 뒤 선이 사라지고 다시 잡히지 않는다.
3. **AC8** — 다시 잡은 뒤 1초 안에 버튼을 뗀다 → 바로 풀림. 떼고 곧바로(1.5초 안) 다시 누르고 있으면 안 잡히고, 약 1.5초 뒤에 잡힌다. (3명이면) A가 놓은 직후 Player3이 B를 잡으려 하면 약 1초 동안 안 잡힌다.
4. **AC9** — B 옆(좌우)이나 뒤를 보고 누르면 안 잡힌다. B와 6칸 이상 떨어져 B를 보고 누른 채 다가가면 5칸 안에 드는 순간 잡힌다.
5. **AC10** — (a) 잡힌 B가 Shift로 다이브해 멀어지면 풀린다. (b) `skewer-showdown`에서 A가 날치알 공에 맞아 넘어지면 풀린다. (c) B가 결승선을 통과하면 풀리고, 대기석에서 B가 정상 속도로 걷는다.
6. **AC11** — 로비, 대기석, 라운드 소개 중, 탈락 후 관전 중에 좌클릭해도 아무도 안 잡힌다. 로비의 방 만들기 등 UI 버튼을 클릭할 때, 서버 창에서 `game.ReplicatedStorage.Remotes.GrabInput.OnServerEvent:Connect(function(p, v) print("GrabInput", p, v) end)`를 Command Bar로 실행해 두면 UI 버튼 클릭에는 출력이 없어야 한다(빈 땅 클릭에는 출력되는 게 정상, 서버가 무시함).
7. **AC12** (선택) — 플레이어 4명으로 방 2개(2명씩)를 동시에 진행. 서로 다른 방 사람은 잡히지 않는다 (아레나가 2000 떨어져 있어 실제로 마주칠 수 없으므로 자동 테스트로 대신 확인함).
8. **AC13** — `soy-swamp`에서 B가 잡힌 채로 간장 웅덩이에 들어갔다 나온다. 잡기가 끝난 뒤 서버 창 Explorer에서 `Workspace/Player2/Humanoid.WalkSpeed`가 16인지 본다.
9. **AC14** — Test 탭 → Device를 휴대폰으로 바꾸고 F5. 점프 버튼 바로 위에 같은 크기의 "잡기" 버튼, 왼쪽에 "다이브" 버튼(m3-06 병합 후)이 겹치지 않는다. "잡기"를 누르고 있으면 잡고(버튼 주황색), 떼면 놓는다. 손가락을 누른 채 버튼 밖으로 끌었다 떼도 놓인다.
10. **AC15** — 잡는 도중 A 창을 닫는다(또는 Player 나가기) → B의 "잡혔다!"·선이 바로 사라지고 B 속도가 정상. 반대로 B가 나가는 경우도 한 번. 서버 Output에 빨간 에러가 없다.

## 추가한 테스트
`tests/m3-07-qa.spec.luau` (28개)
- 서버 하네스: 실제 `src/server/GrabService.luau`를 가짜 `game`(Players·RunService.Heartbeat·ReplicatedStorage), 가짜 `RoundService.activeRoomOf`, 가짜 `GrabInput`, 가짜 `os.clock`으로 불러 0.1초 틱을 돌린다. 가짜 Humanoid는 값 쓰기를 기록한다.
  - 성립과 속성, 비 boolean 인자 무시, `true` 빈도 제한·`false` 즉시 처리, 다른 방 못 잡음(AC12), 레이서 아님 못 잡음·못 잡힘(AC11), 누른 채 다가가기(AC9), 옆·뒤 못 잡음
  - 2초 자동 해제·누른 채 재잡기 없음·중복 `true` 재무장 없음·뗐다 누르면 다시 잡음, 쿨다운 1.5초·면역 1초(AC8)
  - 대상/잡는 사람 레이서 아님, 넘어짐·WalkSpeed 0·Anchored·사망(양쪽), 거리 9 유지/9.2 해제, 캐릭터 교체 시 옛·새 캐릭터 속성 없음
  - 같은 틱 서로 잡기·같은 대상 두 명(AC5)
  - 잡힌/잡던 사람 퇴장 시 즉시 속성 정리(AC15), 퇴장자 기록이 같은 userId 재접속에 남지 않음
  - 서버가 Humanoid 값을 하나도 쓰지 않음(AC13)
- 정적: 잡기 파일 3개에 `WalkSpeed/JumpPower/PlatformStand` 대입 없음, `Input+1`·MouseButton1·ButtonR2·gameProcessed·WindowFocusReleased 존재
- GrabLogic 경계: 수직만 보는 방향, 내적 61도/59도, 2초 정확히·거리 9 정확히, 면역 대상 `begin` 거부, 잡힌 사람이 나가면 잡던 사람 쿨다운

## 인계 메모
- 지금 브랜치: `m3-07-qa` (`origin/m3-07-grab` + `origin/main` d399995 병합, 충돌 없음) — QA 커밋 + push.
- 끝난 것: 자동 검증 4종 통과(303/0), AC1~AC6 통과, 서버 판정·보안 리뷰(서버 하네스로 실제 GrabService 실행), 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC7~AC15 (위 체크리스트, 특히 2번의 감속 정도). 메인 세션이 `m3-07-qa`를 main에 병합. 기획 질문 G2(사슬 잡기)·G3(잡는 사람 다이브).
- 다음에 할 첫 단계: `m3-07-qa` 병합 → docs-writer가 DEV-SETUP에 체크리스트 1~10 반영. m3-06 병합 후 AC14(버튼 겹침)를 같이 확인.
- 막힌 점: 없음.
