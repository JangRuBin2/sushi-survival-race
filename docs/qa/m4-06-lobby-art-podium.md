# QA — m4-06 로비 아트 · 조명 · 우승자 단상

- 스펙: `docs/specs/m4-06-lobby-art-podium.md`
- 검증 커밋: `e8c4b36` (m4-06-lobby) + `origin/main` 병합 `2a43fd0` (m4-04/05/07/08 포함, 충돌 없음)
- 결과: **통과** (P0/P1 없음, P2 1건·P3 3건). Studio 항목 AC6~AC11은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 703 passed, 0 failed (병합 후 기존 692 + QA 추가 11) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `tests/lobby-layout.spec.luau` "AC1" 2개. 파츠 265 (예산 800), 빛 8 |
| AC2 | 통과 | `lobby-layout.spec` "AC2" 3개 + QA "스폰(12x12)과 그 위 캐릭터 공간", "스폰 → 단상 사이", "충돌 파츠 사이 좁은 틈 없음", "아레나 슬롯·우승 연출 무대와 떨어져 있어요" |
| AC3 | 통과 | `lobby-layout.spec` "AC3" 4개 + QA "큰 서버 시각(1.9e9)에서도 접시 간격·위치가 정확해요" |
| AC4 | 통과 | `lobby-layout.spec` "AC4" (Density 0.22, Technology 키 없음) + QA 소스 검사 "Technology 안 건드림" |
| AC5 | 통과 | 위 자동 검증 4개 |
| AC6 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC7 | 사용자 확인 필요 | 체크리스트 2. 코드상 스폰·통로·스폰→단상 길에 충돌 파츠 없음 (QA 테스트), 로비 UI는 ScreenGui라 3D에 가려지지 않음 |
| AC8 | 사용자 확인 필요 | 체크리스트 3. 승수는 `Won` 결과 때 RewardService가 메모리 프로필에 동기 반영(`DataService.update`), 단상은 그 10초 뒤(`MatchService.luau` VictoryDuration 대기 후) 읽으므로 순서 문제 없음. L1(이름표 아래 줄 가림) 확인 |
| AC9 | 사용자 확인 필요 | 체크리스트 4. 코드: `GetServerTimeNow` 기준 `BulkMoveTo`, 서버는 접시를 t=0에 고정 |
| AC10 | 사용자 확인 필요 | 체크리스트 5. Lighting을 바꾸는 다른 코드 없음(grep), Density 0.22 |
| AC11 | 사용자 확인 필요 | 체크리스트 6. 매 프레임 비용: 접시 16 × (이분 탐색 10단계) + CFrame 52개 `BulkMoveTo`, 카메라가 레일에서 400 넘게 멀면 쉼 |

판정: 자동 확인 가능한 AC1~AC5 5/5 통과, AC6~AC11 6개 사용자 확인 필요.

## 버그
### [P2] L1 단상 인형 머리가 이름표 아래 두 줄("N승", 칭호 아래쪽)을 가림
- 재현: 한 판 이긴 뒤(1승 이상) 로비로 돌아와 단상을 정면에서 본다.
- 기대: "🏆 이름 / 칭호 / N승" 세 줄이 인형 위에 다 보인다.
- 실제(계산): 인형(1.5배 계란초밥) 꼭대기 y = 5 + 2.3×1.5 + 2.4×1.5 = **12.05**. 이름표 BillboardGui는 가운데 y 13, 높이 4.5 → 10.75~15.25이고 아래 정렬이라 Wins 줄 10.75~11.875, Title 줄 11.875~13.225, Name 줄 13.225~15.25. `AlwaysOnTop`이 꺼져 있어 인형(폭 4.2)이 Wins 줄 전체와 Title 줄 아래쪽을 앞에서 가린다. 빈 단상("다음 우승자는 누구?")과 이름 줄은 괜찮다.
- 고치는 방법 예: `PODIUM.labelHeight`를 약 14.5 이상으로 올리거나 `billboard.StudsOffset`/`ExtentsOffsetWorldSpace`로 위로 띄움. 고친 뒤 `tests/m4-06-qa.spec.luau`의 단상 테스트를 `dollTop <= labelBottom`으로 강화 권장.
- 위치: `src/shared/LobbyLayout.luau:313` (`labelHeight = 13`), `src/server/LobbyService.luau:157`
- Studio 확인 필요 (계산상 확실하지만 실제 가림 정도는 화면에서).

### [P3] L2 우승자가 Victory 10초 안에 나가면 단상 인형이 기본 외형, 칭호·승수 없음
- 재현: 결승에서 이긴 직후(우승 화면 10초 동안) 게임을 나간다.
- 기대: 스펙 "플레이어가 나가도 인형은 남는다(이름은 그대로)" — 쇼케이스 뒤 퇴장은 만족. 쇼케이스 전 퇴장은 스펙에 없음.
- 실제: `fireWinnerShowcase`가 캐릭터 속성에서 외형을 읽어 나간 사람은 `Config.Appearance.Default`, 프로필도 내려가 칭호·승수 생략. 이름은 순위표에서 가져와 정상.
- 위치: `src/server/MatchService.luau:113`, `src/server/LobbyService.luau:204`. 지금은 스킨이 하나라 눈에 안 띔. 스킨(m4-14) 때 매치 시작 시 외형을 ctx에 저장해 두는 쪽 권장. 개발 메모에 이미 적혀 있음.

### [P3] L3 로비 플레이스(PlaceRole "Lobby")에서는 단상 쇼케이스를 보내는 곳이 없음
- `MatchService.fireWinnerShowcase`는 `"Single"`에서만 보내고, `"Lobby"` 역할의 송신은 m4-11 몫(주석에 명시). 로비는 지어지지만 단상은 계속 빈 단상. m4-11 스펙에 이어서 넣을 것. 지금은 항상 Single이라 영향 없음.
- 위치: `src/server/MatchService.luau:103-105`

### [P3] L4 벽 밖 Baseplate 띠(폭 약 38)가 그대로 보임
- 결정 기록(개발, "반지름 128 = 수평 거리" → 안쪽 벽면 ±88)대로 구현. 벽 14 studs는 점프(최대 약 6.4)로 못 넘으므로 플레이어가 나갈 수는 없음. 위에서 내려다보는 카메라(관전에서 로비로 돌아오는 순간 등)에만 보이는 외관 문제. 사용자가 원하면 Baseplate를 줄이거나 벽 밖을 다른 색으로.

## 스펙과 다르게 한 것 (타당성)
- **인형을 클라이언트가 생성**: 타당. `tests/m3-02-qa.spec.luau`가 서버 소스 전체에서 `SushiBody` 문자열을 막는다(AppearanceService만 예외). 서버는 `Lobby.Podium` 폴더 속성 3개(`WinnerUserId`·`WinnerAppearanceId`·`WinnerSerial`)만 바꾸고, 클라이언트가 serial 변경 때 인형을 다시 세움. 속성은 serial을 마지막에 쓰므로 클라이언트가 serial 신호를 받을 때 appearanceId는 이미 갱신돼 있다. 늦게 들어온 클라이언트도 `watchPodium`이 처음 한 번 `placeDoll`을 불러 현재 우승자를 세움. 결과: 서버 Explorer에는 인형이 없다(Studio 확인 때 혼동 주의).
- **벽 위치 ±88~90**: 스펙 "원점 반지름 128"을 수평 거리로 지키려면 모서리 기준 정사각형 반폭 ≤ 90.5라 타당. 대신 L4.
- 스펙 지정 외 파일 수정: **없음**. 브랜치 diff는 `LobbyService.luau`, `LobbyFxController.luau`, 새 `LobbyLayout.luau`, `tests/lobby-layout.spec.luau`, 스펙·개발 기록뿐. 공용 파일·`default.project.json` 변경 없음.

## 추가 확인 (코드 리뷰)
- **아레나·연출 무대와 겹침 없음**: 로비 외곽 x,z ≤ 90, y ≤ 19. 아레나는 x ≥ 2000·y 300, 우승 연출 무대(`VictoryCutsceneLogic.SCENE_ORIGIN` (0,1500,-4000)) — 둘 다 멀리.
- **스폰·통로**: LobbySpawn(12×12, (0,0.5,0)) 위와 스폰 반지름 10, 통로(x ±5, z -27.5~-10), 스폰→단상 길(+X 6~26)에 충돌 파츠 없음. 의자는 장식(충돌 없음)이고 통로 앞 의자는 빠져 있음.
- **끼일 곳**: 충돌 파츠(벽·기둥·카운터·레일·단상) 사이 1~3 studs 틈 없음(QA 테스트). 기둥 (±86,·,0)과 벽 사이 0.5 틈은 캐릭터가 못 들어감. 카운터+레일 높이 3.8 < 점프 약 6.4라 안쪽(셰프 쪽)에 들어가도 나올 수 있음. 단상 계단 2~3 studs 차이도 오를 수 있음.
- **카메라**: 장식(들보·등·노렌)은 `CanQuery = false`라 카메라 Popper에 안 걸림. 들보 y 16.75가 스폰 바로 위를 지나지만 충돌·쿼리 없음.
- **조명**: `init`에서 역할 상관없이 한 번, 이미 있는 Atmosphere/ColorCorrection/Bloom은 재사용(중복 생성 없음), `Technology` 안 건드림. 다른 맵 코드는 Lighting을 안 바꿈.
- **여러 방 동시 우승**: 핸들러는 양보 없이 serial을 1씩 올리고 이름표를 바로 바꿔서 마지막에 불린 쇼케이스가 남음(가장 최근 1명). 핸들러 오류는 `MatchEvents`가 pcall로 감쌈.
- **우승자 퇴장(쇼케이스 뒤)**: 서버 이름표·폴더 속성은 플레이어와 무관하게 남고, 클라이언트 인형도 남음.
- **클라이언트 정리**: `RenderStepped` 연결은 Lobby가 사라지면 끊김. 접시 수 52 파츠, 프레임 비용 작음. 매치 플레이스에서는 `WaitForChild("Lobby", 60)` 뒤 그냥 끝남(경고 없음). 인형 파츠는 앵커·충돌·쿼리·터치 없음.
- **m4-07/m4-08 연동**: `DataService.get`(동기, 양보 없음)과 `ProfileSchema.titleFor`(0승이면 nil)만 읽음. 쓰기 없음.
- **매치 플레이스**: `LobbyService.start`에서 `PlaceService.role() == "Match"`이면 로비·단상 구독 모두 건너뜀(QA 소스 테스트).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 새 리모트 없음. 클라이언트 FX는 리모트를 안 씀(QA 테스트)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 로비는 연출만, 우승자는 MatchService가 확정한 값
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음(로비는 서버에 하나). `LobbyService`의 모듈 상태(`podiumFolder`, `labels`, `showcaseSerial`)는 서버 하나에 로비 하나라 문제 없음
- [x] 연결·인스턴스·스레드가 정리된다 — 서버 구독은 서버 수명 동안 유지(의도), 클라이언트 렌더 연결은 Lobby 제거 시 끊김, 인형은 새로 세울 때 이전 것 Destroy

## 사용자 Studio 확인 체크리스트
`Config.DEBUG.forceMapPlan`은 커밋 상태 `nil`. 3번만 잠깐 바꾸고 커밋하지 말 것.
1. **AC6** F5. 스폰 앞(-Z) 약 40에 타원 카운터와 도는 접시 16개(빨강·파랑·금색), 카운터 안 셰프(흰 모자)·도마, 뒤 벽 메뉴판 4장과 남색 노렌, 반대쪽(+Z) 벽 빨간 노렌과 왼쪽 수조(물고기), 오른쪽(+X 30) 3단 단상(금색 테두리) 위 "다음 우승자는 누구?". 조명이 따뜻한지. 스크린샷.
2. **AC7** 스폰에서 바로 W로 카운터까지, D로 단상까지 걸어간다(막힘 없음). 카운터 위로 점프해 안쪽으로 들어갔다가 다시 나올 수 있는지. 벽 모서리·기둥 사이에서 끼이지 않는지. 방 목록 UI가 그대로 보이는지.
3. **AC8 + L1** `forceMapPlan`에 맵 3개(예: `{ "rotating-belt", "hot-plate", "skewer-showdown" }`)를 넣고 혼자 한 판 이긴다. 로비로 돌아와 단상 가운데에 1.5배 계란초밥 인형이 스폰 쪽을 보고 서 있는지, 이름표 "🏆 내 이름 / 탈출 초밥 / 1승"이 보이는지. **"1승"과 "탈출 초밥" 아래쪽이 인형 머리에 가려지는지 확인(L1)**. 한 번 더 이겨 "2승"으로 바뀌고 인형이 다시 세워지는지. 서버 뷰 Explorer에는 인형이 없고 클라이언트 뷰 `Workspace.Lobby.Podium.WinnerDoll`에 있는 게 정상.
4. **AC9** Test → Clients and Servers 2명. 두 창에서 금색 첫 접시 자리가 거의 같은지(1초 이내). 서버 뷰에서 `Workspace.Lobby.Plates.Plate01`의 Position이 안 바뀌는지.
5. **AC10** 2명 이상으로 매치를 돌려 아레나도 따뜻한 조명인지, 탈락 뒤 관전 화면에서 먼 쪽이 안개로 뿌옇지 않은지.
6. **AC11** 로비에서 MicroProfiler(Ctrl+F6) 또는 Shift+F5 통계로 프레임 확인, M3 로비(이전 커밋)와 비교. Device 에뮬레이터(휴대폰)에서도.
7. (선택) 2개 방을 동시에 돌려 거의 같은 시각에 끝내면 단상에 나중에 끝난 방의 우승자만 남는지.

## 추가한 테스트
`tests/m4-06-qa.spec.luau` (11개)
- 스폰(12x12)과 그 위 캐릭터 공간에 충돌 파츠 없음
- 스폰 → 단상 사이(+X 6~26) 비어 있음
- 충돌 파츠 사이 1~3 studs 끼임 틈 없음
- 카운터·단상 높이가 점프 높이보다 낮음
- 단상 인형이 단 윗면에 서고 이름 줄이 머리 위 (L1의 아래 두 줄 가림은 P2라 실패 테스트로 넣지 않고 주석으로 남김)
- 레일 위 접시 높이·폭
- 큰 서버 시각(1.9e9, 2.1e9)에서 접시 간격·프레임당 이동 정확
- 로비가 아레나 슬롯(높이·x 간격)과 우승 연출 무대에서 떨어짐
- 서버 소스 불변식: start 안 Match 가드, init은 조명만, Technology·SushiBody 없음
- 클라이언트 소스: 서버 시각·BulkMoveTo·연결 끊기·먼 거리 쉼·인형 앵커/충돌 없음·리모트 없음
- 단상 속성 이름 서로 다름

## 인계 메모
- 브랜치: `m4-06-qa` (origin/m4-06-lobby + origin/main 병합). push 완료.
- 끝난 것: 코드 리뷰, 자동 검증 4개 통과, QA 테스트 11개 추가, 이 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인(체크리스트 1~7). L1(P2)은 개발이 고치길 권장(머지 차단 아님). L2·L3는 m4-14·m4-11 때.
- 다음에 할 첫 단계: 이 브랜치를 main에 병합(사용자/메인 세션), 또는 개발이 L1 수정 후 QA 재확인.
- 막힌 점: 없음.
