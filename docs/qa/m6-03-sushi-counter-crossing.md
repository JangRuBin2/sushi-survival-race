# QA — m6-03 대형 Race "초밥집 카운터 대횡단" (`sushi-counter-crossing`)

- 스펙: `docs/specs/m6-03-sushi-counter-crossing.md` (기반 m6-02, 제안서 `docs/proposals/large-maps.md` ①)
- 검증 커밋: `3d50551` (develop/main 끝, m6-08~12 병합 뒤), QA 브랜치 `claude/m6-03-07-qa`
- 결과: **통과** — P0/P1/P2 없음, P3 4개. 스펙 상태 **`qa-passed`**. Studio 항목은 사용자 확인 필요.

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests tools` | 통과 (새 QA 테스트 포함) |
| `selene src` | **근사 std로만 통과**(0 errors / 0 warnings, `tools/cloud/selene.toml`) — Roblox API 검사 없음(API 덤프를 못 받음). 로컬에서 한 번 더 |
| `lune run tests` (전체) | **QA 미실행**(다른 에이전트가 동시에 전체 실행 — 지시대로 단독 spec만). 단독: `map-sushi-counter-crossing` 15/0, **새 `m6-large-maps-qa` 12/0**, `m6-02-large-foundation` 11/0, `m6-01-race-respawn` 7/0, `m6-12-dynamite` 8/0, `m6-12-qa` 9/0, `m6-08-attack` 24/0, `localization` 20/0, `m4-foundation` 26/0, `m5-03-foundation` 31/0, `m5-23-qa` 22/0 |
| `luau-lsp analyze` (새 검사기) | 끝 코드 0 |

## 수용 기준 (스펙에 번호가 없어 항목별로 나눔)
| AC | 결과 | 근거 |
|---|---|---|
| AC1 등록: Race · capacity 40 · minPlayers 12 · 시간 제한 Race 90(`timeLimit` 없음) · 랜덤 풀 · 조명 | 통과 | 개발 "등록" + QA "공통: 5개 모두 랜덤 풀…" |
| AC2 이름·규칙 + CSV `map.sushi-counter-crossing.*`(en "Sushi Counter Crossing") | 통과 | `Strings.csv:140-141`, `localization` 20/0 (DATA_SOURCES 일치) |
| AC3 A 출발 광장 폭 72, 스폰 40(8 × 5) — 진짜 build에서 전부 충돌 바닥 위 | 통과 | 개발 "스폰 40개" + QA "스폰 40개가 모두 충돌 켜진 판정 바닥 바로 위" |
| AC4 B 갈림길 18 × 3 · 틈 9, 레일 4구간(이웃 반대·5초 뒤바뀜·목표 10·청록/연어·0.4초 전 `RailSwitch`), 접시 13개(틈 약 4.4), 간장병(2.5초·14·10 × 4) | 통과 | 개발 "코스 치수", "접시 징검다리", "회전 레일", "간장병·동전", "start: 레일 위면 방향대로 가속" |
| AC5 C 합류 · D 젓가락 들판(0.9초, 반지름 7, 1.5초 뒤 넉백 34 + 16, `ChopstickWarn`·`ChopstickClack`, 양옆 벽 4) | 통과 | 개발 "젓가락", "start: 젓가락 경고 1.5초 뒤 원 안 사람만 넉백" |
| AC6 E 오르막 14 × 4 · 틈 4, 바깥 영수증 뒤로 5(연속 밀기), 안쪽 동전 2.2초 | 통과 | 개발 "코스 치수", "간장병·동전" + 코드 `SushiCounterCrossing.luau:600-617` |
| AC7 F 결승 z -510 / 코스 -Z | 통과 | QA "Race: 코스가 로컬 -Z로" |
| AC8 맞음: 상자 + 1, 발 3.5 미만, 26 + 12, 면제 1, 쿨다운 0.8, cue `Knockdown` | 통과 | 개발 "start: 간장병에 맞으면…". 점프로 넘기는 **마주 달려야** 됨(QA "점프 창": 간장병 0.147초·동전 0.126초, 가만히 서서는 0) — P3-4 |
| AC9 연속 밀기(레일·영수증)는 MoveExempt 없음, 넉백만 `MoveExempt.mark` 한 곳 | 통과 | 개발 "서버 모듈" + QA "소스: … MoveExempt 한 곳 … knock() 안" |
| AC10 낙하선 = 바닥 − 12 → Race 부활 / 정원 뒤 탈락 | 통과 | 개발 "바닥·낙하선" + `m6-01-race-respawn` (맵은 `ctx.eliminate`만, 부활은 RoundService) |
| AC11 `estimateClearTime` ≈ 50초 (45~55) | 통과 | 49.9초 (510/16 + 지연 18). 실측은 사용자 확인 |
| AC12 아트: Large 예산·조명 범위·안개 패널 없음·소개 카메라 상자 + 40·경로가 판정 파츠를 안 뚫음·build 끝 introCamera + attachStudioArt | 통과 | 개발 "장식" + QA "아트: Large 예산…", "소개 카메라 점은 판정 파츠 상자 + 40 안", "소개 카메라 경로", "소스: build 끝…" |
| AC13 렌더 3회, `docs/renders/sushi-counter-crossing/` before/after | **부분** | after-* 6장 + stats만, **before-* 없음**(스펙에 "첫 렌더는 보관하지 못했고"라고 적힘) — P3-1 |
| Studio (DEV-SETUP 3-17 3번) | **사용자 확인 필요** | 아래 체크리스트 |

## 버그
### [P3-1] before 렌더가 없어요 (아트 규칙 12절 "첫/마지막 렌더 커밋")
- 재현: `ls docs/renders/sushi-counter-crossing/` → `after-*`만.
- 기대: `before-*.png`(첫 렌더)와 `after-*.png`.
- 실제: before 없음. 스펙이 이미 인정한 누락이라 기록만. 다음 아트 손질 때 지금 after를 before로 두고 새 after를 남기면 돼요.

### [P3-2] 젓가락 들판 끝(z ≤ 약 -368)에서 맞으면 오르막 줄 사이 틈(4)으로 날아갈 수 있어요
- 재현: 들판 끝 가까이(z -370 근처)에서 빨간 원 앞쪽 가장자리에 서 있기 → 원 중심이 뒤쪽이면 결승 쪽(-z)으로 34 넉백(0.15초 고정 + 짧은 체공 → 약 10 studs) → z ≈ -380 ~ -385의 오르막 쐐기 사이 틈(폭 4)에 떨어지면 3초 부활.
- 기대/실제: 스펙대로의 넉백이라 버그는 아니고 억울함 확인 항목. 원 중심 범위 `STRIKE_Z.back = -374`(`SushiCounterCrossingLayout.luau:112`)를 -366쯤으로 당기면 들판 안에서 끝나요.

### [P3-3] 🧨 다이너마이트 라운드: 갈림길에서는 떨어뜨린 자리의 약 30%가 허공
- m6-12 P3-2(바닥 검사 없는 `DynamiteLogic.dropSpot`, `DynamiteLogic.luau:77-92`)의 이 맵 수치: 레이서가 B 갈림길(레일·간장병 줄 18 폭, 틈 9) 위면 6~12 studs 둘레 자리의 **약 31%**가 바닥 밖(QA 몬테카를로 2만 번). 허공 아이템은 못 줍고 25초 동안 방 상한(2)을 차지. 고치는 건 m6-12 쪽(서버 레이캐스트 후 다시 뽑기).

### [P3-4] 간장병·동전은 가만히 서서 점프로는 못 넘어요 (마주 달려야 0.13~0.15초 여유)
- 계산(QA "점프 창"): 맞는 띠 = 지름/2 + 1 → 간장병 ±3(속도 14)·동전 ±3.5(16), 발 3.5 이상인 체공은 0.342초. 가만히 서면 띠를 지나는 데 0.43초 → **여유 0**, 결승 쪽으로 달리며(닫히는 속도 30·32) 뛰면 여유 0.147초 / 0.126초.
- 레이스는 결승 쪽으로 달리니 보통은 "마주 달려 점프"가 되고, 옆 8로 피할 수도 있어 P3. 단 서버는 복제된(약 0.1~0.2초 늦은) 위치로 판정하므로 Studio에서 "점프했는데 맞았다"가 잦은지 봐 주세요. 잦으면 `HIT_PAD` 1 → 0.5(`SushiCounterCrossingLayout.luau:140`).

## 서버 판정 · 보안 체크
- [x] 새 리모트 없음 — 클라이언트 입력을 받지 않아요.
- [x] 통과(결승선 진행도)·낙하·맞음 판정이 전부 서버 Heartbeat(`SushiCounterCrossing.luau:393-619`), 순위는 RoundService(진행도 -Z).
- [x] 맵 상태는 `start` 지역 변수(레일·병·동전·젓가락 슬롯·`hitReadyAt`), 모듈 수준 표 없음(QA 소스 테스트). 태그는 `ctx.model:IsAncestorOf`로 거름.
- [x] Heartbeat 연결·넉백 `LinearVelocity`·만든 Attachment·`task.delay`가 `ctx.cleanup`에 들어가요.
- [x] Race 부활(m6-01): 맵은 `ctx.getRacers()`만 보므로 부활 대기자는 판정·밀기·넉백에서 빠짐. 넉백 뒤 일으키기는 아직 레이서일 때만(`:318`), 부활은 RoundService `lockMovement`가 `PlatformStand = false`.
- [x] 공격(m6-08) 넉백·다이너마이트(m6-12) 폭발과 겹침: 맵 넉백 0.5~0.6초 뒤 일으키기가 공격 넘어짐 1초를 짧게 끊을 수 있음 — m6-08 QA에 이미 적힌 공통 P3(연출 차이뿐).

## 사용자 Studio 확인 체크리스트 (DEV-SETUP 3-17 3번 보강)
준비: `Config.DEBUG.forceMapPlan = { "sushi-counter-crossing", "hot-plate", "skewer-showdown" }`(커밋 전 `nil`), Test → Clients and Servers 6~8명.
1. 출발: 40칸 스폰 위에 서고 출발 직후 B 갈림길 세 입구로 갈라질 때 막힘이 심하지 않은지.
2. 왼쪽 레일: 5초마다 청록 ↔ 연어로 색이 바뀌고 0.4초 전 소리. 청록 위에서는 빨라지고(약 26), 연어 위에서는 느려지는지(약 6). 출력 창에 `[MovementGuard]` 경고가 없어야 해요.
3. 가운데 접시: 13개를 걷기 점프로 다 건널 수 있는지(틈 약 4.4).
4. 오른쪽 간장병: **결승 쪽으로 달리면서** 점프로 넘는지 10번 해 보고 몇 번 맞는지 적어 주세요(P3-4). 옆 빈 줄(8)로 피하는 것도.
5. D 들판: 빨간 원이 휴대폰 화면에서도 보이는지, 1.5초 뒤 젓가락이 내려와 원 안만 튕기는지. 들판 끝(오르막 바로 앞)에서 맞으면 오르막 틈에 빠지는지(P3-2).
6. E 오르막: 바깥 줄 영수증이 천천히 뒤로 미는지(넘어지지 않음), 안쪽 줄 동전에 맞으면 뒤로 넘어지는지(@_@ 약 0.6초).
7. 갈림길 틈에 일부러 떨어지기 → 3초 뒤 출발점에서 "3·2·1" 부활(m6-01).
8. 완주 시간 실측(목표 50~60초) — 스톱워치로 빠른 사람 한 번.
9. (선택) `Config.Dynamite.UniqueChance = 1`로 이 맵 다이너마이트 라운드 → 갈림길에서 허공에 생기는 빈도(P3-3).

## 추가한 테스트
- `tests/m6-large-maps-qa.spec.luau` (12개, 5개 맵 공통): 공통 계약(풀·인원·시간·추정), 진짜 build에서 스폰 40개가 충돌 바닥 위, Race 코스 -Z, Large 예산·조명 범위·그림자 Spot·안개 패널 없음, 소개 카메라 상자 + 40·경로, 서버 모듈 소스 규칙(build 끝, MoveExempt 한 곳·knock 안, 태그 ctx.model, 모듈 수준 표 없음, Players 직접 안 봄), 점프 창(마주 달려 넘는 여유 ≥ 0.1초).

## 인계 메모 (2026-11-12, QA)
- 브랜치: `claude/m6-03-07-qa` (worktree, push 안 함 — 지시). 끝난 것: 코드 리뷰·테스트 보강·리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인(위 체크리스트), 렌더 before 보관(P3-1, 선택).
- 다음 첫 단계: develop에 QA 브랜치 병합 후 전체 `lune run tests` 한 번(QA는 동시 실행 금지라 전체를 못 돌림).
- 막힌 점: 없음. selene은 근사 std만.
