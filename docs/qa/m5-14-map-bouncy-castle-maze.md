# QA — m5-14 새 Race 맵: 방방 미로 (`bouncy-castle-maze`)

- 스펙: `docs/specs/m5-14-map-bouncy-castle-maze.md`
- 검증 커밋: `4192744` (`main`, m5-14 병합 `a9ca6bb` 포함)
- 결과: **반려 (P1 있음)** → 스펙 상태 `in-dev`. 미로 출구가 모든 레인에 열려 있어 1번 레인을 곧장 달리면 결승에 닿는다(B1).

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 1258 passed, 0 failed (QA 추가 전 1233) |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | 개발 `AC1` 2개. QA `바운스 바닥은 B+C만, 스폰은 전부 A 구간이고 벽에서 1 이상` |
| AC2 | 통과 | 개발 `AC2` 3개 |
| AC3 | 통과(문구상) | 개발 플러드필 테스트 — 입구→(15, −109) 경로, 최소 폭 ≥ 8. **다만 B1 때문에 이 경로가 유일한 길이 아님** |
| AC4 | 통과(문구상) | 개발 `AC4` — 대기실→2·3·4번 레인 직행 없음. 출구 쪽 지름길(B1)은 이 AC가 보지 않는 곳 |
| AC5 | 통과 | 개발 `AC5`. QA: 서버가 위 속도를 0.08초 고정하는 구간까지 넣은 **실제 정점은 약 12.1**(스펙의 7.7이 아님) — 공중 다이브 여유 0.65를 더해도 벽 14보다 낮아 지름길은 없음(B4 참고) |
| AC6 | 통과 | 개발 `AC6`. QA: 실제 비행 시간 ≈ 0.71초도 쿨다운 0.45 < 0.71 < 면제 0.8 |
| AC7 | 통과 | 개발 `AC7` 예산·소개 카메라, `inPool` 줄 없음 |
| AC8 | 통과 | 5단계 + `maps`·`movement-guard` 테스트 통과 |
| AC9~AC16 | 사용자 확인 필요 | 아래 체크리스트. AC10·AC15는 B1·B2의 영향을 받음 |

## 버그
### [P1] B1 미로 출구가 1·2·3번 레인에도 열려 있어 1번 레인 직진으로 결승에 간다
- 재현: 코드 확인 — `build`는 양옆 벽·출발/끝 벽·칸막이 3개·관문만 세운다(`src/shared/maps/BouncyCastleMaze.luau:90-145`). 미로(C, z −20~−110)와 출구 통로(D, z −110~−120) 사이에는 벽이 없고, 칸막이 1·3은 z −100에서 끝난다(`BouncyCastleMazeLayout.luau:64-68`). Studio: `forceMapPlan = { "bouncy-castle-maze", "hot-plate", "skewer-showdown" }`로 출발 → 관문으로 1번 레인(왼쪽) 진입 → 그대로 앞으로 달린다.
- 기대: 스펙 "진행: 1번 → 2번 → 3번 → 4번 레인 → D 구간"(S자 두 번 꺾기, "방향을 꺾어야 하는 원안 핵심"). D로 나가는 길은 4번 레인 끝뿐.
- 실제: 1번 레인 끝(z −110)에서 바로 D(폭 40 전부 열림)로 나가 결승선(−134)까지 약 115 studs 직선. 의도한 S자(약 360 studs)는 아무도 갈 이유가 없어 맵이 "튕기는 직선 복도"가 된다. 2·3번 레인 끝도 마찬가지로 D에 열려 있다.
- 원인: 스펙의 구간·칸막이 표에 "출구 벽"이 빠졌고, 구현이 표대로만 만들었다. `Logic.blockedAt`도 z −110 아래를 모델링하지 않아 개발 플러드필(AC3·AC4)이 이걸 못 잡았다.
- 고치는 방향(개발): z = −110에 x −20~10을 막는 출구 벽(판정 지오메트리, 높이 `WALL_HEIGHT`)을 세우고 4번 레인(x 10~20)만 연다. `Layout`에 `EXIT_GATE`(관문과 같은 모양)를 두고 `blockedAt`이 같이 보게 한 뒤, 플러드필 테스트를 D까지 넓혀 "x > 10을 막으면 D에 닿지 못한다"를 고정한다. 스펙 표에 행 하나 추가가 필요하면 planner 결정 기록에.
- 위치: `src/shared/maps/BouncyCastleMaze.luau:90-145`, `src/shared/maps/BouncyCastleMazeLayout.luau:41-80`, `src/shared/maps/BouncyCastleMazeLogic.luau:18-39`
- 테스트: 실패하는 테스트로 넣지 않았다(전체 검증이 깨짐). 고친 뒤 아래를 `tests/map-bouncy-castle-maze.spec.luau`에 넣기를 권한다 — 입구(−15, −19)에서 플러드필하되 x ≥ 11 칸을 벽으로 취급해 z −111(D)에 닿으면 실패.

### [P2] B2 바운스가 매번 수평 속도를 0으로 만든다
- 재현: 미로에서 앞으로 달리며(또는 다이브하며) 튕긴다.
- 기대: 스펙 "위 속도 55 (수평 성분 없음)" — 위로만 밀고 걷던 속도는 유지.
- 실제: `LinearVelocity`가 `VelocityConstraintMode.Vector` + `MaxForce = math.huge`로 속도 벡터 전체를 (0, 55, 0)에 0.08초 묶고, 그 전에 `AssemblyLinearVelocity = upVelocity`로 수평 속도를 지운다. 튕길 때마다(약 0.7초마다) 앞으로 가던 속도·다이브 속도가 0이 됐다가 공중 조작으로 다시 붙는다. 판정은 안 깨지지만 "튕기면서 달리는" 손맛이 끊기고 진행이 느려진다(Studio 체감 확인 필요).
- 고치는 방향: `VelocityConstraintMode.Line` + `LineDirection = (0,1,0)`(세로만 묶기), 시작 속도는 `velocity * (1,0,1) + up`처럼 수평 성분 유지.
- 위치: `src/shared/maps/BouncyCastleMaze.luau:226-230`

### [P3] B3 바운스마다 `ctx.cleanup`에 항목이 2개씩 쌓인다
- 24명이 90초 동안 튕기면 약 6,000개(LinearVelocity + 이미 끝난 `task.delay` 스레드). 라운드 끝에 한 번에 정리되므로 누수는 아니고, 정리 순간 비용·메모리만 조금 늘어난다. `push`는 `task.delay` 안에서 이미 지우므로 `Debris`나 "살아 있으면 지우기" 한 항목으로 줄일 수 있다.
- 위치: `src/shared/maps/BouncyCastleMaze.luau:231-234`

### [P3] B4 실제 정점이 스펙·주석의 7.7보다 높다 (지름길은 아님)
- `bounceProfile`은 0.08초 고정 구간의 상승(55 × 0.08 = 4.4)을 빼고 계산한다. 실제 발 높이는 약 12.1(+공중 다이브 0.65)로, 벽 14와의 여유는 스펙이 말한 "약 1.8배"가 아니라 약 1.9 studs. 지금은 넘지 못하지만(QA 테스트로 고정), `BOUNCE_UP_SPEED`나 `BOUNCE_HOLD`를 올리면 바로 넘을 수 있다. 수치를 바꿀 때 QA 테스트 `유지 시간까지 넣은 실제 정점…`이 막아 준다.
- 위치: `src/shared/maps/BouncyCastleMazeLayout.luau:37`(주석), `BouncyCastleMazeLogic.luau:42-47`

### [P3] B5 바운스 감지 여유가 0.5 studs
- 발밑 레이캐스트 3.5 vs 서 있을 때 루트 높이 3(기본 블록 R15/R6 — 이 게임은 `LoadCharacterAppearance = false`라 고정). 몸 크기를 바꾸는 일이 생기면(스킨은 크기 불변 규칙이라 지금은 없음) 바운스가 안 걸릴 수 있다. 기록만.

### 아트 (간단히, m5-24가 다시 씀)
- 판정 파츠와 장식 분리, 장식 예산·조명 수는 개발 테스트로 확인. 별도 문제 못 찾음.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 이 맵은 리모트를 쓰지 않음(QA 소스 테스트)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — Heartbeat에서 `ctx.pass` 1곳·`ctx.eliminate` 1곳, 바운스는 판정 뒤 남은 레이서에게만
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `readyAt` 등은 `bounceStepper` 지역, 태그는 `ctx.model:IsAncestorOf`로 거름(QA 소스 테스트)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat·LinearVelocity·`task.delay`·만든 Attachment 모두 `ctx.cleanup`(B3은 양만의 문제)
- [x] MoveExempt — 바운스는 순간 튕김을 짧은 간격으로 반복하는 것이라 튕길 때마다 `MoveExempt.mark(character, 0.8)`(결정 D3과 일치). 위 속도 55는 감시 상승 상한 140보다 작아 면제가 없어도 안전

## 사용자 Studio 확인 체크리스트
준비: `Config.DEBUG.forceMapPlan = { "rotating-belt", "bouncy-castle-maze", "hot-plate" }`, 끝나면 **`nil`로 되돌린다**.
1. (AC9) 대기실·미로 바닥에 가만히 서 있으면 계속 위아래로 튕기는지, 출발·출구·결승 바닥에서는 안 튕기는지.
2. (AC10·B2) 튕기는 중 W를 계속 누를 때 튕길 때마다 앞으로 가던 게 "멈칫"하는지 본다(B2). 칸막이 틈으로 방향을 바꿔 들어갈 수 있는지, 점프·다이브로 칸막이 위를 넘을 수 없는지.
3. (AC11) 대기실에서 오른쪽 3칸(2·3·4번 레인 앞)은 빨간 문에 막히는지.
4. (B1 재현) 1번 레인(왼쪽 끝)으로 들어가 앞으로만 달린다 → 지금은 출구 통로로 바로 나가 결승선을 넘는다. 고친 뒤에는 1번 레인 끝이 막혀 2번 레인으로 꺾어야 해야 한다.
5. (AC12) 벽 너머로 떨어질 길이 있는지(지금 구조는 사방이 높이 14 벽이라 떨어질 곳이 거의 없음). 떨어지면 1초 안에 탈락 연출.
6. (AC13) Test → Clients and Servers 2명: 둘이 함께 튕겨도 어긋나지 않고 Output에 `[MovementGuard]` 로그가 없는지.
7. (AC14) Device Emulator(휴대폰)에서 튕기는 중 점프·다이브 버튼이 동작하는지.
8. (AC15) B1이 고쳐진 뒤 혼자 60~90초 안에 완주되는지.
9. (AC16) 다음 맵(hot-plate)·로비에서 이동이 평소와 같은지(LinearVelocity가 남지 않음).

## 추가한 테스트
- `tests/m5-14-qa.spec.luau` (8개): 유지 구간 포함 실제 정점(+공중 다이브) < 벽 / 실제 비행 시간 vs 쿨다운·면제 / 레이캐스트가 서 있으면 닿고 공중에선 안 닿음 / 위 속도 < 감시 상승 상한 / 바운스 바닥 B+C 한 장·스폰 A 안 / 칸막이 틈·관문 폭 = 레인 폭 / 소스: `ctx.model` 필터·모듈 상태·리모트 없음 / 소스: pass·eliminate 1곳씩·바운스마다 MoveExempt·cleanup 등록·판정 뒤 바운스.

## 인계 메모
- 브랜치: `m5-qa-maps-a`
- 끝난 것: 5단계, AC1~AC8 확인, 서버 코드 리뷰, QA 테스트 8개, 리포트, 스펙 `in-dev`로 반려.
- 남은 것: 개발이 B1(필수)·B2(권장) 수정 → 재QA. Studio AC9~AC16(사용자).
- 다음 첫 단계: developer가 B1 "고치는 방향"대로 출구 벽 + `blockedAt`/플러드필 확장. 스펙 표에 출구 벽 행 추가는 planner 결정 기록에 한 줄.
- 막힌 점: 없음.
