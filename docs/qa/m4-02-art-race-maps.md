# QA — m4-02 맵 아트 패스: 회전 벨트 · 간장 늪 (+ 회전 벨트 태그 전환, 스폰 수정)

- 스펙: `docs/specs/m4-02-art-race-maps.md`
- 검증 커밋: `7e56e00` (브랜치 `m4-02-art-race`). QA 브랜치 `m4-02-qa`에서 `origin/main`(`674c7ae`, m4-04/05/07/08/09 병합 후)을 병합해 검증. 병합 충돌 없음.
- 결과: **통과 (P0/P1/P2 없음)** → 스펙 상태 `qa-passed`. P3 2건. Studio 확인(AC7~AC13)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과: 725 passed, 0 failed (main 병합 직후 718 + QA 추가 7) |

바뀐 파일(`origin/main...origin/m4-02-art-race`): `RotatingBelt.luau`, `RotatingBeltChopstick.luau`, `RotatingBeltArt.luau`(새), `SoySwamp.luau`, `SoySwampHazards.luau`, `SoySwampArt.luau`(새), `tests/map-art-race.spec.luau`(새), 스펙, `docs/developer/m4-02-art-race-maps.md`. 스펙의 "이 스펙이 고치는 파일" 밖의 `src`·공용 파일 변경 없음. `SoySwampLayout.luau`는 바뀌지 않음.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `AC1: 두 맵 decor()가 MapKitLogic.validate를 통과하고 파츠 수 ≤ 600`. 실제 파츠 수 회전 벨트 329, 간장 늪 136. 아트에 조명·파티클 없음 (예산 8/12 해당 없음) |
| AC2 | 통과 | `AC2: 장식 외곽 상자가 코스 공간…`, `AC2: 코스 공간 상자가 실제 코스 폭·길이를 덮어요`. QA `치수: 아트 SECTIONS·결승선·간장 종지 위치가 RotatingBelt.luau 소스 상수와 같아요` (아트 모듈이 옮겨 적은 치수가 소스와 어긋나면 AC2 검사가 무의미해지는 것 방지). courseVolume을 구간별 상자 목록으로 바꾼 결정 기록 확인. P3 Q2(노렌 높이) 참고 |
| AC3 | 통과 | `AC3: introCamera 경유점 3~5개…`(둘 다 4점, 마지막 (0, 12, 10)), `AC3: 소개 카메라 경유점은 장식 안에 묻히지 않아요`. QA `소개 카메라(회전 벨트): 경유점 사이 경로도…` 통과. 간장 늪은 경로가 종이 등을 지나감 → P3 Q1 |
| AC4 | 통과 | 기존 `map-soy-swamp`, `maps`, `map-race-belt` 등 테스트 수정 없이 통과(`git diff`로 tests 기존 파일 변경 없음 확인). `AC4: 판정 수치는 그대로`, `AC4: 회전 벨트 코스 치수·장애물 타이밍 상수는 M3 그대로` |
| AC5 | 통과 | `AC5: RotatingBelt.start는 Hazards 폴더가 아니라 CollectionService 태그로 찾아요`, `태그 전환: 폴더 순회와 같은…다른 방 맵은 빼요`, `같은 station의 Zone이 두 번 태그돼도 한 번만`. 코드: `RotatingBelt.luau:284`, `:339`, `RotatingBeltChopstick.luau:38-59` |
| AC6 | 통과 | 위 자동 검증 4개 |
| AC7 | 사용자 확인 필요 | 아래 체크리스트 1 |
| AC8 | 사용자 확인 필요 | 코드상 장식은 전부 `MapKit.buildDecor`(충돌·쿼리·터치 없음), 젓가락 `Tip`도 CanCollide/CanQuery/CanTouch false·Massless. 체크리스트 2 |
| AC9 | 사용자 확인 필요 | 코드상 판정 수치·타이밍 그대로(아래 "판정 회귀"). 체크리스트 3 |
| AC10 | 사용자 확인 필요 | 체크리스트 4 |
| AC11 | 사용자 확인 필요 | 코드·가짜 인스턴스 테스트로 다른 방 제외 확인. 체크리스트 5 |
| AC12 | 사용자 확인 필요 | 두 맵 build 끝에서 `MapKit.attachStudioArt(model, ID, origin)` 호출 확인. 체크리스트 6 |
| AC13 | 사용자 확인 필요 | 체크리스트 7 |

통과 6 / 실패 0 / 사용자 확인 필요 7.

## 판정 회귀 점검 (코드 리뷰)
- **벨트 밀기**: `PUSH_SPEED 10`, `PUSH_ACCEL 24`, 미는 방향·구역 판정 로직 그대로. 구역 목록만 `Conveyors` 폴더 → `Conveyor` 태그(`RotatingBelt.luau:127`에서 태그, `:284`에서 `ctx.model` 하위만 조회). 모델은 `RoundService.luau:170`에서 Workspace에 들어간 뒤 `start`가 불려 `GetTagged`가 찾을 수 있음.
- **젓가락**: 경고 1초·잡기 3초·쿨다운 2.5~4.5·영역 8×10·높이 10/1.5 그대로. `moveSticks`는 `Sticks`의 자식(StickLeft/Right)만 트윈하고 `Tip`은 스틱의 자식이라 트윈 대상이 아님 → 용접으로 따라감(Studio 눈 확인 필요). 포획은 `PointToObjectSpace` 계산이라 장식·Tip 영향 없음.
- **간장·와사비·날치알**: `SoySwampLayout` 바뀌지 않음. 감속 0.5배, 와사비 위 80·앞 30, 넉다운 시간 그대로. 판정 로직 변경은 `MoveExempt.mark` 호출 추가뿐(`SoySwampHazards.luau:78,85,168,215`). 와사비 쪽 `character` 지역 변수를 `launch` 앞으로 옮겼지만 같은 값.
- **결승선·낙하선**: 결승선 크기·위치·Neon·CanCollide false, `FINISH_LINE_INSET 4`, `VOID_DROP 40` 그대로. 색만 같은 값 유지.
- **재질·물리**: 재질을 바꾼 판정 파츠는 모두 M3 재질의 `CustomPhysicalProperties`를 둠. 회전 벨트 바닥 5개(출발·결승 WoodPlanks / 벨트 SmoothPlastic → 물리 SmoothPlastic·Metal, M3와 같음), 병목 Wood → SmoothPlastic, 종지 SmoothPlastic → Plastic. 간장 늪 바닥·산·경사로·내리막·결승단 → SmoothPlastic(M3의 `makePart` 기본값), 날치알 공 Sand → SmoothPlastic. 벽은 Glass·투명도 그대로(색만). QA 테스트 `물리 유지` 추가.
- **태그 전환이 다른 방을 건드리지 않음**: `taggedIn`이 `IsDescendantOf(container)`로 거름. 같은 서버 다른 맵(`ramen-rapids` 등)이 같은 태그 이름을 써도 ctx.model 밖이라 제외.
- **맵 상태**: 새 상태(`exemptAt`, `released`)는 전부 `start`/`run` 지역 변수. 모듈 상태 없음. 새 연결·스레드 없음(Heartbeat·스레드는 기존 `ctx.cleanup` 등록 그대로).

## 스폰 수정 점검
- **옛 위치가 실제로 허공이었음 (근거)**: 출발 바닥은 `nextSegment(14)` → 중심 z -7, 범위 z 0 ~ -14, 폭 20(x ±10). 옛 식 `z = -7 + 2 + row*4` → -5, -1, **+3, +7**. 3·4번째 줄(Spawn13~24, 12개)은 z > 0 = 바닥 뒤(벽 없음, 허공). 옛 `x = (col - 2.5)*4` → ±10 열(8개)은 스폰 판 절반이 바닥 밖이고 벽(x 10~10.5)에 걸침. QA 테스트 `스폰 근거: 옛 식(M1~M3)은 12개가 …허공, 8개가 바닥 끝`으로 재현.
- **새 위치**: 6열 × 4줄, 간격 3 → x ±7.5, z -2.5 ~ -11.5. 판(3×3) 가장자리가 옆 가장자리에서 1 stud, 앞 끝(z 0)에서 1 stud, 벨트 A·Conveyor 구역(z -14)에서 1 stud 떨어짐. 개발 테스트 + QA `새 위치 24개가 출발 바닥 안쪽, 벨트 구역 밖`.
- **간격 3**: 판끼리 겹치지 않음(맞닿음). 캐릭터 충돌 몸통(HumanoidRootPart·Torso 폭 2, 팔다리는 충돌 안 함) 사이 1 stud 여유 → 끼지 않음. 초밥 몸 외형 폭 2.8(`SushiBody.bounds`)이라 겉모습도 0.2 떨어짐. 다른 맵(3.6)보다 좁은 건 출발 바닥 폭 20에 6열을 1 stud 여유로 넣으려면 3.4 미만이어야 해서 타당. `SPAWN_LIFT` 3 studs 위에서 떨어뜨리는 것은 기존과 같음. 다인원 확인은 체크리스트 5.
- 간장 늪 스폰은 바뀌지 않음(원래 출발 구간 안), 테스트만 추가됨.

## 이동 감시 면제(MoveExempt) 위치
- 벨트 밀기: 미는 프레임마다가 아니라 0.5초 간격(`RotatingBelt.luau:328`) — 기본 면제 1.0초보다 짧아 밀리는 동안 빈틈 없음(QA 테스트).
- 젓가락 잡기 `GRAB_DURATION + 1`(4초), 놓을 때 1초 (`RotatingBeltChopstick.luau:165,180`).
- 간장 감속 켜기·끄기 각 1초, 와사비 2.5초, 날치알 넉다운 `KNOCKDOWN_DURATION + 1`.
- 면제 후보로 빠진 곳 없음. 다만 간장 감속은 속도를 **낮추는** 쪽이라 m4-10이 상한만 본다면 면제가 없어도 오탐 없음(참고).
- `MovementGuardService`는 지금 껍데기라 실제 효과는 m4-10 병합 뒤에 확인된다.

## 버그
### [P3] Q1 간장 늪 소개 카메라가 마지막 구간에서 종이 등을 뚫고 지나감
- 재현: `IntroCameraLogic.sample(SoySwampArt.introCamera() 경로, t)`를 0~1로 2000등분해 장식 외곽 상자와 비교. t ≈ 0.69~0.70에서 카메라 위치 (0, 23.2, -49.5)가 `Lantern`(중심 (0, 22, -48), 지름 3) 안. 3번 점 (0, 38, -128) → 4번 점 (0, 12, 10) 직선이 z -48에서 높이 약 22.9를 지나기 때문.
- 기대: 경유점 사이 경로도 장식 안을 지나가지 않음 (AC10 "벽에 묻히지 않는다"의 연장).
- 실제: 플라이스루 마지막 구간에서 아주 잠깐(전체의 약 0.9%) 화면이 빨간 등 안쪽으로 덮임. 경유점만 검사하는 개발 테스트로는 안 잡힘. 회전 벨트 경로는 문제 없음(QA 테스트 통과).
- 고치는 방법 예: 등을 x 쪽으로 비키거나(예: x ±6), 3번 점 높이를 낮추거나, 등 높이를 26 이상으로. 고친 뒤 QA 테스트 `소개 카메라(회전 벨트)…`를 간장 늪까지 넓히면 됨.
- 위치: `src/shared/maps/SoySwampArt.luau:261-266`(등), `:286-287`(경유점)

### [P3] Q2 회전 벨트 노렌이 코스 안쪽 바닥 위 12.2~15 높이에 있음
- 재현: `RotatingBeltArt.decor()`의 `Noren`(y 12.2~15.0), `NorenMark`(13.1~14.5)이 결승 구간 벽 안쪽(x ±10 안) 위에 있음.
- 기대: 스펙 "코스 안쪽에는 벽 바깥, 바닥 아래, **머리 위 15 studs 이상만**".
- 실제: AC2 상자(2~12)와는 안 겹쳐서 테스트는 통과하지만 스펙 문구의 15 이상 규칙보다 2.8 낮음. 충돌 없음이고 점프 최고점(머리 약 11.4)보다 높아 판정 영향은 없음. 결승 직전 카메라가 위를 볼 때 시야를 조금 가릴 수 있음 → Studio에서 거슬리면 노렌을 15 위로 올리거나 스펙 문구를 "12 이상"으로 바꿈(기획 판단).
- 위치: `src/shared/maps/RotatingBeltArt.luau:304-308`

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가·변경하지 않음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 결승선·낙하 판정 그대로 서버 Heartbeat
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 새 상태는 함수 지역 변수
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 새 연결·스레드 없음. 장식·Tip은 맵 Model 하위라 맵과 같이 지워짐

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }`, Rojo 연결. **커밋 전에 `nil`로 되돌린다.**
1. (AC7) 혼자 Play → 방 만들기 → 시작. 회전 벨트: 나무 바닥 출발·결승, 어두운 벨트 + 가로 줄무늬, 벽 위 은색 레일·나무 손잡이, 벽 밖 카운터·의자·초밥 접시·간장병·찻잔, 거대 손님 얼굴 3개, 병목 흰 종지 + 남색 테두리 + 빨강·파랑·금색 접시 더미, 빨강/검정 젓가락 + 나무색 끝, 결승 체크무늬 + 노렌 문틀이 보이는지. 다음 라운드 간장 늪: 나무 바닥, 반짝이는 간장, 웅덩이 흰 테두리, 연두 패드 위 작은 공, 벽 밖 층층 연두 언덕, 날치알 그릇, 거대 간장병(빨간 띠), 강판, 분홍 생강. 각 맵 스크린샷 1장 이상.
2. (AC8) 회전 벨트 줄무늬·결승 체크무늬, 간장 늪 웅덩이 테두리·와사비 공 위를 걸어 지나가며 걸리거나 튀지 않는지. 카메라를 한 바퀴 돌려 코스가 가려지는 곳이 없는지(특히 회전 벨트 결승 노렌 아래 — Q2).
3. (AC9) 회전 벨트: 벨트에서 뒤로 밀림, 젓가락 빨간 경고 약 1초 → 내려와 약 3초 못 움직임 → 풀림, 젓가락 끝 나무색 조각이 젓가락과 같이 내려오고 올라가는지(떨어져 남지 않는지). 간장 늪: 간장에서 느려지고 점프 안 됨, 와사비 패드에서 크게 튕김, 날치알 공에 맞으면 넘어졌다 일어남, 공이 M3처럼 굴러 내려오는지. 두 맵 완주 시간이 M3 때와 비슷한지.
4. (AC10) 라운드 소개: 회전 벨트는 출발 위 → 병목·젓가락 → 결승 노렌 → 출발선 뒤로, 간장 늪은 출발 위 → 와사비 패드·절벽 → 날치알 내리막·결승 → 출발선 뒤로 나는지. 벽 속에 묻히지 않는지. 간장 늪 마지막 구간에서 빨간 등에 잠깐 가려지는지(Q1, 보이면 리포트에 기록). 간장 늪 마지막 점은 출발 유리벽 뒤라 유리 너머로 보이는 게 정상.
5. (AC11 + 스폰) Test → Clients and Servers, 플레이어 4명: 클라이언트 2명씩 방 2개를 만들어 둘 다 시작(`Config.DEBUG.minPlayersToStart` 1). 각 방의 젓가락이 자기 맵에서만 움직이는지(다른 방 맵 위치로 Explorer에서 이동해 비교). 시작 직후 아무도 떨어지지 않고 캐릭터끼리 끼지 않는지. 혼자 시작했을 때 Spawn01이 출발 바닥 위인지. (선택) Explorer에서 회전 벨트 `Spawns`의 Spawn13~24가 모두 나무 바닥 위에 있는지 눈으로 확인.
6. (AC12) `ServerStorage`에 Folder `MapArt` → 그 안에 Model `rotating-belt`(파트 1개, 피벗 = 맵 origin)를 넣고 회전 벨트 시작 → 맵 `Decor/StudioArt`에 나타나고 그 파트를 지나갈 수 있는지.
7. (AC13) Shift+F1/F2로 두 맵이 도는 동안 프레임 50 이상 유지되는지.

## 추가한 테스트
`tests/m4-02-qa.spec.luau` (7개)
- 스폰 근거: 옛 식(M1~M3)은 12개가 출발 바닥 뒤 허공, 8개가 바닥 끝(x ±10)에 걸쳤어요
- 스폰: 새 위치 24개가 출발 바닥 안쪽, 벨트 구역(z < -14) 밖, 이름순 앞줄부터
- 스폰: 간격 3 — 판끼리 겹치지 않고 캐릭터 몸통(폭 2) 사이 1 stud 이상
- 치수: 아트 SECTIONS·결승선·간장 종지 위치가 RotatingBelt.luau 소스 상수와 같아요
- 소개 카메라(회전 벨트): 경유점 사이 경로도 장식·벽 속을 지나가지 않아요
- 이동 감시: 벨트 면제 갱신 간격이 면제 시간보다 짧아 밀리는 동안 빈틈이 없어요
- 물리 유지: 회전 벨트에서 Material을 바꾼 판정 파츠는 모두 CustomPhysicalProperties를 같이 둬요

간장 늪 경로 검사(Q1)는 지금 실패하므로 테스트로 넣지 않고 위 재현 절차로 남겼다. 고친 뒤 같은 테스트를 간장 늪까지 넓힐 것.

## 인계 메모
- 브랜치: `m4-02-qa` (`origin/m4-02-art-race` + `origin/main` 병합, push 완료)
- 끝난 것: AC1~AC6 검증, 판정 회귀·태그 전환·스폰 수정·MoveExempt 코드 리뷰, QA 테스트 7개, 리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC7~AC13. P3 Q1·Q2는 개발/기획 판단(병합을 막지 않음).
- 다음에 할 첫 단계: `m4-02-qa`(또는 `m4-02-art-race`)를 main에 병합 → 사용자 Studio 체크리스트.
- 막힌 점: 없음.
