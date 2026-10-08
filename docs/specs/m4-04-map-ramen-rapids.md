status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-04 — 새 Race 맵: 라멘 국물 급류 (`ramen-rapids`)

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §5.2 ③ (라멘 그릇 속 국물 급류, 떠다니는 차슈·나루토, 회전 젓가락 막대), §5.2 Race(최대 90초), §11.4(태그, 자기 방 맵만)
- 참고: `CLAUDE.md` "맵 모듈 공통 인터페이스", `docs/specs/m4-02-art-race-maps.md` "공통 규칙"(아트), 기존 `SoySwampHazards.luau`(서버 LinearVelocity로 튕기기), `SkewerShowdown.luau`(회전 막대 넉백)
- 담당 개발 worktree: `m4-ramen` (Rojo 포트 34874)
- 공용 파일 수정 담당: 없음 (id·이름·규칙 문구·등록은 m4-01이 확정)
- 의존: **m4-01 머지 후 시작** (stub 파일을 덮어씀)
- **이 스펙이 고치는 파일**: `src/shared/maps/RamenRapids.luau`(stub 덮어쓰기), 새 파일 `src/shared/maps/RamenRapidsLayout.luau`, `src/shared/maps/RamenRapidsLogic.luau`, `src/shared/maps/RamenRapidsArt.luau`, `tests/map-ramen-rapids.spec.luau`

## 목표
거대한 라멘 그릇 안을 국물 급류에 휩쓸리며 내려가는 Race. 급류가 앞으로 밀어 줘서 빠르지만 옆으로 쏠려 떨어지기 쉽고, 가라앉는 차슈 위를 건너고, 마지막엔 회전하는 젓가락 막대를 피한다. 회전 벨트(거슬러 달리기)·간장 늪(느려짐)과 손맛이 다르다.

## 범위
- 포함 (수치는 전부 기본값, `RamenRapidsLayout` 상수로 모아 둔다):
  1. **코스** (origin 앞 = 로컬 -Z, 전체 길이 약 300 studs, 출발 → 결승이 약 40 studs 내려감):
     - **구간 A 출발** (z 0 ~ -16, 폭 24, 평지): 스폰 24개.
     - **구간 B 급류 미끄럼틀** (z -16 ~ -126, 폭 20, 약 12도 내리막, 양옆 낮은 벽 높이 3): 바닥이 `Broth` 태그 구역. 그 위에 서 있으면 **앞쪽으로 14 studs/s**까지 밀고, 구간 안 **소용돌이 3곳**(지름 8, 좌우 번갈아)은 벽 쪽 옆으로 10 studs/s 민다. 벽이 낮아서 옆으로 크게 밀리면 넘어갈 수 있다 → 떨어지면 아래 국물 = 탈락(낙하 판정). **면발 줄기**(낮은 장애물, 높이 1.5, 점프로 넘음) 4개.
     - **구간 C 토핑 건너기** (z -126 ~ -206): 바닥 없음(아래로 떨어지면 탈락). **차슈 발판**(지름 9 원판) 9개를 3줄 지그재그로 두고, 각 차슈는 주기 6초로 **천천히 가라앉았다 떠오름**(위아래 3 studs, 가장 낮을 때 국물 아래 0.5 studs로 잠겨 미끄러짐 없이 그냥 내려감 — 그 위에 있으면 따라 내려가 다음 것으로 뛰어야 함). 차슈마다 위상이 달라 항상 건널 길이 있다. **나루토 발판**(지름 7, 분홍 소용돌이 무늬) 4개는 가라앉지 않고 제자리에서 **보기 좋게만 천천히 돈다**(회전은 장식 파트만, 밟는 원판은 고정 — 회전 발판 위 미끄러짐 문제를 피함).
     - **구간 D 회전 젓가락 막대** (z -206 ~ -276, 원형 발판 지름 40 두 개를 이어 붙임): 발판마다 가운데 축에 **젓가락 막대 1쌍**(길이 = 반지름, 높이 2.5, 바닥 위 1.5)이 돈다. 첫 발판 40도/s, 둘째 55도/s, 방향 반대. 맞으면 바깥으로 넉백(`SkewerShowdown`과 같은 방식) + 넘어짐. 점프로 넘을 수 있다.
     - **구간 E 결승** (z -276 ~ -300, 폭 24): `FinishLine` 통과 → `ctx.pass`. 그릇 가장자리(숟가락 모양 출구) 느낌.
  2. **판정**: 결승선 통과 → `ctx.pass`. 그 구간 바닥보다 25 studs 아래로 떨어지면 → `ctx.eliminate` (각 구간 바닥 높이가 달라서 origin 기준 대신 구간별 기준 높이를 `RamenRapidsLogic.fallLineAt(z)`로). 시간 제한은 `Config.TimeLimit.Race`(90초).
  3. **장애물 구현 규칙**: 태그 `Broth`(밀기 구역), `Chashu`(가라앉는 발판), `NoodleSweeper`(회전 젓가락 막대). `start`에서 `ctx.model` 하위 태그 파츠만 동작. 상태는 `ctx`(또는 `start` 안 지역 변수)에 둔다.
     - 밀기는 회전 벨트와 같은 방식(서버가 `AssemblyLinearVelocity`를 목표 속도 쪽으로 가속). 밀 때 `MoveExempt.mark(character)`.
     - 가라앉는 차슈와 회전 막대는 서버 Heartbeat에서 앵커 파츠 CFrame을 바꾼다. 위치·각도는 순수 함수(`RamenRapidsLogic.chashuHeight(i, t)`, `sweeperAngle(i, t)`)로.
     - 넉백은 `SoySwampHazards` 와사비처럼 서버 `LinearVelocity`를 짧게 붙이는 방식 + `MoveExempt.mark`.
  4. **소리**: 기존 cue만 쓴다 (`MapSfx`): 급류에 들어갈 때 `SoySlow`, 막대에 맞을 때 `SkewerWhoosh`, 차슈가 가라앉기 시작할 때 소리는 없음. 새 cue가 꼭 필요하면 결정 기록에 적고 사용자에게 알린다(SfxCues는 이 스펙 범위 밖).
  5. **아트** (m4-02 공통 규칙): 그릇 안쪽 벽(흰 도자기, 바깥 빨간 무늬), 국물(주황 갈색 반투명 `Glass`, Transparency 0.2), 떠다니는 파·김·삶은 달걀 반쪽 장식(코스 밖·국물 위), 거대한 젓가락 한 쌍이 그릇 위를 가로지름(머리 위 20 이상), 김(ParticleEmitter 3개). `IntroCamera` 4점.
  6. **순수 로직 분리**: `RamenRapidsLayout`(치수·스폰·구간 표), `RamenRapidsLogic`(차슈 높이, 막대 각도, 밀기 벡터, 낙하선, 진행도) — Roblox 자료형 없이 숫자로.
- 제외:
  - 국물 물리(Terrain Water) — 판정 안정성 때문에 파츠로만
  - 맵 안 랜덤 배치

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/map-ramen-rapids.spec.luau`)
- [ ] AC1: 레이아웃이 `MapTypes.validate`를 통과하고(Spawns 24, FinishLine), 스폰 24개가 출발 구간 안에서 서로 3 studs 이상 떨어져 있다.
- [ ] AC2: `chashuHeight`로 0~60초를 0.1초 간격으로 보면, **어느 시각이든** 구간 C를 건너는 경로(가로 거리 7 studs 이하로 이어진 발판 사슬, 각 발판 높이가 잠김 아님)가 하나 이상 있다.
- [ ] AC3: 차슈 높이는 주기 6초, 위아래 폭 3 안에 있다. 두 회전 막대의 각속도가 40·55도/s이고 방향이 반대다.
- [ ] AC4: `fallLineAt(z)`가 각 구간 바닥보다 25 낮다. 구간 B 소용돌이 밀기 벡터가 벽 쪽(좌우 번갈아)이고 앞쪽 성분은 14 이하다.
- [ ] AC5: 진행도(로컬 -Z)가 코스를 따라 단조 증가한다(결승이 가장 큼).
- [ ] AC6: 장식이 `MapKitLogic.validate` 통과, 600개 이하, 시야 상자와 안 겹침.
- [ ] AC7: 검증 명령 4개 통과 + 기존 `maps` 테스트(6맵 풀) 통과.

### Studio 확인 (`forceMapPlan = { "ramen-rapids", "hot-plate", "soy-swamp", "skewer-showdown" }`)
- [ ] AC8: 혼자 완주할 수 있고, 급류 구간에서 몸이 앞으로 빨리 밀리며 소용돌이에서 벽 쪽으로 쏠린다.
- [ ] AC9: 차슈 위에 서 있으면 같이 천천히 내려가고, 잠기기 전에 다음 차슈로 뛰어 건널 수 있다. 차슈·나루토 위에서 미끄러져 저절로 떨어지지 않는다.
- [ ] AC10: 회전 젓가락 막대에 맞으면 바깥으로 밀려 넘어지고(@_@), 점프로 넘을 수 있다.
- [ ] AC11: 어느 구간에서든 떨어지면 1초 안에 탈락하고 탈락 연출이 나온다. 결승선을 넘으면 통과(대기석으로).
- [ ] AC12: 4명 이상 랜덤 판에서 이 맵이 첫 라운드로 나왔을 때 처음 하는 사람이 60~90초 안에 목표 인원이 차는 정도의 난이도다 (사용자 확인, 바꿀 수치를 알려 주면 Layout 상수만 고침).
- [ ] AC13: 2개 방이 동시에 이 맵을 돌려도 각 방의 차슈·막대가 자기 맵에서만 움직인다.

## 공용 파일 변경
- 없음

## 사용자 작업 (스펙을 막지 않음)
- AC12 난이도 체감. (선택) `assets/map-art/ramen-rapids.rbxm`.

## 결정 기록
- 2026-10-08 · 떠다니는 토핑 · 옆으로 움직이는 발판은 캐릭터가 같이 안 움직여 미끄러지는 문제가 있어 **위아래로 가라앉는 차슈**와 **제자리 회전 장식 나루토**로 정함 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 코스 길이 약 300 studs, 내리막 + 급류 밀기로 회전 벨트(120 studs, 거슬러 달림)보다 길지만 체감 시간은 비슷하게 · **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 소리는 기존 cue 재사용 (SfxCues 수정 없음) · planner
- 2026-10-08 · **잠긴 차슈 = 밟을 수 없음**: 윗면이 수면 아래로 내려간 동안(주기의 약 27%, 1.6초) 서버가 `CanCollide = false`로 바꿔서 위에 있던 사람은 국물로 빠져 낙하 탈락. "잠기기 전에 다음 차슈로 뛰어야 함"을 그대로 판정으로 옮긴 해석 · **기본값으로 진행, 사용자 수정 가능** · developer
- 2026-10-08 · **젓가락 막대 치수 해석**: "1쌍" = 젓가락 두 짝을 위아래로 겹친 막대 하나(두께 2.5, 중심이 바닥 위 1.5 → 0.25~2.75), 길이 = 반지름(축에서 바깥 끝까지 한쪽 팔). 맞음 판정은 `SkewerShowdownLogic.isHit` 재사용. 서 있으면 맞고 점프(발 높이 약 6.4)로 넘음 · **기본값, 수정 가능** · developer
- 2026-10-08 · **높이**: 급류 12도 × 110 = 약 23.4 내려가고, 토핑·막대·결승은 국물 수면(-31) + 1 = **-30**. 출발 → 결승 약 30 studs 내려감(스펙 "약 40"보다 작음 — 급류 끝에서 토핑으로 더 크게 떨어뜨리면 착지가 어려워져서). `RamenRapidsLayout.BROTH_Y` 하나로 조정 가능 · developer
- 2026-10-08 · **C 구간 낙하선 기준**: 바닥이 없어서 고정 발판(나루토) 윗면 = 회전 발판 높이(-30)를 바닥으로 봄 → 낙하선 -55. 낙하선이 출발 → 결승으로 갈수록 높아지지 않게 · developer
- 2026-10-08 · **급류 밀기**: 회전 벨트처럼 "그 방향 속도가 목표보다 느릴 때만 가속"(앞 14, 소용돌이 옆 10). 앞으로 걷는 속도(16)가 이미 14보다 빨라서 걸을 때는 밀기가 더해지지 않고, 서 있거나 옆/뒤로 갈 때 밀림. 더 빠르게 느끼게 하려면 `BROTH_PUSH_SPEED`를 16 이상으로 · developer
- 2026-10-08 · **QA 후 수정 (R1)**: 급류 끝(z -126) 바로 아래에 넓은 고정 착지판 `LandingRaft`(폭 24, z -126~-142, 나루토 높이 -30)를 둠. 급류 끝 어디서 걸어 나가도, 밀기 최고 속도(20)로 점프해도 1 stud 이상 여유로 착지 (테스트 `QA R1`). 그래서 토핑 배치를 줄 간격 9로 다시 짬: 차슈 2(z -147) → 나루토(-156) → 차슈 3(-165) → 나루토(-174) → 차슈 2(-183) → 나루토(-192) → 차슈 2(-201), 첫 나루토는 착지판 왼쪽 옆 갈림길(x -17, z -147). 건너기 시작점(`gapFromRapids`)은 이제 착지판 끝 · developer
- 2026-10-08 · **QA 후 수정 (R2)**: `BROTH_PUSH_SPEED` 14 → **20**(걷기 16보다 빨라서 달려도 밀림), 가속 30 → 40. 소용돌이 안에서는 앞 밀기를 14(`WHIRLPOOL_FORWARD_SPEED`)로 줄이고 옆 10 → 합쳐도 약 17 studs/s라 이동 감시 상한(80 studs/s)의 절반 아래, 밀 때마다 `MoveExempt.mark`(0.5초 갱신) 그대로 (테스트 `QA R2`) · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 2026-10-08 · 구현 (브랜치 `m4-04-ramen`)
**바뀐 파일**
- `src/shared/maps/RamenRapids.luau` — stub 덮어씀. build(구간 A~E, 태그 `Broth`·`Chashu`·`NoodleSweeper`, 장식·김 3개·IntroCamera·`attachStudioArt`), start(Heartbeat 하나에서 차슈 오르내림·막대 회전·나루토 장식 회전 → 결승선/낙하 판정 → 급류 밀기·막대 넉백). id·kind·displayName·rule 그대로.
- `src/shared/maps/RamenRapidsLayout.luau` (새) — 치수·튜닝 상수, 구간 표, 스폰 24개, 차슈 9·나루토 4·소용돌이 3·면발 4·막대 2 배치.
- `src/shared/maps/RamenRapidsLogic.luau` (새) — `chashuHeight`, `chashuSubmerged`, `sweeperAngle`, `sweeperHit`, `pushVector`, `pushDelta`, `whirlpoolAt`, `floorAt`, `fallLineAt`, `progress`, `crossingPath`(AC2 경로 탐색).
- `src/shared/maps/RamenRapidsArt.luau` (새) — 장식 `DecorSpec` 161개(그릇 벽·빨간 무늬·남색 테두리·바닥, 국물 수면 Glass 0.2, 파·김·달걀 반쪽·면발, 거대한 젓가락 2개 y 34~37, 숟가락 출구), 김 자리 3, IntroCamera 4점, 구간별 시야 상자 5개.
- `tests/map-ramen-rapids.spec.luau` (새) — 16개 (AC1~AC6 + 막대 맞음·pushDelta·면발·IntroCamera).
- 공용 파일 변경 없음.

**장애물 동작**
- 급류: `Broth` 판 위(판 윗면 + 5 안)면 `AssemblyLinearVelocity`를 앞(LookVector) 14까지 가속 30, 소용돌이 안이면 옆(RightVector, 소용돌이 쪽 벽) 10까지 가속 40. 밀 때 `MoveExempt.mark`(0.5초마다 갱신). 들어갈 때 `SoySlow` 소리.
- 차슈: `chashuHeight(i, t)`로 매 프레임 CFrame, 잠기면 CanCollide 끔.
- 막대: `sweeperAngle(i, t)`로 매 프레임 CFrame(충돌 없음), 맞으면 바깥 32 + 위 20 `LinearVelocity` 0.1초 + PlatformStand 1초 + `MoveExempt.mark` 1.5초 + `SkewerWhoosh`. 같은 사람 1초 쿨다운.
- 판정: 결승선 로컬 z 통과 → `ctx.pass`, 로컬 y < `fallLineAt(z)` → `ctx.eliminate`.

**Studio 확인 방법**
1. `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 `{ "ramen-rapids", "hot-plate", "soy-swamp", "skewer-showdown" }`로 바꾸고(커밋하지 말 것) Play → 방 만들기 → 시작.
2. AC8: 급류에서 가만히 서 있으면 앞으로 흘러가고, 소용돌이(진한 원)에 들어가면 벽 쪽으로 쏠림. 벽(3)을 점프로 넘으면 떨어져 탈락.
3. AC9: 차슈 위에 서서 같이 내려가는지, 수면 아래로 잠기면 빠지는지, 잠기기 전에 옆 차슈·나루토로 건널 수 있는지. 미끄러져 떨어지지 않는지.
4. AC10: 회전 막대에 일부러 맞아 바깥으로 튕겨 넘어지는지(@_@), 점프로 넘을 수 있는지.
5. AC11: 각 구간(급류 옆, 토핑 사이, 원판 밖)에서 떨어지면 1초 안에 탈락 연출, 결승선 넘으면 통과.
6. AC13: Test → Clients and Servers 4명, 방 2개를 만들어 둘 다 이 맵으로 시작 → 각 방 차슈·막대가 자기 맵에서만 움직이는지.
7. AC12(난이도)는 사용자 체감. 바꿀 값은 `RamenRapidsLayout` 상수(밀기 속도, 차슈 주기·위상, 막대 속도, 넉백).

**남은 이슈 / 확인 필요**
- 서버가 클라이언트 소유 캐릭터의 `AssemblyLinearVelocity`를 바꾸는 방식(회전 벨트와 같음)이 Studio에서 충분히 느껴지는지 확인 필요. 약하면 와사비처럼 `LinearVelocity`(힘 제한) 방식으로 바꿀 수 있음.
- 앵커 차슈를 CFrame으로 올릴 때 위에 선 캐릭터가 덜컹거리는지 확인 (최고 1.6 studs/s라 괜찮을 것으로 예상).
- 결승까지 내려가는 높이가 스펙 "약 40"보다 작은 약 30 (결정 기록).
