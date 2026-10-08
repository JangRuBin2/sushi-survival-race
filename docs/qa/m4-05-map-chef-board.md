# QA — m4-05 새 Survival 맵 "셰프의 도마" (`chef-board`)

- 스펙: `docs/specs/m4-05-map-chef-board.md`
- 검증 커밋: `0c847d5` (브랜치 `m4-05-chef-board`), QA 브랜치 `m4-05-qa`에서 `origin/main`(`89b0211`, m4-01 QA)을 병합해 검증. 병합 충돌 없음.
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. Studio 확인(AC8~AC13)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과: 571 passed, 0 failed (병합 직후 558 + QA 추가 13) |

바뀐 파일(`origin/main...origin/m4-05-chef-board`): `src/shared/maps/ChefBoard.luau`, `ChefBoardLogic.luau`(새), `ChefBoardArt.luau`(새), `tests/map-chef-board.spec.luau`(새), 스펙, `docs/developer/m4-05-map-chef-board.md`. 스펙의 "이 스펙이 고치는 파일" 밖의 `src`/공용 파일 변경 없음.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `AC1: chef-board는 인터페이스를 지키는 Survival 맵`, `AC1: 칸 61개…`, `AC1: 스폰 24개가 가운데 쪽 칸 위`. QA `스폰 24곳이 서로 다른 칸 중앙이고 도마 가장자리에서 10 studs 이상 안쪽`(가장 바깥 스폰 반지름 22.6 → 여유 13.4, 네 이웃 칸 모두 있음) |
| AC2 | 통과 | `AC2: 칼 주기 6 → 4.5 → 3초…`. QA `칼 한 번이 다음 경고 전에 끝나고, 마지막 내려침이 60초 전`(경고 시각 3, 9, 15, 21, 25.5, 30, 34.5, 39, 43.5, 46.5, 49.5, 52.5, 55.5, 58.5 — 칼 한 번 최대 1.97초 < 최소 간격 3초) |
| AC3 | 통과 | `AC3: 시드 1~200…`, 가중 랜덤 테스트. QA `시드 1~200, 칼마다 고른 줄은 남은 칸이 있고 18줄 중 하나`(nil 없음) |
| AC4 | 통과 | `AC4: 시드 1~200으로 60초 뒤에도 가운데 3×3 9칸…`. QA 최악 경우 `모든 줄을 차례로 100바퀴 내려쳐도 가운데 3×3만 남고 줄 고르기는 nil이 안 됨` |
| AC5 | 통과 | `AC5` 기울기·회전축·넉백 테스트. QA `모든 줄·줄 위 모든 칸에서 넉백은 단위 벡터, 줄과 수직, 바깥쪽`(전수), `기울기 창 5개가 서로 겹치지 않고 53초에 끝남` |
| AC6 | 통과 | `AC6: 장식이 MapKitLogic.validate 통과, 600개 이하`, 시야 상자 테스트. QA `장식 전체가 예산 안, 아트에 조명·파티클 없음` |
| AC7 | 통과 | 검증 4개 통과, 기존 `maps`·`map-sfx` 테스트 통과 (MAP_CUES에 ChefBoard 추가 후에도 통과) |
| AC8 | 사용자 확인 필요 | 코드: 경고 줄(`KnifeWarning`, 반투명 빨강 Neon, 깜박임) → 경고 시간 뒤 칼 0.12초 내려침 → 줄 위(반폭 5.5, 높이 -4~14) 레이서만 넉백 + PlatformStand 1초 (`ChefBoard.luau:435-494, 320-333`). QA `맞음 폭은 옆 줄 중심에 닿지 않아요` |
| AC9 | 사용자 확인 필요 | `cutCells` → `removeCells` → `dropCell`(0.5초 흔들림, 0.8초 30 studs 낙하·투명, Destroy) (`:389-416, 497-504`). 보호 칸은 순수 로직으로 확인(AC4) |
| AC10 | 사용자 확인 필요 | Heartbeat에서 `tiltCFrameParams`로 칸 CFrame 회전, 도마 반지름+2 안·높이 -8~10 레이서를 낮은 쪽으로 최대 6 studs/s 가속 (`:336-386`) |
| AC11 | 사용자 확인 필요 | 낙하 탈락은 origin 기준 로컬 Y < -30에서 `ctx.eliminate`만 부름(`:360-367`), `ctx.pass` 없음. Survival 종료·전원 통과는 RoundLogic 기존 경로. 손님 얼굴 장식 꼭대기가 -30 아래 (QA 테스트) |
| AC12 | 사용자 확인 필요 | 난이도 체감. 조정 값은 `ChefBoardLogic.luau` 맨 위 상수 |
| AC13 | 사용자 확인 필요 | 코드: 칸·칼을 `taggedInModel(ctx.model, …)`(`model:IsAncestorOf`)로만 찾고, 상태(board, tiltPlan, lastHitAt 등)는 전부 `start` 지역 변수. QA 소스 점검 테스트 `태그는 ctx.model 하위만, 모듈 수준 가변 상태 없음` |

요약: 순수 로직 AC1~AC7 7개 통과, Studio AC8~AC13 6개 사용자 확인 필요. 실패 0.

## 개발 결정 검토: 61칸 기준 `CENTER_LIMIT = 35`
- 스펙 본문이 서로 맞지 않는다: "칸 중심이 반지름 36 원 안" 그대로면 69칸이고, 61칸은 기준 반지름이 33.95~35.77일 때만 나온다 (QA `반지름 36 그대로면 69칸, 61칸은 CENTER_LIMIT 33.95~35.77에서만`).
- AC1 문구("61개이고 모든 칸 중심이 반지름 36 안")는 35로 두 조건을 모두 만족한다. 결정 기록에 사유가 남아 있고 사용자 수정 가능으로 표시됐다 → **타당**. 기획 담당이 스펙 본문 1번을 "칸 중심이 반지름 35 안"으로 고치면 된다.

## 버그
P0/P1/P2 없음.

### [P3] C1 도마가 "원형"이 아니라 계단 모양이고, 바깥 칸 모서리가 반지름 36을 넘는다
- 재현: Studio에서 도마를 위에서 본다.
- 기대: 스펙 범위 1 "지름 72 원형 도마".
- 실제: 칸(8×8)만 있어 외곽이 계단 모양. 예: 칸 (3,3)의 바깥 모서리는 중심에서 39.6. 기울기 밀기 반경은 36+2=38이라 이 모서리 끝 1.6 studs에 선 사람은 밀리지 않는다 (판정에는 영향 없음, 체감 차이 미미).
- 위치: `src/shared/maps/ChefBoardLogic.luau:45, 72`, `src/shared/maps/ChefBoard.luau:352`
- 제안: 연출 문제라 그대로 두거나, 밀기 반경을 `BOARD_RADIUS + 4`로. 사용자 확인 후 판단.

### [P3] C2 칼이 올라갈 때 도마 가운데가 아니라 방금 친 줄 위로 올라가고, 그때의 기울기를 무시한다
- 재현: 칼이 Row4를 친 뒤 다음 경고까지 본다.
- 실제: 쉬는 위치가 `origin * lineRel * (0, 34, 0)`이라 마지막 줄 위 34 studs에 떠 있다. 기울기 중이면 칼이 수평으로 돌아온다. 다음 경고 때 0.35초 동안 새 줄로 옮겨 가므로 동작에는 문제 없음 (연출만).
- 위치: `src/shared/maps/ChefBoard.luau:510`

### [P3] C3 (개발 메모에 이미 적힘) 기울기 램프 0.5초 동안 내려치면 칼날이 칸에 묻히거나 뜬다
- 내려치는 목표 CFrame을 내려치기 시작 순간의 `currentTilt`로 고정한다. 판정은 줄 좌표라 무관.
- 위치: `src/shared/maps/ChefBoard.luau:465-470`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가하지 않았다.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — `ctx.eliminate` 한 곳(낙하), 넉백·밀기·맞음 판정 모두 서버 `start` 안. 점수(높이)는 RoundService 기존 방식.
- [x] 맵 상태가 모듈이 아니라 `ctx`/`start` 지역에 있다 — 모듈 최상위는 상수·함수·require만 (QA 소스 테스트). 랜덤은 `ctx.rng`만.
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 1개, `task.spawn` 3곳(칼 루프, 칼 조준, 칸 떨어짐), `task.delay` 1곳(넉백 해제)이 모두 `ctx.cleanup:add`. 경고 줄·칸·칼은 `ctx.model` 하위라 모델과 함께 지워진다. 칼 루프 안에서 `ctx.isActive()`를 확인해 라운드가 끝나면 경고 줄을 지우고 멈춘다.
- [x] 서버가 캐릭터를 튕기거나 밀 때 `MoveExempt.mark` — 넉백 `mark(character, KNOCKDOWN_TIME + 1)`, 기울기 밀기 중 0.5초마다 `mark(character)`.
- [x] 넉백으로 켠 PlatformStand: 탈락하면 손대지 않고(`isRacer`), 라운드가 끝나면 RoundService/`CharacterUtil.toLobby`의 `resetMovement`가 끈다 (SkewerShowdown과 같은 패턴).

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "chef-board", "soy-swamp", "skewer-showdown" }` (커밋 금지). Rojo 연결.
1. (AC8) Play → 벨트 통과 → 2라운드 도마. 약 3초에 빨간 줄이 깜박이고 1.2초 뒤 칼이 그 줄로 내려치는지. 줄 위에 서 있으면 바깥쪽으로 튕겨 1초 넘어지는지(@_@), 바로 옆 줄에 서 있으면 아무 일 없는지. 40초 이후엔 경고가 0.8초로 짧아지는지.
2. (AC9) 칼이 지나간 줄 양 끝 칸이 0.5초 흔들리다 떨어져 사라지고 "TileVanish" 소리가 나는지. 60초 동안 도마가 눈에 띄게 작아지되 가운데 3×3(24×24 studs)은 끝까지 남는지.
3. (AC10) 10·20·30·40·50초에 도마가 약 8도 기울고 낮은 쪽으로 밀리는 게 느껴지는지, 3초 뒤 평평해지는지. 기울기 동안 경고 줄도 같이 기우는지.
4. (AC11) 도마 밖으로 떨어지면 손님 얼굴 쪽으로 떨어지며 탈락 연출이 나오는지. 4명 이상(Test → Clients and Servers)에서 남은 인원이 목표 이하가 되면 바로 끝나는지, 60초를 버티면 남은 사람 전원 통과하는지.
5. (AC12) 4명 이상에서 60초 안에 적당히 떨어지는지. 너무 쉽거나 어려우면 주기·넉백 값(`ChefBoardLogic` 맨 위 상수)을 알려 주기.
6. (AC13) 클라이언트 8명 정도로 방 2개를 만들어 동시에 도마 라운드를 돌릴 때 칼·경고 줄·칸 떨어짐·기울기가 각자 자기 방 맵에서만 일어나는지.
7. (선택) 출력 창에 이 맵 관련 에러/경고가 없는지, Script Analysis에서 `ChefBoard*.luau` 타입 경고가 없는지 (검증 명령에 타입 검사 없음).
8. (선택) 이동 감시(m4-10)가 들어간 뒤라면 넉백·기울기 밀기에서 오탐 되돌림이 없는지.

## 추가한 테스트
- `tests/m4-05-qa.spec.luau` (13개): 스폰 가장자리 여유·이웃 칸, 61칸 기준 경계(36이면 69칸), 보호 칸 최악 경우(전 줄 100바퀴), 시드 1~200 줄 고르기 nil 없음, 칼 한 번 길이 vs 다음 경고·60초, 기울기 창 겹침 없음, 넉백 방향 전수, 맞음 폭 vs 옆 줄, 장식 예산·조명/파티클 없음, 소스 점검(ctx.model 태그 필터·모듈 상태 없음 / cleanup 등록 수 / ctx.eliminate만·MoveExempt 2곳·ctx.rng만·Survival 시간 제한), 손님 얼굴 높이·쉬는 칼 높이.
- `tests/map-sfx.spec.luau` MAP_CUES에 `ChefBoard.luau = { ChefHandWarn, SkewerWhoosh, TileVanish }` 추가.

## 인계 메모
- 브랜치: `m4-05-qa` (`origin/m4-05-chef-board` + `origin/main` 병합). push 완료.
- 끝난 것: 자동 검증 4개, 순수 로직 AC1~AC7 통과, 코드 리뷰(서버 판정·ctx 상태·cleanup·MoveExempt·예산·파일 범위), QA 테스트 13개 + MAP_CUES 추가, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC8~AC13 (위 체크리스트). P3 C1~C3은 반려 사유 아님. 스펙 본문 범위 1의 "반지름 36"을 "35"로 맞추는 문서 정리는 기획 담당.
- 다음에 할 첫 단계: `m4-05-qa`를 `main`에 병합(사용자/병합 담당) → 사용자 Studio 확인.
- 막힌 점: 없음.
