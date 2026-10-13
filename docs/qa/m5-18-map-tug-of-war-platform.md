# QA — m5-18 세 번째 결승 맵: 줄다리기 발판 (`tug-of-war-platform`)

- 스펙: `docs/specs/m5-18-map-tug-of-war-platform.md`
- 검증 커밋: `4192744` (`origin/main`, m5-18 병합 `907fdee` 포함) + QA 테스트 추가 (브랜치 `m5-qa-maps-b`)
- 결과: **통과 (qa-passed)**. P0/P1 없음, P2 1건(연장전 "설 곳 없음" 계약의 기하 구멍, 안전 상한이 마무리) + P3 1건 + Studio 위험 2건. Studio 항목 AC9~AC16은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 포함) |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — **1258 passed, 0 failed** (QA 25 포함, 이 스펙 QA 8) |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-tug-of-war-platform.spec` "AC1" 2개 + QA "스폰 24개 가장자리에서 2 이상 안쪽, 좌우 토크 합 0" |
| AC2 | 통과 | `map-tug-of-war-platform.spec` "AC2" + QA "좌우 대칭·오른쪽 추가 단조(1000번)", "포화 경계 104.9/105" |
| AC3 | 통과 | `map-tug-of-war-platform.spec` "AC3" + QA "approach 무작위 1000번(넘어서지 않음, |변화| ≤ maxDelta)", "60fps 흉내: 평평 → 포화 ≥ 1.5초" |
| AC4 | 통과 | `map-tug-of-war-platform.spec` "AC4" + QA "꺾인점 부호 +,−,+,− 크기 30/50/70/90" |
| AC5 | 통과 | `map-tug-of-war-platform.spec` "AC5" + QA "8·20·40초, 시작 각도 5종: 시작 순간 끊김 없음, 프레임당 변화 ≤ 160°/(d/4), |각도| ≤ 90°, 끝난 뒤 계속 수직" (단 B1 참고 — 순수 로직은 맞고, 판정 파츠 두께 때문에 생기는 구멍) |
| AC6 | 통과 | `map-tug-of-war-platform.spec` "AC6" |
| AC7 | 통과 | `map-tug-of-war-platform.spec` "AC7" 2개 |
| AC8 | 통과 | 위 자동 검증 5단계, `maps`·`round-logic` 통과 |
| AC9 | 사용자 확인 필요 | 체크리스트 1 (부호: `CFrame.Angles(0,0,z)`는 z>0이면 +X가 올라가서 `TILT_SIGN = -1`이 맞아요 — 코드 계산상 OK) |
| AC10 | 사용자 확인 필요 | 체크리스트 2 (R1) |
| AC11 | 사용자 확인 필요 | 체크리스트 3 (B1) |
| AC12 | 사용자 확인 필요 | 체크리스트 4 (R2) |
| AC13 | 사용자 확인 필요 | 체크리스트 5 |
| AC14 | 사용자 확인 필요 | 체크리스트 6 (지금 결승 풀 = 꼬치·줄다리기·인형뽑기 3개, ikura-bombs는 아직 풀 밖) |
| AC15 | 사용자 확인 필요 | 체크리스트 7 |
| AC16 | 사용자 확인 필요 | 체크리스트 8 |

자동 확인 8/8 통과, Studio 8개 대기.

## 버그
### [P2] B1 연장전 끝(정확히 90°)에 발판 끝면이 2×22 수평 턱이 된다
- 재현(기하 계산): 발판은 길이 70 × 두께 2 × 폭 22, 피벗은 윗면 가운데. 마지막 꺾인점 −90°에서 +X 끝이 위로 서는데, 그 끝면(원래 법선 +X, 크기 2×22)이 회전하면 법선이 정확히 +Y가 돼요 → 피벗 위 35 높이에 **너비 2, 길이 22의 수평 턱**. 75°쯤부터 이 면의 경사는 15° 이하라 휴머노이드가 설 수 있는 경사(MaxSlopeAngle 기본 89°)이고, `collapseDuration` 뒤에는 각도가 −90°로 고정돼 계속 남아요.
- 기대: 스펙 D2·`MapTypes` 연장전 계약 — "collapseDuration 안에 어떤 레이서도 안전하게 서 있을 수 없게(매달리기·높은 곳 버티기 자리도 없게)". 스펙은 "수직이면 설 수평면이 없다"를 기하학적 보장으로 들었어요.
- 실제: 윗면은 수직이라 못 서지만 끝면(두께 2)이 그 순간 수평면이 돼요. 마지막 스윙(+70° → −90°, 약 32°/s)에서 +X 끝 모서리에 붙어 있던 사람이 턱 위로 올라앉으면 안전 상한(150초)까지 버티고, 상한에서 "가장 높은 1명"으로 우승해요. 경기는 끝나니 P2(계약 위반, 실제로 오를 확률은 낮음 — Studio 확인 필요).
- 위치: `src/shared/maps/TugOfWarPlatformLogic.luau:15` (`LETHAL_ANGLE = rad(90)`), 판정 파츠 `src/shared/maps/TugOfWarPlatform.luau:71-81`
- 제안(developer): ① `elapsed ≥ collapseDuration`이면 `Platform.CanCollide = false`(가장 확실, 꼬치 쇼다운의 "마지막 줄 제거"와 같은 결), 또는 ② 마지막 꺾인점을 90°보다 크게(예 110°) 해 끝면이 바깥으로 기울게. ②는 스펙 AC4·AC5 수치(마지막 = 정확히 90°)를 바꾸니 planner 확인이 필요하고, ①은 스펙 수치를 그대로 둬요.

### [P3] B2 발판 밖으로 미끄러져 떨어지는 사람도 잠깐 토크에 들어간다
- 재현: 코드 확인. 낙하선(−25) 위에 있는 동안은 공중·발판 밖이어도 `relative.X`가 그대로 `positions`에 들어가요(예: x = 40). 탈락 처리 전 수 프레임 동안 그쪽으로 조금 더 기울어요.
- 기대: 스펙은 "레이서의 로컬 X(−35~35)".
- 실제: 체감 영향은 작음(TILT_RATE 제한으로 프레임당 0.33°). 고친다면 `math.clamp(relative.X, -HALF_LENGTH, HALF_LENGTH)` 또는 발판 위(레이캐스트)인 사람만.
- 위치: `src/shared/maps/TugOfWarPlatform.luau:204-212`

## 위험 (Studio에서 확인)
- **R1 30°에서 정말 미끄러지는가**: 맵의 위험은 "마찰 0.35 + 30° → 미끄러짐"에 기대요. Roblox 휴머노이드는 경사 89° 아래에서는 바닥으로 인식하고 이동 힘으로 버티는 편이라, 가만히 서 있으면 30°에서도 안 미끄러질 수 있어요. 그러면 평상시 결승은 위험이 거의 없고 연장전만 승부가 돼요. AC9·AC10에서 꼭 확인하고, 안 미끄러지면 planner·developer가 `MAX_ANGLE`/마찰/휴머노이드 `MaxSlopeAngle` 조정을 결정해야 해요.
- **R2 회전하는 발판이 사람을 퍼 올림**: 발판은 Anchored + `BulkMoveTo`라 표면 속도가 0인 채로 위치만 바뀌어요. 연장전 마지막 스윙에서 끝부분은 약 19.5 studs/s로 사람을 밀어 올려요(겹침 해소). 이동 감시 상한(수평 80, 상승 140)보다 한참 낮아 계산상 안전하지만, 겹침 해소로 튕기는 순간이 있는지 AC12에서 Output을 봐요. 스펙대로 `MoveExempt`는 안 달려 있어요(연속 움직임 규칙에 맞음).

## 코드 확인 (서버 판정 · 맵 계약)
- 판정은 전부 서버: origin 기준 Y < −25면 `ctx.eliminate`, 라운드가 끝나면 즉시 return(`TugOfWarPlatform.luau:204-210`). `ctx.pass` 없음(결승선 없음).
- 평상시 30°에서 낮은 끝 윗면은 −17.5 → 서 있는 사람(루트 약 +3)은 탈락선 위(QA 테스트). 수직이면 낮은 끝은 −35로 탈락선 아래.
- 상태: `roundStates[ctx]`(ctx 키, `ctx.cleanup`이 지움) — 꼬치 쇼다운과 같은 허용 패턴. 여러 방이 섞이지 않아요.
- 연장전 훅: 기다리지 않고 시작 시각·각도만 기록, Heartbeat가 적용(`:233-243`). `start` 전에 불리면 그냥 return(안전 상한이 마무리).
- 충돌 파츠는 `Platform` 하나뿐: 장식(`deckDecor`·`decor`)은 `MapKit.buildDecor`(충돌·쿼리·터치 없음), 스폰 `CanCollide=false`. 그래서 B1의 턱만 빼면 연장전 뒤 설 곳이 없어요.
- `MoveExempt` 안 씀 — 스펙 D3·CLAUDE.md(기울기 = 연속 밀기)에 맞아요.
- 정리: Heartbeat 연결과 상태 지우기가 `ctx.cleanup`. 새 리모트 없음.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트 없음
- [x] 통과·탈락·순위 판정이 서버에만 있다
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 (`roundStates[ctx]`)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다

## 사용자 Studio 확인 체크리스트
준비: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "tug-of-war-platform" }`, 빠른 연장전은 `Config.DEBUG.overtimeAt = 15`. **확인 뒤 둘 다 `nil`.**
1. (AC9) 결승에서 오른쪽(+X, `Spawn13`~`Spawn24`가 있는 쪽) 끝으로 걸어가면 그쪽이 1~2초에 걸쳐 서서히 내려가는지(홱 꺾이지 않음). 내 쪽이 올라가면 `TugOfWarPlatform.luau`의 `TILT_SIGN`을 뒤집어야 해요. 반대편으로 가면 서서히 평평해지는지.
2. (AC10, R1) 혼자 끝에 서면 약 10°만 기울어요. Clients and Servers 3명 이상으로 한쪽 끝에 몰려 30°가 됐을 때 **가만히 서 있는 사람이 실제로 미끄러지는지** 꼭 적어 주세요. 2명이 반대편에 나뉘면 오래 버티는지.
3. (AC11, B1) `overtimeAt = 15`로 연장전 배너 뒤 발판이 좌우로 점점 크게 흔들리다 약 20초 뒤 수직이 되는지, 전원이 떨어지고 늦게 떨어진 사람이 우승하는지. 마지막 스윙 때 위로 올라가는 끝 모서리에 일부러 붙어 있다가 수직이 된 발판의 **위쪽 끝(두께 2짜리 턱)** 위에 올라설 수 있는지 시도해 봐요. 올라서져서 150초까지 버티면 B1 재현.
4. (AC12, R2) 미끄러질 때와 연장전 스윙 때 서버 Output에 `[MovementGuard]` 경고·되돌림이 없는지.
5. (AC13) Play Solo 결승도 연장전 → 수직 붕괴로 끝나는지(멈추지 않음).
6. (AC14) 강제 플랜 없이(`forceMapPlan = nil`) 4명 이상 판을 여러 번 해서 결승이 꼬치 쇼다운·줄다리기 발판·인형뽑기 중 무작위로 나오는지.
7. (AC15) 휴대폰 에뮬레이터에서 저울 접시·동아줄이 시야를 가리지 않고, 기울 때 카메라가 어지럽지 않은지.
8. (AC16) 재미: "몰리면 위험하다" 느낌인지, 억울하게 미끄러지는지. 숫자(`MAX_ANGLE`·`SATURATION_TORQUE`·`TILT_RATE`·마찰)를 알려 주세요.

## 추가한 테스트
- `tests/m5-18-qa.spec.luau` (8개): tilt 좌우 대칭·단조(1000번), 포화 경계, approach 무작위 불변식, 60fps 서버 루프 흉내(포화까지 ≥ 1.5초, 반대편까지 ≥ 3초), overtimeAngle 연속성·프레임당 변화 상한·90° 넘지 않음·끝난 뒤 수직(3 길이 × 5 시작 각도), 꺾인점 부호, 낙하선(30°에서 오탐 없음/수직이면 아래), 스폰 가장자리 여유·출발 토크 0.

## 인계 메모 (2026-10-13, qa)
- 브랜치: `m5-qa-maps-b` (`origin/main` `4192744` 기준).
- 끝난 것: 검증 5단계, AC1~AC8 확인, QA 테스트 8개, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: B1(P2) 수정 — developer, 제안 ①은 스펙 수치를 안 바꿔요. 사용자 Studio 확인 AC9~AC16(특히 R1 "30°에서 미끄러지는가").
- 다음 첫 단계: developer가 B1 ①(`collapseDuration` 뒤 `Platform.CanCollide = false`)을 넣고 QA 재확인, 또는 사용자 확인 결과를 보고 함께.
- 막힌 점: 없음.

## 재QA (2026-10-13, qa) — 브랜치 `m5-maps-fix-b` (`ae59293`)
### 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **1456 passed, 0 failed** |
| `luau-lsp analyze ... src` | 통과 (끝 코드 0) |

### 수정 확인
| 버그 | 결과 | 근거 |
|---|---|---|
| B1 90° 끝면 턱 | 고침 | `TugOfWarPlatform.luau:190-198, 231-236` 연장전 `collapseDuration`이 지나면 Heartbeat에서 한 번 `disablePlatform()` — `PlatformGroup`의 BasePart 전부(발판 + 무게추 장식) `CanCollide/CanTouch/CanQuery = false`. 모델의 다른 파츠는 장식(`MapKit.buildDecor`, 충돌 없음)과 스폰(충돌 없음)뿐이라 설 곳이 0. 재QA 테스트 "m5-18 재QA B1": collapseDuration 8·20·40 × 시작 각도 3개에서 `since ≥ collapseDuration`이면 각도가 정확히 ±90°이고 같은 순간 `platformSolid = false`, 직전(−0.01)은 true — 턱이 수평으로 남는 틱이 없음(각도·충돌이 같은 Heartbeat에서 바뀜). 스펙 수치(마지막 꺾인점 90°)는 그대로. |
| B2 발판 밖 토크 | 고침 | `:224-227` `Logic.riderX` — \|x\| > 35는 토크에서 뺌. 30° 기운 발판 끝에 선 사람도 origin 기준 X ≈ 35·cos30 + 3·sin30 ≈ 31.8로 안쪽이라 정상 레이서는 빠지지 않음. |

- 바뀐 곳은 토크 입력 필터와 연장전 끝 충돌 끄기뿐. 낙하 판정(origin 기준 Y < −25), 기울기 공식, 연장전 각도 일정은 그대로.
- 연장전 끝 동작: 20초 시점에 남은 사람이 동시에 떨어지면 같은 묶음 → 높이 순(기존 결승 규칙). 안전 상한(150초)까지 가지 않음.
- 사용자 Studio 확인(추가): `overtimeAt = 15`, 연장전 20초 뒤 수직 발판이 통과돼 남은 사람이 모두 떨어지고 경기가 바로 끝나는지, 발판 끝 모서리에 매달려도 버틸 수 없는지. 나머지 AC9~AC16은 원래 체크리스트대로.
- 상태: `in-qa` → **`qa-passed`**.

## 인계 메모 (2026-10-13, qa 재QA)
- 브랜치: `m5-maps-fix-b`.
- 끝난 것: B1(P2)·B2(P3) 수정 확인, 검증 5단계, 재QA 테스트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인(AC9~AC16 + 위 추가 항목, 특히 R1 "30°에서 미끄러지는가").
- 다음 첫 단계: main 병합 → docs-writer 반영 → `done`.
- 막힌 점: 없음.
