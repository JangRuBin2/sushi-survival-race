# QA — m3-06 다이브

- 스펙: `docs/specs/m3-06-dive.md`
- 검증 커밋: `1bd2eef` (`origin/m3-06-dive`) + `origin/main`(`08d49fd`, m3-01 QA) 병합. 병합 충돌 없음.
- 결과: **통과 (P0/P1 없음, P2 1건, P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC7~AC15)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 273 passed, 0 failed (병합 전 기존 + 개발 14 + QA 추가 24) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `dive.spec` AC1 3개 + QA `canDive: …` 4개 (WalkSpeed 0.01/음수, 체력 음수, 쿨다운 1.5 정각·1.4999, 같은 시각 재입력) |
| AC2 | 통과 | `dive.spec` AC2 4개 + QA `launch: …` (이동 길이 정확히 0.1이면 바라보는 방향, 수평 성분 없음 → -Z, 바라보는 방향 정규화, WalkSpeed 0/음수 → 수평 0) |
| AC3 | 통과 | `dive.spec` AC3 + QA 간장 웅덩이 값(8, JumpPower 0) → 수평 20·vy 0, 공중 상승 중 vy 유지 |
| AC4 | 통과 | `dive.spec` AC4 4개 + QA 착지 유예 0.1 정각, 최대 체공 시각에 착지하면 Stunned, 경직은 땅 여부와 무관, begin/step 입력 불변, 끊긴 뒤 쿨다운 유지 |
| AC5 | 통과 (문구 그대로) / 단, 아래 B1 | `dive.spec` AC5 + QA 프레임 시뮬레이션(60Hz): 걷기 16.0, 땅 다이브 연타 < 16, 점프 꼭대기 다이브 연타 < 16. **점프 직후(올라가는 중) 다이브 연타는 걷기보다 빠름** — B1 |
| AC6 | 통과 | 위 자동 검증 |
| AC7~AC15 | 사용자 확인 필요 | 아래 체크리스트. AC9는 QA 시뮬레이션으로 "꼭대기 다이브가 그냥 점프의 1.5배 넘게 멀리 감"을 확인(물리 근사) |

요약: 순수 로직 AC1~AC6 통과(6/6), Studio AC7~AC15 사용자 확인 필요(9). 실패한 기준 없음.

## 코드 리뷰

### 범위·공용 파일
- `git diff origin/main...origin/m3-06-dive`: 바뀐 파일은 스펙이 지정한 `DiveController.luau`, 새 `DiveButton.luau`, 새 `DiveLogic.luau`, 새 `tests/dive.spec.luau`와 문서(`docs/specs/m3-06-dive.md`, `docs/developer/m3-06-dive.md`)뿐. **공용 파일(`Config`, `Remotes`, `Types`, `maps/init`, `default.project.json`) 변경 없음.**
- `CharacterUseJumpPower = true`(`default.project.json`)라 `JumpPower`로 땅 판정·간장 웅덩이 규칙을 읽는 게 맞다.

### 서버 값·판정과 충돌 없음
- `DiveController`는 `WalkSpeed`·`JumpPower`·`PlatformStand`에 쓰지 않는다(QA 소스 테스트). 리모트·속성·`FireServer` 없음.
- 서버가 쓰는 값과의 관계:
  | 서버 쪽 | 값 | 다이브 |
  |---|---|---|
  | 라운드 시작 이동 잠금 `RoundService.luau:100-102` | WalkSpeed 0 | canDive false, 날던 중이면 끊김 |
  | 젓가락 `RotatingBeltChopstick.luau:104-105` | WalkSpeed·JumpPower 0 | canDive false / 끊김 → 즉시 일어섬 |
  | 탈락 고정 `EliminationService.luau:78-80` | WalkSpeed 0, PlatformStand, Anchored | 끊김. 자세 snap은 Anchored·PlatformStand면 건너뜀 (`DiveController.luau:151`) |
  | 날치알 공·꼬치 넉백 `SoySwampHazards.luau:199`, `SkewerShowdown.luau:397` | PlatformStand + 속도 | 다음 PreSimulation에서 끊김 → 서버 넉백 속도를 덮어쓰지 않음 |
  | 간장 웅덩이 `SoySwampHazards.luau:71-72` | WalkSpeed 8, JumpPower 0 | 수평 20, vy 0 (AC3·AC11) |
- 통과·탈락 판정은 그대로 서버 맵 루프(루트 위치)가 한다. 다이브는 이동 수단일 뿐이라 판정 경로 변화 없음.

### 차단 조건
- 관전: `CameraSubject ~= 내 Humanoid` 또는 `CameraType = Scriptable`이면 막힘(`DiveController.luau:75-81`). 관전의 E(다음 사람)와 겹치지 않음. 탈락 대상 비추기(Scriptable)도 막힘.
- 라운드 소개: 지금은 WalkSpeed 0으로 막히고, m3-04가 Scriptable 카메라를 쓰면 이중으로 막힘.
- 넘어짐: `PlatformStand`로 막힘 + 날던 중이면 즉시 해제.
- 채팅 입력 중: `gameProcessed`로 무시.

### 개발이 남긴 이슈 위험도
| 이슈 | 위험도 | 판단 |
|---|---|---|
| 공중 다이브 최대 40 studs (`DiveController.luau:261-264`) | 낮음~중간 | 40 studs를 다 가려면 1초 동안 약 98 studs를 떨어져야 해서 실제로는 낙차가 상한을 정한다(회전 벨트 탈락선 40 studs 아래 → 최대 약 0.64초·25 studs). 그보다 **점프 직후 다이브 연타가 걷기보다 빠른 문제(B1)**가 더 크다. 발판 사이 지름길은 Studio 확인(B2) |
| 다이브 중 `FallingDown`·`Ragdoll`·`GettingUp` 끄기 (`:33-37, 111-113, 146-148`) | 낮음 | 클라이언트 소유 휴머노이드 로컬 상태라 서버 값과 무관하고, 끝나면 다시 켠다. 지금은 다른 코드가 이 상태를 건드리지 않음(grep). 다만 나중에 다른 컨트롤러가 이 상태·`AutoRotate`·`Jumping`을 끄면 다이브 끝에서 무조건 다시 켜 버린다(B4) |
| 경직 이동 막기 실행 순서 (`:30, 86-91`) | 낮음 | 기본 `ControlModule`은 `RenderPriority.Input`에서 `Move`를 부르고 다이브는 `Input + 2`라 나중에 실행돼 이긴다. 클릭 이동(`ClickToMove`, 사용자가 설정에서 고른 경우)은 `MoveTo` 경로라 `Move(zero)`로 안 막힐 수 있음 — 기본 설정에서는 해당 없음. 점프 키를 누른 채면 경직이 끝나는 순간 바로 점프하는데 정상 동작 |

### 정리(Cleanup)
- `AlignOrientation`·`Attachment`는 `finish`/`standUp`에서 지우고, 리스폰(`CharacterAdded`)·사망·캐릭터 제거 때도 `finish`가 돈다. 경직 렌더 바인딩도 `finish`에서 해제.
- `DiveButton`은 자기 `Cleanup` 두 개(전체·점프 버튼 연결)로 연결을 정리하고, 점프 버튼이 다시 생기면 다시 붙는다. 컨트롤러 연결 자체는 세션 내내 사는 클라이언트 연결이라 정리 대상 아님.

## 버그
P0/P1 없음.

### [P2] B1 점프 직후(올라가는 중) 다이브를 반복하면 걷기보다 빠름
- 재현: 땅에서 점프하고 바로(0.1초 안) 다이브 → 착지·경직 → 쿨다운(1.5초)이 끝날 때마다 반복.
- 기대: 스펙 목표 "연타하면 그냥 달리는 것보다 느리다", AC5 "쿨다운마다 다이브하는 것이 걷기만 하는 것보다 느리다".
- 실제(물리 근사 계산, 240Hz, 중력 196.2): 점프 후 다이브까지 지연에 따라 평균 속력 0.02초 → **18.6**, 0.05초 → **18.1**, 0.1초 → **17.3**, 0.2초 → 15.7, 꼭대기(0.255초) → 14.8, 땅 다이브 → 13.4 studs/s (걷기 16). 점프 직후 vy(약 45~50)를 그대로 두고(스펙 범위 3) 그 긴 체공(약 0.5초) 내내 수평 40을 유지하기 때문. AC5 테스트는 땅 다이브만 보기 때문에 통과한다 — **구현이 스펙과 다른 게 아니라 스펙 규칙끼리 충돌**.
- 영향: 판정 문제는 아니고 레이스 속도 균형. 아는 사람은 Race 맵에서 약 13~16% 빨리 갈 수 있다.
- 제안(기획 결정 필요): 공중 다이브의 수직 속도를 `min(지금 vy, UpSpeed)`로 자르기(꼭대기·하강 중 다이브 = AC9 "체공 늘리기"는 그대로), 또는 공중 다이브 수평 속도를 체공 동안 줄이기. 고친 뒤 `tests/m3-06-qa.spec.luau`에 "점프 직후 다이브 반복도 걷기보다 느리다" 시뮬레이션 테스트를 추가(자리 주석 있음). m3-09(통합·밸런스)에서 처리해도 됨.
- 위치: `src/shared/DiveLogic.luau:108-113`, `src/client/input/DiveController.luau:261-264`

### [P3] B2 발판 끝·벨트 틈에서 공중 다이브로 코스를 건너뛸 수 있는지 미확인
- 재현(Studio): 회전 벨트·간장 늪에서 높은 곳 끝으로 달려 떨어지면서 다이브.
- 기대: 다이브로 장애물을 피하거나 틈을 넘는 건 의도, 코스 구간을 통째로 건너뛰는 지름길은 없어야 함.
- 실제: 낙차가 h studs면 약 `40 × sqrt(2h/196.2)` studs 앞으로 간다 (10 studs 낙차 → 약 13 studs, 30 → 22). 맵 레이아웃상 아래쪽 코스로 뛰어내려 앞서는 길이 있는지는 Studio 확인 필요 (체크리스트 6).
- 위치: `src/client/input/DiveController.luau:261-264`

### [P3] B3 날아가는 동안 서버의 PlatformStand 없는 밀기를 덮어씀
- 재현: 회전 벨트 컨베이어 구역 위에서 공중 다이브 / 와사비 패드에 튕긴 직후 다이브.
- 실제: Flying 동안 매 프레임 수평 속도를 발사값으로 다시 넣어서 컨베이어 밀기(`RotatingBelt.luau:266-273`)가 최대 1초 무시되고, 와사비 튕김(앞 30, 강제 0.08초)은 그 뒤 수평 40으로 바뀐다(위 80은 유지 → 약 0.8초 × 40). 넘어짐(PlatformStand)을 거는 장애물은 끊겨서 영향 없음.
- 영향: 작음. 와사비 + 다이브가 꽤 멀리 가는데, 와사비는 원래 앞으로 보내 주는 패드라 의도와 크게 어긋나진 않음. Studio 체감 후 m3-09에서 판단.
- 위치: `src/client/input/DiveController.luau:261-264`

### [P3] B4 다이브가 끝나면 Humanoid 로컬 상태를 무조건 다시 켬
- 실제: `standUp`이 `AutoRotate = true`, `FallingDown/Ragdoll/GettingUp` 켜기, `setStun(off)`가 `Jumping` 켜기를 원래 값과 관계없이 한다. 지금은 다른 코드가 이 값을 끄지 않아서 문제없음.
- 위험: m3-02(넘어짐 연출)·m3-07(잡기)·m3-04(소개)가 같은 값을 끄면 다이브 끝에 되살아난다. 그 스펙 QA 때 다시 확인.
- 위치: `src/client/input/DiveController.luau:99-104, 145-148`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 다이브는 리모트가 없다(QA 소스 테스트). 클라이언트 물리 속도 악용 감시는 스펙 결정 기록대로 M4.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 판정 코드 변경 없음.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 맵 코드 변경 없음. 다이브 상태는 클라이언트 컨트롤러 지역 변수.
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 위 "정리" 참고.

## 사용자 Studio 확인 체크리스트
준비: `rojo serve` → Studio 연결. 맵을 고를 때는 `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 바꾸고, **끝나면 `nil`로 되돌린다**.

1. **AC7 기본 다이브** — F5, 로비에서 W를 누른 채 Shift. 초밥이 앞으로 엎드려 날아가고, 착지 뒤 약 0.5초 엎드려 있다가 일어선다. 오른쪽 Shift, E, (게임패드 연결 시) X도 같다. 마우스가 화면 가운데 고정되지 않는다(Shift Lock 꺼짐). 엎드린 채 공중에 떠 보이거나 바닥에 박히지 않는지 본다(개발 메모 위험). 서 있다가(이동 키 없이) Shift를 누르면 바라보는 방향으로 나간다.
2. **AC8 쿨다운** — Shift를 연타한다. 첫 다이브 뒤 1.5초 안에는 안 나가고 1.5초 지나면 나간다. 경직 중에 WASD·Space를 눌러도 움직이거나 점프하지 않는다.
3. **AC9 점프 다이브** — 점프 꼭대기에서 Shift. 그냥 점프보다 확실히 멀리 간다. 공중에서 다이브하고 1초 넘게 떨어지면 착지 전에 일어선 자세로 돌아온다.
4. **AC10 차단** — `forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`.
   - 라운드 시작 전 스폰에 멈춰 있는 동안 Shift → 안 나감.
   - 회전 벨트: 젓가락에 들려 있는 동안 Shift → 안 나감. 다이브 중에 젓가락에 잡히면 바로 일어선 자세가 된다.
   - 간장 늪: 날치알 공에 맞아 넘어진 동안 Shift → 안 나감. 다이브 중에 맞으면 엎드린 자세가 바로 풀리고 공에 맞은 넉백대로 날아간다.
   - 꼬치 쇼다운: 꼬치에 맞아 넘어진 동안 안 나감.
   - 떨어져 탈락하는 연출 중 Shift → 안 나감.
5. **AC11 간장 웅덩이** — 간장 늪 웅덩이 안에서 Shift. 위로 튀지 않고 평소 절반 정도만 나간다.
6. **B1·B2 확인 (밸런스)** — 회전 벨트 평지에서 같은 거리를 (a) 그냥 달리기 (b) 점프하자마자 Shift를 1.5초마다 반복 으로 가 보고 시간을 비교한다. (b)가 빠르면 B1 재현. 발판 끝·벨트 틈에서 떨어지며 다이브해 코스 일부를 건너뛸 수 있는지 본다(B2). 와사비 패드에서 튕기자마자 다이브하면 얼마나 가는지 본다(B3).
7. **AC12 다른 사람 화면** — Test → Clients and Servers, 플레이어 2명. Player1이 다이브하면 Player2 화면에서 Player1이 엎드려 날아가는 모습이 보인다. Player1 화면에 "@_@"(넘어짐 표시)가 뜨지 않는다.
8. **AC13 관전 중 E** — 2~3명으로 판을 시작해 Player1이 떨어져 탈락 → 관전 중 E를 누르면 관전 대상만 바뀌고, 로비에 있는 Player1 캐릭터는 다이브하지 않는다(서버 창에서 Player1 캐릭터가 엎드리지 않는지 확인). 탈락 직후 떨어진 자리를 비추는 3초 동안에도 E로 다이브하지 않는다.
9. **AC14 모바일** — Test 탭 → Device(휴대폰 에뮬레이터, 예: iPhone) 선택 후 F5. 오른쪽 아래 점프 버튼 왼쪽에 같은 크기의 "다이브" 버튼이 겹치지 않게 있다. 누르면 다이브하고, 어두운 덮개가 위에서부터 1.5초 동안 줄어든다. 가로/세로 회전·다른 기기로 바꿔도 위치가 맞는다. 에뮬레이터를 끄고 PC로 F5하면 버튼이 없다.
10. **AC15 회귀** — 4번 맵 순서로 한 판을 다이브를 섞어 끝까지 돈다. 결승선을 다이브로 넘어도 통과, 맵 밖으로 다이브해 떨어지면 탈락 — M2와 같다. Output에 빨간 에러가 없다.

## 추가한 테스트
`tests/m3-06-qa.spec.luau` (24개)
- `canDive` 경계: WalkSpeed 0.01/음수, 체력 음수, 쿨다운 1.5 정각·1.4999, 같은 시각 재입력.
- `launch` 경계: 이동 길이 정확히 0.1, 수평 성분 없음 → -Z, 바라보는 방향 정규화, 간장 웅덩이 값, 공중 상승 vy 유지, WalkSpeed 0/음수.
- `step` 경계: 착지 유예 0.1 정각, 최대 체공 시각 착지 → Stunned, 경직은 땅 여부 무관, begin/step 입력 불변, 끊긴 뒤 쿨다운.
- 프레임 시뮬레이션(60Hz, `DiveLogic`을 그대로 돌림): 걷기 = 16, 땅 다이브 연타 < 걷기, 꼭대기 점프 다이브 연타 < 걷기(AC5 보강), 꼭대기 다이브 > 그냥 점프 × 1.5(AC9 근사).
- 소스 확인: `DiveController`가 WalkSpeed·JumpPower·JumpHeight·PlatformStand에 대입하지 않음, 다이브 파일 3개에 Remotes·SetAttribute·FireServer 없음, 키 4개·gameProcessed·경직 우선순위 Input+2·Sfx 두 개, `DiveButton` TouchEnabled·ResetOnSpawn false·"DiveGui"·"다이브"·간격 0.15, `SfxCues`에 Dive·DiveLand.

## 인계 메모
- 지금 브랜치: `m3-06-qa` (`origin/m3-06-dive` + `origin/main` 병합, QA 커밋 + push)
- 끝난 것: 자동 검증 4종 통과(273/0), AC1~AC6 통과, 코드 리뷰, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC7~AC15 (위 체크리스트). 메인 세션이 `m3-06-qa`를 main에 병합.
- 다음에 할 첫 단계: 기획이 B1(점프 직후 다이브 연타가 걷기보다 빠름)을 어떻게 할지 정한다 — 공중 다이브 vy 상한 등. 정하면 m3-09나 별도 수정으로 개발, QA는 `tests/m3-06-qa.spec.luau`의 B1 자리 주석에 시뮬레이션 테스트 추가.
- 막힌 점: 없음.
