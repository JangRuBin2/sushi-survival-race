# QA — m5-05 새 Survival 맵: 튀김 냄비 탈출 (`tempura-pot`)

- 스펙: `docs/specs/m5-05-map-tempura-pot.md`
- 검증 커밋: `05b387b` (origin/main `9be7767` + origin/m5-05-tempura `210a19a` 머지) + QA 테스트 커밋
- 결과: **통과** (P0/P1 없음). 스펙 상태 `in-qa` → `qa-passed`. P2 1건·P3 5건은 플레이테스트 뒤 다듬기로 넘김.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **1649 passed, 0 failed** (107개 파일, QA 추가 24개 포함) |
| `luau-lsp analyze ... --flag:LuauSolverV2=true src` | 끝 코드 0 |
| `lune run tools/render-map tempura-pot --view all` | decor 1495/1500, lights 18/24 (shadowed 1/2), particles 6/16, anim 53/80, void 0% (8개 뷰 전부) — 개발 메모 숫자와 같음 |

## 수용 기준
| AC | 결과 | 근거 (테스트 이름 / 파일:줄 / 사용자 확인 필요) |
|---|---|---|
| AC1 | 통과 | `map-tempura-pot` "AC1" 2개. QA: 렌더러 환경 실제 build에서 스폰 24개 CanCollide 없음(`m5-05-qa` "QA build: 충돌 파츠는…") |
| AC2 | 통과 | `map-tempura-pot` "AC2" 3개. QA 경계: 6.01초부터 오름, 61초에 정확히 22, 음수 시간 0 |
| AC3 | 통과 | `map-tempura-pot` "AC3". QA: 13.5초 바구니 발(3) = 기름(3)이면 살고 13.6초에 튀겨짐. **실제 `start`를 가짜 Heartbeat로 돌려** 바구니 레이서가 13.4초까지 살고 13.7초 전에 탈락, 꼭대기 레이서는 60초까지 생존, 안전망 아래는 한 번만 탈락 |
| AC4 | 통과 | `map-tempura-pot` "AC4" 5개(D4 해석 — 사용자 확정). QA: **모든 발판(22개)과 바구니에서** 꼭대기까지 길이 있음(AC12 "떨어져도 계속"), 층 간격 정확히 4 |
| AC5 | 통과 | `map-tempura-pot` "AC5" 2개. QA: 실제 build한 벽 32조각 전부 꼭대기 40·안쪽 면 반지름 ≥ 36, 넉백 최고점(약 +5.3)으로도 테두리에 안 닿음 |
| AC6 | 통과 | `map-tempura-pot` "AC6" (넓이 합 약 153) |
| AC7 | 통과 | `map-tempura-pot` "AC7" 3개. QA 경계: 반경 정확히 5 맞음 / 5.0001 안 맞음, 모든 방향 수평 크기 35·바깥쪽, 간격 29.99→3·44.99→2·1000→1.5. **실제 `start`**: 10초 전 경고 없음, 10초에 발밑 원(OilSplash 태그, 충돌·쿼리 없음), 1.2초 뒤 LinearVelocity(로컬 바깥 35, 위 25, MaxForce 무한) → 0.15초 뒤 제거, PlatformStand 1초 뒤 풀림, MoveExempt 1.5초, `OilSplash` 소리, 원 밖으로 피하면 안 맞음, 공중 레이서는 대상 아님, 10~30초 7번·45~60초 9~11번 |
| AC8 | 통과 | `map-tempura-pot` "AC8·AC16" (Extended로 읽음 — AC16 문구대로), `inPool` 없음 → 랜덤 풀 합류 |
| AC9 | 통과 | 위 5단계 + `maps` 테스트 통과 |
| AC10 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC11 | 사용자 확인 필요 | 체크리스트 2 (경로는 순수 테스트로 확인 — 실제 점프 감각만) |
| AC12 | 사용자 확인 필요 | 체크리스트 3 (서버 동작은 가짜 환경으로 확인) |
| AC13 | 사용자 확인 필요 | 체크리스트 4 (Survival 끝 판정은 `RoundService`/`RoundLogic` 공통 — 맵은 `ctx.eliminate`만 부름) |
| AC14 | 사용자 확인 필요 | 체크리스트 5. 코드로는 확인: 충돌 파츠는 냄비 벽·바닥·발판·바구니뿐, 장식·기름·OilFollowers·경고 원·방울 전부 CanCollide/CanQuery/CanTouch false (`m5-05-qa` "QA build: 충돌 파츠는…") |
| AC15 | 사용자 확인 필요 | 재미 확인 (플레이테스트) |
| AC16 | 통과 (자동 부분) | 렌더러 다시 돌림(위 표), 개발 메모에 반복 5회 비평·최종 PNG 경로·전/후 PNG 있음, `checkBudget(Art.decor(), "Extended")` 통과, `lighting` 프리셋 + `MapTypes.validate` 통과, 소개 카메라 4점이 아레나 상자 안(`m5-23-qa` 전 맵 검사). 아트 품질 의견은 아래 P3 |
| AC17 | 사용자 확인 필요 | 체크리스트 6 (밤 조명·기름 빛·휴대폰에서 경고 원 — 경고 원은 런타임에만 생겨 렌더에 없음) |

**통과 10 / 실패 0 / 사용자 확인 필요 7** (AC10~AC15, AC17)

## 버그

### [P2] 튀는 기름이 바로 위층(+4) 발판에 서 있는 사람도 밀어요 — 원은 아래층에 보이는데
- 재현: 7층 발판 끝(11층 발판과 틈 1~2.5인 쪽)에 A가 서 있고, 11층 발판 가장자리에 B가 서 있다. 경고 원이 A 발밑(7층 윗면)에 뜬다. B는 자기 발판 위라서 원 "밖"이라고 생각하고 가만히 있는다.
- 기대: AC12 "원 밖으로 피하면 안 맞는다" — 원이 그려진 발판 높이 근처만 맞는다.
- 실제: 원 안 판정이 수평 반경 5 + 발 높이 "윗면 −1 ~ +6"이라 4 위인 위층 발판의 사람도 수평 5 안이면 넉백(35/25)을 맞아 위층에서 떨어진다. 층 사이 수평 틈이 1~2.5라 실제 배치에서 생긴다. (`m5-05-qa` "QA splash: 원 안이어도 … 위층(+4)은 맞아요"가 지금 동작을 고정)
- 참고: D5에서 높이 범위 −1 ~ +6이 확정됐지만, 그때 위층까지 닿는다는 점은 적혀 있지 않았다. 점프로 넘는 걸 막으려는 의도면 `SPLASH_HEIGHT_RANGE`를 층 간격(4)보다 작게(예: 3.5 — 점프 최고점 약 6.4 중 오르내리는 대부분은 여전히 맞음) 하거나, 대상 발판(`raft`) 위에 있는 사람만(`Logic.isOnRaft(raft, x, z)` 또는 `standingOn[player] == raft.key` + 공중) 맞히면 된다. 수치 조정이라 planner/developer가 정할 것 — 기획 확인 필요.
- 위치: `src/shared/maps/TempuraPot.luau:478`, `src/shared/maps/TempuraPotLogic.luau:44`

### [P3] 가만히 서 있던 대상은 항상 냄비 로컬 +X 쪽으로 날아가요
- 재현: 경고 원이 뜬 뒤 움직이지 않는다.
- 기대: "원 중심에서 바깥으로" — 방향이 상황에 맞게(예: 냄비 중심 쪽 또는 바깥 벽 쪽, 무작위) 정해진다.
- 실제: 원 중심 = 고를 때의 대상 위치라 거리가 거의 0이면 `splashKnockback`이 +X로 민다. 서버의 루트 위치가 조금이라도 흔들리면 그 흔들림 방향(사실상 무작위)으로 간다. 어느 쪽이든 약 18 studs 날아가 발판에서 떨어지니 판정 결과는 같지만, 방향이 냄비 한쪽으로 쏠린다.
- 위치: `src/shared/maps/TempuraPotLogic.luau:76`

### [P3] 계속 점프하는 사람은 튀는 기름 대상이 덜 돼요
- 내용: 대상 후보는 마지막 0.1초 확인 때 발밑 레이(4.5, 발 위 1.5까지)가 발판에 닿은 사람뿐이라, 계속 뛰는 사람은 뽑힐 확률이 낮다. 위층에서 뛰기만 해도 덜 노려진다. 플레이테스트에서 눈에 띄면 "최근 1초 안에 서 있던 발판"을 쓰면 된다.
- 위치: `src/shared/maps/TempuraPot.luau:381`

### [P3] (아트) 새우 꼬리 빨강-주황 쐐기가 위험 색과 겹쳐 보여요
- 렌더 `eye.png`·`intro-04.png`에서 발판 끝의 꼬리(`ShrimpTail`)가 빨강-주황 삼각형으로 눈에 띈다. 디렉션은 빨강-주황을 튀는 기름 경고에만 쓰기로 했다. 꼬리를 튀김옷 색에 더 가깝게(분홍-코랄을 더 연하게) 하면 경고 원이 더 읽힌다.
- 위치: `src/shared/maps/TempuraPotArt.luau:436` 근처

### [P3] (아트) 냄비 바깥면이 무쇠보다 나무 통처럼 읽혀요
- `overview.png`·`intro-01.png`: 갈색 기운의 벽 + 가로 띠 2줄 + 손잡이로 나무 통/양동이처럼 보인다. "검은 무쇠 냄비"라면 띠를 더 얇게/어둡게 하고 Metal 반사를 Studio에서 확인. 렌더러 근사라 Studio Future 조명에서 다를 수 있음.

### [P3] 공용 파일 주석이 낡음
- `src/shared/maps/init.luau:17` "(inPool = false)" — tempura-pot은 이제 풀에 있다. 공용 파일이라 다음 담당자가 지운다(개발 메모에도 적힘).

### 확인했지만 문제 아님
- 장식으로 기름을 피하는 자리: 장식(림·손잡이·온도계·젓가락·후드·OilFollowers)은 전부 `MapKit.buildDecor`/`ghost`로 충돌·쿼리 없음 → 올라설 수 없다. 냄비 안(벽 안쪽, y −10~40) 장식 중 발판처럼 보이는 넓고 평평한 판(가짜 바닥)도 없다(`m5-05-qa` "가짜 바닥", 50개 넘게 검사).
- 예산 여유: 장식 1495/1500은 `Art.decor()` 스펙 수라 런타임에 생기는 경고 원·방울(Decor 밖)은 예산에 들어가지 않는다. 실제 인스턴스 조명 18/24, 파티클 6 + 튀는 기름 동시 최대 2 = 8/16. 다만 장식 여유가 5개뿐이라 장식을 더 넣을 때는 다른 장식을 줄여야 한다.
- PlatformStand가 라운드 끝에 남는 경우: `RoundService`가 통과·대기석 이동 때 `resetMovement`로 풀어 준다(다른 맵과 같은 방식). 넉백 중 탈락하면 풀지 않는다(QA 테스트로 확인).
- 이동 감시: 넉백은 `MoveExempt.mark` 1.5초(비행 약 0.5초). 순간 이동이 아니라 연속 밀기도 없다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 — 이 맵은 리모트를 새로 만들지 않는다.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 기름 높이는 숫자(`Logic.oilHeight`, 서버 시계), 탈락은 서버 Heartbeat 0.1초 확인, 끝 판정은 `RoundService`.
- [x] 맵 상태가 모듈이 아니라 `ctx`/`start` 지역 변수에 있다 (`standingOn`, `lastHitAt`, `followers`). 레이캐스트 필터는 이 방 Model의 발판만(`m5-05-qa` "QA 여러 방").
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat, 일정 스레드, 튀는 기름 스레드, 경고 원, 방울, LinearVelocity·Attachment, PlatformStand/제거 delay 전부 `ctx.cleanup`. 라운드가 끝나면 일정·넉백·탈락 멈춤(QA 테스트). OilFollowers·기름 표면은 Model 하위라 맵 Model과 같이 지워진다.

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "tempura-pot", "skewer-showdown" }` → Play(혼자) 또는 Test → Clients and Servers(2~4명). 회전 벨트를 통과하면 냄비 라운드. **확인 뒤 `nil`로 되돌리기.**
1. (AC10) 출발 뒤 약 6초까지 기름이 그대로이고 그 뒤 눈에 보이게 올라온다. 바구니에 가만히 있으면 약 13~14초에 탈락하고 손님 입 연출이 나온다.
2. (AC11) 혼자 바구니 → 7층(바구니 가장자리 고구마·깻잎) → 나선을 따라 옆 발판으로 건너며 → 꼭대기(31층, 가장 작은 원판)까지 점프로 올라간다. 발판 위에서 미끄러지지 않는다. 머리가 위층 발판에 부딪혀 점프가 막히는 곳이 없다.
3. (AC12) 10초부터 내 발밑에 주황 원이 깜빡이고 약 1.2초 뒤 기름이 튀며 밀려 넘어진다(1초). 원 밖으로 5 넘게 피하면 안 맞는다. 떨어진 아래층이 아직 안 잠겼으면 다시 올라갈 수 있다. **P2 확인**: 2명으로, 한 명은 7층 발판 끝, 다른 한 명은 바로 위 11층 발판의 가까운 가장자리에 서서 아래 사람 발밑에 원이 떴을 때 위 사람도 날아가는지 본다.
4. (AC13) 60초가 끝날 때 23층 이상에 있던 사람은 전원 통과. 4명 이상 판에서 목표 인원만 남으면 그 자리에서 끝난다.
5. (AC14) 냄비 벽·테두리·젓가락·후드·온도계에 올라설 수 없다(장식은 통과해 떨어져야 함). 넉백을 맞아도 Output에 `[MoveGuard]` 되돌리기 로그가 안 생긴다.
6. (AC17) 소개가 시작되면 밤 주방 조명(어두운 청색 + 주황 기름빛)으로 바뀌고, 기름이 오를 때 주황 빛·김이 같이 올라온다. 휴대폰 에뮬레이터(가로)에서 주황 경고 원이 노릇한 발판 위에서 잘 보이고, 층이 구분된다. 너무 어두우면 `TempuraPotArt.LIGHTING`의 Brightness·ExposureCompensation만 올린다.
7. (AC15, 플레이테스트) 4~8명이 했을 때 60초 안에 목표 인원 근처까지 줄어드는지, 처음 하는 사람도 "위로 가야 한다"를 바로 아는지. `docs/playtest/`에 적기.
8. (선택) 냄비 바깥면이 무쇠로 보이는지(P3 아트), 새우 꼬리 색이 경고처럼 보이지 않는지.

## 추가한 테스트
- `tests/m5-05-qa.spec.luau` (새, 24개)
  - 정적 6: 기름 경계, 튀는 기름 간격·넉백 경계, 모든 발판에서 꼭대기까지 길, 층 간격, 머리 공간(높이 차 12 미만 겹침 없음), 벽 위로 못 올라감(점프·넉백)
  - 렌더러 환경 실제 build 5: 충돌 파츠 감사(냄비·발판만, 나머지 충돌·쿼리·터치 없음), 벽 높이·안쪽 면·바닥, 냄비 안 가짜 바닥 없음, 실제 조명·파티클 + 런타임 여유, OilFollowers·기름 ghost
  - `start`를 가짜 Heartbeat·task·레이캐스트(돌린 origin)로 13: 기름 표면·OilFollowers 따라감, 13.5초 바구니 탈락·꼭대기 60초 생존, 안전망 한 번만 탈락, 10초 경고 원, 넉백 속도·PlatformStand·MoveExempt·소리·LinearVelocity 제거, 원 밖 회피, 공중 비대상, 쿨다운·탈락자 PlatformStand 유지, 높이 범위(위층 +4 맞음 — P2 동작 고정), 일정 간격, cleanup·끝난 뒤 멈춤, 여러 방 레이캐스트 필터
- `tests/m5-23-qa.spec.luau` 수정: 개발자가 넣은 하드코딩 `EXTENDED = { ["tempura-pot"] = true }`를 **각 맵 `<Map>Art.BUDGET`를 읽는 `artBudgetTier`**(렌더러 `budgetTier`와 같은 규칙, Art 모듈이 없으면 Standard)로 바꿈. Extended 맵이 1개 이상 읽히는지도 확인.

## 인계 메모
- **브랜치**: 로컬 `worktree-agent-a5f3520ceda882668` → 원격 `m5-05-tempura` (`git push origin HEAD:m5-05-tempura`).
- **끝난 것**: m5-05 QA 전부(자동 검증 5단계 + 렌더러, 순수·서버 코드 검토, 아트 검토, QA 테스트 24개, m5-23-qa 예산 단계 정리). 스펙 상태 `qa-passed`.
- **남은 것**: 사용자 Studio 확인(위 체크리스트 1~8), P2(위층 넉백) 기획 결정, P3 다듬기. `main` 머지는 메인 세션이 한다(머지 뒤 검증 다시 돌리기).
- **다음에 할 첫 단계**: 메인 세션이 `m5-05-tempura`를 `main`에 머지 → 5단계 검증 → docs-writer가 CHANGELOG·DEV-SETUP(확인 목록)·CLAUDE.md(맵 풀 7개 Survival, 태그 `TempuraRaft`·`HotOil`·`OilSplash`) 반영.
- **막힌 점**: 없음.
