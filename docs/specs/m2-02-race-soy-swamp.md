status: ready
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
  - **태그 규칙 (M1 B10)**: 장애물 파츠에 태그를 붙이고, `start`에서 **`ctx.model` 하위에 있는 태그 파츠만** 찾아 동작시킨다 (예: `CollectionService:GetTagged("SoySauce")`를 `ctx.model:IsAncestorOf(part)`로 거름). 사용자가 결정 기록의 B10 질문에서 다른 안을 고르면 그 방식으로 바꾼다 — 수용 기준은 어느 쪽이든 같다.
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
구조 확인은 DEV-SETUP 3-6과 같은 방식(Command bar로 `Maps.get("soy-swamp").build(CFrame.new(0,10,0))`), 동작 확인은 `Config.DEBUG.forceMapPlan = { "soy-swamp", "rotating-belt", "skewer-bridge" }`로 혼자 시작한다.
- [ ] AC3: 지은 Model 안에 `Spawns`(Spawn01~Spawn24), `FinishLine`, `SoySauce` 태그 파츠 1개 이상, `Wasabi` 태그 파츠 1개 이상이 있다.
- [ ] AC4: 출발 → 간장 늪 → 와사비 산 → 날치알 내리막 → 결승 순서로 바닥이 이어지고, 양옆 벽 때문에 코스 밖으로 걸어서 나갈 수 없다.
- [ ] AC5: 간장 웅덩이에 들어가면 눈에 띄게 느려지고 Space를 눌러도 점프가 안 된다. 나오면 바로 원래 속도로 걷고 점프할 수 있다.
- [ ] AC6: 와사비 패드를 밟으면 캐릭터가 크게 튀어 오르고 머리 위에 "매워!!"가 잠깐 뜬다. 패드에서 튀어 오르면 경사로를 돌아가지 않고 와사비 산 위로 올라갈 수 있다.
- [ ] AC7: 날치알 공이 몇 초마다 내리막을 굴러 내려온다. 공에 맞으면 캐릭터가 약 1초 넘어졌다가 다시 움직일 수 있다. 공은 계속 쌓이지 않고 사라진다(30초 뒤 Workspace의 공 개수가 몇 개 이하로 유지).
- [ ] AC8: 결승선을 넘으면 "✅ 1번째로 통과했어요!"가 한 번만 뜬다. 결승선 바로 앞에서 점프해서 넘어도 통과로 판정되고 코스 밖으로 떨어지지 않는다.
- [ ] AC9: 라운드가 끝나면 맵 Model과 날치알 공이 모두 사라지고, 다음 라운드에서 캐릭터 속도·점프가 정상이다 (간장 안에서 라운드가 끝났어도).
- [ ] AC10: 플레이어 4명(Test → Clients and Servers)으로 같은 맵을 돌려도 각자 간장 감속·와사비·공 넘어짐이 따로 적용되고 서버 Output에 에러가 없다.
- [ ] AC11: 잘 아는 플레이어가 혼자 달려서 결승까지 30~60초 안에 도착한다 (Race 제한 90초 안에 여유).

## 공용 파일 변경
- `shared/Config.luau`: 없음 (`Config.Character.WalkSpeed/JumpPower`는 읽기만)
- `shared/Remotes.luau`: 없음

## 결정 기록
- 2026-10-08 · 날치알 공 "맞으면 넘어져요"를 M2에서 어떻게 · `PlatformStand` 1초로 표현, 래그돌은 M3 · planner
- 2026-10-08 · 간장 효과가 언제 풀리나 · 웅덩이 영역을 벗어나는 즉시 · planner (GDD에 지속시간 없음, 가장 단순한 해석)
- 2026-10-08 · **[사용자 확인 필요] M1 B10 — 장애물 동작 규칙** · 선택지: (A) 태그를 붙이고 `start`에서 `ctx.model` 하위의 태그 파츠만 찾아 동작 **(추천: CLAUDE.md 태그 규칙을 지키면서 여러 방 동시 진행에도 안전)** / (B) 태그는 표시용, 동작은 맵 Model 안 폴더(`Hazards` 등) 순회 — 지금 회전 벨트 방식, CLAUDE.md 문구를 고쳐야 함 / (C) 전역 태그 서비스 하나가 모든 방의 태그 파츠를 돌림 — 방별 ctx와 연결하기 번거로움. 결정 전까지 (A)로 개발하고, 다른 안이 정해지면 개발 메모에 맞춰 바꾼다. 수용 기준은 바뀌지 않아서 이 스펙은 ready로 둔다. 같은 규칙이 m2-03, m2-04에도 적용된다. · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
