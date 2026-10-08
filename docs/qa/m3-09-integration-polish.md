# QA — m3-09 M3 통합 · 장애물 소리 · 튜닝 (M3 전체 통합 QA)

- 스펙: `docs/specs/m3-09-integration-polish.md`
- 검증 커밋: `57cc877` (main = m3-01~08 병합 + m3-09 `3926a36`, `f3eebe6`, `57cc877`)
- 결과: **통과** (P0/P1 없음) → 스펙 상태 `qa-passed`. P2 1건, P3 4건. Studio 항목(AC4~AC15)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests` | OK |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 개발 시점 463 passed → QA 테스트 추가 후 **484 passed / 0 failed** |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 간격 제한 | 통과 | `map-sfx.spec` AC1 3개 + `m3-09-qa.spec` 부동소수점 0.1+0.1, 정리가 간격 안 기록을 안 지움, 더 긴 gap 정리 기준 |
| AC2 cue 표 | 통과 | `map-sfx.spec` "AC2", 맵 파일 4개가 표의 cue를 부름 |
| AC3 검증·forceMapPlan nil | 통과 | 위 자동 검증, `Config.luau:109` `forceMapPlan = nil` (`m3-09-qa.spec`) |
| AC4 장애물 소리 | 사용자 확인 필요 | 체크리스트 H. 코드상 표의 7개 순간에 호출 있음. `ChopstickWarn`·`HotTileSizzle`·`ChefHandWarn`은 id nil이라 무음이 정상 |
| AC5 맵 판정 회귀 | 코드 통과 / 사용자 확인 필요 | 맵 diff는 `MapSfx.play` 한 줄씩 + 꼬치 `lastElapsed` 추적뿐, `RoundLogic` 변경 없음. 체크리스트 I |
| AC6 카메라 순서 | 사용자 확인 필요 | 체크리스트 J1~J3. 소개 중 탈락 → `IntroController` 중단(B1 수정 확인) |
| AC7 결승 마지막 탈락 | 사용자 확인 필요 | 체크리스트 J4. 서버 3초 지연 확인(`RoundService.luau:212-222, 457-463`). 아래 "결승 지연 검토"와 B1 참고 |
| AC8 잡기+장애물·다이브 | 사용자 확인 필요 | 체크리스트 F |
| AC9 다이브 중 낙하 탈락 | 사용자 확인 필요 | 체크리스트 E3 |
| AC10 연출 중 방 나가기 | 사용자 확인 필요 | 체크리스트 J5 |
| AC11 외형 한 벌 | 사용자 확인 필요 | 체크리스트 A |
| AC12 휴대폰 배치 | 계산 통과 / 사용자 확인 필요 | `m3-09-qa.spec` 음소거 버튼 배치 계산(560~899px 아이콘, 900~2560px 글자 버튼). 체크리스트 K |
| AC13 8명 성능 | 사용자 확인 필요 | 체크리스트 L |
| AC14 두 판 연속 | 사용자 확인 필요 | 체크리스트 M |
| AC15 친구 테스트 | 사용자 확인 필요 | 체크리스트 N |

정리: 자동 확인 가능한 AC1~AC3 **3/3 통과**, AC5·AC12는 코드/계산으로 통과하고 Studio 확인 남음, AC4·AC6~AC11·AC13~AC15는 Studio·사용자 확인 필요. 실패 0.

## 넘긴 버그 대조 (m3-01 ~ m3-08 → m3-09)
| 원래 리포트 | 버그 | 상태 | 근거 |
|---|---|---|---|
| m3-01 B1 | 관전 비추기가 서버 로비 이동보다 늦게 끝남 | 고침 | `SpectateController` hold = `EliminationCutscene - Config.Fx.SpectateHoldMargin`(2.7초) |
| m3-01 B2 | 리셋 탈락 위치를 새 캐릭터(로비)로 채움 | 고침 | `RoundService.queueFall(..., knownCharacter=true)`, `EliminationService.luau:67` Reset이면 대체 안 함 |
| m3-01 B3 / m3-03 B4 | 시간 종료·정원 마감 탈락 cause nil | 고침 | `"Timeout"` 추가, `RoundService.luau:236`. 퇴장은 `EliminationService.left` → `Left` 유지 (`m3-09-qa.spec`) |
| m3-02 B1 | 탈락 고정이 넘어짐(@_@·Knockdown)으로 보임 | 고침 | `CharacterFxController` `not root.Anchored` (넘어짐 장애물은 Anchored 아님 → 그대로) |
| m3-02 B2 | Head 투명으로 이름표 안 보일 위험 | 고침 (Studio 확인) | 자체 BillboardGui 이름표 + 기본 이름표 로컬 None. 연출로 숨기면 이름표도 숨김 |
| m3-02 B3 | 캐릭터 아래 붙는 파츠 전부 숨김 | 고침 | `Attributes.KeepVisible` 제외 규칙 (`AppearanceService.isSushiPart`) |
| m3-02 B4 | 초밥 이름 상수 두 곳 | 고침 | `SushiBody.MODEL_NAME/JOINT_NAME` 공용 |
| m3-03 B1 | 결승 마지막 탈락 연출이 Victory에 바로 지워짐 | 고침(조치) — **원래 진단이 틀렸음** | 아래 "결승 지연 검토". 결승 뒤에도 RoundResults(5초)가 있어 Victory가 즉시 오지 않았다. 지연 3초는 해가 없고 맵이 연출 동안 남는 이득이 있음 |
| m3-04 B1 | 소개 중 리셋한 사람에게 "출발!"·플라이스루 재개 | 고침 | `IntroController` 본인 Eliminated 수신 시 중단, RoundActive에서 `isAlive()` 확인 |
| m3-05 B3 | 우승자 개인 결과 글씨가 연출과 겹침 | 고침 — **부작용 B1(P2)** | `HudController.luau:53` Won 글씨 생략. 결승 우승은 Victory가 8초 뒤라 원래 겹치지 않았고, 이제 우승자에게 그동안 아무 표시가 없음 |
| m3-06 B1 | 점프 직후 다이브 연타가 걷기보다 빠름 | 고침 | `DiveLogic` 공중 vy ≤ `AirMaxUpSpeed`(16). 시뮬레이션 0.02/0.05/0.1/0.2초 모두 걷기보다 느림 + QA 경계값 |
| m3-06 B4 | 다이브 끝에 Humanoid 상태를 무조건 켬 | 고침 | `DiveController` AutoRotate·TIP_STATES·Jumping 원래 값 복원 |
| m3-07 G2 | 잡고 있는 사람이 잡힘(×0.35) | 고침 | `GrabLogic.begin`/`pickTarget` + `GrabService` 후보 `grabbing`. 놓으면 다시 대상 (`m3-09-qa.spec`) |
| m3-07 G3 | 잡는 사람이 다이브해도 잡기 유지 | 고침 | `DiveController.luau:218` `GrabController.cancelHold()` → `GrabInput(false)`. 서버는 놓기를 간격 제한 없이 항상 처리(`GrabService` onInput) |
| m3-08 B1 | 조작 버튼 클릭음 | 고침 (Studio 확인) | `TouchGui`·`ContextActionGui`·`NoClickSfx` 제외, `DiveGui`·`GrabGui`에 속성 |
| m3-08 B2 | 좁은 화면 음소거 버튼 겹침 | 고침 (Studio 확인) | 폭 < 900이면 아이콘 34×28. QA 계산: 560~899px에서 HUD·로비 내용과 가로로 안 겹침. P3 B5 참고 |
| m3-08 B3 | 재부모 시 연결 중복 | 고침 | 약한 키 표 `hookedButtons` |
| m3-08 B4 | 서버 장애물 소리에 pitch·음소거 미적용 | 고침 | 서버는 RemoteEvent만, 클라이언트 `Sfx.play`가 재생 (pitch·음소거·한도 공통) |
| m3-08 B5 | 10초 넘는 소리 잘림 | 고침 | `Sfx` 수명 연장 (`map-sfx.spec`) |

손대지 않은 것(결정 기록대로, 동의): m3-02 B5, m3-03 B2·B3, m3-04 B2, m3-06 B2·B3, m3-07 G1·G4, m2-07 I1·I2, M1 B10.

## 개발이 바꾼 기존 QA 테스트 기대값 (7곳) 검토
| 테스트 | 바뀐 것 | 판단 |
|---|---|---|
| `camera-priority.spec` Attributes 개수 | 6 → 8, 키 목록에 `KeepVisible`·`NoClickSfx` 추가 | 정당. 기존 키 검사 유지, 중복 검사 그대로 |
| `grab.spec` "나간 플레이어…" | 두 번째 `begin` 대신 기록 직접 넣기 | 정당. G2로 그 상태를 begin으로 만들 수 없게 됨. `removePlayer`가 두 역할을 다 지우는지는 여전히 확인. G2 테스트도 새로 추가됨 |
| `m3-01-qa` Config.Dive | `ProneAngle`·`AirMaxUpSpeed` 키 추가 | 정당. 기존 5개 값 그대로 |
| `m3-02-qa` 이름 상수 | 문자열 비교 → 공용 상수 사용 확인 + 값 고정 | 정당. 오히려 더 강함 (서버 = 공용 = "SushiBody"/"SushiJoint", 클라이언트가 공용 상수를 씀) |
| `m3-03-qa` shouldPlay | Timeout false → true | 정당 (결정 기록의 기획 변경). Left·nil·소문자 "timeout" 등은 여전히 false |
| `m3-06-qa` 공중 vy | 45 → `AirMaxUpSpeed` | 정당 (B1 원인). 5·-20 경계 추가, B1 시뮬레이션 4개 추가 — 약해지지 않음 |
| `m3-06-qa` 정적 검사 | `x:SetAttribute(Attributes.NoClickSfx, true)` 한 줄만 지우고 검사 | 정당 (좁은 패턴). 참고: 이제 다이브가 `GrabController.cancelHold`로 **간접적으로** `GrabInput(false)`를 보내는데 이 정적 검사는 파일 글자만 봐서 못 잡는다. 놓기는 서버 판정을 바꾸지 않아 문제 없음 — 숨긴 버그는 없음 |

`tests/lib/FakeSfxEnv`는 도우미 변경(진짜 Config·Attributes 주입, Get/SetAttribute)이라 기대값 변경 아님.

## 새 RemoteEvent `MapSfx` 검토
- **방향**: 서버 → 클라이언트 전용. 서버에 `OnServerEvent` 연결 없음, 클라이언트 어디에도 `FireServer` 없음, 보내는 곳은 `MapSfx.luau` 한 곳 (`m3-09-qa.spec` 정적 확인). 클라이언트가 이 리모트로 보내도 서버가 듣지 않아 아무 일도 안 일어난다(다른 서버→클라이언트 이벤트 `PlayerResult` 등과 같은 방식).
- **서버 가드**: `MapSfx.play`는 `RunService:IsServer()`일 때만 리모트를 잡고, id nil·파트 없음·간격 제한이면 안 보냄.
- **클라이언트 인자 검증**: `Sfx.playMapSfx`가 cue 문자열·position Vector3 확인, part는 BasePart이고 Parent가 있을 때만 붙임 (`map-sfx.spec` 이상한 인자 무시).
- **방 범위**: **방 사람에게만 가지 않는다** — `FireAllClients`(`MapSfx.luau:44`). 클라이언트가 카메라에서 `SfxMaxDistance`(120) 밖이면 버린다. 아레나 간격 2000, 로비는 아레나보다 300 아래라 다른 방·로비에 **들리지는 않는다**. 네트워크만 낭비 → P3 B2.
- **0.2초 간격**: (파트, cue)별, `Config.Fx.MapSfxMinInterval`. 리미터는 모듈 전역이지만 키가 방마다 다른 파트 인스턴스라 방끼리 섞이지 않음. 정리는 호출이 있을 때만 돌아서 마지막 호출 뒤 지워진 파트를 잠깐 붙잡고 있음 → P3 B3.

## 결승 우승 발표 지연 검토 (`RoundService.luau:212-222, 243-249, 457-463`)
- **m3-03 B1의 원래 진단이 틀렸다.** `MatchService.luau:207-224`는 결승(`roundIndex == roundCount`)이 끝나도 `break`하지 않고 `RoundResults`(5초)를 방송한 뒤 `nextRound`가 nil이 되어 Victory로 간다. 즉 m3-09 전에도 마지막 탈락 → Victory 사이에 약 5초가 있었고 셰프 손 연출(3초)은 지워지지 않았다. (m3-03·m3-05 QA가 "같은 틱에 Won → Victory"라고 적은 것은 잘못.) 다만 m3-09 전에는 `run`이 0.2초 안에 끝나 맵이 바로 사라져서 연출이 빈 하늘에서 재생됐다 — 지연 3초는 맵을 연출 동안 남겨 주는 이득이 있다. 비용은 결승 뒤 3초(탈락 연출 3초 + RoundResults 5초 + Victory 10초).
- **우승자 판정**: `applyOutcomes`가 지연 전에 Standings에 우승자를 기록한다. `decideWinner`는 `standings.winnerUserId`를 먼저 보므로 지연 중 무슨 일이 있어도 우승자는 Won을 받은 그 사람이고 Won이 두 번 가지 않는다 (`m3-09-qa.spec`).
- **지연 중 우승자가 나가면**: `onMemberLeft`는 `placeOf`가 1이라 Left를 보내지 않음 → 3초 뒤 남은 사람에게 Won → RoundResults → Victory(나간 우승자, 이름은 순위표). m3-05 AC11과 같은 처리, 새 문제 없음.
- **지연 중 진 사람이 나가면**: 이미 등수가 있어 아무 일 없음. 우승자 그대로.
- **리셋·퇴장 경합(I1)**: 같은 묶음에서 낙하 + 리셋이 섞이는 규칙은 그대로라 I1은 바뀌지 않음. 상대가 **퇴장**이면 `leaveRoom`이 방에서 빼는 것이 deferred flush보다 먼저라 `getRoomIdOf ~= roomId` → 지연 없이 즉시 Won (결정 기록대로). 상대가 **결승 소개 중 리셋**이면 `released = false`라 즉시 Won → 소개 끝에 Victory가 와서 리셋 연출이 잘림 (결정 기록 "소개 중 취소는 기다리지 않음", P3 B4).
- **지연 중 판정**: `round.ended`라 낙하·리셋 감시·`getRacers`가 모두 멈춤. 우승자가 그 사이 떨어져도 무관.

## Timeout cause 검토
- 낙하(`ctx.eliminate`) = Fall, 사망·캐릭터 교체·캐릭터 없음 = Reset, 방/게임 나감 = Left(`EliminationService.left`, 방에 없으면 이 경로), 그 밖에 `RoundLogic`이 정리한 탈락(Race 시간 종료·정원 마감, 결승 시간 종료) = `causeOf[userId] or "Timeout"`. 구제된 낙하자는 Passed라 cause가 남아도 쓰이지 않음. 모든 비낙하 탈락 경로에 맞게 붙는다.
- 연출: Race·Survival = 젓가락, 결승 = 셰프 손 (`m3-09-qa.spec`). Survival은 시간 종료면 전원 통과라 Timeout 탈락이 사실상 없다.

## 버그
### [P2] B1 결승 우승자에게 Victory 전 약 8초 동안 우승 표시가 없음 (m3-05 B3 수정의 부작용)
- 재현: 2명 결승, B가 떨어져 A가 우승. A 화면을 본다.
- 기대: A가 이겼다는 걸 바로 안다 (예전에는 "🏆 우승했어요!" 4초).
- 실제(코드상): Won은 마지막 탈락 3초 뒤에 오고, Victory는 그 뒤 RoundResults 5초가 지나야 온다(`MatchService.luau:216-224`). `HudController.luau:53`이 Won 글씨를 생략해서, A는 3초간 진 사람의 셰프 손 연출을, 그다음 5초간 "라운드 종료! / 다음 라운드를 준비하고 있어요"(`HudScreen.luau:281-283`, 결승 뒤에도 같은 문구 — M2부터 있던 문구)만 본다. m3-05 B3이 말한 "Victory 연출과 겹침"은 결승 경로에서는 없었다(진단 오류). 겹침은 부전승 경로(`MatchService.luau:231-249`, Won 직후 Victory)에서만 생긴다.
- 제안(개발 판단): Won 글씨는 Victory 단계가 아닐 때만 생략하지 말고 띄우기(부전승처럼 곧 Victory가 오는 경우만 생략), 또는 결승 뒤 RoundResults 배너를 "결승 종료! 우승자 발표 준비 중" 같은 문구로. 반려 사유는 아님(곧 Victory가 옴).
- 위치: `src/client/ui/HudController.luau:53`, `src/client/ui/HudScreen.luau:281-283`, `src/server/MatchService.luau:207-224`

### [P3] B2 장애물 소리 신호가 서버의 모든 클라이언트에 감
- 실제: `MapSfx.luau:44` `FireAllClients`. 다른 방·로비 클라이언트도 받고 거리(120)로 버린다. 들리지는 않지만, 방이 여럿이면 철판 타일마다 오는 신호가 전부에게 간다.
- 제안: 파트 조상 맵 Model의 `Attributes.RoomId`로 `RoomService.getPlayers(roomId)`에만 보내기 (서버 모듈 의존이 생기므로 `ctx`에 sender를 넣는 방식도 가능). 지금 규모에서는 급하지 않음.

### [P3] B3 소리 간격 리미터가 지워진 맵 파트를 잠깐 붙잡음
- 실제: `MapSfx.luau:16` 모듈 전역 리미터의 키가 파트 인스턴스(강한 참조), 정리는 `allow` 호출 때만. 매치가 끝나 더 이상 소리가 안 나면 마지막 라운드 파트 몇십 개가 다음 호출까지 남는다. 메모리 영향은 매우 작음.
- 제안: 약한 키 표(`__mode = "k"`) 또는 `ctx.cleanup`에서 그 맵 키 지우기.

### [P3] B4 결승 소개 중 상대가 리셋하면 리셋 연출이 Victory에 잘림
- 실제: 소개 중(`released = false`)에는 Won을 미루지 않고, 소개가 끝나면 `aliveCount < 2` → 바로 Victory(`MatchService.luau:184-188`). 진 사람의 3초 연출이 남은 소개 시간만큼만 보인다. 결정 기록이 이 경우를 일부러 뺐음 — 기록용.

### [P3] B5 900~980px 창에서 글자 음소거 버튼이 로비 패널 제목 줄 오른쪽 끝 위에 놓임
- 계산: 폭 W ≥ 900이면 버튼은 W-126~W-16, 로비 패널(최대 760) 내용 오른쪽 끝은 W/2+364 → W < 980이면 가로로 겹친다. 제목 글자는 가운데 정렬이라 실제 글자를 가리지는 않고 패널 빈 곳 위에 뜬다. 980 이상이나 900 미만(아이콘)은 겹치지 않음.
- 위치: `src/client/Sfx.luau:267-281`, `src/client/ui/LobbyScreen.luau:52-62`

### 관찰 (버그 아님)
- `IntroController` 소개 중 탈락: 카메라는 바로 놓지만 HUD 배너(맵 이름·규칙)는 RoundActive까지 남음. 의도와 어긋나지 않음.
- 다이브가 잡기를 놓을 때 서버에는 `GrabInput(false)` 하나만 감 (`holding`일 때만). 놓기는 서버가 항상 처리하므로 다이브와 잡기를 거의 동시에 눌러도 서버 잡기가 남지 않음.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 클라이언트→서버 경로 없음. `MapSfx`는 서버→클라이언트 전용(서버가 듣지 않음). `GrabInput` 검증 그대로
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 맵은 소리 호출만 추가, `RoundLogic` 변경 없음. 우승 지연도 서버
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 꼬치 `whooshMarks`/`lastElapsed`는 `start` 지역 변수. MapSfx 리미터는 모듈 전역이지만 키가 방별 파트라 섞이지 않음(B3)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 새 서버 연결 없음. 클라이언트 이름표는 캐릭터가 사라지면 `removeNameTag`, 음소거 버튼 ViewportSize 연결은 세션 1회

## 사용자 Studio 확인 체크리스트 (M3 전체 — DEV-SETUP M3 절로 옮길 수 있게)
준비: `rojo serve` → Studio 연결. 맵 순서를 고를 때만 `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 로컬에서 바꾸고(예: `{ "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`) **끝나면 `nil`로 되돌린다(커밋 금지)**. 다인원은 Test 탭 → Clients and Servers. 모든 단계에서 서버·클라이언트 Output에 빨간 에러가 없는지 같이 본다.

**A. 계란초밥 외형 (m3-02, AC11)**
1. 혼자 F5. 로비 캐릭터가 계란초밥(흰 밥·노란 계란·김 띠·눈·입·발)이고 아바타 옷·모자·얼굴이 안 보인다. 끝까지 줌인하면 1인칭에서 초밥이 화면을 가리지 않는다.
2. Esc → Reset 3번. 서버 보기 Explorer `Workspace/<내 이름>` 아래 `SushiBody`가 하나, `Body`에 `SushiJoint`. 라운드를 옮겨 다닌 뒤에도 하나.
3. 2명: 서로 상대 초밥 머리 위에 **흰 이름이 하나만** 보인다(기본 이름표와 겹쳐 두 개면 안 됨). 거리 100 넘게 떨어지면 사라진다.
4. 걸으면 통통 튀고 기우뚱, 멈추면 선다. 날치알·꼬치에 맞으면 누워 떨며 "@_@"와 Knockdown 소리.
5. 낙하로 탈락하는 순간 내 화면·남 화면 모두 "@_@"·Knockdown 소리가 **나지 않는다**.

**B. 탈락 연출 (m3-03)**
1. 3명, 회전 벨트에서 A가 떨어짐 → A 화면: 젓가락 → 간장 → "냠!" + "먹혔다!" 도장 + "n등", 약 3초 뒤 관전. B·C 화면: 같은 연출, 그동안 A 캐릭터·이름표 안 보임.
2. 라운드 중 Esc → Reset → 리셋한 자리에서 젓가락 연출.
3. 철판에서 떨어짐 → 아래에서 벌린 입 연출.
4. **Timeout**: 회전 벨트에서 통과 인원이 차거나 90초가 지나 남은 사람이 탈락 → 그 사람에게도 젓가락 연출 + "먹혔다!" (예전 "🥢 탈락했어요" 글씨 대신).
5. 방 나가기로 빠진 사람은 연출 없음.
6. 클라이언트 Explorer `Workspace/EliminationCutscenes`가 연출 뒤 비어 있다.

**C. 라운드 소개 (m3-04)**
1. 혼자 4라운드: 소개 3초 동안 카메라가 새 맵을 훑고 내 초밥 뒤로 돌아온 뒤 "출발!" + 소리, 바로 움직일 수 있다.
2. 3명: 1라운드에서 탈락한 C는 2라운드 소개 때 관전 화면 유지, 플라이스루·"출발!" 없음.
3. 소개 3초 안에 Esc → R: 탈락 연출로 넘어가고 "출발!"·Go 소리가 **안 뜨며**, 플라이스루 카메라가 다시 잡히지 않는다.
4. 방 2개(2명씩) 동시 시작: 각자 자기 방 아레나만 훑는다.

**D. 우승 연출 (m3-05)**
1. 결승 우승 → 문이 열리고 인형이 부두를 달려 물에 뛰어듦 → "탈출 성공! 🏆" + 물고기 박수(인형·물고기가 보임) → 약 6초 뒤 로비 우승자 비추기 → "🏆 우승!" 배너·순위표 → 대기실.
2. 끝난 뒤 `Workspace.CurrentCamera.FieldOfView`가 70, `Workspace`에 `VictoryCutscene` 없음.
3. 연출 도중 우승자 창을 닫아도 나머지 화면에서 끝까지 재생.

**E. 다이브 (m3-06)**
1. Shift/E/게임패드 X로 앞으로 엎드려 날고, 착지 뒤 0.5초 경직, 1.5초 쿨다운.
2. **점프 직후 Shift를 1.5초마다 반복**해도 그냥 달리기보다 빠르지 않다. 꼭대기에서 다이브하면 그냥 점프보다 멀리 간다.
3. (AC9) 다이브 도중 맵 밖으로 떨어져 탈락 → 엎드린 자세가 아니라 탈락 연출 인형이 보이고, 연출 뒤 로비 캐릭터가 똑바로 서서 방향을 돌고 점프할 수 있다.
4. 젓가락에 들린 동안·넘어진 동안·소개 중·관전 중에는 다이브 안 됨.

**F. 잡기 (m3-07, AC8)**
1. 2명: A가 B 뒤에서 좌클릭 유지 → 선 + "잡혔다!", B 약 절반 속도, 2초 뒤 풀림.
2. 잡힌 B가 젓가락에 들리거나 날치알에 맞으면 풀리고, 내려온 뒤 B 속도 정상(서버 `Humanoid.WalkSpeed` 16).
3. 잡힌 B가 다이브해 멀어지면 풀림.
4. 3명: A가 B를 잡고 있는 동안 C가 A를 잡으려 해도 안 잡힘. A가 놓으면 C가 A를 잡을 수 있다.
5. A가 잡은 채 Shift(다이브) → 바로 풀림. 버튼을 계속 누르고 있어도 다시 누르기 전에는 안 잡음.

**G. 사운드 (m3-08)**
1. 로비 버튼 "딸깍". 음소거 버튼: 🎵 음악 끔 → 🔇 모두 끔(딸깍·장애물 소리도 안 남) → 🔊 소리 켬.
2. 결승선 통과 "뿅". 한 판 뒤 `SoundService`에 쌓인 Sound가 없다.
3. 휴대폰 에뮬레이터에서 점프·다이브·잡기 버튼은 "딸깍"이 **안 난다**(메뉴 버튼은 남).

**H. 장애물 소리 (m3-09, AC4)**
1. 간장 늪: 간장 웅덩이에 들어갈 때 "출렁"(수영 소리 낮게), 와사비 패드 튕김 "뾰잉"(점프 소리 높게).
2. 철판: 타일이 사라질 때 발소리(낮게).
3. 꼬치 쇼다운: 10·20·30·40·50·60초마다 "휙".
4. 회전 벨트 경고·철판 달아오름·셰프 손 경고는 지금 무음이 정상(`SfxLibrary` id 없음).
5. 멀리(120 studs 밖) 있는 장애물 소리는 안 들리고, 다른 방 아레나 소리는 들리지 않는다. 🔇 모두 끔이면 장애물 소리도 안 난다.

**I. 맵 판정 회귀 (AC5)** — 4맵을 한 번씩: 회전 벨트 결승선 통과·젓가락 포획, 간장 늪 감속·와사비, 철판 타일(뜨거운 타일 탈락, Survival 시간 종료면 버틴 사람 통과), 꼬치 쇼다운 낙하 탈락·우승. M2와 같다.

**J. 교차 시나리오 (3명)**
1. (AC6) 관전 중 다음 라운드 소개가 와도 관전 화면 유지.
2. (AC6) 달리는 사람 기준: 플라이스루 → "출발!" → 떨어짐 → 탈락 연출 카메라 → 자동 관전 → (결승 뒤) 우승 연출 → 로비 우승자 비추기 → 대기실 내 캐릭터. 카메라가 엉뚱한 곳에 멈추지 않는다.
3. 관전 중 보던 사람이 떨어지면 약 2.7초 그 자리를 비춘 뒤 다음 사람(로비로 순간이동하는 모습이 안 보임).
4. (AC7) 2명 결승에서 한 명이 떨어짐 → 셰프 손 연출이 3초 끝까지 보이고(진 사람 화면에 "먹혔다! 2등"), 맵이 그동안 남아 있다. 그 뒤 "라운드 종료" 약 5초 → 우승 연출을 모두가 본다. **우승자 화면에 그 8초 동안 우승 표시가 없는지 확인해 B1 체감을 메모.** 두 사람이 거의 동시에 떨어져도 같은지.
5. (AC10) 탈락 연출·우승 연출·플라이스루 도중 "방 나가기" → 카메라가 로비의 내 캐릭터로, `Workspace`에 연출 소품(`EliminationCutscenes` 안, `VictoryCutscene`)이 남지 않음.

**K. 휴대폰 (AC12)** — Device 에뮬레이터(iPhone SE 가로 등): 음소거 버튼이 아이콘(🔊)만 오른쪽 위 끝, HUD 위 가운데 패널·로비 패널 내용과 안 겹침. 점프·다이브·잡기 버튼, 관전 바, HUD가 서로 안 겹침. "먹혔다!"·"탈출 성공!" 글씨가 안 잘림. PC 창을 900~980px 폭으로 줄이면 글자 음소거 버튼이 로비 패널 제목 줄 오른쪽 끝 위에 놓이는지(B5) 메모.

**L. 성능 (AC13)** — Clients and Servers 8명, 1라운드에서 여러 명이 거의 동시에 떨어짐 → 클라이언트 프레임(Ctrl+F7 또는 Shift+F5 통계)이 30fps 아래로 오래 떨어지지 않음. 7명째부터는 캐릭터만 사라졌다 나타남(동시 연출 한도 6).

**M. 두 판 연속 (AC14)** — 한 판을 우승까지 → 같은 방에서 바로 다시 시작해 우승까지. 두 번째 판도 같게 동작하고(소개·연출·관전·소리), Output에 빨간 에러 없음.

**N. 친구 테스트 (AC15)** — 4명 이상으로 몇 판. 탈락·우승 연출에 "웃기다" 반응이 나오는지, 바꾸고 싶은 수치(`Config.Fx`, `Config.Dive`, `Config.Grab`, `Config.Match`)와 연출을 메인 세션에 알려 준다.

## 추가한 테스트
`tests/m3-09-qa.spec.luau` (21개)
- MapSfxLogic: 부동소수점 0.2초 경계, 정리가 간격 안 기록을 안 지움, 더 긴 gap 기준 정리, MIN_INTERVAL = Config 값
- 꼬치 가속 휙: 60fps 90초 = 정확히 6번, 렉으로 두 시각을 넘어도 한 번
- Timeout: 연출 종류(Race·Survival 젓가락, 결승 셰프 손), 동시 한도 = Config.Fx, Race 시간 종료·정원 마감이 cause 없는 Eliminated → 서버가 Timeout, 퇴장은 Left
- 결승 지연: 2명 결승 마지막 낙하 = Eliminated + Won, 지연 중 우승자가 나가도 Standings 우승자 유지·Won 중복 없음, 진 사람이 나가도 우승자 유지, 서버 소스(지연 조건·Won 호출 2곳)
- 잡기 G2: 잡고 있는 사람은 대상 아님, 놓으면 다시 대상, 잡힌 사람은 잡기 시작 불가
- 다이브: 공중 vy 상한 정확히/살짝 넘음/살짝 아래, 바닥 다이브 UpSpeed
- 음소거 버튼 배치 계산: 560~899px 아이콘, 900~2560px 글자 버튼이 HUD와 안 겹침
- MapSfx 리모트: 서버가 듣지 않고 클라이언트가 보내지 않음, 보내는 곳 한 곳, 서버 가드
- forceMapPlan nil

## 인계 메모 (2026-10-08 · qa)
- **브랜치**: `m3-09-qa` (origin/main `57cc877`에서), push함.
- **끝난 것**: m3-09 검증 + M3 통합 QA. 자동 검증 4개 통과(484/0), 넘긴 버그 19건 대조(전부 조치됨, m3-03 B1·m3-05 B3은 원래 진단 오류 지적), 기존 테스트 기대값 7곳 검토(모두 정당), MapSfx·결승 지연·Timeout 검토. 스펙 상태 `qa-passed`.
- **남은 것**: 사용자 Studio 체크리스트 A~N. P2 B1(결승 우승자 표시 공백)과 P3 B2~B5는 개발이 원하면 후속으로. docs-writer가 위 체크리스트를 DEV-SETUP M3 절로 옮기고 CHANGELOG 반영.
- **다음에 할 첫 단계**: 메인 세션이 `m3-09-qa`를 main에 병합 → docs-writer 단계.
- **막힌 점**: 없음. Studio를 돌릴 수 없어 AC4~AC15는 확인하지 못함.
