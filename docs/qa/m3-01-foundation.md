# QA — m3-01 M3 기반 작업 (공용 파일 · 카메라 중재 · 연출/입력 껍데기)

- 스펙: `docs/specs/m3-01-foundation.md`
- 검증 커밋: `5f2e43b` (main)
- 결과: **통과 (P0/P1/P2 없음, P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC5~AC9)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 235 passed, 0 failed (M2 209 + 개발 6 + QA 추가 20) |

참고: 검증 4종에는 Luau 타입 검사가 없다 (m2-07 I2와 같음). 시그니처가 바뀐 `EliminationService.eliminate(roomId, player, place, cause?, position?)`의 호출부는 `RoundService.luau:212` 한 곳뿐이고 맞다. `left`/`passed`/`won` 시그니처는 그대로다.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `camera-priority.spec.luau` AC1 3개 + `m3-01-qa.spec.luau` `CameraPriority.pick: …` 3개. 그리고 `CameraDirector.luau`를 가짜 `game`/`workspace`로 불러 실제 중재 동작을 확인한 8개 (`CameraDirector: …`) |
| AC2 | 통과 | `camera-priority` AC2 + QA `Config: M2 연출 시간은 그대로, 우승 단계만 10초`, `Config.Dive·Grab 값이 스펙 기본값이고 범위가 말이 돼요`. `forceMapPlan = nil` (`Config.luau:92`) |
| AC3 | 통과 | `camera-priority` AC3 2개 (Attributes 6개 중복 없음, SfxCues 효과음 28 + 음악 4 중복 없음) |
| AC4 | 통과 | 위 자동 검증 (기존 209개 포함) |
| AC5 | 사용자 확인 필요 | 체크리스트 1 |
| AC6 | 사용자 확인 필요 | 체크리스트 2. 코드상 속성은 `model.Parent = workspace` 직전에 단다 (`RoundService.luau:143-146`) |
| AC7 | 사용자 확인 필요 | 체크리스트 3. `default.project.json` 값은 QA 테스트 `default.project.json: Shift Lock 끄기…`로 확인 |
| AC8 | 사용자 확인 필요 | 체크리스트 4. 코드 경로는 아래 "cause/position 경로" 표로 확인 |
| AC9 | 사용자 확인 필요 | 체크리스트 5 |

요약: 순수 로직 AC1~AC4 통과(4/4), Studio AC5~AC9 사용자 확인 필요(5). 실패한 기준 없음.

## 코드 리뷰

### cause/position 경로 (스펙 범위 3)
| 상황 | 경로 | cause | position |
|---|---|---|---|
| 맵 낙하 판정 | `ctx.eliminate` → `queueFall(…, "Fall")` (`RoundService.luau:362-366`) | Fall | 그 순간 루트 위치 (`:267-271`) |
| 사망(리셋) | `Humanoid.Died` (`:291-293`) | Reset | 죽은 캐릭터의 루트 위치 |
| 캐릭터 제거·교체 | `AncestryChanged`/`CharacterAdded` (`:295-302`) | Reset | 옛 캐릭터 루트 위치 (없으면 아래 B2) |
| 배치 때 캐릭터 없음 | `placeAt` (`:310-315`) | Reset | nil |
| 라운드 중 방/게임 나감 | `handlePlayerLeft` → `queueFall("Reset")` → flush 때 `getRoomIdOf ~= roomId`라서 `EliminationService.left` (`:211-221`). `RoomService.leaveRoom`이 핸들러를 부른 뒤 바로 멤버십을 지우고(`RoomService.luau:245-253`), flush는 `task.defer`라 항상 그 뒤에 돈다 | Left | nil |
| 라운드 밖에서 나감 | `MatchService.luau:285-289` → `left` | Left | nil |
| 시간 종료·인원 다 참 | `RoundLogic.timeout`/pass 뒤 남은 사람 | nil (스펙 결정 기록) | 그 순간 위치 (`EliminationService.luau:70` fallback) |
| 결승 진출 2명 보장 구제 | Passed로 바뀜 | 해당 없음 | 해당 없음 |

### 다른 M3 스펙이 기대하는 인터페이스 대조
| 인터페이스 | 쓰는 스펙 | 결과 |
|---|---|---|
| `CameraDirector.request/release/isActive`, `Priority` 5개 값 | m3-03(Elimination), m3-04(Intro), m3-05(VictoryCutscene) | 일치. QA 테스트로 값과 동작 확인 |
| SpectateController가 `Victory`(20)로 우승자 비추기 | m3-05 "release 뒤 Victory가 이어받음" | 일치 (`SpectateController.luau:143-151`) |
| `Attributes.AppearanceId/GrabbedBy/GrabbingUserId/RoomId/RoundIndex/MapId` | m3-02, m3-04, m3-07 | 일치 |
| `SfxCues` 이름, `Sfx.play/setMusic/start` | m3-02~m3-09 | 일치. `Sfx.play`는 start 전에도 에러 없음, 모르는 이름 이름당 1회 경고 (QA 테스트) |
| `SushiBody.layout`(lune에서 불러올 수 있음) / `build`(PrimaryPart `Body`, 2.4×4×1.8) | m3-02, m3-03, m3-05 | 일치 |
| `AppearanceService.applyAppearance(character, appearanceId?)`, `CharacterAdded` 연결 | m3-02 | 일치 |
| `GrabService` (GrabInput 받고 무시), `Remotes.event("GrabInput")` | m3-07 | 일치. 이름은 EVENTS에만 있음 (QA 테스트) |
| `RoundService.activeRoomOf(player)` — 출발 후·배치됨·대기열 아님·아직 레이서일 때만 방 id | m3-07 | 일치 (`RoundService.luau:387-394, 494-504`). 사망·캐릭터 교체 순간 `pendingIds`로 바로 nil이 되고, flush 뒤에는 `isRacing`이 false |
| `PlayerResult.cause/position`, `shouldPlay(nil) = false` | m3-03 | 일치 (시간 종료 탈락은 연출 없음 — 스펙 결정 기록의 열린 질문) |
| `Config.Dive/Grab/Appearance/Match.VictoryCutscene` | m3-02, m3-05~m3-07 | 일치 (QA 테스트로 값 고정) |
| E 키 충돌 (관전 "다음 사람" = 다이브) | m3-06 | m3-06이 `CameraSubject`가 내 Humanoid가 아니면 다이브하지 않도록 이미 정함. 관전 cycle은 관전 중일 때만 동작하므로 충돌 없음 |

### M2 회귀
- `SpectateController`: M2의 `cameraOverridden`(우리가 바꿨을 때만 되돌림)이 "요청하지 않은 owner의 release는 아무것도 안 함"으로 바뀌었다 — 같은 의미 (QA 테스트 `요청하지 않은 owner를 release해도 아무 일 없어요`). 0.25초마다 재요청할 때 1등이면 apply를 다시 불러 기본 카메라 스크립트가 되돌린 `CameraSubject`를 다시 맞추는 M2 동작도 유지 (`1등 owner가 다시 요청하면 apply를 또 불러요`).
- `Victory`↔`Spectate` 전환 때 `release`→`request` 사이에 기본 카메라가 한 번 적용되지만 같은 프레임 안이라 보이지 않는다.
- `RoundService`: `activeRacing`은 `activeRemovers`와 같은 방식으로 `close()`에서 지운다. 판정·순위 로직(`RoundLogic`)은 바뀌지 않았다. 기존 209개 테스트 통과.

## 버그
P0/P1/P2 없음.

### [P3] B1 관전 "탈락 대상 비추기"가 서버의 로비 이동보다 네트워크 지연만큼 늦게 끝남
- 재현: 2~3명, A가 B를 관전 중에 B가 낙하로 탈락.
- 기대: 약 3초 동안 B가 떨어진 자리를 비춘 뒤 다음 사람으로 넘어간다.
- 실제(코드상): 서버는 방송 순간부터 3초 뒤 B를 로비로 옮기고(`EliminationService.luau:86`), 클라이언트 hold는 받은 순간부터 3초(`SpectateController.luau:201`)라 그 차이(핑)만큼 B가 로비로 순간이동하는 모습이 비칠 수 있다. m3-03이 진짜 캐릭터를 숨기고 인형을 쓰면 거의 안 보일 것. 신경 쓰이면 m3-09에서 hold를 조금 짧게(예: `EliminationCutscene - 0.3`).
- 위치: `src/client/ui/SpectateController.luau:201`, `src/server/EliminationService.luau:86`

### [P3] B2 Reset 경로에서 옛 캐릭터 루트가 이미 없으면 position이 새 캐릭터(로비) 위치로 채워질 수 있음
- 재현(드묾): 죽음(`Died`) 없이 캐릭터가 교체·제거되거나, 루트 파트가 먼저 사라진 뒤 사망하는데 그 사이 새 캐릭터가 생긴 경우.
- 기대: position = 탈락 자리, 모르면 nil (m3-03은 position이 없으면 연출을 안 함).
- 실제: `lastPosition()`이 nil이면 `queueFall`이 `rootOf(player)`(지금 `player.Character` = 새 캐릭터)로, `EliminationService.eliminate`도 `player.Character`의 루트로 채운다 → 로비 스폰 위치에서 탈락 연출·관전 hold가 나올 수 있다. 일반 리셋(Esc→R)은 `Died`가 먼저 와서 해당 없음.
- 위치: `src/server/RoundService.luau:267-271`, `src/server/EliminationService.luau:70`

### [P3] B3 (질문, 버그 아님) 시간 종료·인원 다 참 탈락은 cause nil이라 탈락 연출이 없음
- 개발이 스펙 결정 기록에 남긴 열린 질문과 같다. Race에서 가장 흔한 탈락이라 연출을 원하면 기획이 `"Timeout"` 같은 cause를 정해 m3-09에서 추가 (`Types.EliminationCause`, `RoundService`, m3-03 `shouldPlay`).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 `GrabInput`은 껍데기라 아무것도 하지 않는다(무해). 타입·간격 검증은 m3-07 몫이고 `GrabService.luau` 맨 위 주석에 적혀 있다.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — cause/position은 서버가 채우고 클라이언트(SpectateController)는 카메라만 바꾼다.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 새 `causeOf`/`positionOf`는 `prepareRound` 지역 상태, 방별 `activeRacing`은 `close()`에서 지움.
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 새 연결 없음(기존 `watch` 연결에 위치만 추가). `AppearanceService`의 플레이어별 `CharacterAdded` 연결은 Player가 사라지면 같이 정리된다.

## 사용자 Studio 확인 체크리스트
1. **AC5 한 판 끝까지** — `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 `{ "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`로 바꾸고 `rojo serve` → Studio F5. 방 만들기 → 시작 → 우승 화면까지. 서버·클라이언트 Output에 빨간 에러가 없어야 한다. 우승 단계가 약 10초인지 본다. (끝나면 `forceMapPlan = nil`로 되돌릴 것)
2. **AC6 속성** — 라운드 중 Studio 상단 "Current: Client"를 "Server"로 바꿔 Explorer에서 `Workspace/Round1_soy-swamp`를 선택 → Properties 아래 Attributes에 `RoomId`(문자열), `RoundIndex = 1`, `MapId = "soy-swamp"`. `Workspace/<내 이름>` 캐릭터에 `AppearanceId = "tamago"`. 로비에서도 캐릭터에 같은 속성이 있어야 한다.
3. **AC7** — 플레이 중 Shift를 눌러도 마우스가 화면 가운데에 고정되지 않는다. Esc 설정 메뉴에 Shift Lock 항목이 없거나 꺼져 있다. 내 캐릭터가 옷·모자 없는 기본 블록 체형이다.
4. **AC8 cause/position** — Test 탭 → Clients and Servers, 플레이어 3명. 각 클라이언트 창의 Command Bar(View → Command Bar, 클라이언트 쪽)에서
   `game.ReplicatedStorage.Remotes.PlayerResult.OnClientEvent:Connect(function(r) print(r.userId, r.result, r.cause, r.position) end)` 실행.
   - Player1이 맵 밖으로 떨어진다 → 다른 클라이언트 Output에 `Eliminated Fall <x, y, z>`.
   - Player2가 Esc → Reset Character → `Eliminated Reset <x, y, z>`.
   - (새 판에서) 한 명이 라운드 중 방 나가기 버튼 → `Eliminated Left nil`.
   - 참고: 시간 종료로 탈락하면 `cause = nil`이 정상이다 (B3).
5. **AC9 관전 회귀** — `docs/DEV-SETUP.md`의 M2 관전 항목(m2-06 AC5~AC12)을 그대로 따라 한다. 추가로: 탈락해서 관전 중일 때 보고 있던 사람이 떨어지면 약 3초 동안 그 자리를 계속 비춘 뒤 다음 사람으로 넘어간다. 그 3초 동안 ←/→(Q/E)를 누르면 바로 넘어간다. 보고 있던 사람이 결승선을 통과하거나 방을 나가면 바로 넘어간다.

## 추가한 테스트
`tests/m3-01-qa.spec.luau` (20개)
- `CameraPriority.pick`: 입력 불변, 먼저 요청한 높은 우선순위가 이김, 다섯 owner 동시.
- `CameraDirector`(가짜 `game`·`workspace`·`Enum`으로 실제 모듈을 불러옴): `Priority` 값, 높은 요청만 apply·release 뒤 다음 owner 재적용, 아무도 없으면 기본 카메라(Custom + 내 Humanoid), 1등 재요청 시 apply 재호출, 요청 안 한 owner release 무시, 낮은 owner release 때 1등 재적용 안 함, 같은 우선순위·재요청 순서, 우선순위 변경, apply 에러 시 경고만.
- `Sfx` 껍데기: start 전 호출 무시, 모르는 cue·music 이름당 1회 경고, 효과음/음악 이름 구분.
- `Config`: M2 연출 시간 유지·VictoryDuration 10, Dive·Grab 기본값과 범위.
- 공용 파일: `GrabInput`이 RemoteEvent 목록에만 있음, `default.project.json` StarterPlayer 값, `SushiBody`를 lune에서 불러올 수 있음, 클라이언트/서버 init 등록과 `start(gui)`/`init()`·`start()` 존재.

## 인계 메모
- 지금 브랜치: `m3-01-qa` (main `5f2e43b`에서 분기, QA 커밋 + push)
- 끝난 것: 자동 검증 4종 통과(235/0), AC1~AC4 통과, 인터페이스 대조, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC5~AC9 (위 체크리스트). 메인 세션이 `m3-01-qa`를 main에 병합.
- 다음에 할 첫 단계: `m3-01-qa` 병합 → m3-02~m3-08 worktree 생성. docs-writer가 DEV-SETUP에 M3 기반 확인 항목(체크리스트 1~5) 반영.
- 막힌 점: 없음. 기획 결정 하나 남음 — 시간 종료 탈락 cause(B3).
