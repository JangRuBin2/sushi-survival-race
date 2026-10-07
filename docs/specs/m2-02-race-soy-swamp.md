status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m2-02 — Race 맵 "간장 늪 & 와사비 산" (회색 박스)

- 마일스톤: M2
- GDD 근거: `docs/GDD.md` §5.2 ②, §6(넘어짐), §11.4(태그)
- 담당 개발 worktree: `m2-soy-swamp` (Rojo 포트 34873)
- 공용 파일 수정 담당: 없음
- 의존: **m2-01 머지 후 시작** (stub `src/shared/maps/SoySwamp.luau`가 이미 풀에 등록돼 있음). m2-03~m2-06과 동시에 개발 가능.

## 목표
두 번째 Race 맵. 간장 웅덩이에 빠지면 느려지고, 와사비 패드를 잘 쓰면 지름길로 튀어 오르고, 굴러오는 날치알 공에 맞으면 넘어진다. 회전 벨트와 다른 "길 고르기" 재미를 준다.

## 범위
- 포함 (이 worktree가 고치는 파일: `src/shared/maps/SoySwamp.luau`, 새 파일 `src/shared/maps/SoySwamp*.luau`(장애물 헬퍼), 새 파일 `tests/map-soy-swamp.spec.luau`(선택))
  - **코스 구성** (origin에서 로컬 -Z로 뻗음, 전체 길이 150~190 studs 권장):
    1. 출발 구간 — `Spawns` 24개 (`Spawn01`~`Spawn24`)
    2. **간장 늪** — 넓은 바닥(폭 20 이상)에 간장 웅덩이 여러 개. 웅덩이 사이로 폭 3~4 studs의 마른 길이 구불구불 이어져서, 피해 가면 멀고 웅덩이를 가로지르면 느리다.
    3. **와사비 산** — 높이 12~16 studs의 언덕/단. 옆으로 돌아 올라가는 경사로(느리지만 안전)와, 언덕 앞의 와사비 패드(밟으면 위로 튕겨 바로 올라감, 잘 쓰면 지름길)가 둘 다 있다.
    4. **날치알 내리막** — 결승 쪽에서 출발 쪽으로 기울어진 경사로. 위에서 날치알 공이 주기적으로 굴러 내려온다.
    5. 결승 구간 + `FinishLine` (CanCollide false, 네온)
    - 양옆 벽으로 코스 밖으로 떨어지지 않게 막는다(와사비로 튕겨서 넘어갈 수 없을 만큼 높게).
  - **장애물 (전부 서버에서 판정, `CollectionService` 태그로 동작)**
    - `SoySauce` 태그 (간장 웅덩이 영역 파츠): 안에 있는 레이서는 이동 속도 50% (`Config.Character.WalkSpeed × 0.5`), 점프 불가. 영역을 벗어나면 `Config.Character.WalkSpeed`·`Config.Character.JumpPower`로 즉시 복구.
    - `Wasabi` 태그 (패드 파츠): 밟으면 위(+앞)로 크게 튕긴다. 같은 플레이어는 1초 쿨다운. 튕길 때 그 캐릭터 머리 위에 "매워!!" 글자(BillboardGui)를 1초 띄운다.
    - 날치알 공: 내리막 위쪽에서 2~3초 간격으로 생성되는 공(지름 4~6 studs, 주황색). 굴러 내려가다 바닥 끝이나 8초 뒤 사라진다. 레이서에 닿으면 그 레이서가 **1초 동안 넘어진다**(`Humanoid.PlatformStand = true` 후 복구, 같은 플레이어 1.5초 쿨다운). 공의 네트워크 소유권은 서버로 고정한다.
  - **판정**: 결승선 통과 → `ctx.pass(player)` (플레이어당 1번). 점프해서 넘어도 통과로 판정돼야 한다 (M1 B2와 같은 문제를 만들지 않게: 키 큰 트리거나 위치 기반 판정 — B2 수정에서 쓴 방식을 따른다). 결승선 뒤에 바닥과 끝 벽이 있다. origin보다 40 studs 아래로 떨어지면 `ctx.eliminate(player)` (안전망).
  - **태그 규칙 (M1 B10)**: 장애물 파츠에 태그를 붙이고, `start`에서 **`ctx.model` 하위에 있는 태그 파츠만** 찾아 동작시킨다 (예: `CollectionService:GetTagged("SoySauce")`를 `ctx.model:IsAncestorOf(part)`로 거름). (B10 (A)로 확정)
  - 모든 연결·스레드·생성한 공은 `ctx.cleanup`에 넣는다. 상태는 모듈 전역이 아니라 `ctx`/지역 변수에 둔다(여러 방 동시 진행).
  - 튜닝 초기값(맵 모듈 안 지역 상수, 플레이테스트로 조정): 와사비 튕김 위 80 / 앞 30 studs/s, 공 간격 2~3초, 넘어짐 1초.
- 제외:
  - 넘어짐 래그돌 연출, "매워!!" 효과음·파티클 (M3)
  - 아트, 간장 텍스처 (M4)
  - `RoundService`/`MatchService`/Config 변경 (필요하면 사용자에게 알림)

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `Maps.get("soy-swamp")`이 `MapTypes.validate`를 통과하고 kind가 `Race`, displayName·rule이 m2-01 표와 같다 (m2-01의 maps.spec이 확인).
- [ ] AC2: `lune run tests` 전체가 통과한다 (모듈을 require만 해도 Roblox API를 부르지 않는다 — Roblox API는 함수 안에서만 쓴다).

### Studio 확인
구조 확인은 DEV-SETUP 3-6과 같은 방식(Command bar로 `Maps.get("soy-swamp").build(CFrame.new(0,10,0))`), 동작 확인은 `Config.DEBUG.forceMapPlan = { "soy-swamp", "rotating-belt", "skewer-showdown" }`로 혼자 시작한다.
- [ ] AC3: 지은 Model 안에 `Spawns`(Spawn01~Spawn24), `FinishLine`, `SoySauce` 태그 파츠 1개 이상, `Wasabi` 태그 파츠 1개 이상이 있다.
- [ ] AC4: 출발 → 간장 늪 → 와사비 산 → 날치알 내리막 → 결승 순서로 바닥이 이어지고, 양옆 벽 때문에 코스 밖으로 걸어서 나갈 수 없다.
- [ ] AC5: 간장 웅덩이에 들어가면 눈에 띄게 느려지고 Space를 눌러도 점프가 안 된다. 나오면 바로 원래 속도로 걷고 점프할 수 있다.
- [ ] AC6: 와사비 패드를 밟으면 캐릭터가 크게 튀어 오르고 머리 위에 "매워!!"가 잠깐 뜬다. 패드에서 튀어 오르면 경사로를 돌아가지 않고 와사비 산 위로 올라갈 수 있다.
- [ ] AC7: 날치알 공이 몇 초마다 내리막을 굴러 내려온다. 공에 맞으면 캐릭터가 약 1초 넘어졌다가 다시 움직일 수 있다. 공은 계속 쌓이지 않고 사라진다(30초 뒤 Workspace의 공 개수가 몇 개 이하로 유지).
- [ ] AC8: 결승선을 넘으면 "✅ 1번째로 통과했어요!"가 한 번만 뜬다. 결승선 바로 앞에서 점프해서 넘어도 통과로 판정되고 코스 밖으로 떨어지지 않는다.
- [ ] AC9: 라운드가 끝나면 맵 Model과 날치알 공이 모두 사라지고, 다음 라운드에서 캐릭터 속도·점프가 정상이다 (간장 안에서 라운드가 끝났어도).
- [ ] AC10: 플레이어 4명(Test → Clients and Servers)으로 같은 맵을 돌려도 각자 간장 감속·와사비·공 넘어짐이 따로 적용되고 서버 Output에 에러가 없다.
- [ ] AC11: 잘 아는 플레이어가 혼자 달려서 결승까지 **약 15~60초** 안에 도착한다 (Race 제한 90초 안에 여유). 걸린 시간을 개발 메모나 QA 리포트에 적는다. (2026-10-08 수정: 하한 30초 → 15초, 결정 기록 참고)

## 공용 파일 변경
- `shared/Config.luau`: 없음 (`Config.Character.WalkSpeed/JumpPower`는 읽기만)
- `shared/Remotes.luau`: 없음

## 결정 기록
- 2026-10-08 · 날치알 공 "맞으면 넘어져요"를 M2에서 어떻게 · `PlatformStand` 1초로 표현, 래그돌은 M3 · planner
- 2026-10-08 · 간장 효과가 언제 풀리나 · 웅덩이 영역을 벗어나는 즉시 · planner (GDD에 지속시간 없음, 가장 단순한 해석)
- 2026-10-08 · **확정 M1 B10 — 장애물 동작 규칙** (메인 세션 경유) · (A) 장애물 파츠에 태그를 붙이고, `start`에서 `ctx.model` 하위의 태그 파츠만 찾아 동작시킨다. m2-03, m2-04에도 같은 규칙. 회전 벨트를 이 규칙으로 바꾸는 건 M2 범위 밖(필요하면 별도 작업) · user
- 2026-10-08 · **질문 (developer → planner)** AC11 "혼자 결승까지 30~60초" vs 코스 길이 150~190 권장 · 이 코스(174 studs)는 WalkSpeed 16 기준 직선 11초, 늪 지그재그·와사비·공 피하기를 넣어도 잘 아는 플레이어는 약 18~25초로 예상. AC11을 "60초(제한 90초) 안에 도착" 상한으로 읽고 구현했다. 30초 이상이 꼭 필요하면 코스를 늘리거나(스펙 길이 범위 밖) 장애물을 더 넣어야 하니 기획 확인 필요 · developer
  - **답 (planner, 2026-10-08, 확정)**: **AC11 쪽을 고친다. 코스 길이(150~190 studs)와 지금 구현(174 studs, 혼자 약 18~25초)은 그대로 둔다. 코드 변경 없음.** 수치 조정 수준이라 planner가 결정했다 (GDD 원칙과 충돌 없음).
    - 이유 1: GDD가 정한 건 Race 최대 90초와 한 판 4~5분뿐이고, 30초 하한은 스펙에서 정한 초기값이었다. Race는 목표 인원이 들어오는 순간 끝나서, 실제 라운드 길이는 혼자 달리는 시간보다 다인원 혼잡(웅덩이 병목, 와사비 패드 줄서기, 공 넘어짐)과 목표 인원 순번이 결정한다. 혼자 20초대면 다인원 실전은 대략 30~45초가 예상된다.
    - 이유 2: 한 판 시간 예산. 4라운드 = 시작 3초 + 라운드마다 소개 3초·결과 5초(약 32초) + Race 2판 약 35~45초씩 + Survival 최대 60초 + 결승 60~90초 + 우승 6초 → 약 4~5분. Race를 혼자 30~60초로 늘리면 다인원 실전에서 60초를 넘겨 한 판이 5분을 넘기기 쉽다.
    - 이유 3: 회전 벨트(약 120 studs, 벨트가 뒤로 밂)와 비슷한 체감 길이라 두 Race 맵의 길이가 고르다.
    - 후속: m2-07 통합 테스트(AC9 한 판 길이)에서 Race 라운드가 너무 빨리 끝나 재미가 없다는 의견이 나오면 그때 코스를 늘리거나 장애물을 더한다 (그때 바꿀 곳: `SoySwampLayout.luau`의 구간 길이 상수, `tests/map-soy-swamp.spec.luau`의 길이 범위 테스트).
- 2026-10-08 · 와사비 튕김을 서버에서 어떻게 거나 · 캐릭터 물리는 클라이언트 소유라 서버가 속도만 바꾸면 덮어써질 수 있어서, 서버가 `LinearVelocity`(위 80/앞 30)를 0.08초 붙였다 떼는 방식으로 했다 (스펙 범위 안의 구현 선택). 강제 구간만큼 최고점이 약 6 studs 더 높다 → 플레이테스트로 조정 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->

### 인계 메모
- 브랜치: `worktree-m2-soy-swamp` (worktree `m2-soy-swamp`, Rojo 포트 34873)
- 끝난 것: 코스·장애물·판정 구현, 순수 로직 테스트, 검증 4종 통과 → `in-qa`
- 남은 것: QA, Studio 확인(AC3~AC11), AC11 기획 답변(결정 기록 "질문")
- 막힌 점: 없음

### 바뀐 파일
- `src/shared/maps/SoySwamp.luau` — stub을 실제 맵으로 교체 (build: 회색 박스 코스, start: 결승선 위치 판정·낙하 탈락 + 장애물 Heartbeat)
- `src/shared/maps/SoySwampLayout.luau` (새) — 코스 치수·튜닝 상수와 순수 계산(판 위 판정, 간장 속도, 공 수명, 쿨다운). Roblox API 없음
- `src/shared/maps/SoySwampHazards.luau` (새) — `SoySauce`/`Wasabi` 태그 파츠(ctx.model 하위만)와 날치알 공 동작
- `tests/map-soy-swamp.spec.luau` (새) — AC1, 코스 치수 약속(길이·폭·지그재그 마른 길·산 높이·튕김 최고점 vs 벽·경사로), 판정 계산 12개
- 공용 파일 변경 없음

### 코스 (로컬 z, 0 = 출발 끝, 폭 24, 벽 높이 48)
| 구간 | z | 내용 |
|---|---|---|
| 출발 | 0 ~ -16 | Spawn01~24 (6×4), 뒤에 StartWall |
| 간장 늪 | -16 ~ -60 | 웅덩이 3개(20×10, `SoySauce`), 오른쪽→왼쪽→오른쪽 폭 4 마른 길 + 줄 사이 가로 마른 길 |
| 산 앞 평지 | -60 ~ -72 | 와사비 패드 1개(12×5, `Wasabi`, 절벽 6~11 studs 앞) |
| 와사비 산 | -72 ~ -112 | 높이 12. 왼쪽 몸통(x -12~4)은 앞이 절벽. 오른쪽 지면 통로(x 8~12)로 산 뒤까지 가서 경사로(x 4~8)를 되돌아 올라감 |
| 날치알 내리막 | -112 ~ -160 | 높이 12 → 20 (결승 쪽이 높음). z -157에서 지름 5 공이 2~3초마다 생성, 최고 속도 28, 8초 또는 내리막 아래 끝을 지나면 삭제, 서버 소유 |
| 결승 | -160 ~ -174 | 높이 20 단, FinishLine z -170 (위치 판정), EndWall |

### 동작 요약
- 간장: 매 Heartbeat에 HumanoidRootPart가 웅덩이 판 위 0~5 studs 안이면 WalkSpeed 8·JumpPower 0, 벗어나면 즉시 `Config.Character` 값. 통과·탈락해서 레이서가 아니게 된 사람은 되돌리지 않고 잊는다(탈락 고정을 풀지 않게. 통과자/탈락자/다음 라운드 배치 때 `CharacterUtil`이 기본값으로 돌린다 → AC9).
- 와사비: 패드 위 0~4.5 studs면 `LinearVelocity`로 위 80·앞 30을 0.08초 걸고 머리 위 "매워!!" BillboardGui 1초. 플레이어별 1초 쿨다운.
- 날치알: 공과 HumanoidRootPart 거리 ≤ 4면 `PlatformStand = true` 1초 뒤 복구(아직 레이서일 때만), 맞은 순간부터 1.5초 쿨다운.
- 모든 연결·스레드·공·GUI·LinearVelocity는 `ctx.cleanup`, 상태는 start 안 지역 변수 (방마다 따로).

### Studio 확인 방법
1. `rojo serve --port 34873`, Studio 플러그인을 34873에 연결.
2. 구조(AC3): Command bar에서
   `local M=require(game.ReplicatedStorage.Shared.maps).get("soy-swamp"); local m=M.build(CFrame.new(0,10,0)); m.Parent=workspace`
   → Spawns 24개, FinishLine, SoyPuddles(3, 태그 SoySauce), WasabiPads(1, 태그 Wasabi). 태그는 `game.CollectionService:GetTags(part)`로 확인. 확인 후 `m:Destroy()`.
3. 동작(AC4~AC9, AC11): `Config.DEBUG.forceMapPlan = { "soy-swamp", "rotating-belt", "skewer-showdown" } :: { string }?`로 바꾸고 F5 혼자 시작 (커밋 전 nil로 되돌림).
   - 간장 웅덩이에 들어가면 절반 속도, Space 무시 → 나오면 바로 정상 (AC5)
   - 초록 네온 패드 밟기 → 크게 튀어 "매워!!", 절벽 위로 착지 (AC6). 오른쪽 통로 끝에서 경사로로 돌아서도 올라갈 수 있는지
   - 내리막에서 주황 공이 굴러오고 맞으면 약 1초 넘어짐. 30초 뒤 Explorer에서 `soy-swamp > TobikoBalls` 자식이 5개 이하 (AC7)
   - 결승선 직전 점프로 넘기 → "✅ 1번째로 통과했어요!" 한 번 (AC8)
   - 간장 안에 서서 시간 종료(90초)까지 기다린 뒤 다음 라운드에서 속도·점프 정상, 맵과 공 사라짐 (AC9)
   - 결승까지 걸린 시간 (AC11, 결정 기록의 질문 참고)
4. 다인원(AC10): Test → Clients and Servers 4명, 서로 다른 장애물 효과가 각자에게만 걸리는지, 서버 Output 에러 없음.

### 남은 이슈 / 확인 필요
- 와사비 튕김·공 속도·넘어짐은 튜닝 초기값. 특히 패드에서 서 있기만 해도(입력 없이) 산 위에 착지하는지 Studio에서 확인 필요.
- 서버가 설정한 PlatformStand가 클라이언트 소유 캐릭터에서 눈에 띄게 "넘어짐"으로 보이는지는 Studio 확인 필요 (래그돌은 M3).

