# QA — m5-17 새 Survival 맵: 고양이 카페 캣타워 (`cat-cafe-shelves`)

- 스펙: `docs/specs/m5-17-map-cat-cafe-shelves.md`
- 검증 커밋: `4192744` (`origin/main`, m5-17 병합 `a681824` 포함) + QA 테스트 추가 (브랜치 `m5-qa-maps-b`)
- 결과: **통과 (qa-passed)**. P0/P1 없음, P3 2건 + Studio 확인 위험 1건. Studio 항목 AC12~AC18은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 포함) |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — 병합 상태 1233 + QA 25(m5-17 11 · m5-18 8 · m5-19 6) = **1258 passed, 0 failed** |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-cat-cafe-shelves.spec` "AC1" (validate, Survival, timeLimit nil, inPool 없음) |
| AC2 | 통과 | `map-cat-cafe-shelves.spec` "AC2" 2개 + QA "같은 단 선반 4개는 겹치지 않고 넓이 합 = 테두리", "서로 다른 단은 수평으로 안 겹침" |
| AC3 | 통과 | `map-cat-cafe-shelves.spec` "AC3" + QA "스폰 24개 각각 정확히 1단 선반 하나 위, 2·3단 아래 아님, 서로 3 이상" |
| AC4 | 통과 | `map-cat-cafe-shelves.spec` "AC4" + QA "오르는 틈 4 + 높이 5 < 점프 6.4, 탈락선 −11" |
| AC5 | 통과 | `map-cat-cafe-shelves.spec` "AC5" + QA "0~300초 공 전체(반지름 포함)가 선반 안, 9개 위상 모두 다름" |
| AC6 | 통과 | `map-cat-cafe-shelves.spec` "AC6" + QA "isHit 경계 2.2 / 2.2+1e-6" |
| AC7 | 통과 | `map-cat-cafe-shelves.spec` "AC7" + QA "1·2단 모든 점에서 넉백 방향의 바깥 가장자리 성분 ≥ 0.55" |
| AC8 | 통과 | `map-cat-cafe-shelves.spec` "AC8" + QA "pawInterval 그레이스 뒤 nil 없음·단조·2 아래 없음" (단 실제 주기는 B1) |
| AC9 | 통과 | `map-cat-cafe-shelves.spec` "AC9" + QA "가중치 3:1 → 75%±3%", "무작위 2000번: 0명·Top·직전 선반 안 고름, nil이면 정말 후보 없음" |
| AC10 | 통과 | `map-cat-cafe-shelves.spec` "AC10" 2개 (validate, 예산, IntroCamera 4점) |
| AC11 | 통과 | 위 자동 검증 5단계, 기존 `maps`·`m5-13-foundation`(현 `m5-03-foundation`) 통과 |
| AC12 | 사용자 확인 필요 | 체크리스트 1 |
| AC13 | 사용자 확인 필요 | 체크리스트 2 |
| AC14 | 사용자 확인 필요 | 체크리스트 3 (경고는 선반 주황색만, 발 그림자 없음 — 개발 메모대로) |
| AC15 | 사용자 확인 필요 | 체크리스트 4 |
| AC16 | 사용자 확인 필요 | 체크리스트 5 |
| AC17 | 사용자 확인 필요 | 체크리스트 6 |
| AC18 | 사용자 확인 필요 | 체크리스트 7 (R1 참고) |

자동 확인 11/11 통과, Studio 7개 대기.

## 버그
### [P3] B1 고양이 발 실제 주기가 표보다 경고 시간(1.1초)만큼 길다
- 재현: 코드 확인. 발 루프는 `pickShelf` → 경고 `task.wait(1.1)` → 밀기 → `task.wait(pawInterval)` 순서라 대상이 있을 때 실제 주기 = 간격 + 1.1초.
- 기대: 표의 "간격" 5 / 3.2 / 2초마다 고양이 발 (45~60초는 2초마다).
- 실제: 6.1 / 4.3 / 3.1초마다. 45~60초 구간이 표보다 55% 느슨해요. 대상이 없는 차례는 간격만 기다려요.
- 위치: `src/shared/maps/CatCafeShelves.luau:326`, `:346-347`
- 제안: 다음 차례 시각을 `pickShelf` 시점 기준으로 잡거나(경고는 `task.delay`), 의도된 체감이면 스펙 표를 "경고 끝 → 다음 경고 사이 간격"으로 고쳐요. AC18 체감 뒤에 정해도 돼요.

### [P3] B2 꼭대기("캣방석") 공 판정이 폭 방향 거리를 안 본다
- 재현: 코드 확인. 맞음 판정은 선반 길이 축(along) 거리만 봐요(스펙 AC6대로). 1·2단은 폭 4라 문제없지만 꼭대기는 12×12라, 공이 X축으로 지나갈 때 공과 Z로 5 떨어진 사람도 "맞음"(넉백)이에요.
- 기대: 공이 보이는 자리 근처에 있는 사람만 밀림.
- 실제: 꼭대기에서 공과 같은 X 줄(±2.2)이면 Z 거리와 상관없이 밀림 — "안 맞았는데 밀렸다"로 보일 수 있어요.
- 위치: `src/shared/maps/CatCafeShelves.luau:277-279`
- 제안: 폭 방향 거리(`|across| ≤ BALL_HIT_RANGE`)도 함께 보거나, 꼭대기만 2D 거리로. 스펙 결정이 필요하면 planner.

## 위험 (Studio에서 확인)
- **R1 넉백 세기**: 대략 계산(중력 196.2, LinearVelocity 강제 시간 + 포물선)으로 공은 약 3 studs, 고양이 발은 약 5.6 studs 밀어요. 선반 폭이 4라 고양이 발은 안쪽 끝에 서 있어도 거의 확실히 떨어지고, 공도 가운데에서 맞으면 떨어질 수 있어요. 스펙 AC14 "안쪽에 있으면 안 떨어질 수 있다"와 다를 수 있으니 AC18 체감 때 확인하고, 세면 `CatCafeShelvesLogic`의 `BALL_KNOCK_*`/`PAW_KNOCK_*`만 줄여요. 2단에서 바깥으로 밀리면 1단과의 틈(4)으로 바로 떨어지는 것도 의도인지 확인해요.

## 코드 확인 (서버 판정 · 맵 계약)
- 판정은 전부 서버: 탈락은 루트 로컬 Y < `ELIMINATION_Y`(−11)일 때 `ctx.eliminate`, 그 탈락으로 라운드가 끝나면 즉시 return(`CatCafeShelves.luau:254-259`). `ctx.pass` 안 씀(Survival).
- 맵 상태(`ballCooldown`, `standingOn`, `occupancy`, `previousPaw`)는 전부 `start` 지역 변수. 선반·공은 `ctx.model` 하위 태그/폴더만(`:189-210`).
- 정리: Heartbeat 연결, 발 루프 스레드, 넉백 `LinearVelocity`·`Attachment`·되돌리는 `task.delay` 모두 `ctx.cleanup`.
- `MoveExempt`: 공(1.2초)·고양이 발(1.6초) 둘 다 순간 넉백에만 — 연속 밀기 없음. 규칙에 맞아요.
- 스폰 24개 모두 1단 판정 바닥 위(QA 테스트), 선반끼리 수평으로 안 겹쳐서 아래 방향 레이캐스트(4.5)가 위 단을 천장으로 잘못 잡을 일이 없어요.
- 리모트: 이 맵은 새 리모트 없음.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 새 리모트 없음
- [x] 통과·탈락·순위 판정이 서버에만 있다
- [x] 맵 상태가 모듈이 아니라 `ctx`(start 지역 변수)에 있다
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "cat-cafe-shelves", "skewer-showdown" }`. **확인 뒤 `nil`로 되돌리기.**
1. (AC12) Play로 회전 벨트를 통과하면 2라운드가 캣타워예요. 1단 선반 위 아무 데서나 가만히 서서, 공·고양이 발에 안 맞는 동안 떨어지지 않는지 봐요.
2. (AC13) 분홍 공이 선반 위를 왕복하는지, 공에 닿으면 타워 바깥쪽(가운데 구멍 반대쪽)으로 밀리는지, 가장자리 근처에서 맞으면 떨어지고 손님 입 연출이 나오는지 봐요. 꼭대기에서 공과 멀리(Z로 4~5) 떨어져 있는데도 밀리면 B2예요.
3. (AC14) 8초 뒤부터 사람이 선 선반 하나가 주황색이 되고 약 1.1초 뒤 그 선반 위 사람이 크게 밀리는지 봐요. 안쪽(구멍 쪽) 끝에 서서 한 번, 바깥쪽 끝에서 한 번 맞아 보고 떨어지는지 적어 주세요(R1). 경고 사이 간격을 대충 세어 45초 뒤에 2초보다 3초 쪽에 가까운지도 봐요(B1).
4. (AC15) 1단 안쪽 끝에서 점프해 2단, 2단 안쪽 끝에서 점프해 3단(꼭대기)에 오를 수 있는지. 꼭대기에 있는 동안은 주황 경고가 꼭대기에 안 뜨고, 공은 계속 도는지 봐요.
5. (AC16) 혼자면 60초 끝에 통과(다음 라운드로)하는지. Test → Clients and Servers 4명이면 목표 인원만 남는 순간 바로 끝나는지.
6. (AC17) 공·고양이 발에 밀린 직후 서버 Output에 `[MovementGuard]` 되돌림 로그가 없는지 봐요.
7. (AC18) 재미: 좁은 선반을 옮겨 다니는 느낌, 밀림 세기(너무 약함/너무 셈). 숫자로 알려 주면 상수만 고쳐요.

## 추가한 테스트
- `tests/m5-17-qa.spec.luau` (11개): 같은 단 선반 겹침·넓이, 다른 단 수평 겹침 없음, 오르는 틈·탈락선, 스폰 위치(정확히 1단 선반 하나 위), 공이 선반 밖으로 안 나감(300초)·위상 9개 모두 다름, 공 안전 지대 없음(꼭대기 포함), isHit 경계, 넉백 방향 바깥 성분, pickShelf 가중치·무작위 불변식, pawInterval 단조.
- 참고(P3, 테스트 품질): `tests/map-cat-cafe-shelves.spec.luau`의 `fakeRng`(`state * 1103515245`)는 곱이 2^53을 넘어 double 정밀도가 깨져요. 지금 테스트는 통과하지만 분포를 재는 테스트에 쓰면 편향돼요(QA 테스트는 Park–Miller로 씀).

## 인계 메모 (2026-10-13, qa)
- 브랜치: `m5-qa-maps-b` (worktree `agent-a5450984eef7a2b66`, `origin/main` `4192744` 기준).
- 끝난 것: 검증 5단계, AC1~AC11 확인, QA 테스트 11개, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인(AC12~AC18), B1·B2는 developer가 원하면 다음 배치에(블로킹 아님).
- 다음 첫 단계: docs-writer가 CHANGELOG·DEV-SETUP 반영 → `done`. 사용자 체크리스트 결과가 오면 R1 수치 조정.
- 막힌 점: 없음.

## 재QA (2026-10-13, qa) — 브랜치 `m5-maps-fix-b` (`ae59293`)
### 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **1456 passed, 0 failed** (fix-b 개발 테스트 + 재QA `tests/m5-maps-fix-b-qa.spec.luau` 5개) |
| `luau-lsp analyze ... src` | 통과 (끝 코드 0) |

### 수정 확인
| 버그 | 결과 | 근거 |
|---|---|---|
| B1 고양이 발 주기 | 고침 | `CatCafeShelves.luau:320-349` 차례 시작 시각에 `pawInterval`을 읽고 경고 뒤 `pawRest(interval, 쓴 시간)`만 기다림. 재QA 테스트 "m5-17 재QA B1"이 서버 루프 순서 그대로 8~60초를 돌려 경고 시작 간격이 5 / 3.2 / 2초와 같음, 45~60초에 7번 이상 확인. |
| B2 꼭대기 공 폭 판정 | 고침 | `:278-279` `isHitAt(along, across)`. 꼭대기에서 폭 방향 2.2 초과는 안 맞음. 1·2단은 레이캐스트가 선반을 맞힌 사람의 폭 거리 ≤ 2(SHELF_WIDTH/2) ≤ 2.2라 판정이 `isHit(along)`과 같음(회귀 없음, 재QA 테스트 "m5-17 재QA B2"). |

- 바뀐 곳은 공 판정·발 루프 대기뿐. 탈락 판정(`ELIMINATION_Y`), 넉백 세기, 대상 선반 고르기, 정리(Cleanup)는 그대로.
- 남은 것: R1 넉백 세기, AC12~AC18은 그대로 사용자 Studio 확인. 추가로 45~60초에 고양이 발 경고가 약 2초마다 뜨는지, 꼭대기에서 공과 옆으로 떨어져 서 있으면 안 밀리는지.
- 상태: `qa-passed` 유지.

## 인계 메모 (2026-10-13, qa 재QA)
- 브랜치: `m5-maps-fix-b` (QA 커밋을 같은 브랜치에 push).
- 끝난 것: B1·B2 수정 확인, 검증 5단계, 재QA 테스트 추가.
- 남은 것: 사용자 Studio 확인(AC12~AC18 + 위 두 가지).
- 다음 첫 단계: `m5-maps-fix-b`를 main에 병합 → docs-writer가 CHANGELOG·DEV-SETUP 반영 → `done`.
- 막힌 점: 없음.
